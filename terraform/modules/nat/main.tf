locals {
  common_tags = {
    Name = "costbuddy-nat-gateway"
  }
}

# Creates a Elastic IP address
resource "aws_eip" "nat" {

  count = var.parent && length(var.input_subnet_id) == 0 ? 1 : 0
  vpc   = true
  tags  = merge(local.common_tags, var.tags)
}

resource "aws_nat_gateway" "main" {
  count = var.parent && length(var.input_subnet_id) == 0 ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = element(var.public_subnet_id, 0)
  tags          = merge(local.common_tags, var.tags)
}


# Creates Route table if no Subnets are provided
resource "aws_route_table" "private" {

  count  = var.parent && length(var.input_subnet_id) == 0 ? 1 : 0
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main[0].id
  }
  tags = merge(local.common_tags, var.tags)
}

# Creates Route table association rules if no Subnets are provided
resource "aws_route_table_association" "private" {


  count          = var.parent && length(var.input_subnet_id) == 0 ? length(var.private_subnet_id) : 0
  subnet_id      = element(var.private_subnet_id, count.index)
  route_table_id = aws_route_table.private[0].id
}
