[prometheus]
    gateway = "${prom_gw_address}"
    port = "${prom_gw_port}"
[s3]
    bucket = "${s3_output_bucket}/output-metrics" 
[cur]
    bucket = "${cur_input_data_s3_path}"
    daily_file_pattern = "${cur_input_data_s3_daily_pattern}"
    monthly_file_pattern = "${cur_input_data_s3_monthly_pattern}"
