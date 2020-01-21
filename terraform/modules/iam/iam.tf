locals {
  common_tags = {
    Name = "costbuddy-iam-role"
  }
}

# Create a policy for CE cross account query
resource "aws_iam_role_policy" "costbuddy_access_policy" {
  name = "costbuddy_access_policy"
  role = "${aws_iam_role.costbuddy_access_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ce:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# IAM STS Assume role for CE cross account calls
resource "aws_iam_role" "costbuddy_access_role" {
  name = "costbuddy_access_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Effect": "Allow",
        "Principal": {
        "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
    },
    {
        "Effect": "Allow",
        "Principal": {
        "AWS": "arn:aws:iam::${lookup(var.account_ids, "parent_account_id")}:role/costbuddy_lambda_role"
        },
        "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags               = merge(local.common_tags, var.tags)
}
