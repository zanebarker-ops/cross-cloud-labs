# Azure side — Site-to-Site VPN lab

Azure-side Terraform for the cross-cloud VPN lab. See [cross-cloud reference doc](../../../docs/reference-architectures/cross-cloud/vpn-site-to-site/README.md) for the full picture.

## Three-phase apply (because state is local on both sides)

### Phase 1 — Azure (here)

Creates the VNet, subnets, VPN Gateway, public IP, NSG, and workload VM.
**Does not** create the Local Network Gateway or Connection (AWS info isn't known yet).

```bash
# from this dir
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars     # paste your SSH public key, leave create_connection=false

set -a && source ../../../.env && set +a
terraform init
terraform plan
terraform apply
```

Note the outputs:

```bash
terraform output azure_gw_public_ip
terraform output azure_bgp_asn
terraform output azure_vnet_cidr
```

Paste those into the AWS lab's `terraform.tfvars` and ping the AWS session.

### Phase 2 — AWS (other session)

The AWS session does its `terraform apply`. Their outputs:

- `aws_tunnel1_address`
- `aws_tunnel1_psk` (sensitive — use `terraform output -raw aws_tunnel1_psk`)
- `aws_vgw_asn` (locked at 65020)
- `aws_vpc_cidr` (locked at 10.20.0.0/16)

### Phase 3 — Azure (here, again)

Paste the AWS outputs into `terraform.tfvars` and flip `create_connection = true`:

```hcl
create_connection   = true
aws_tunnel1_address = "x.x.x.x"
aws_tunnel1_psk     = "<paste>"
aws_vgw_asn         = 65020
aws_vpc_cidr        = "10.20.0.0/16"
```

Then:

```bash
terraform plan
terraform apply
```

This creates the Local Network Gateway and the Connection. Tunnel comes up within ~1–2 minutes.

## Validation

```bash
# Azure tunnel state
az network vpn-connection show \
  -g rg-cross-cloud-labs-vpn-eastus \
  -n cn-azure-aws \
  --query connectionStatus -o tsv
# Expect: Connected

# Cross-cloud ping (SSH into Azure VM via Bastion or jump, then):
ping <aws_workload_private_ip>
```

## Teardown

```bash
./destroy.sh
```

VPN Gateway delete takes 10–20 minutes — expected. The script is idempotent.

## Costs

Approximately **$0.21/hr** while running (VPN GW + public IP + B1s VM + disk). At 8 hours/day with nightly teardown: ~$1.70/day Azure-side. See cross-cloud doc for full breakdown.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Provider version pins |
| `variables.tf` | Inputs (locked params + phase-3 AWS inputs) |
| `main.tf` | All Azure resources |
| `outputs.tf` | What to paste into AWS tfvars |
| `terraform.tfvars.example` | Template; copy to `terraform.tfvars` and fill |
| `destroy.sh` | Wraps `terraform destroy -auto-approve` |
