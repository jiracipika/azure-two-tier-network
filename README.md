# 02 — Two-Tier VNet + Bastion

**Azure Cloud Engineering Portfolio** · [GitHub: jiracipika](https://github.com/jiracipika) · **PRIVATE repository** · **Offline scaffold / Azure NOT DEPLOYED**

## Goal
Demonstrate permitted web traffic while rejecting unauthorized app and SSH traffic.

## Planned Azure architecture
VNet, web/app subnet isolation, Nginx VMs, Azure Load Balancer, Bastion, NAT and NSGs.

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

## Source contents

- `AGENTS.md`: enforceable GLM implementation contract
- `docs/GLM_TASKS.md`: project-specific milestones
- `docs/ARCHITECTURE.md`: intended topology and assumptions
- `docs/SECURITY.md` / `docs/COSTS.md`: guardrails and financial control
- `docs/VALIDATION.md`: log real evidence only
- `docs/TEARDOWN.md`: future approved cleanup plan
- `diagrams/architecture.mmd`: initial editable Mermaid model
- `infra/terraform/`: safe offline provider root, no billable resources declared
- `.github/workflows/validate.yml`: offline validation, no deploy step
- `tests/`: initial safety regression tests

## Status and safety

This is an initial engineering scaffold, **not** a deployed production system. Terraform currently defines no Azure services. The architecture modules, end-to-end tests and production readiness must be implemented and verified in subsequent GLM work. **Repository visibility must remain PRIVATE.** No credentials, secrets, real customer data, Terraform state or internal account identifiers may be committed.
