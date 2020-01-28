
locals {
  common_tags = {
    Name = "costbuddy_lambda"
  }
}

# Query the private subnet to get attributes like VPC id etc.
data "aws_subnet" "private_subnet" {
  count = var.parent ? 1 : 0
  id    = var.private_subnet_id
}


# Archive the costbuddy application to deploy lambda
data "archive_file" "costbuddy_lambda_zip" {
  count       = var.parent ? 1 : 0
  output_path = "/tmp/costbuddy_lambda_function.zip"
  type        = "zip"
  source_dir  = "../src"

}

# Creates security group for costbuddy lambda
resource "aws_security_group" "lambda_sg" {
  count  = var.parent ? 1 : 0
  name   = "costbuddy_lambdas_sg"
  vpc_id = data.aws_subnet.private_subnet[0].vpc_id
  tags   = merge(local.common_tags, var.tags)

  # Explicit whitelisting for outbound access
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Deploys the layers required for costbuddy lambda
resource "aws_lambda_layer_version" "cost_buddy_layer" {
  #description = var.layer_size
  count            = var.parent ? 1 : 0
  filename         = "./modules/layers/costbuddy-lambda-layer.zip"
  layer_name       = "cost_buddy_layer_v1"
  source_code_hash = filebase64sha256("./modules/layers/costbuddy-lambda-layer.zip")
}

# Deploys the costbuddy lambda function.
resource "aws_lambda_function" "cost_buddy" {
  count            = var.parent ? 1 : 0
  filename         = "/tmp/costbuddy_lambda_function.zip"
  source_code_hash = data.archive_file.costbuddy_lambda_zip[0].output_base64sha256
  function_name    = "cost_buddy"
  role             = aws_iam_role.iam_for_lambda[0].arn
  handler          = "${lower(var.costbuddy_mode)}.process_daily_monthly_spend.lambda_handler"
  layers           = [aws_lambda_layer_version.cost_buddy_layer[0].arn, lookup(var.SciPy_layer, var.region)]
  timeout          = 900
  memory_size      = 3000
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg[0].id]
    subnet_ids         = [var.private_subnet_id]
  }
  environment {
    variables = {
      s3_bucket = var.costbuddy_output_bucket
    }
  }

  runtime = "python3.7"

  tags       = merge(local.common_tags, var.tags)
  depends_on = [data.archive_file.costbuddy_lambda_zip[0]]
}

# Deploys the costbuddy trigger lambda function
resource "aws_lambda_function" "cost_buddy_trigger" {
  count            = var.parent ? 1 : 0
  filename         = "/tmp/costbuddy_lambda_function.zip"
  source_code_hash = data.archive_file.costbuddy_lambda_zip[0].output_base64sha256
  function_name    = "cost_buddy_trigger"
  role             = aws_iam_role.iam_for_lambda[0].arn
  handler          = "ce.trigger.lambda_handler"

  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg[0].id]
    subnet_ids         = [var.private_subnet_id]
  }
  environment {
    variables = {
      s3_bucket = var.costbuddy_output_bucket
    }
  }

  runtime = "python3.7"
  timeout = 300
  tags    = merge(local.common_tags, var.tags)
}

# Deploys the costbuddy budget lambda
resource "aws_lambda_function" "cost_buddy_budget" {
  count            = var.parent ? 1 : 0
  source_code_hash = data.archive_file.costbuddy_lambda_zip[0].output_base64sha256
  filename         = "/tmp/costbuddy_lambda_function.zip"
  function_name    = "cost_buddy_budget"
  role             = aws_iam_role.iam_for_lambda[0].arn
  handler          = "budget.process_allocated_budget_data.lambda_handler"
  layers           = [aws_lambda_layer_version.cost_buddy_layer[0].arn, lookup(var.SciPy_layer, var.region)]
  timeout          = 900

  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg[0].id]
    subnet_ids         = [var.private_subnet_id]
  }

  environment {
    variables = {
      s3_bucket = var.costbuddy_output_bucket
    }
  }

  runtime = "python3.7"

  tags       = merge(local.common_tags, var.tags)
  depends_on = [data.archive_file.costbuddy_lambda_zip[0]]
}

# Dynamically geberates the JSON for IAM policy based on the account provided
data "template_file" "policy_json" {
  template = file("./modules/lambda/iam.tpl")
  count    = length(lookup(var.account_ids, "child_account_ids")) == 0 ? 1 : length(lookup(var.account_ids, "child_account_ids"))
  vars = {
    iam_arns = length(lookup(var.account_ids, "child_account_ids")) > 0 ? lookup(var.account_ids, "child_account_ids")[count.index] : "*"
  }
}

# Dynamically geberates the JSON for IAM policy based on the account provided
data "template_file" "service_json" {
  template = file("./modules/lambda/iam_policy.tpl")
  vars = {
    value         = join(",", data.template_file.policy_json.*.rendered)
    s3_bucket     = var.costbuddy_output_bucket
    cur_s3_bucket = var.cur_input_data_s3_path
  }
}

# Creates the IAM policy based on the account provided.
resource "aws_iam_role_policy" "costbuddy_lambda_policy" {
  count = var.parent ? 1 : 0
  name  = "costbuddy_lambda_policy"
  role  = aws_iam_role.iam_for_lambda[0].id

  policy = data.template_file.service_json.rendered

}

