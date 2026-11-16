# Architecture: Two-Tier VNet and Bastion

Public load balancer -> two Nginx web VMs in subnet web -> one private API VM in app subnet; Bastion, NSGs, NAT.

Goal: Prove valid web routing while denying untrusted app and management traffic.

Known implementation risk: Bastion and NAT have standing costs; health-probe rules do not substitute for client access rules.

Workload, Azure control plane, storage/data plane, GitHub CI and public internet are separate trust boundaries. Map ports and credential scopes precisely. This is a design, not a deployed system.
