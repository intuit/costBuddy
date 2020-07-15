
locals {
  common_tags = {
    Name = "costbuddy-monitoring-server"
  }
}


data "external" "getip" {
  program = ["bash", "./modules/prometheus/get_ip.sh"]
}

locals {
  cidr_admin_whitelist_all = concat(var.cidr_admin_whitelist, lookup(data.external.getip.result, "result", null) == null ? [] : list(lookup(data.external.getip.result, "result")))
}

# Uploads a new keypair
resource "aws_key_pair" "keypair" {
  count      = var.parent && var.key_pair == "" ? 1 : 0
  key_name   = "deployer-key"
  public_key = file(var.public_key_path)
}

# Get the subnet details including VPC id.
data "aws_subnet" "ingress_subnet" {
  count = var.parent ? 1 : 0
  id    = var.ingress_subnet_id
}


# Get the subnet details including VPC id.
data "aws_subnet" "private_subnet" {
  count = var.parent ? 1 : 0
  id    = var.private_subnet_id
}

#Creates S3 bucket for costbuddy
resource "aws_s3_bucket" "out_bucket" {
  count         = var.parent ? 1 : 0
  bucket        = var.costbuddy_output_bucket
  acl           = "private"
  force_destroy = true
  tags          = merge(local.common_tags, var.tags)
}


# Create user data file using templates.
data "template_file" "user_data" {
  count    = var.parent ? 1 : 0
  template = file("./modules/prometheus/userdata.tpl")
  vars = {
    parent_account          = var.parent_account
    docker_compose_version  = var.docker_compose_version
    md5                     = aws_s3_bucket_object.costbuddy_artifacts_object[0].etag
    costbuddy_output_bucket = var.costbuddy_output_bucket
  }
}

data "archive_file" "costbuddy_lambda_zip" {
  count       = var.parent ? 1 : 0
  output_path = "/tmp/artifacts.zip"
  type        = "zip"
  source_dir  = "../docker_compose"

}

resource "aws_s3_bucket_object" "costbuddy_artifacts_object" {
  count      = var.parent ? 1 : 0
  bucket     = aws_s3_bucket.out_bucket[0].id
  key        = "artifacts/artifacts.zip"
  source     = "/tmp/artifacts.zip"
  etag       = data.archive_file.costbuddy_lambda_zip[0].output_md5
  depends_on = [aws_s3_bucket.out_bucket[0], data.archive_file.costbuddy_lambda_zip[0]]
}

# Creates an EC2 instance to deploy Prometheus and Grafana
resource "aws_instance" "prometheus" {
  count = var.parent && var.prometheus_push_gw == "" ? 1 : 0

  ami = var.ami_id
  #availability_zone    = data.aws_subnet.ingress_subnet[0].availability_zone
  availability_zone    = var.subnet_az
  instance_type        = "t3.large"
  iam_instance_profile = aws_iam_instance_profile.costbuddy_profile[0].name
  subnet_id            = var.ingress_subnet_id
  user_data_base64     = base64gzip(data.template_file.user_data[0].rendered)
  key_name             = var.key_pair == "" ? aws_key_pair.keypair[0].key_name : var.key_pair
  vpc_security_group_ids = [
    aws_security_group.costbuddy_ssh_access[0].id,
    aws_security_group.costbuddy_http_outbound[0].id,
    aws_security_group.costbuddy_external_http_traffic[0].id,
  ]
  root_block_device {
    volume_type = "gp2"
    volume_size = 50

  }
  tags = merge(local.common_tags, var.tags)
}


data "aws_availability_zones" "available" {}


# Security group rules for ssh access to prometheus and grafana servers
resource "aws_security_group" "costbuddy_ssh_access" {
  count       = var.parent ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "Costbuddy_SSH_Access"
  description = "Allow SSH access"

  # Whitelisting ssh access from admin ip addresses
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = local.cidr_admin_whitelist_all
  }

  # Whitelisting bastion security group for ssh access
  dynamic "ingress" {
    for_each = var.bastion_security_group

    content {
      protocol        = "tcp"
      from_port       = 22
      to_port         = 22
      security_groups = var.bastion_security_group
    }
  }
  tags = merge(local.common_tags, var.tags)
}

