
locals {
  common_tags = {
    Name = "costbuddy-internet-gateway"
  }
}

# Creates Internet Gateway if no Subnets are provided
resource "aws_internet_gateway" "main" {
  count  = var.parent && length(var.input_subnet_id) == 0 ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(local.common_tags, var.tags)
}

# Creates Route table if no Subnets are provided
resource "aws_route_table" "public" {

  count  = var.parent && length(var.input_subnet_id) == 0 ? 1 : 0
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  tags = merge(local.common_tags, var.tags)
}

# Creates Route table association rules if no Subnets are provided
resource "aws_route_table_association" "public" {


  count          = var.parent && length(var.input_subnet_id) == 0 ? 1 : 0
  subnet_id      = element(var.public_subnet_id, 0)
  route_table_id = aws_route_table.public[0].id
}

