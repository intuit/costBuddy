variable "tags" { type = map }
variable "region" { type = string }
variable "SciPy_layer" { type = map }
variable "costbuddy_output_bucket" {}
variable "cur_input_data_s3_path" {}
variable "costbuddy_mode" {}
variable "account_ids" {}
variable "ingress_subnet_id" {}
variable "private_subnet_id" {}
variable "ingress_vpc_id" {}
variable "parent" { type = bool }
