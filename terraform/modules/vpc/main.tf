
locals {
  common_tags = {
    Name = "costbuddy-vpc"
  }
}


# Get the subnet details including VPC id.
data "aws_subnet" "subnet" {

  count = var.parent ? length(var.public_subnet_id) == 0 && length(var.private_subnet_id) == 0 ? 0 : 1 : 0

  id = coalescelist(var.public_subnet_id, var.private_subnet_id)[0]
}



# Creates a VPC if no subnet ids are provided
resource "aws_vpc" "main" {

  count = var.parent && length(var.public_subnet_id) == 0 && length(var.private_subnet_id) == 0 ? 1 : 0

  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, var.tags)
}

