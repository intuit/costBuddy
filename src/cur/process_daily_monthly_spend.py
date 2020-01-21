#!/bin/env python
# -*- coding: utf-8 -*-

import time
from multiprocessing import Process

import pandas as pd

from lib.budget import AccountBudget
from lib.cur_cost_usage import CostUsageReportSpend
from lib.cur_projected_spend import CostUsageReportProjected
from lib.metric_exporter import OutputConfigParser
from lib.util import Utils, LOGGER


def lambda_handler(event, context):
    """"
        Lambda function to process daily and monthly spend using AWS cost utilization report.
    """
    logger = LOGGER('__cur_cost_usage__').config()

    budget = AccountBudget()
    # Get the list of AWS accounts from budget file
    accounts = budget.get_aws_accounts()

    util = Utils()
    util.clean_up_tmp_dir()

    prom_conf = OutputConfigParser().parse_output_config('prometheus')
    prom_endpoint = "%s:%s" % (prom_conf['gateway'], prom_conf['port'])

    cur_conf = OutputConfigParser().parse_output_config('cur')
    s3_bucket = cur_conf['bucket']
    daily_file_pattern = cur_conf['daily_file_pattern']
    monthly_file_pattern = cur_conf['monthly_file_pattern']

    #201912*filefomart.csv
    #TODO file pattern suffix
    daily_cur_file = "%s_%s.csv000" % (util.get_current_month_year(), daily_file_pattern)
    monthly_cur_file = "%s_%s.csv000" % (util.get_current_month_year(), monthly_file_pattern)

    # Daily cost usage report
    try:
        downloaded_file = util.download_s3_file(bucket=s3_bucket, filename=daily_cur_file)
        logger.info("Downloaded file name %s", downloaded_file)
    except Exception as error:
        logger.exception("Unable to download file %s", error)
        return

    # TODO Column name change
    columns = ['usagestartdate_date', 'aws_account_number', 'environment', 'aws_account_name',
               'aws_service_code', 'operation', 'component', 'app',
               'appenv', 'user', 'bu', 'cost_total']

    try:
        daily_usage_df = pd.read_csv(downloaded_file, dtype=str, header=None)
        # set the column names
        daily_usage_df.columns = columns

        # Convert cost_total column to float
        convert_dict = {'cost_total': float}
        daily_usage_df = daily_usage_df.astype(convert_dict)
    except Exception as error:
        logger.error("Unable to read daily usage CSV File %s ", error)
        return

    # Process latest set of records
    last_record_date = "1970-01-01"
    for lastrecord in getattr(daily_usage_df.tail(1), 'usagestartdate_date'):
        last_record_date = lastrecord

    today = util.get_day_month_year()

    latest_df = daily_usage_df[daily_usage_df['usagestartdate_date'] == last_record_date]
    accounts_df = latest_df[latest_df['aws_account_number'].isin(accounts)]

    cur_spend = CostUsageReportSpend()
    cur_spend.account_month_to_date_spend(accounts_df, today, prom_endpoint)

    # Clean up /tmp dir before processing monthly cur file.
    util.clean_up_tmp_dir()

    # Monthly cost and usage report, seperate function
    try:
        downloaded_file = util.download_s3_file(bucket=s3_bucket, filename=monthly_cur_file)
        logger.info("Downloaded file name %s", downloaded_file)
    except Exception as error:
        logger.exception("Unable to download file, %s", error)
        return

    # TODO Column name change
    columns = ['month_of_year', 'fiscal_quarter_of_year', 'as_of_date', 'bu', 'application_name',
               'aws_account_number', 'environment', 'account_name', 'aws_service_code', 'operation',
               'component', 'user_app', 'appenv', 'user', 'finance_part', 'monthly_cost_to_date',
               'projected_month_end_cost', 'quarterly_cost_to_date', 'projected_quarter_end_cost']

    try:
        monthly_spend_df = pd.read_csv(downloaded_file, dtype=str, header=None)
        monthly_spend_df.columns = columns

        convert_dict = {'monthly_cost_to_date': float,
                        'projected_month_end_cost': float,
                        'quarterly_cost_to_date': float,
                        'projected_quarter_end_cost': float
                        }
        monthly_spend_df = monthly_spend_df.astype(convert_dict)
    except Exception as error:
        logger.exception("Unable to read CSV File, %s", error)
        return

    accounts_df = monthly_spend_df[monthly_spend_df['aws_account_number'].isin(accounts)]

    cur_projected = CostUsageReportProjected()

    # Process monthly/projected spend cost by account id
    process = Process(target=cur_projected.account_monthly_projected_spend, args=(accounts_df, prom_endpoint))
    cur_projected.processes.append(process)

    # start all processes
    for process in cur_projected.processes:
        process.start()

    # Wait for thread completion and ensure all threads have finished
    for process in cur_projected.processes:
        process.join()
