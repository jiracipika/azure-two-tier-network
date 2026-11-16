# Spend safety

Azure spend authorized: $0. Never run cloud apply, premium gateway
provisioning, paid load tests or production identity changes without a
SKU/region quote and explicit approval. Budgets alert but do not cap
spending. Bastion and NAT have standing costs; health-probe rules do not
substitute for client access rules.

## Deployment price preparation (milestone item 6 — estimates only)

Estimated **~$240/month** if deployed exactly as coded (canadacentral list
prices, ballpark — MUST be re-verified with the Azure pricing calculator
before any approval):

| Item | SKU / basis | Estimate |
|---|---|---|
| Azure Bastion | Basic, $0.19/hr standing | ~$140/mo |
| NAT gateway | $0.045/hr + data processed | ~$33/mo + usage |
| Load Balancer | Standard, $0.025/hr + 1 rule $0.01/hr | ~$26/mo |
| Public IPs ×3 | Standard, ~$0.005/hr each (LB, Bastion, NAT) | ~$11/mo |
| VMs ×3 | Standard_B1s (2 web + 1 app), ~$0.0104/hr | ~$23/mo |
| OS disks ×3 | 30 GB Standard_LRS | ~$5/mo |

Cost levers, in order of impact:

1. **Bastion dominates.** Basic SKU is the floor for a standing host. For a
   short demo window, deploy last and destroy first; Bastion Developer SKU
   (session-based billing) could be a future variant if the region supports it.
2. **NAT gateway is the second standing charge.** Acceptable trade for
   controlled, auditable egress; deleting it requires re-enabling default
   outbound access (weaker posture).
3. Deallocate/stop the B1s VMs when idle (compute stops, disks keep billing
   ~$5/mo).
4. Reduce `web_vm_count` from 2 to 1 to save ~$8/mo (weakens the HA story).

No resource in this repository may be created without the owner approving
this estimate first.
