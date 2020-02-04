# Specify the compatible terraform version
terraform {
  required_version = ">= 0.12.0"
  # To prevent automatic upgrades to new major versions 
  required_providers {
    archive  = "~> 1.3"
    aws      = "~> 2.34"
    template = "~> 2.1"
    local    = "~> 1.2"
  }

}

# Create the IAM roles for the resources
module "costbuddy_iam" {
  source = "./modules/iam"

  account_ids = var.account_ids

  tags = var.tags
}

# Creates S3 bucket and generates the output.conf file
module "costbuddy_s3" {
  source = "./modules/s3"

  account_ids                 = var.account_ids
  parent                      = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  prometheus_push_gw_endpoint = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") && module.prometheus.prometheus_instance != null ? coalesce(var.prometheus_push_gw_endpoint, module.prometheus.prometheus_instance.private_ip) : coalesce(var.prometheus_push_gw_endpoint, "${var.www_domain_name}.${var.costbuddy_zone_name}")

  prometheus_push_gw_port           = coalesce(var.prometheus_push_gw_port, "9091")
  cur_input_data_s3_path            = var.cur_input_data_s3_path
  cur_input_data_s3_daily_pattern   = var.cur_input_data_s3_daily_pattern
  cur_input_data_s3_monthly_pattern = var.cur_input_data_s3_monthly_pattern
  costbuddy_output_bucket           = "${var.costbuddy_output_bucket}-${data.aws_caller_identity.current.account_id}"
  out_bucket                        = module.prometheus.output_bucket


  tags = var.tags

}

# Creates a VPC
module "vpc" {
  source = "./modules/vpc"

  parent = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  public_subnet_id  = var.public_subnet_id
  private_subnet_id = var.private_subnet_id
  cidr_block        = "192.168.0.0/24"

  tags = var.tags

}

# Creates a Subnet
module "public_subnet" {
  source = "./modules/subnet"

  parent = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  name              = "public"
  subnet_id         = var.public_subnet_id
  vpc_id            = module.vpc.vpc_id
  subnet_cidr_block = ["192.168.0.0/25"]

  tags = var.tags
}

# Creates a Subnet
module "private_subnet" {
  source = "./modules/subnet"

  parent = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  name              = "private"
  subnet_id         = var.private_subnet_id
  vpc_id            = module.vpc.vpc_id
  subnet_cidr_block = ["192.168.0.128/26"]

  tags = var.tags
}

# Creates a InternetGateway and attaches the public subnets
module "igw" {
  source = "./modules/igw"

  parent = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  input_subnet_id  = var.public_subnet_id
  public_subnet_id = module.public_subnet.subnet_id
  vpc_id           = module.vpc.vpc_id

  tags = var.tags
}

# Creates a NATGateway and attaches the private subnets
module "nat_gw" {
  source = "./modules/nat"

  parent = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  input_subnet_id   = var.private_subnet_id
  public_subnet_id  = module.public_subnet.subnet_id
  private_subnet_id = module.private_subnet.subnet_id
  vpc_id            = module.vpc.vpc_id
  mod_depends_on    = module.igw

  tags = var.tags
}

# Deploys the lambda application
module "costbuddy_lambda" {
  source = "./modules/lambda"

  SciPy_layer = var.SciPy_layer
  region      = var.region
  parent      = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  account_ids = var.account_ids
  # ingress_subnet_id       = var.public_subnet_id
  # private_subnet_id       = var.private_subnet_id
  ingress_subnet_id = module.public_subnet.subnet_id[0]
  private_subnet_id = module.private_subnet.subnet_id[0]
  # ingress_vpc_id          = module.prometheus.prometheus_vpc_id
  ingress_vpc_id          = module.vpc.vpc_id
  costbuddy_mode          = var.costbuddy_mode
  cur_input_data_s3_path  = var.cur_input_data_s3_path
  costbuddy_output_bucket = "${var.costbuddy_output_bucket}-${data.aws_caller_identity.current.account_id}"


  tags = var.tags
}

# Provisions the EC2 instances and installs Prometheus and grafana stack
module "prometheus" {
  source = "./modules/prometheus"

  parent = data.aws_caller_identity.current.account_id == lookup(var.account_ids, "parent_account_id") ? true : false
  region = var.region
  # private_subnet_id      = var.private_subnet_id
  private_subnet_id      = module.private_subnet.subnet_id[0]
  ingress_subnet_id      = module.public_subnet.subnet_id[0]
  subnet_az              = module.public_subnet.subnet_az
  vpc_id                 = module.vpc.vpc_id
  bastion_security_group = var.bastion_security_group_id
  prometheus_push_gw     = var.prometheus_push_gw_endpoint

  ami_id                  = coalesce(var.ami_id, data.aws_ami.ubuntu.id)
  zone_name               = var.costbuddy_zone_name
  hosted_zone_name_exists = var.hosted_zone_name_exists
  www_domain_name         = var.www_domain_name
  cidr_admin_whitelist    = var.cidr_admin_whitelist
  public_key_path         = var.public_key_path
  key_pair                = var.key_pair
  #  ingress_subnet_id       = var.public_subnet_id
  docker_compose_version  = var.docker_compose_version
  parent_account          = lookup(var.account_ids, "parent_account_id")
  costbuddy_output_bucket = "${var.costbuddy_output_bucket}-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

# Identify the Caller account details
data "aws_caller_identity" "current" {}

# Fetch the latest Ubuntu image from Canonical Ubuntu Account
data "aws_ami" "ubuntu" {
  most_recent = true

  # Canonical Ubnuntu distribution
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
