# Architecture: Two-Tier VNet and Bastion

Public Load Balancer → two Nginx web VMs in `snet-web` → one private API VM in
`snet-app`; Azure Bastion for management; NAT gateway for egress; per-subnet
NSGs enforcing the tier boundaries.

Goal: prove valid web routing while denying untrusted app and management
traffic — offline, via `tests/nsg_simulator.py` replaying the real rule matrix.

## Implemented topology (as code, gated off)

| Element | Terraform | Notes |
|---|---|---|
| VNet `vnet-two-tier` 10.10.0.0/16 | `modules/hub_network` | single-region lab footprint |
| `snet-web` 10.10.1.0/24 | `modules/hub_network` | public tier; `default_outbound_access_enabled = false` |
| `snet-app` 10.10.2.0/24 | `modules/hub_network` | private tier; `default_outbound_access_enabled = false` |
| `AzureBastionSubnet` 10.10.250.0/26 | `modules/hub_network` | fixed name + /26 minimum required by Bastion |
| NAT gateway (Standard) + 1 public IP | `modules/hub_network` | associated to web AND app subnets: the only egress path |
| NSGs web/app/bastion | `modules/hub_network/nsg-rules.tf` | standalone `azurerm_network_security_rule` resources (azurerm 4.x pattern) |
| Bastion host (Basic SKU default) | `modules/bastion` | TLS entry point for SSH; no other management path exists |
| Public LB (Standard) + probe + rule 80→80 | `modules/web_tier` | `N` (`web_vm_count`, default 2) Ubuntu 22.04 Nginx VMs behind pool `be-web` |
| Private API VM | `modules/app_tier` | Ubuntu 22.04, nginx on TCP/8080, no public IP, no LB |

## NSG rule matrix (direction Inbound unless noted)

| NSG | Priority | Rule | Source | Port | Effect |
|---|---|---|---|---|---|
| web | 100 | Allow-HTTP-From-Internet | `Internet` | 80 | the ONLY client path |
| web | 110 | Allow-HealthProbe-From-AzureLB | `AzureLoadBalancer` | 80 | probe rule — deliberately separate from 100 |
| web | 120 | Allow-SSH-From-Bastion | 10.10.250.0/26 | 22 | management via Bastion only |
| app | 100 | Allow-API-From-Web | 10.10.1.0/24 | 8080 | tier-to-tier API traffic |
| app | 110 | Allow-SSH-From-Bastion | 10.10.250.0/26 | 22 | management via Bastion only |
| bastion | 100 | Allow-HTTPS-From-Internet | `Internet` | 443 | Bastion browser session entry |
| bastion | 110–130 | GatewayManager / AzureLoadBalancer / host communication | service tags | 443, 8080, 5701 | Azure Bastion documented requirements |
| bastion | 200–230 (Outbound) | SSH/RDP to VNet, host communication, AzureCloud 443, Internet 80 | — | 22, 3389, 443, 8080, 5701, 80 | Azure Bastion documented requirements |

Everything not listed is denied by the platform default rules (inbound).

## Trust boundaries

1. **Public Internet** → may ONLY reach the LB frontend :80 and Bastion :443 (TLS).
2. **Web tier** → may call the app tier :8080; may not SSH anywhere.
3. **App tier** → accepts traffic from the web subnet and Bastion only; has no
   public IP, no DNAT, no path from the Internet at all.
4. **Management plane** → Bastion subnet is the sole SSH source; workload
   VMs have no password login (`disable_password_authentication = true`).
5. **Egress** → VM subnets disable default outbound access; all egress is
   SNAT'd through the NAT gateway's single public IP (auditable).
6. **Azure control plane / GitHub CI** → read-only offline checks; no
   credentials in repo, no deploy step (see `.github/workflows/validate.yml`).

## Architecture security flaws considered (milestone item 1)

- **Health probes are not client access.** A common failure is opening only
  the `AzureLoadBalancer` probe port: the pool shows healthy while clients
  get timeouts. Both rules exist separately (priorities 100/110) and are
  separately asserted in tests.
- **Standing costs of Bastion + NAT.** Documented in docs/COSTS.md (~$240/mo
  estimate); Basic SKU chosen as the floor; deployment only on owner approval.
- **Default outbound access** would silently give VMs implicit egress IPs;
  disabled on both VM subnets in favour of the NAT gateway.
- **SSH/RDP exposure**: rejected outright — no workload NIC has a public IP
  and no NSG rule admits 22/3389 from `Internet`; verified by simulation.
- **Lateral movement**: app-to-app and web-to-web SSH are denied; only the
  Bastion subnet reaches port 22.
- **Known lab limitation (accepted)**: the public path is HTTP-only (no TLS
  termination at the LB); fine for a cost-gated demo, flagged for a future
  Application Gateway / Front Door milestone.

This is validated code, not a deployed system: `deploy_enabled = false`
means `terraform plan` proposes zero resources.
