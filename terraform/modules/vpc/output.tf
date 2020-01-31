output "vpc_id" {
  value = var.parent ?  length(var.public_subnet_id) == 0 && length(var.private_subnet_id) == 0  ? length(aws_vpc.main) > 0 ? aws_vpc.main[0].id : ""  : data.aws_subnet.subnet[0].vpc_id : ""
}
