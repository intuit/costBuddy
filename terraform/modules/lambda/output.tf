output "state_function" {
  value = var.parent && length(aws_sfn_state_machine.costbuddy_state_function) != 0 ? aws_sfn_state_machine.costbuddy_state_function[0].id : null
}

output "budget_lambda" {
  value = var.parent && length(aws_lambda_function.cost_buddy_budget) != 0 ? aws_lambda_function.cost_buddy_budget[0].arn : null
}
output "cur_lambda" {
  value = var.parent && length(aws_lambda_function.cost_buddy) != 0 ? aws_lambda_function.cost_buddy[0].arn : null
}