# Creates a IAM  role for the costbuddy lambda
resource "aws_iam_role" "iam_for_lambda" {
  count = var.parent ? 1 : 0
  name  = "costbuddy_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = merge(local.common_tags, var.tags)
}

# Creates a IAM  policy for the costbuddy state function
resource "aws_iam_role_policy" "costbuddy_state_function_policy" {
  count  = var.parent ? 1 : 0
  name   = "costbuddy-state-function-policy"
  role   = aws_iam_role.costbuddy_state_function_role[0].id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "${aws_lambda_function.cost_buddy_trigger[0].arn}",
                "${aws_lambda_function.cost_buddy[0].arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "states:StartExecution"
            ],
            "Resource": [
                "${aws_sfn_state_machine.costbuddy_state_function[0].id}"
            ]
	}
    ]
}
EOF
}

# Creates a IAM  role for the costbuddy state function
resource "aws_iam_role" "costbuddy_state_function_role" {
  count              = var.parent ? 1 : 0
  name               = "costbuddy-state-function-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["states.amazonaws.com", "events.amazonaws.com", "lambda.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = merge(local.common_tags, var.tags)
}

# Deploys the state function
resource "aws_sfn_state_machine" "costbuddy_state_function" {
  #count      = var.parent && upper(var.costbuddy_mode) == "CE" ? 1 : 0
  count      = var.parent ? 1 : 0
  name       = "costbuddy-state-function"
  role_arn   = aws_iam_role.costbuddy_state_function_role[0].arn
  definition = <<EOF
{
  "Comment": "Process Daily usage cost for all child accounts",
  "StartAt": "GetAllAccounts",
  "TimeoutSeconds": 900,
  "States": {
    "GetAllAccounts": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.cost_buddy_trigger[0].arn}",
      "ResultPath": "$",
      "Next": "ProcessDailyUsageAllAccounts",
      "Comment": "Get List of Child Accounts",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.SdkClientException",
            "Lambda.Unknown"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ]
    },
    "ProcessDailyUsageAllAccounts": {
      "Type": "Map",
      "InputPath": "$.accounts",
      "ItemsPath": "$",
      "MaxConcurrency": 0,
      "Iterator": {
        "StartAt": "ProcessDailyUsage",
        "States": {
          "ProcessDailyUsage": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.cost_buddy[0].arn}",
            "End": true
          }
        }
      },
      "ResultPath": "$.output",
      "End": true
    }
  }
}
EOF

  tags = merge(local.common_tags, var.tags)
}

# Creates a CloudWatch rule to trigger Sate function and Lambda
resource "aws_cloudwatch_event_rule" "trigger_costbuddy_function" {
  count               = var.parent ? 1 : 0
  name                = "costbuddy_trigger_event"
  description         = "Cloudwatch rule to trigger costbuddy step function, trigger everyday at 23:00"
  schedule_expression = "cron(0 23 * * ? *)"
  tags                = merge(local.common_tags, var.tags)
}

# Creates a Cloud Watch Event target to trigger state function
resource "aws_cloudwatch_event_target" "attach_cw_rule_with_sfn" {
  count    = var.parent && upper(var.costbuddy_mode) == "CE" ? 1 : 0
  arn      = aws_sfn_state_machine.costbuddy_state_function[0].id
  rule     = aws_cloudwatch_event_rule.trigger_costbuddy_function[0].name
  role_arn = aws_iam_role.costbuddy_state_function_role[0].arn
}

# Creates a Cloud Watch Event target to trigger lambda function
resource "aws_cloudwatch_event_target" "attach_cw_rule_with_cur_lambda" {
  count = var.parent && upper(var.costbuddy_mode) == "CUR" ? 1 : 0
  arn   = aws_lambda_function.cost_buddy[0].arn
  rule  = aws_cloudwatch_event_rule.trigger_costbuddy_function[0].name
}

# Creates a CloudWatch rule to trigger Sate function and Lambda
resource "aws_cloudwatch_event_rule" "costbuddy_budget_lambda_cw_rule" {
  count               = var.parent ? 1 : 0
  name                = "costbuddy_budget_trigger_event"
  description         = "Cloudwatch rule to trigger costbuddy budget lambda, trigger everyday at 23:00"
  schedule_expression = "cron(0 23 * * ? *)"
  tags                = merge(local.common_tags, var.tags)
}

# Creates a Cloud Watch Event target to trigger lambda function
resource "aws_cloudwatch_event_target" "costbuddy_attach_cw_rule_with_lambda" {
  count = var.parent ? 1 : 0
  arn   = aws_lambda_function.cost_buddy_budget[0].arn
  rule  = aws_cloudwatch_event_rule.costbuddy_budget_lambda_cw_rule[0].name
}

resource "aws_lambda_permission" "allow_cloudwatch_budget" {
  count         = var.parent ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchBudget"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_buddy_budget[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.costbuddy_budget_lambda_cw_rule[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_cur" {
  count         = var.parent && upper(var.costbuddy_mode) == "CUR" ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchCostbuddy"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_buddy[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.costbuddy_budget_lambda_cw_rule[0].arn
}
