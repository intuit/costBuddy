""" This module interact with AWS CostExplorer API to get daily and monthly usage cost
"""

import ast

from lib.credentials import SessionCreds
from lib.metric_exporter import OutputConfigParser
from lib.metric_exporter import PrometheusPushMetric, S3Upload
from lib.util import Utils, LOGGER


class CostExplorerUsage:
    """
    Calculates AWS account billing information using AWS CostExplorer API.
    """
    def __init__(self, account_id):
        """
        Args:
            account_id : 12 digit AWS account id without hyphen
        """
        self.account_id = account_id
        self.logger = LOGGER('__CostExplorer__').config()
        self.util = Utils()
        self.cred = SessionCreds()

        self.begin_of_month = self.util.first_day_of_month()
        self.yesterday = self.util.preceding_day()

        self.today = self.util.get_day_month_year()
        self.last_day = self.util.last_day_of_month(self.today)

        self.client = self.cred.get_client(account_id, 'ce')

        self.results = []

        self.prom_conf = OutputConfigParser().parse_output_config('prometheus')
        self.prom_endpoint = "%s:%s" % (self.prom_conf['gateway'], self.prom_conf['port'])

        self.s3_conf = OutputConfigParser().parse_output_config('s3')
        self.s3_bucket = self.s3_conf['bucket']

        self.s3_upload = S3Upload(account_id, self.s3_bucket, 'daily_%s' % self.today.isoformat())

    def daily_service_usage(self):
        """
        calculates daily service cost and usage metrics for your account and forwards the metrics to prometheus
        and uploads to s3

        start and end dates are required retrieving AWS costs and granularity daily

        Start: The beginning of the time period that you want the usage and costs for. The start date is inclusive.
        End: The end of the time period that you want the usage and costs for. The end date is exclusive.
        """
        self.logger.info("Getting daily service usage amount..")

        # Prometheus labels to be included in the service metric
        labels = {
            'account_id': '',
            'aws_service': ''
        }

        metric_service_daily_usage = PrometheusPushMetric(self.account_id, self.prom_endpoint,
                                                          'ce_aws_service_daily_spend', 'AWS Service Usage Cost',
                                                          **labels)
        token = None
        while True:
            if token:
                kwargs = {'NextPageToken': token}
            else:
                kwargs = {}
                # TODO - Linked account
                data = self.client.get_cost_and_usage(TimePeriod={'Start': self.yesterday.isoformat(),
                                                                  'End':  self.today.isoformat()},
                                                      Granularity='DAILY', Metrics=['UnblendedCost'],
                                                      GroupBy=[{'Type': 'DIMENSION', 'Key': 'LINKED_ACCOUNT'},
                                                               {'Type': 'DIMENSION', 'Key': 'SERVICE'}],
                                                      **kwargs)
                self.results += data['ResultsByTime']
                token = data.get('NextPageToken')
                if not token:
                    break

        for result_by_time in self.results:
            for group in result_by_time['Groups']:
                amount = group['Metrics']['UnblendedCost']['Amount']
                if ast.literal_eval(amount) != 0:
                    labels = {
                        'account_id': group['Keys'][0],
                        'aws_service': group['Keys'][1]
                    }
                    # Push daily cost usage metrics to prometheus
                    metric_service_daily_usage.push(amount, **labels)
                    # Upload cost usage data to s3
                    self.s3_upload.add_excel_row(self.today.isoformat(), amount, labels)

    def service_month_to_date_spend(self):
        """
        calculates month to date spend cost and usage metrics by service.

        Gets the spend data from beginning of the month to month to date by each service and forwards the metrics to
        prometheus and uploads to s3.

       start and end dates are required retrieving AWS costs and granularity monthly

       Start: First date of the current month. The start date is inclusive.
       End: Month to date/current date. The end date is exclusive.
       """

        # Prometheus labels to be included in the service metric
        labels = {
            'account_id': '',
            'aws_service': ''
        }
        self.logger.info("Getting month to date spend by each service..")
        metric_service_month_to_date_spend = PrometheusPushMetric(self.account_id, self.prom_endpoint,
                                                                  'ce_aws_service_monthly_spend',
                                                                  'AWS Service month to date spend amount',
                                                                  **labels)


        kwargs = {}
        data = self.client.get_cost_and_usage(TimePeriod={'Start': self.begin_of_month.isoformat(),
                                                          'End': self.today.isoformat()},
                                              Granularity='MONTHLY',
                                              Metrics=['UnblendedCost'],
                                              GroupBy=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}],
                                              **kwargs)

        for service in data['ResultsByTime'][0]['Groups']:
            amount = service['Metrics']['UnblendedCost']['Amount']
            if ast.literal_eval(amount) != 0:
                labels = {
                    'aws_service': service['Keys'][0]
                }

                metric_service_month_to_date_spend.push(amount, **labels)

    def account_month_to_date_spend(self):
        """
        calculates month to date spend cost and usage metrics for your account.
        Gets the account spend data from beginning of the month to month to date and forwards the metrics to prometheus
        and uploads to s3

        start and end dates are required retrieving AWS costs and granularity monthly

        Start: First date of the current month. The start date is inclusive.
        End: Month to date/current date. The end date is exclusive.
        """
        # Prometheus labels to be included in the account metricx
        labels = {
            'account_id': ''
        }
        self.logger.info("Getting month to date spend by account..")
        metric_account_month_to_date_spend = PrometheusPushMetric(self.account_id, self.prom_endpoint,
                                                                  'ce_aws_account_monthly_spend',
                                                                  'AWS account monthly spend',
                                                                  **labels)
        kwargs = {}
        data = self.client.get_cost_and_usage(TimePeriod={'Start': self.begin_of_month.isoformat(),
                                                          'End': self.today.isoformat()},
                                              Granularity='MONTHLY',
                                              Metrics=['UnblendedCost'],
                                              GroupBy=[{'Type': 'DIMENSION', 'Key': 'LINKED_ACCOUNT'}],
                                              **kwargs)
        for account in data['ResultsByTime']:
            amount = account['Groups'][0]['Metrics']['UnblendedCost']['Amount']
            account_id = account['Groups'][0]['Keys'][0]
            labels = {
                'account_id': account_id
            }
            metric_account_month_to_date_spend.push(amount, **labels)
