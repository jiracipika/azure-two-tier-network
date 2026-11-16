# GLM backlog — Two-Tier VNet and Bastion

## Immediate milestone
1. Confirm the provided architecture and its security flaws.
2. Build offline runnable topology or Terraform modules; keep deploy_enabled=false.
3. Write test cases proving: Prove valid web routing while denying untrusted app and management traffic.
4. Validate terraform fmt/init -backend=false/validate and unittest; capture real output in VALIDATION.md.
5. Refine Mermaid diagram and README to match code.
6. Prepare live deployment pricing, identities and teardown for explicit owner review.

## Design caveat
Bastion and NAT have standing costs; health-probe rules do not substitute for client access rules.

No live Azure resources are authorized. Do not stop after planning: build/test locally.
