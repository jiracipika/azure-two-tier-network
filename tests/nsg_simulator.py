"""Offline NSG rule simulator: parses the real HCL rule matrix and replays flows.

Reads modules/hub_network/nsg-rules.tf (azurerm_network_security_rule resources)
and modules/hub_network/main.tf (locals + cidrsubnet subnet plan + variable
default), so the security tests assert against the actual configuration that
Terraform would deploy — not a hand-copied table.
"""

from pathlib import Path
import ipaddress
import re

TF = Path(__file__).resolve().parents[1] / "infra" / "terraform"

# Azure service tags the rule set uses, mapped to the flow "kind" they admit.
TAG_KIND = {
    "Internet": "internet",
    "AzureLoadBalancer": "azure_lb",
    "GatewayManager": "gateway_manager",
    "AzureCloud": "azure_cloud",
    "VirtualNetwork": "vnet",
}


def cidrsubnet(cidr: str, newbits: int, netnum: int) -> str:
    """Python equivalent of Terraform's cidrsubnet() for IPv4."""
    net = ipaddress.ip_network(cidr)
    hostbits = net.max_prefixlen - net.prefixlen - newbits
    parent_size = 1 << (net.max_prefixlen - net.prefixlen)
    if hostbits < 0 or netnum < 0 or (netnum << hostbits) >= parent_size:
        raise ValueError("invalid cidrsubnet expression")
    addr = int(net.network_address) + (netnum << hostbits)
    return f"{ipaddress.ip_address(addr)}/{net.prefixlen + newbits}"


def subnet_host(prefix: str, offset: int = 10) -> str:
    """A representative host address inside a subnet prefix."""
    return str(ipaddress.ip_network(prefix).network_address + offset)


def _parse_variable_default(name: str, text: str) -> str:
    block = re.search(rf'variable "{name}"\s*\{{(.*?)\n\}}', text, re.S)
    if not block:
        raise ValueError(f"variable {name} not found")
    m = re.search(r'default\s*=\s*\["([^"]+)"\]', block.group(1))
    if not m:
        raise ValueError(f"variable {name} has no list default")
    return m.group(1)


def load_subnet_plan() -> dict:
    """Resolve the web/app/bastion prefixes exactly as the HCL computes them."""
    main = (TF / "modules/hub_network/main.tf").read_text()
    variables = (TF / "modules/hub_network/variables.tf").read_text()
    address_space = _parse_variable_default("address_space", variables)

    plan = {}
    for key, expr in re.findall(r'^\s{2}(\w+_prefix)\s+= (.+)$', main, re.M):
        m = re.match(r'cidrsubnet\(var\.address_space\[0\], (\d+), (\d+)\)', expr.strip())
        if not m:
            raise ValueError(f"unsupported subnet expression for {key}: {expr}")
        plan[key] = cidrsubnet(address_space, int(m.group(1)), int(m.group(2)))
    return plan


def _parse_value(raw: str, plan: dict):
    raw = raw.strip()
    if raw.startswith("["):
        items = [s.strip().strip('"') for s in raw.strip("[]").split(",") if s.strip()]
        return [int(i) if i.isdigit() else i for i in items]
    if raw.startswith('"'):
        return raw.strip('"')
    if raw.lstrip("-").isdigit():
        return int(raw)
    m = re.fullmatch(r"local\.(\w+)", raw)
    if m:
        return plan.get(m.group(1), raw)
    return raw  # resource references etc. pass through as opaque strings


def load_rules() -> list:
    """Parse every azurerm_network_security_rule resource in nsg-rules.tf."""
    plan = load_subnet_plan()
    text = (TF / "modules/hub_network/nsg-rules.tf").read_text()
    rules = []
    for block in re.finditer(
        r'resource "azurerm_network_security_rule" "(\w+)" \{\n(.*?)\n\}', text, re.S
    ):
        attrs = {}
        for key, raw in re.findall(r'^\s{2}(\w+)\s+= (.+)$', block.group(2), re.M):
            attrs[key] = _parse_value(raw, plan)
        nsg_ref = attrs.get("network_security_group_name", "")
        # azurerm_network_security_group.<key>.name -> <key> (web|app|bastion)
        nsg = nsg_ref.split(".")[-2] if isinstance(nsg_ref, str) and nsg_ref.count(".") >= 2 else str(nsg_ref)
        rules.append(_compile_rule(block.group(1), attrs, nsg))
    if not rules:
        raise ValueError("no NSG rules parsed — parser and HCL drifted")
    return rules


def _compile_rule(resource_name: str, attrs: dict, nsg: str) -> dict:
    port_range = attrs.get("destination_port_range", "*")
    port_ranges = attrs.get("destination_port_ranges", [])
    ports = ["*"] if port_range == "*" and not port_ranges else (
        [str(port_range)] if not port_ranges else [str(p) for p in port_ranges]
    )
    source = attrs.get("source_address_prefix", "*")

    def port_matches(port: int) -> bool:
        return any(p == "*" or p == str(port) or _port_in(p, port) for p in ports)

    def source_matches(kind: str, ip: str, plan: dict) -> bool:
        if source == "*":
            return True
        if source in TAG_KIND:
            if TAG_KIND[source] == kind:
                return True
            if source == "Internet" and kind in TAG_KIND.values():
                return kind == "internet"
            return False
        if "/" in source:  # CIDR
            try:
                return ipaddress.ip_address(ip) in ipaddress.ip_network(source)
            except ValueError:
                return False
        return False

    return {
        "resource": resource_name,
        "name": attrs.get("name", resource_name),
        "priority": int(attrs["priority"]),
        "direction": attrs["direction"],
        "access": attrs["access"],
        "protocol": attrs["protocol"],
        "source": source,
        "ports": ports,
        "nsg": nsg,
        "port_matches": port_matches,
        "source_matches": source_matches,
    }


def _port_in(spec: str, port: int) -> bool:
    if "-" in spec:
        lo, hi = spec.split("-", 1)
        return int(lo) <= port <= int(hi)
    return spec == str(port)


def decide_flow(rules: list, plan: dict, kind: str, ip: str, port: int, nsg: str,
                direction: str = "Inbound", protocol: str = "Tcp") -> str:
    """Apply NSG semantics: lowest priority number first match wins; unmatched
    inbound traffic hits the implicit platform default-deny."""
    applicable = [
        r for r in rules
        if r["nsg"] == nsg and r["direction"] == direction and r["protocol"] in (protocol, "*")
    ]
    for r in sorted(applicable, key=lambda r: r["priority"]):
        if r["port_matches"](port) and r["source_matches"](kind, ip, plan):
            return r["access"]
    return "Deny" if direction == "Inbound" else "Allow"
