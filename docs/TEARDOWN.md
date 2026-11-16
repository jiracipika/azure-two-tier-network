# Safe cleanup

No deployed resources exist. When deployment is later approved, the complete
resource inventory created by this code is:

## Resource inventory (all in `rg-two-tier-network` unless noted)

| Resource | Terraform address | Notes |
|---|---|---|
| Resource group | `azurerm_resource_group.this` | container for everything below |
| VNet + subnets | `module.hub_network[0].azurerm_virtual_network.this`, `azurerm_subnet.web/app/bastion` | |
| NSGs ×3 + rules ×13 | `module.hub_network[0].azurerm_network_security_group.*`, `azurerm_network_security_rule.*` | |
| NAT gateway + public IP + associations ×2 | `module.hub_network[0].azurerm_nat_gateway.*` | |
| Bastion host + public IP | `module.bastion[0].azurerm_bastion_host.this`, `azurerm_public_ip.bastion` | |
| Load balancer + public IP + probe + rule + backend pool | `module.web_tier[0].azurerm_lb.*` | |
| Web VMs ×N + NICs + pool associations | `module.web_tier[0].azurerm_linux_virtual_machine.web[*]`, `azurerm_network_interface.web[*]` | N = `web_vm_count` |
| App VM + NIC | `module.app_tier[0].azurerm_linux_virtual_machine.app`, `azurerm_network_interface.app` | |

## Approved cleanup plan (to execute only with owner authorization)

1. Confirm nothing else shares the resource group or VNet (peering, private
   endpoints, DNS zones) — nothing in this repo creates shared dependencies,
   but verify live state before destroying.
2. `terraform destroy` with the same `-var-file=environments/dev.tfvars` plus
   the deploy variables that were approved — expected: 24+N+N resources
   destroyed (no state lock contention: single-writer workflow).
3. Preserve recovery data first if any test artifacts were placed on VM disks
   (none by default; cloud-init writes only a placeholder index page).
4. Verify billable remnants afterwards: `az resource list --resource-group
   rg-two-tier-network` returns empty, no orphaned public IPs or disks remain
   in the subscription (check resource-group-deleted cleanup of dangling
   NICs/disks is not blocked by locks).
5. Confirm no NSG diagnostics/storage was created outside the resource group
   (none is declared in this repo).
