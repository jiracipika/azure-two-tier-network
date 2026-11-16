# GLM backlog — Two-Tier VNet and Bastion

## Immediate milestone — STATUS: implemented 2026-11-16 (offline validation green)

1. ✅ Confirm the provided architecture and its security flaws →
   docs/ARCHITECTURE.md ("Architecture security flaws considered"),
   docs/SECURITY.md ("Controls implemented").
2. ✅ Build offline runnable Terraform topology with reusable modules
   (`hub_network`, `bastion`, `web_tier`, `app_tier`); every resource gated by
   `deploy_enabled = false`.
3. ✅ Test cases proving valid web routing while denying untrusted app and
   management traffic: `tests/nsg_simulator.py` parses the real NSG rule
   matrix + cidrsubnet subnet plan and replays flows through NSG semantics
   (34 tests total, incl. negative flows: Internet→app:*, Internet→SSH,
   lateral app→app, web→SSH).
4. ✅ terraform fmt/init -backend=false/validate and unittest — real outputs
   in docs/VALIDATION.md, including three validate failures and three test
   bugs found and fixed.
5. ✅ Mermaid diagram and README refined to match the implemented code.
6. ✅ Deployment pricing prepared in docs/COSTS.md (~$240/mo estimate,
   Bastion-dominated); teardown inventory in docs/TEARDOWN.md — awaiting
   explicit owner review for anything live.

## Next milestone (offline, no approval needed)

- Add TLS at the edge (Application Gateway with a self-signed/lab cert, or
  Front Door) to retire the HTTP-only limitation; extend flow tests to 443.
- Add NSG flow-logs / Azure Monitor diagnostics as code (Log Analytics
  workspace gated by deploy_enabled) and document query coverage.
- Add a Checkov/tflint job to CI (pinned versions) once image budget allows.

## Live deployment (owner approval required first)

- Approve the cost quote in docs/COSTS.md, provide subscription id and an
  admin SSH public key, then execute the inventory apply per
  docs/TEARDOWN.md.

## Design caveat (addressed, kept for history)

Bastion and NAT have standing costs; health-probe rules do not substitute for
client access rules. Both are encoded as explicit rules (web NSG priorities
100/110) with a dedicated regression test. No live Azure resources are
authorized. Do not stop after planning: build/test locally.
