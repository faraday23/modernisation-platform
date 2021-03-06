data "aws_caller_identity" "current" {}

data "aws_ec2_transit_gateway" "transit-gateway" {
  provider = aws.core-network-services
  filter {
    name   = "options.amazon-side-asn"
    values = ["64589"]
  }
}

data "aws_ram_resource_share" "transit-gateway-shared" {
  provider = aws.core-network-services

  name           = "shared-transit-gateway"
  resource_owner = "SELF"
}

# # Create RAM principal assocation for this account
resource "aws_ram_principal_association" "transit_gateway_association" {
  provider = aws.core-network-services

  principal          = data.aws_caller_identity.current.account_id
  resource_share_arn = data.aws_ram_resource_share.transit-gateway-shared.arn
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
}

# Attach the VPC to the central Transit Gateway
module "vpc_attachment" {
  for_each = local.network
  source   = "../../modules/ec2-tgw-attachment"
  providers = {
    aws.transit-gateway-tenant = aws
    aws.transit-gateway-host   = aws.core-network-services
  }

  resource_share_name = "shared-transit-gateway"
  transit_gateway_id  = data.aws_ec2_transit_gateway.transit-gateway.id
  type                = each.key

  subnet_ids = module.vpc[each.key].tgw_subnet_ids
  vpc_id     = module.vpc[each.key].vpc_id

  tags = local.tags
}
