"""Security assertions over the Terraform sources — two-tier network edition.

Two layers of offline proof:

1. Flow simulation: tests/nsg_simulator.py parses the REAL
   azurerm_network_security_rule resources out of modules/hub_network,
   resolves the subnet plan (locals + cidrsubnet + variable defaults) and
   replays sample flows through NSG semantics (lowest priority number wins,
   implicit default-deny inbound). This proves "valid web routing while
   denying untrusted app and management traffic" against the actual rule
   matrix — not against a copy of it.
2. Structural invariants: pin hardening controls (deploy gate, no public IPs
   on NICs, SSH-key-only login, NAT egress, module provider declarations,
   CI safety) with regex assertions that survive terraform fmt realignment.
"""

from pathlib import Path
import re
import unittest

from nsg_simulator import cidrsubnet, decide_flow, load_rules, load_subnet_plan, subnet_host

ROOT = Path(__file__).resolve().parents[1]
TF = ROOT / "infra" / "terraform"


def read(rel: str) -> str:
    return (TF / rel).read_text()


class NsgSimulator(unittest.TestCase):
    """Sanity of the simulator itself: the plan it reads must be the plan HCL computes."""

    def test_subnet_plan_matches_cidrsubnet_semantics(self):
        plan = load_subnet_plan()
        self.assertEqual(plan["web_subnet_prefix"], cidrsubnet("10.10.0.0/16", 8, 1))
        self.assertEqual(plan["app_subnet_prefix"], cidrsubnet("10.10.0.0/16", 8, 2))
        self.assertEqual(plan["bastion_subnet_prefix"], cidrsubnet("10.10.0.0/16", 10, 1000))
        self.assertTrue(plan["web_subnet_prefix"].startswith("10.10.1."))
        self.assertTrue(plan["app_subnet_prefix"].startswith("10.10.2."))
        self.assertTrue(plan["bastion_subnet_prefix"].startswith("10.10.250."))


class WebRoutingFlows(unittest.TestCase):
    """Proof: the valid client path into the workload exists and is load-balanced."""

    @classmethod
    def setUpClass(cls):
        cls.rules = load_rules()
        cls.plan = load_subnet_plan()

    def decide(self, kind, ip, port, nsg):
        return decide_flow(self.rules, self.plan, kind, ip, port, nsg)

    def test_internet_client_http_to_web_allowed(self):
        self.assertEqual(self.decide("internet", "203.0.113.9", 80, "web"), "Allow")

    def test_health_probe_from_azurelb_allowed_on_separate_rule(self):
        self.assertEqual(self.decide("azure_lb", "168.63.129.16", 80, "web"), "Allow")
        probe_rules = [r for r in self.rules
                       if r["nsg"] == "web" and r["source"] == "AzureLoadBalancer"]
        client_rules = [r for r in self.rules
                        if r["nsg"] == "web" and r["source"] == "Internet"]
        self.assertTrue(probe_rules, "web NSG must explicitly admit LB health probes")
        self.assertTrue(client_rules, "web NSG must admit client traffic separately from probes")

    def test_internet_to_bastion_https_allowed(self):
        self.assertEqual(self.decide("internet", "203.0.113.9", 443, "bastion"), "Allow")

    def test_internet_to_app_on_any_port_denied(self):
        for port in (80, 443, 8080, 22, 3389):
            self.assertEqual(self.decide("internet", "203.0.113.9", port, "app"), "Deny",
                             f"Internet must not reach app tier on port {port}")


class AppTierIsolationFlows(unittest.TestCase):
    """Proof: untrusted app traffic is denied; the legitimate web->app path works."""

    @classmethod
    def setUpClass(cls):
        cls.rules = load_rules()
        cls.plan = load_subnet_plan()

    def decide(self, kind, ip, port, nsg):
        return decide_flow(self.rules, self.plan, kind, ip, port, nsg)

    def test_web_to_app_api_allowed(self):
        web_vm_ip = subnet_host(self.plan["web_subnet_prefix"])
        self.assertEqual(self.decide("vnet", web_vm_ip, 8080, "app"), "Allow")

    def test_lateral_app_to_app_denied(self):
        app_vm_ip = subnet_host(self.plan["app_subnet_prefix"])
        self.assertEqual(self.decide("vnet", app_vm_ip, 8080, "app"), "Deny",
                         "even in-VNet sources outside the web subnet must not reach the API")

    def test_bastion_to_app_denied_on_api_port(self):
        bastion_ip = subnet_host(self.plan["bastion_subnet_prefix"])
        self.assertEqual(self.decide("vnet", bastion_ip, 8080, "app"), "Deny",
                         "bastion manages via SSH only; it is not an API client")

    def test_app_nsg_has_no_internet_or_wildcard_source(self):
        for r in self.rules:
            if r["nsg"] == "app":
                self.assertNotIn(r["source"], ("Internet", "*", "0.0.0.0/0", "/0"))


class ManagementPlaneFlows(unittest.TestCase):
    """Proof: untrusted management traffic denied; bastion is the only SSH path."""

    @classmethod
    def setUpClass(cls):
        cls.rules = load_rules()
        cls.plan = load_subnet_plan()

    def decide(self, kind, ip, port, nsg):
        return decide_flow(self.rules, self.plan, kind, ip, port, nsg)

    def test_ssh_from_internet_denied_everywhere(self):
        for nsg in ("web", "app", "bastion"):
            self.assertEqual(self.decide("internet", "203.0.113.9", 22, nsg), "Deny",
                             f"port 22 from Internet must not reach {nsg}")

    def test_rdp_from_internet_denied_everywhere(self):
        for nsg in ("web", "app", "bastion"):
            self.assertEqual(self.decide("internet", "203.0.113.9", 3389, nsg), "Deny")

    def test_ssh_from_bastion_subnet_allowed_to_workloads(self):
        bastion_ip = subnet_host(self.plan["bastion_subnet_prefix"])
        self.assertEqual(self.decide("vnet", bastion_ip, 22, "app"), "Allow")
        self.assertEqual(self.decide("vnet", bastion_ip, 22, "web"), "Allow")

    def test_ssh_from_other_vnet_sources_denied(self):
        web_vm_ip = subnet_host(self.plan["web_subnet_prefix"])
        self.assertEqual(self.decide("vnet", web_vm_ip, 22, "app"), "Deny")
        self.assertEqual(self.decide("vnet", web_vm_ip, 22, "web"), "Deny")


