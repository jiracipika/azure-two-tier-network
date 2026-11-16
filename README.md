# 02 — Two-Tier VNet + Bastion

**Azure Cloud Engineering Portfolio** · [GitHub: jiracipika](https://github.com/jiracipika) · **PRIVATE repository** · **Offline scaffold / Azure NOT DEPLOYED**

## Goal
Demonstrate permitted web traffic while rejecting unauthorized app and SSH traffic.

## Architecture (implemented as code, gated off)
Public Load Balancer → two Nginx web VMs in `snet-web` → one private API VM
in `snet-app`; Azure Bastion as the only management path; NAT gateway as the
only egress; per-subnet NSGs enforce the tier boundaries. Proven offline by a
flow simulator that replays the real NSG rule matrix (allow: Internet→web:80,
web→app:8080, bastion→workloads:22; deny: Internet→app on any port,
Internet→SSH anywhere, lateral app↔app).

## GLM / ZCode — start here

1. Read [AGENTS.md](AGENTS.md), [GLM tasks](docs/GLM_TASKS.md), [architecture](docs/ARCHITECTURE.md), [security](docs/SECURITY.md), and [validation](docs/VALIDATION.md).
2. Implement the next offline milestone in **docs/GLM_TASKS.md** with runnable code and negative tests, not just a plan.
3. Verify Terraform syntax and security, run unit tests, record actual results, and keep diagrams/documentation current.
4. **Do not apply Terraform or deploy any billable Azure resources or alter cloud IAM without my explicit approval.**
5. Report changed files, actual tests and blockers in your ZCode session and commits.

## Offline starting commands

```sh
python3 -m unittest discover -s tests -v
terraform -chdir=infra/terraform fmt -check -recursive
terraform -chdir=infra/terraform init -backend=false -input=false
terraform -chdir=infra/terraform validate
```

All four pass locally (34 tests) and in CI; see docs/VALIDATION.md for the
real output log, including the failures that were found and fixed.

## Source contents

- `AGENTS.md`: enforceable GLM implementation contract
- `docs/GLM_TASKS.md`: project-specific milestones and current status
- `docs/ARCHITECTURE.md`: topology, CIDR/NSG matrix, trust boundaries, flaws considered
- `docs/SECURITY.md` / `docs/COSTS.md`: controls, guardrails, cost estimate (~$240/mo if deployed)
- `docs/VALIDATION.md`: real evidence only — actual commands and results
- `docs/TEARDOWN.md`: resource inventory + approved cleanup plan
- `diagrams/architecture.mmd`: editable Mermaid model with trust boundaries
- `infra/terraform/`: root module + `modules/hub_network`, `modules/bastion`, `modules/web_tier`, `modules/app_tier`; everything gated by `deploy_enabled=false`
- `infra/terraform/environments/dev.tfvars`: offline-safe defaults
- `.github/workflows/validate.yml`: offline validation, no deploy step
- `tests/`: safety gates, security invariants and the NSG flow simulator

## Status and safety

Terraform modules for the full two-tier topology are implemented and
validated offline; **no Azure services are deployed** and `terraform plan`
with defaults proposes zero resources. Repository visibility must remain
**PRIVATE**. No credentials, secrets, real customer data, Terraform state or
internal account identifiers may be committed.
