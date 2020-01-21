#!/bin/env python
# -*- coding: utf-8 -*-

# custom modules
from lib.metric_exporter import PrometheusPushMetric
from lib.util import LOGGER


class CostUsageReportSpend:
    def __init__(self):
        self.logger = LOGGER('__cur_cost_usage__').config()

    def account_month_to_date_spend(self, accounts_df, date, prom_endpoint):
        required_columns = ['u_aws_account_number', 'u_environment', 'billing_account_name']

        tags = ['account_id', 'env', 'account_name']

        labels = {'year': date.year,
                  'month': date.month,
                  'day': date.day}

        account_ids = accounts_df['u_aws_account_number'].unique()

        for account_id in account_ids:
            self.logger.info("Processing Account %s", account_id)
            account_df = accounts_df[accounts_df['u_aws_account_number'] == account_id]

            total = format(float(account_df['cost_total'].sum()), '.3f')
            # Get the last row of the from pandas data frame, to get the column details
            row = account_df.iloc[-1]

            for index, _ in enumerate(required_columns):
                labels = {tags[index]: getattr(row, required_columns[index])}

            metric_cur_daily_usage = PrometheusPushMetric(account_id, prom_endpoint,
                                                          'cur_aws_daily_usage_cost', 'AWS Daily Usage Cost', **labels)

            metric_cur_daily_usage.push(total, **labels)

    def service_month_to_date_spend(self):
        pass