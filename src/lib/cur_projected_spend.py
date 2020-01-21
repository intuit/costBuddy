""" This module uses AWS Cost and Usage report file to get month to date spend and monthly projected spend.
"""
from multiprocessing import Process

# custom modules
from lib.metric_exporter import PrometheusPushMetric
from lib.util import Utils, LOGGER


class CostUsageReportProjected:
    """
       Calculates AWS account and service monthly projected spend information using AWS Cost and Usage report file.
    """
    def __init__(self):
        self.logger = LOGGER('__cur_monthly_projected_spend').config()
        self.util = Utils()
        self.processes = []

    def account_monthly_projected_spend(self, accounts_df, prom_endpoint):
        """
        Parse AWS Cost and Usage Monthly Report and calculate how much Amazon Web Services predicts that you will
        spend over for each account from beginning of the month to last day of the month.

        Also, calculates monthly spend so far by each account.

        Args:
            accounts_df : Pandas data frame containing AWS services month to date spend and projected spend
            prom_endpoint : Prometheus push gateway endpoint, IP address or a DNS name.
        """
        account_ids = accounts_df['u_aws_account_number'].unique()  # get list of unique aws account ids

        for account_id in account_ids:
            self.logger.info("Processing AWS Account ID %s", account_id)
            account_df = accounts_df[accounts_df['u_aws_account_number'] == account_id]

            # Process monthly spend / projected spend by aws service
            process = Process(target=self.service_monthly_projected_spend, args=(account_df, account_id, prom_endpoint))
            process.start()
            process.join()

            cost_total = account_df['monthly_cost_to_date'].sum()
            projected_total = account_df['projected_month_end_cost'].sum()
            month_todate_spend = format(float(cost_total), '.3f')
            projected_spend = format(float(projected_total), '.3f')
            last_row = account_df.iloc[-1]

            _, cost_year, cost_month, cost_day = self.util.get_date(getattr(last_row, 'as_of_date'))

            labels = {'account_id': account_id,
                      'account_name': getattr(last_row, 'billing_account_name'),
                      'env': getattr(last_row, 'u_environment'),
                      'year': cost_year,
                      'month': cost_month,
                      'day': cost_day
                      }

            metric_account_month_todate_spend = PrometheusPushMetric(account_id, prom_endpoint,
                                                                     'cur_aws_account_monthly_spend',
                                                                     'AWS account month to date spend cost',
                                                                     **labels)

            metric_account_month_todate_spend.push(month_todate_spend, **labels)

            metric_account_projected_spend = PrometheusPushMetric(account_id, prom_endpoint,
                                                                  'cur_aws_account_monthly_forecast',
                                                                  'AWS account month to date spend cost',
                                                                  **labels)

            metric_account_projected_spend.push(projected_spend, **labels)

    def service_monthly_projected_spend(self, services_df, account_id, prom_endpoint):
        """
        Parse AWS Cost and Usage Monthly Report and calculate how much Amazon Web Services predicts that you will
        spend over for each service from beginning of the month to last day of the month.

        Also, calculates monthly spend so far by each service.

        Args:
            services_df : Pandas data frame containing AWS services month to date spend and projected spend
            account_id : 12 digit AWS account id without hyphen
            prom_endpoint : Prometheus push gateway endpoint, IP address or a DNS name.
        """

        # get list of unique aws account ids
        services = services_df['aws_service_code'].unique()
        # Prometheus labels to be included in the service metric
        labels = {'account_id': '', 'account_name': '', 'env': '', 'aws_service': '', 'year': '', 'month': '',
                  'day': ''}

        metric_service_monthly_spend = PrometheusPushMetric(account_id, prom_endpoint,
                                                            'cur_aws_service_monthly_spend',
                                                            'AWS service month to date spend cost',
                                                            **labels)

        metric_service_projected_spend = PrometheusPushMetric(account_id, prom_endpoint,
                                                              'cur_aws_service_monthly_forecast',
                                                              'AWS service month to date spend cost',
                                                              **labels)

        for service in services:
            self.logger.info("Processing AWS Service %s", service)
            service_df = services_df[services_df['aws_service_code'] == service]
            cost_total = service_df['monthly_cost_to_date'].sum()
            projected_total = service_df['projected_month_end_cost'].sum()

            month_todate_spend = format(float(cost_total), '.3f')
            projected_spend = format(float(projected_total), '.3f')
            last_row = service_df.iloc[-1]

            _, cost_year, cost_month, cost_day = self.util.get_date(getattr(last_row, 'as_of_date'))

            labels = {'account_id': account_id,
                      'account_name': getattr(last_row, 'billing_account_name'),
                      'env': getattr(last_row, 'u_environment'),
                      'aws_service': service,
                      'year': cost_year,
                      'month': cost_month,
                      'day': cost_day
                      }

            metric_service_monthly_spend.push(month_todate_spend, **labels)
            metric_service_projected_spend.push(projected_spend, **labels)
