variable "ami_id" {}
variable "region" {}
variable "key_pair" {}
variable "parent_account" {}
variable "docker_compose_version" {}
variable "bastion_security_group" {}
variable "prometheus_push_gw" {}
variable "ingress_subnet_id" {}
variable "private_subnet_id" {}
variable "tags" {}
variable "parent" {}
variable "zone_name" {}
variable "cidr_admin_whitelist" {}
variable "www_domain_name" {}
variable "hosted_zone_name_exists" {}
variable "device_mount_path" {
  description = "The path to mount the promethus disk"
  default     = "/dev/sdh"
}
variable "public_key_path" {
  description = "My public ssh key"
}
variable "costbuddy_output_bucket" {}
