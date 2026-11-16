# Security requirements

No secrets, state, privileged tokens, public SSH/RDP or customer data in git.
Pin or review CI dependencies, scope federated identity, apply least
privilege, block unauthorized network paths and log denial tests. Critical
risk: Bastion and NAT have standing costs; health-probe rules do not
substitute for client access rules.

## Controls implemented (offline-verified)

| Control | Where | Test |
|---|---|---|
| Deploy gate default OFF | `infra/terraform/variables.tf` `deploy_enabled = false` | SpendGuard / scaffold tests |
| All resources gated (rg + 4 modules) | `infra/terraform/main.tf` (5× `var.deploy_enabled ? 1 : 0`) | `test_all_root_resources_gated` |
| No inbound SSH/RDP from Internet (any NSG) | `modules/hub_network/nsg-rules.tf` | flow simulation + structural scan |
| App tier unreachable from Internet (any port) | app NSG has no Internet/wildcard source | `test_internet_to_app_on_any_port_denied` |
| Web→app API only from web subnet | `Allow-API-From-Web` (priority 100) | `test_web_to_app_api_allowed` |
| Lateral SSH denied (web→web, app→app, web→app:22) | implicit default deny + scoped rules | `test_ssh_from_other_vnet_sources_denied` etc. |
| Management only via Bastion subnet | `Allow-SSH-From-Bastion` rules | `test_ssh_from_bastion_subnet_allowed_to_workloads` |
| Health probe ≠ client access (both rules required) | web NSG priorities 100 + 110 | `test_health_probe_from_azurelb_allowed_on_separate_rule` |
| Workload NICs have no public IP | `modules/web_tier`, `modules/app_tier` | `test_no_public_ip_on_workload_nics` |
| No default outbound access; NAT-only egress | subnets + `modules/hub_network` NAT | `test_vm_subnets_disable_default_outbound` |
| SSH-key-only login, passwords disabled | `admin_ssh_key` + `disable_password_authentication = true` | `test_ssh_key_only_login` |
| Bastion subnet /26 minimum, documented NSG set | `modules/hub_network` | `test_bastion_subnet_minimum_size` |
| Placeholder subscription (no real IDs in git) | `variables.tf` default GUID | `test_placeholder_subscription_id` |
| CI read-only, no apply/destroy/login, pinned TF | `.github/workflows/validate.yml` | CiSafety tests |

## Residual risks / not yet implemented

- HTTP-only public endpoint (no TLS at the edge yet) — documented lab
  limitation in docs/ARCHITECTURE.md.
- No Azure Monitor / NSG flow logs — future milestone.
- `terraform plan` offline run stops at provider authorizer (no `az` CLI /
  credentials in the sandbox) — expected; validate + unit battery is the CI gate.
