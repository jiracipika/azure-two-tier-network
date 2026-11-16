# Security requirements

No secrets, state, privileged tokens, public SSH/RDP or customer data in git. Pin or review CI dependencies, scope federated identity, apply least privilege, block unauthorized network paths and log denial tests. Critical risk: Bastion and NAT have standing costs; health-probe rules do not substitute for client access rules.
