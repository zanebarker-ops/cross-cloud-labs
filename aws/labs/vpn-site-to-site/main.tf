terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      owner      = "zane"
      project    = "cross-cloud-labs"
      lab        = "vpn-site-to-site"
      managed_by = "terraform"
    }
  }
}

locals {
  name_prefix = "ccl-vpns2s"
}

# ---------------------------------------------------------------------------
# VPC + subnets
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.aws_public_subnet_cidr
  availability_zone       = var.aws_az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public"
    tier = "public"
  }
}

resource "aws_subnet" "workload" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.aws_workload_subnet_cidr
  availability_zone = var.aws_az

  tags = {
    Name = "${local.name_prefix}-workload"
    tier = "workload"
  }
}

# ---------------------------------------------------------------------------
# Internet gateway + route tables
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Workload route table:
#   - default route to IGW so the EC2 instance can reach SSM endpoints
#     (cheaper than a NAT Gateway for a lab; instance gets a public IP but
#     SG ingress is locked to ICMP from Azure CIDR only)
#   - VGW route propagation enabled so the Azure VNet CIDR is learned via BGP
resource "aws_route_table" "workload" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-workload"
  }
}

resource "aws_route_table_association" "workload" {
  subnet_id      = aws_subnet.workload.id
  route_table_id = aws_route_table.workload.id
}

resource "aws_vpn_gateway_route_propagation" "workload" {
  vpn_gateway_id = aws_vpn_gateway.this.id
  route_table_id = aws_route_table.workload.id

  depends_on = [aws_vpn_gateway_attachment.this]
}

# ---------------------------------------------------------------------------
# VPN: VGW + Customer Gateway + VPN Connection (BGP, both tunnels created)
# ---------------------------------------------------------------------------

resource "aws_vpn_gateway" "this" {
  amazon_side_asn = var.aws_vgw_asn

  # vpc_id intentionally omitted — attachment is managed by
  # aws_vpn_gateway_attachment.this. Setting both leads to drift.

  tags = {
    Name = "${local.name_prefix}-vgw"
  }
}

resource "aws_vpn_gateway_attachment" "this" {
  vpc_id         = aws_vpc.this.id
  vpn_gateway_id = aws_vpn_gateway.this.id
}

resource "aws_customer_gateway" "azure" {
  bgp_asn    = var.azure_bgp_asn
  ip_address = var.azure_gw_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "${local.name_prefix}-cgw-azure"
  }
}

# AWS PSK character set: [A-Za-z0-9._], 8–64 chars, cannot start with 0.
# We pin tunnel1's PSK so the value is deterministic across applies and the
# user can paste it into Azure tfvars. Tunnel 2's PSK is left to AWS-default
# (HA future-work — Azure side only consumes tunnel 1 in v1).
#
# random_password can't constrain the first character, so we generate 31
# chars and prepend a fixed letter — gives 32 total and guarantees the
# leading char is not '0'.
resource "random_password" "tunnel1_psk" {
  length           = 31
  special          = true
  override_special = "._"
  upper            = true
  lower            = true
  numeric          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
}

locals {
  tunnel1_psk = "k${random_password.tunnel1_psk.result}"
}

resource "aws_vpn_connection" "azure" {
  customer_gateway_id = aws_customer_gateway.azure.id
  vpn_gateway_id      = aws_vpn_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_preshared_key = local.tunnel1_psk

  tags = {
    Name = "${local.name_prefix}-vpn-azure"
  }

  # Pin the PSK to whatever AWS first negotiated, so a future random_password
  # regeneration (e.g. after state loss + re-import) does not force-replace
  # the VPN connection and break the Azure side, which has the original PSK
  # pasted into its tfvars.
  lifecycle {
    ignore_changes = [tunnel1_preshared_key]
  }

  depends_on = [aws_vpn_gateway_attachment.this]
}

# ---------------------------------------------------------------------------
# Workload SG + EC2 (Amazon Linux 2023, t3.micro, SSM-managed)
# ---------------------------------------------------------------------------

resource "aws_security_group" "workload" {
  name        = "${local.name_prefix}-sg-workload"
  description = "Allow ICMP from Azure VNet CIDR only; egress all"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-sg-workload"
  }
}

resource "aws_vpc_security_group_ingress_rule" "icmp_from_azure" {
  security_group_id = aws_security_group.workload.id
  description       = "ICMP echo from Azure VNet CIDR"
  cidr_ipv4         = var.azure_vnet_cidr
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.workload.id
  description       = "Egress anywhere (needed for SSM + ICMP to Azure)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workload" {
  name               = "${local.name_prefix}-workload-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.workload.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "workload" {
  name = "${local.name_prefix}-workload-profile"
  role = aws_iam_role.workload.name
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "workload" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.workload.id
  vpc_security_group_ids      = [aws_security_group.workload.id]
  iam_instance_profile        = aws_iam_instance_profile.workload.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-workload"
  }
}
