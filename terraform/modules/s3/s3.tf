
locals {
  common_tags = {
    Name = "costbuddy-s3-bucket"
  }
}

# Creates a S3 key and values corresponding to each account id input user has provided
resource "aws_s3_bucket_object" "object" {
  for_each   = var.parent ? toset(concat([lookup(var.account_ids, "parent_account_id")], lookup(var.account_ids, "child_account_ids"))) : []
  bucket     = var.out_bucket.id
  key        = "accounts/${each.value}"
  depends_on = [var.out_bucket]
}

# Uploads a file in S3 by detemplatizing output.conf file
resource "aws_s3_bucket_object" "output_object" {
  count  = var.parent ? 1 : 0
  bucket = var.out_bucket.id
  key    = "conf/output.conf"

  content = templatefile("./modules/s3/output.conf.tpl", { prom_gw_address = var.prometheus_push_gw_endpoint, prom_gw_port = var.prometheus_push_gw_port, s3_output_bucket = var.costbuddy_output_bucket, cur_input_data_s3_path = var.cur_input_data_s3_path, dummy_var = var.prometheus_push_gw_endpoint, cur_input_data_s3_monthly_pattern = var.cur_input_data_s3_monthly_pattern, cur_input_data_s3_daily_pattern = var.cur_input_data_s3_daily_pattern })

  etag = md5(templatefile("./modules/s3/output.conf.tpl", { prom_gw_address = var.prometheus_push_gw_endpoint, prom_gw_port = var.prometheus_push_gw_port, s3_output_bucket = var.costbuddy_output_bucket, cur_input_data_s3_path = var.cur_input_data_s3_path, dummy_var = var.prometheus_push_gw_endpoint, cur_input_data_s3_monthly_pattern = var.cur_input_data_s3_monthly_pattern, cur_input_data_s3_daily_pattern = var.cur_input_data_s3_daily_pattern }))

}

# Uploads billing xls to S3 bucket
resource "aws_s3_bucket_object" "costbuddy_billing_file" {
  count      = var.parent ? 1 : 0
  bucket     = var.out_bucket.id
  key        = "input/bills.xlsx"
  source     = "../src/conf/input/bills.xlsx"
  etag       = filemd5("../src/conf/input/bills.xlsx")
  depends_on = [var.out_bucket]
}

# Creates a directory under the S3 bucket
resource "aws_s3_bucket_object" "costbuddy_output_metrics" {
  count      = var.parent ? 1 : 0
  bucket     = var.out_bucket.id
  key        = "output-metrics/"
  depends_on = [var.out_bucket]
}

