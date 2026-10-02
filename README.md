# AWS ↔ Azure Cross-Cloud VPN Connectivity

A real, working Site-to-Site VPN tunnel between an AWS VPC and an Azure
VNet, built with each cloud's native IaC tool — Terraform for AWS, Bicep for
Azure — and proven with actual cross-cloud ping traffic, not just a
"Connected" status light.

**This project's real point isn't "I can click through two cloud consoles
and connect them."** It's: build both sides correctly from code, hit real
platform-specific failures along the way, diagnose a genuinely subtle
cross-cloud configuration bug using telemetry rather than guesswork, fix it,
and prove the fix with real traffic. Full diagnostic writeup:
[`docs/connectivity-test-writeup.md`](docs/connectivity-test-writeup.md).

---

## Architecture

```
                    AWS VPC (10.2.0.0/16)                          Azure VNet (10.3.0.0/16)
                 us-east-1                                       eastus
  ┌─────────────────────────────────┐                 ┌─────────────────────────────────┐
  │                                   │                 │                                   │
  │   ┌─────────────┐                 │                 │                 ┌─────────────┐   │
  │   │ Private      │                 │                 │                 │ Test Subnet  │   │
  │   │ Subnet       │                 │                 │                 │ 10.3.1.0/24  │   │
  │   │ 10.2.1.0/24  │                 │                 │                 │              │   │
  │   │              │                 │                 │                 │ ┌──────────┐ │   │
  │   │ ┌──────────┐ │                 │                 │                 │ │  Test VM  │ │   │
  │   │ │ Test EC2  │ │  IPsec VPN      │                 │  IPsec VPN      │ │ (no inbound)│ │
  │   │ │ (SSM-only)│◄┼─────Tunnel──────┼─────────────────┼─────Tunnel──────┼►│            │ │
  │   │ └──────────┘ │  (static route) │                 │ (static route)  │ └──────────┘ │   │
  │   └─────────────┘                 │                 │                 └─────────────┘   │
  │                                   │                 │                                   │
  │   Customer Gateway ◄──────────────┼─────────────────┼──────────────► Local Network GW    │
  │   VPN Gateway                     │                 │   VPN Gateway (VpnGw1AZ)            │
  │   (VGW, static routes)            │                 │                                   │
  └─────────────────────────────────┘                 └─────────────────────────────────┘
```

Three VPC Interface Endpoints (`ssm`, `ssmmessages`, `ec2messages`) allow the
AWS test instance to be managed via SSM with **no internet access or NAT
Gateway at all** — a fully private subnet. The Azure VM is managed the same
way via `az vm run-command invoke`, with no public IP and no inbound rules.

---

## Repo Structure

```
aws-azure-cross-cloud-network/
├── aws-terraform/
│   ├── main.tf           # provider, backend
│   ├── variables.tf
│   ├── vpc.tf            # VPC, subnet, route table
│   ├── vpn.tf            # Customer Gateway, VPN Gateway, Connection, static route
│   ├── nsg.tf            # security groups
│   ├── iam.tf            # SSM role/instance profile
│   ├── ec2.tf            # test instance, AMI lookup, VPC endpoints
│   └── outputs.tf
├── azure-bicep/
│   └── main.bicep         # VNet, gateways, route table, NIC, test VM
├── bootstrap/              # S3 state bucket + DynamoDB lock table (AWS side only)
├── docs/
│   └── connectivity-test-writeup.md
└── README.md
```

---

## AWS vs. Azure — Networking Concepts, Side by Side

Having built the same conceptual thing (a VPN tunnel) on both platforms,
here's where the two genuinely differ in approach:

