output "subnet_id" {
  value = var.parent ? length(var.subnet_id) > 0 ? var.subnet_id : length(aws_subnet.main) >0 ? aws_subnet.main[*].id : [""] : [""]
}
output "subnet_az" {
  value = var.parent ? length(var.subnet_id) > 0 ? data.aws_subnet.subnet[0].availability_zone : length(aws_subnet.main) > 0 ? aws_subnet.main[0].availability_zone : "" : ""
}
