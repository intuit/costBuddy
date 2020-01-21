
variable "SciPy_layer" {
  type = map
  default = {
    "us-west-2" : "arn:aws:lambda:us-west-2:420165488524:layer:AWSLambda-Python37-SciPy1x:2",
    "us-east-1" : "arn:aws:lambda:us-east-1:668099181075:layer:AWSLambda-Python37-SciPy1x:2",
    "us-west-1" : "arn:aws:lambda:us-west-1:325793726646:layer:AWSLambda-Python37-SciPy1x:2",
    "us-east-2" : "arn:aws:lambda:us-east-2:259788987135:layer:AWSLambda-Python37-SciPy1x:2"
  }
}

variable "public_key_path" {
  description = "My public ssh key"
  default     = "~/.ssh/id_rsa.pub"
}
variable "account_ids" {
  description = "Parent and Child account ID's"
  type = object({
    parent_account_id = string
  child_account_ids = list(string) })
}

variable "layer_name" {
  description = "Name of AWS SciPy layer"
  default     = "AWSLambda-Python37-SciPy1x"
}

variable "costbuddy_mode" {
  description = "Run Costbuddy on Cost Explorer data/ Cost Usage Report (CE/CUR)"
  default     = "CE"
}
variable "ami_id" {
  description = "AMI id to use while spinning up the monitoring servers. Default is Ubuntu base image"
  default     = ""
}

variable "prometheus_push_gw_endpoint" {
  description = "AWS region to deploy CostBuddy"
  type        = string
  default     = ""
}
variable "prometheus_push_gw_port" {
  description = "AWS region to deploy CostBuddy"
  type        = string
  default     = "9091"
}
variable "bastion_security_group_id" {
  description = "All Bastion security groups that require access"
  type        = list
  default     = []
}
variable "region" {
  description = "AWS region to deploy CostBuddy"
  type        = string
  default     = "us-west-2"
}
variable "docker_compose_version" {
  description = "AWS region to deploy CostBuddy"
  type        = string
  default     = "1.24.0"
}

variable "public_subnet_id" {
  description = "Subnet ID with Ingress access"
  type        = string
  default     = ""
}
variable "private_subnet_id" {
  description = "Subnet ID with Ingress access"
  type        = string
  default     = ""
}
variable "tags" {
  description = "CostBuddy Reosurce Tagging"
  type        = map
}

variable "costbuddy_zone_name" {
  description = "Prometheus Domain Name"
  type        = string
}
variable "hosted_zone_name_exists" {
  description = "Flag to determine whether the Zone needs to be created or it already exists."
  type        = bool
  default     = false
}

variable "cidr_admin_whitelist" {
  description = "CIDR ranges permitted to communicate with administrative endpoints"
  type        = "list"
}

variable "bastion_admin_whitelist" {
  description = "CIDR ranges permitted to communicate with administrative endpoints"
  type        = "list"
  default = [
    "0.0.0.0/32"
  ]
}
variable "key_pair" {
  description = "Valid AWS Key Pair"
  default     = ""
}
variable "costbuddy_output_bucket" {
  description = "Existing S3 bucket where Cost Buddy will write the result to, for QuickSight and other service to consume"
  default     = "costbuddy-output-bucket"
}
variable "cur_input_data_s3_path" {
  description = "Existing S3 bucket where Cost Buddy will read the AWS detailed billing report."
  default     = ""
}
variable "cur_input_data_s3_daily_pattern" {
  description = "File name prefix pattern in CUR S3 bucket where Cost Buddy will read the AWS detailed billing report."
  default     = ""
}
variable "cur_input_data_s3_monthly_pattern" {
  description = "File name prefix pattern in CUR S3 bucket where Cost Buddy will read the AWS detailed billing report."
  default     = ""
}

variable "www_domain_name" { default = "dashbaord" }
variable "device_mount_path" { default = "/dev/sdg" }