# Security group for outbound security groups
resource "aws_security_group" "costbuddy_http_outbound" {
  count       = var.parent ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "Costbuddy_HTTP_outbound"
  description = "Allow HTTP connections out to the internet"

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, var.tags)
}

# Security group for external http traffic
resource "aws_security_group" "costbuddy_external_http_traffic" {
  count       = var.parent ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "costbuddy_external_http_traffic"
  description = "Allow external http traffic"

  # Whitelist 80 port of Grafana to all admin IP addresses
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = local.cidr_admin_whitelist_all
  }

  # Whitelist 9090 port of prometheus to all admin ipaddresses
  ingress {
    protocol    = "tcp"
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = local.cidr_admin_whitelist_all
  }

  # Whitelist 9091 port of prometheus gateway to all admin ipaddresses
  ingress {
    protocol    = "tcp"
    from_port   = 9091
    to_port     = 9091
    cidr_blocks = local.cidr_admin_whitelist_all
  }

  # Whitelist 9091 port of prometheus gateway to costbuddy lambda function
  ingress {
    protocol    = "tcp"
    from_port   = 9091
    to_port     = 9091
    cidr_blocks = [data.aws_subnet.private_subnet[0].cidr_block]
  }
  tags = merge(local.common_tags, var.tags)
}

# Creates a Elastic IP address
resource "aws_eip" "eip_prometheus" {

  count = var.parent ? 1 : 0
  vpc   = true
  tags  = merge(local.common_tags, var.tags)
}

# Associates the Elastic IP address to the Prometheus instance
resource "aws_eip_association" "eip_assoc" {

  count         = var.parent ? 1 : 0
  instance_id   = aws_instance.prometheus[0].id
  allocation_id = aws_eip.eip_prometheus[0].id

}


data "aws_route53_zone" "costbuddy" {
  count = var.hosted_zone_name_exists && var.zone_name != "" ? 1 : 0
  name  = var.zone_name
}


# Creates a Route53 zone record to access grafana and prometheus
resource "aws_route53_zone" "metrics" {

  count = var.parent && var.hosted_zone_name_exists == false && var.zone_name != "" ? 1 : 0
  name  = var.zone_name

  tags = merge(local.common_tags, var.tags)
}

# Creates a Route53 zone record to access grafana and prometheus
resource "aws_route53_record" "prometheus_www" {

  count   = var.parent && var.www_domain_name != "" ? 1 : 0
  zone_id = var.hosted_zone_name_exists ? data.aws_route53_zone.costbuddy[0].zone_id : aws_route53_zone.metrics[0].zone_id
  #  zone_id = aws_route53_zone.metrics[0].zone_id
  name    = var.www_domain_name
  type    = "A"
  ttl     = "3600"
  records = [aws_eip.eip_prometheus[0].public_ip]

}

# Creates an instance profile for Prometheus server
resource "aws_iam_instance_profile" "costbuddy_profile" {
  count = var.parent ? 1 : 0
  name  = "costbuddy_instance_profile"
  role  = aws_iam_role.iam_for_monitoring[0].name
}

# Creates an IAM role for instance profile
resource "aws_iam_role" "iam_for_monitoring" {
  count = var.parent ? 1 : 0
  name  = "costbuddy_role"
  force_detach_policies = true
  
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = merge(local.common_tags, var.tags)
}

# Creates an IAM policy for instance profile
resource "aws_iam_role_policy" "costbuddy_instance_policy" {
  count  = var.parent ? 1 : 0
  name   = "costbuddy-state-function-policy"
  role   = aws_iam_role.iam_for_monitoring[0].id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
              "arn:aws:s3:::${aws_s3_bucket.out_bucket[0].id}",
              "arn:aws:s3:::${aws_s3_bucket.out_bucket[0].id}/*"
            ]
        }
    ]
}
EOF
}

# Creates a EBS volume to store persistant data of prometheus server
resource "aws_ebs_volume" "promethues-disk" {
  count             = var.parent ? 1 : 0
  availability_zone = var.subnet_az
  size              = "75"

  tags = merge(local.common_tags, var.tags)


# Attaches the EBS volume to the Prometheus server
resource "aws_volume_attachment" "attach-prometheus-disk" {
  count        = var.parent ? 1 : 0
  force_detach = true
  device_name  = var.device_mount_path
  volume_id    = aws_ebs_volume.promethues-disk[0].id
  instance_id  = aws_instance.prometheus[0].id
}
