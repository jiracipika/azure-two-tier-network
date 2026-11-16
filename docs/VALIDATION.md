# Evidence log

Every entry below is an actual command execution with its real result. Azure
live deployment: **NOT RUN** (no authorization; `terraform plan` offline also
stops at the provider authorizer because the sandbox has no `az` CLI or
credentials — expected, not a code failure).

## 2026-11-16T14:15Z — local offline battery (GLM/ZCode session, terraform v1.9.8)

| Command | Result | Evidence |
|---|---|---|
| `python3 -m unittest discover -s tests` | **PASS** | `Ran 34 tests ... OK` |
| `terraform -chdir=infra/terraform fmt -check -recursive` | **PASS** | exit 0 after fixes |
| `terraform -chdir=infra/terraform init -backend=false -input=false` | **PASS** | azurerm v4.81.0 installed; 4 modules loaded |
| `terraform -chdir=infra/terraform validate` | **PASS** | `Success! The configuration is valid.` |
| `terraform -chdir=infra/terraform plan -input=false -refresh=false` | **PARTIAL (expected)** | proposes only `+ status = "offline-scaffold-only"` (zero resources); then errors `could not configure AzureCli Authorizer: az: executable not found` — offline sandbox has no credentials |

### Failures found and fixed during this run (real history)

1. `fmt -check` failed on `variables.tf`, `versions.tf` (scaffold commits not
   canonically formatted) — fixed with `terraform fmt -recursive`; this was
   also the root cause of the red "Safe offline checks" badge on runs
   43875285702 and 43875757705 (CI log: `Terraform exited with code 3`).
2. `validate` failed: `azurerm_nat_gateway_public_ip_association` takes
   `public_ip_address_id`, not `public_ip_id` (verified against
   `terraform providers schema -json` for azurerm 4.81.0) — fixed.
3. `validate` warned: `enable_tcp_reset` deprecated in favour of
   `tcp_reset_enabled` (removed in provider 5.0) — fixed.
4. First test run (22 tests): 5 errors + 1 failure —
   (a) Python `cidrsubnet` re-implementation had an over-strict guard
   rejecting `cidrsubnet("10.10.0.0/16", 10, 1000)` (netnum may exceed one
   octet); (b) the no-public-IP test matched a comment and the legitimate LB
   frontend IP — now parses only `azurerm_network_interface` bodies with
   comments stripped; (c) NSG-rule parser extracted the wrong segment of
   `azurerm_network_security_group.web.name` (`name` instead of `web`).
   All fixed; suite green at 34 tests.

### Schema verification method (as required)

Provider attributes were verified against the installed provider, not
guessed: `terraform -chdir=infra/terraform providers schema -json` (azurerm
4.81.0) confirmed `azurerm_subnet.default_outbound_access_enabled`, that NSG
rules are standalone `azurerm_network_security_rule` resources (no inline
`security_rule` blocks in azurerm 4.x), `azurerm_bastion_host.ip_configuration
{name, subnet_id, public_ip_address_id}`, and the NAT-association attribute
name above.

GitHub Actions: run status recorded below after pushing this commit.

| Date | Run | Conclusion |
|---|---|---|
| 2026-11-16T13:23Z | 43875285702 (scaffold) | failure — `fmt -check` exit 3 |
| 2026-11-16T13:26Z | 43875757705 (scaffold) | failure — `fmt -check` exit 3 |
| 2026-11-16T14:20Z | 43884259073 (implementation, commit 7d1ccb5) | **success — 34 tests + fmt + init + validate green on ubuntu runner / terraform 1.10.5** |