| Concept | AWS | Azure |
|---|---|---|
| The "other side's" gateway, from this cloud's perspective | Customer Gateway | Local Network Gateway |
| This cloud's own VPN endpoint | VPN Gateway (attached directly to a VPC) | VPN Gateway (needs its own dedicated Public IP resource, deployed separately) |
| Gateway subnet requirement | None — VGW attaches to the VPC directly | A subnet literally named `GatewaySubnet` is mandatory, min `/27` |
| Tunnel redundancy | Two tunnels created automatically per connection | One connection; redundancy is a separate concern (zone-redundant SKUs) |
| PSK generation | Generated automatically by AWS per tunnel | You supply it explicitly, must match exactly |
| Static route propagation into subnets | Explicit `aws_vpn_gateway_route_propagation` resource | A regular route table, associated to the subnet, `nextHopType: VirtualNetworkGateway` |
| No-inbound-access management | AWS Systems Manager (SSM) Session Manager | `az vm run-command invoke` |
| VPN Gateway provisioning time | A few minutes | 30-45+ minutes — notably much slower |

**The single biggest practical difference:** Azure's VPN Gateway takes
dramatically longer to provision than AWS's, which has real workflow
implications — iterating on Azure's VPN configuration is much slower to
test than AWS's side, so getting the Bicep template right on fewer attempts
matters more.

---

## Deliberate Tradeoffs

| Decision | Reasoning |
|---|---|
| Static routing instead of BGP | Static routes are far more tractable to reason about and debug on a first cross-cloud VPN attempt. BGP (dynamic routing, ASNs, route propagation) is a legitimate next step, noted here rather than attempted in this iteration. |
| Only one of AWS's two tunnels configured | AWS provisions two for redundancy by default; only tunnel 1 was wired to Azure, since the goal was proving connectivity works, not building a fully redundant production tunnel. |
| `Standard_D2as_v4` instead of a burstable B-series Azure VM | B-series SKUs had no capacity in `eastus` at deployment time — confirmed directly via `az vm list-skus`, not assumed. A real, live platform constraint, not a design choice. |
| No SSH/key-pair access on either test resource | Matches the "private by default, managed via cloud-native control plane" approach used throughout this portfolio (SSM on AWS, Run Command on Azure) — no open management ports on either side. |

---

## Running This Yourself

```bash
# 1. AWS bootstrap + infrastructure
cd bootstrap && terraform init && terraform apply
cd ../aws-terraform
terraform init
terraform apply -var="my_ip_cidr=<your-ip>/32"

# 2. Get AWS's tunnel IP and PSK for Azure's side
terraform output vpn_tunnel1_address
aws ec2 describe-vpn-connections --vpn-connection-ids <id> \
  --query "VpnConnections[0].Options.TunnelOptions[0].PreSharedKey" --output text

# 3. Azure resource group + Bicep deployment
az group create --name cross-cloud-rg --location eastus
az deployment group create --resource-group cross-cloud-rg \
  --template-file azure-bicep/main.bicep \
  --parameters awsTunnelIp=<tunnel-ip> sharedKey='<psk>' adminPassword='<strong-password>'

# 4. Confirm the tunnel is up on both sides
az network vpn-connection show --resource-group cross-cloud-rg \
  --name cross-cloud-rg-vpn-connection --query "connectionStatus"
aws ec2 describe-vpn-connections --vpn-connection-ids <id> \
  --query "VpnConnections[0].VgwTelemetry"

# 5. Prove connectivity
az vm run-command invoke --resource-group cross-cloud-rg \
  --name cross-cloud-rg-test-vm --command-id RunShellScript \
  --scripts "ping -c 4 <aws-instance-private-ip>"

# 6. Tear down
az group delete --name cross-cloud-rg --yes
cd aws-terraform && terraform destroy -var="my_ip_cidr=<your-ip>/32"
```

---

## What I'd Do Differently at Larger Scale

- BGP-based dynamic routing instead of static routes, for automatic
  failover and easier multi-subnet scaling on both sides
- Both AWS tunnels configured for real redundancy, rather than only tunnel 1
- Zone-redundant Azure VPN Gateway SKU and a secondary AWS VGW attachment
  for genuine high availability of the tunnel itself, not just the
  endpoints behind it
- Automated secret handling for the pre-shared key (e.g., stored in both
  clouds' native secret managers and referenced rather than passed as a
  CLI parameter in plaintext)
- A CI/CD pipeline running `terraform plan`/`what-if` (Bicep's equivalent of
  `plan`) on both sides before any apply, extending the IaC-gate pattern
  from an earlier project in this portfolio to a dual-cloud deployment