class StructuralInvariants(unittest.TestCase):
    """Hardening controls that must never regress (regex: fmt-stable)."""

    def test_no_allow_rule_permits_ssh_or_rdp_from_internet(self):
        src = read("modules/hub_network/nsg-rules.tf")
        for block in re.finditer(r'resource "azurerm_network_security_rule"[^}]+\}', src, re.S):
            b = block.group(0)
            if re.search(r'access\s*=\s*"Allow"', b) and re.search(r'direction\s*=\s*"Inbound"', b):
                if re.search(r'source_address_prefix\s*=\s*"(Internet|\*|0\.0\.0\.0/0)"', b):
                    ports = re.findall(r'destination_port_ranges?\s*=\s*(.+)', b)
                    joined = " ".join(ports)
                    self.assertNotRegex(joined, r'"(22|3389)"',
                                        "no inbound allow rule may expose SSH/RDP to the Internet")

    def test_no_public_ip_on_workload_nics(self):
        for module in ("web_tier", "app_tier"):
            src = read(f"modules/{module}/main.tf")
            nics = re.findall(
                r'resource "azurerm_network_interface" "\w+" \{(.*?)\n\}', src, re.S)
            self.assertTrue(nics, f"{module} must declare its workload NICs")
            for nic in nics:
                body = "\n".join(
                    line for line in nic.splitlines() if not line.lstrip().startswith("#"))
                self.assertNotIn("public_ip_address_id", body,
                                 f"{module} NICs must not have public IPs")

    def test_vm_subnets_disable_default_outbound(self):
        src = read("modules/hub_network/main.tf")
        self.assertEqual(len(re.findall(r'default_outbound_access_enabled\s*=\s*false', src)), 2,
                         "web and app subnets must both disable default outbound access")

    def test_nat_gateway_associated_with_both_vm_subnets(self):
        src = read("modules/hub_network/main.tf")
        self.assertIn("azurerm_subnet_nat_gateway_association", src)
        self.assertEqual(len(re.findall(r'resource "azurerm_subnet_nat_gateway_association"', src)), 2)
        self.assertRegex(src, r'sku_name\s*=\s*"Standard"')

    def test_ssh_key_only_login(self):
        for module in ("web_tier", "app_tier"):
            src = read(f"modules/{module}/main.tf")
            self.assertRegex(src, r'disable_password_authentication\s*=\s*true',
                             f"{module} VM must disable password auth")
            self.assertIn("admin_ssh_key {", src)
            self.assertNotRegex(src, r'admin_password\s*=')

    def test_bastion_subnet_minimum_size(self):
        src = read("modules/hub_network/main.tf")
        plan = load_subnet_plan()
        import ipaddress
        self.assertTrue(ipaddress.ip_network(plan["bastion_subnet_prefix"]).prefixlen >= 26,
                        "AzureBastionSubnet must be /26 or larger")

    def test_lb_rule_maps_80_to_80(self):
        src = read("modules/web_tier/main.tf")
        self.assertRegex(src, r'frontend_port\s*=\s*80')
        self.assertRegex(src, r'backend_port\s*=\s*80')
        self.assertRegex(src, r'protocol\s*=\s*"Http"')
        self.assertRegex(src, r'request_path\s*=\s*"/"')

    def test_deploy_disabled_by_default(self):
        self.assertRegex(read("variables.tf"), r'"deploy_enabled"\s*\{[^}]*default\s*=\s*false')

    def test_all_root_resources_gated(self):
        main = read("main.tf")
        self.assertEqual(main.count("var.deploy_enabled ? 1 : 0"), 5,
                         "resource group + 4 modules must all be gated")

    def test_placeholder_subscription_id(self):
        self.assertIn("00000000-0000-0000-0000-000000000000", read("variables.tf"))

    def test_ssh_key_default_is_inert(self):
        self.assertRegex(read("variables.tf"), r'"admin_ssh_public_key"\s*\{[^}]*default\s*=\s*""')

    def test_child_modules_declare_required_providers(self):
        for module in ("hub_network", "bastion", "web_tier", "app_tier"):
            src = read(f"modules/{module}/versions.tf")
            self.assertIn("required_providers", src)
            self.assertRegex(src, r'azurerm\s*=\s*\{')
            self.assertIn("hashicorp/azurerm", src)


class CiSafety(unittest.TestCase):
    """Negative tests: CI must never mutate cloud state."""

    def test_workflow_has_no_apply_or_destroy(self):
        wf = (ROOT / ".github/workflows/validate.yml").read_text()
        self.assertNotIn("terraform apply", wf)
        self.assertNotIn("terraform destroy", wf)
        self.assertNotIn("az login", wf)

    def test_workflow_permissions_read_only(self):
        wf = (ROOT / ".github/workflows/validate.yml").read_text()
        self.assertIn("contents: read", wf)

    def test_terraform_version_pinned(self):
        wf = (ROOT / ".github/workflows/validate.yml").read_text()
        self.assertRegex(wf, r"terraform_version:\s*'\d+\.\d+\.\d+'")


if __name__ == "__main__":
    unittest.main()
