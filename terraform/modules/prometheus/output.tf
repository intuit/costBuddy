output "prometheus_instance" {
  value = var.parent && length(aws_instance.prometheus) != 0 ? aws_instance.prometheus[0] : null
}
output "eip_instance" {
  value = var.parent && length(aws_eip.eip_prometheus) != 0 ? aws_eip.eip_prometheus[0] : null
}
output "prometheus_vpc_id" {
  value = var.parent && length(data.aws_subnet.ingress_subnet) != 0 ? data.aws_subnet.ingress_subnet[0].vpc_id : null
}
output "output_bucket" {
  value = var.parent && length(aws_s3_bucket.out_bucket) != 0 ? aws_s3_bucket.out_bucket[0] : null
}
