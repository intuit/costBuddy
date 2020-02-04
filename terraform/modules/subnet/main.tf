locals {
  common_tags = {
    Name = "costbuddy-${var.name}-subnet"
  }
}


# Get the subnet details including VPC id.
data "aws_subnet" "subnet" {

  count = var.parent && length(var.subnet_id) > 0 ? 1 : 0

  id = var.subnet_id[0]
}

data "aws_availability_zones" "available" {}


# Creates subnet if no Subnets are provided
resource "aws_subnet" "main" {
  # Hardcoding the availability region since the ebs volume lifecycle is related to this
  count                   = var.parent && length(var.subnet_id) ==  0 ? length(var.subnet_cidr_block) : 0
  availability_zone       = data.aws_availability_zones.available.names[0]
  vpc_id                  = var.vpc_id
  cidr_block              = element(var.subnet_cidr_block, count.index)
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, var.tags)
}
