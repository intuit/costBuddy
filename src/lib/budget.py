""" This module will parse and process allocation budget information file.
"""

import os
from datetime import datetime

import pandas as pd

from lib.metric_exporter import OutputConfigParser
from lib.metric_exporter import PrometheusPushMetric
from lib.util import Utils, LOGGER


class AccountBudget:
    """
    This class parse and process the budget file, which has monthly budget information for each AWS accounts
    """

    def __init__(self):
        self.logger = LOGGER('__AccountBudget__').config()
        self.util = Utils()

        # Prometheus labels to be included in the metric
        self.labels = {
            'account_id': '',
            'account_name': '',
            'owner': ''}

        self.costbuddy_output_bucket = os.getenv('s3_bucket')

        # Get the current YearMonth for processing budget allocation, example 201912
        self.current_month = datetime.strftime(datetime.today(), "%Y%m")

    def parse_budget_file(self):
        """
        Download and parse the allocated budget file and return the list of excel sheet names and excel file class

        :return: excel: Pandas excel file class
        :return  sheet_names: list of excel sheet names
        """

        budget_file = self.util.download_s3_file(bucket=self.costbuddy_output_bucket, filename='input/bills.xlsx')
        self.logger.info('Allocates Budget file downloaded location %s', budget_file)

        try:
            excel = pd.ExcelFile(budget_file)
            sheet_names = excel.sheet_names
        except Exception as error:
            self.logger.error("Unable to read XLXS File, error %s", error)
            return None, []

        return excel, sheet_names

    def get_aws_accounts(self):
        """
        Get the list of accounts from excel sheets

        :return: accounts: List of AWS Accounts
        """
        accounts = []
        excel, sheets = self.parse_budget_file()

        if len(sheets) == 0:
            return accounts

        for sheet in sheets:
            try:
                # All the columns in the data frame loaded as string data type
                # This required because some of the AWS account number has preceding zeros
                sheet_df = pd.read_excel(excel, sheet_name=sheet, dtype=str)

                # Convert month field data type from string to float
                convert_dict = {int(self.current_month): float}
                sheet_df = sheet_df.astype(convert_dict)

                # drop last row which has total
                sheet_df.drop(sheet_df.tail(1).index, inplace=True)
                accounts.extend(list(sheet_df['AWS Account ID'].unique()))

            except Exception as error:
                self.logger.exception("Unable to read sheet name %s  \n Error %s", sheet, error)
                # In case a sheet malformed, process other
                continue

        return accounts

    def process_budget_by_account(self, sheet_df):
        """
            Process monthly budget allocation for each account and send it to promethous gateway node

            :param sheet_df: An Excel Sheet data loaded into pandas.DataFrame
        """
        self.logger.info("Processing monthly budget by account")
        account_ids = sheet_df['AWS Account ID'].unique()  # get list of unique aws account ids

        for account_id in account_ids:
            self.logger.info("Processing Account %s", account_id)
            # Filter the row matches account_ids
            account_df = sheet_df[sheet_df['AWS Account ID'] == account_id]
            total = account_df[int(self.current_month)].sum()

            # Incase multiple row is matched, use the last row to fetch account name and owner info
            last_row = account_df.iloc[-1]

            account_name = getattr(last_row, 'Account Description')
            owner = getattr(last_row, 'Owner')

            try:
                prom_conf = OutputConfigParser().parse_output_config('prometheus')
                prom_endpoint = "%s:%s" % (prom_conf['gateway'], prom_conf['port'])

                metric_budget = PrometheusPushMetric(account_id, prom_endpoint, 'aws_account_monthly_budget',
                                                     'AWS monthly account budget', **self.labels)
            except Exception as error:
                self.logger.error(error)
                self.logger.error('Unable to load output conf.')
                return

            self.labels = {
                'account_id': account_id,
                'account_name': account_name,
                'owner': owner
            }

            metric_budget.push(total, **self.labels)

    def process_monthly_budget(self):
        """"
            Iterate over each spread sheet in the excel file and process the monthly budget info for each accounts
        """

        excel, sheets = self.parse_budget_file()

        if len(sheets) == 0:
            return

        for sheet in sheets:
            try:
                # All the columns in the data frame loaded as string data type
                # This required because some of the AWS account number has preceding zeros
                sheet_df = pd.read_excel(excel, sheet_name=sheet, dtype=str)

                # Convert month field data type from string to float
                convert_dict = {int(self.current_month): float}
                sheet_df = sheet_df.astype(convert_dict)

                # drop last row which has total
                sheet_df.drop(sheet_df.tail(1).index, inplace=True)
                self.process_budget_by_account(sheet_df)

            except Exception as error:
                self.logger.exception("Unable to read sheet name %s  \n Error %s", sheet, error)
                # In case a sheet malformed, process other
                continue
