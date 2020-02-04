""" This module interact with AWS CostExplorer API to get monthly projected spend
"""

import ast

from lib.credentials import SessionCreds
from lib.metric_exporter import OutputConfigParser
from lib.metric_exporter import PrometheusPushMetric
from lib.util import Utils, LOGGER


class CostExplorerProjected:
    """
       Calculates AWS account and service monthly projected spend information using AWS CostExplorer API.
    """
    def __init__(self, account_id):
        """
        Args:
            account_id : 12 digit AWS account id without hyphen
        """
        self.cred = SessionCreds()
        self.client = self.cred.get_client(account_id, 'ce')

        self.account_id = account_id
        self.util = Utils()
        self.logger = LOGGER('__forecast__').config()

        self.begin_of_month = self.util.first_day_of_month()
        self.yesterday = self.util.preceding_day()
        self.today = self.util.day_of_month()
        self.last_day = self.util.last_day_of_month(self.today)
        self.first_day_next_month = self.util.first_day_of_next_month()
        self.next_day_of_month = self.util.next_day_of_month()

        self.prom_conf = OutputConfigParser().parse_output_config('prometheus')
        self.prom_endpoint = "%s:%s" % (self.prom_conf['gateway'], self.prom_conf['port'])

    def account_monthly_projected_spend(self):
        """
        Retrieves a forecast for how much Amazon Web Services predicts that you will spend over the forecast
        time period i.e from beginning of the month to last day of the month
       """

        self.logger.info("Getting aws account projected spend amount..")

        # Prometheus labels to be included in the account level metric
        labels = {'account_id': self.account_id}

        metric_account_projected_spend = PrometheusPushMetric(self.account_id, self.prom_endpoint,
                                                              'ce_aws_account_monthly_forecast',
                                                              'AWS account monthly projected',
                                                              **labels)
        try:
            response = self.client.get_cost_forecast(
                TimePeriod={
                    'Start': self.next_day_of_month.isoformat(),
                    'End': self.first_day_next_month.isoformat()
                },
                Metric='UNBLENDED_COST',
                Granularity='MONTHLY',
                PredictionIntervalLevel=90  ## 51 - 99 Range #TODO User input
            )

            metric_account_projected_spend.push(response['Total']['Amount'], **labels)

        except Exception as error:
            self.logger.error(error)
            # If there is exception and projected cost not found for the account, send projected spend as 0
            metric_account_projected_spend.push(0, **labels)

    def get_active_services(self):
        """
        Get the list of actively used services. A service is active or not is determined based cost incurred

        Returns:
            services: list of actively used services

        """
        self.logger.info("Getting list of active services..")
        kwargs = {}
        results = []
        services = []
        token = None
        while True:
            if token:
                kwargs = {'NextPageToken': token}
            else:
                kwargs = {}
                data = self.client.get_cost_and_usage(TimePeriod={'Start': self.yesterday.isoformat(),
                                                                  'End': self.today.isoformat()},
                                                      Granularity='DAILY', Metrics=['UnblendedCost'],
                                                      GroupBy=[{'Type': 'DIMENSION', 'Key': 'LINKED_ACCOUNT'},
                                                               {'Type': 'DIMENSION', 'Key': 'SERVICE'}],
                                                      **kwargs)

                results += data['ResultsByTime']
                token = data.get('NextPageToken')
                if not token:
                    break

        for result_by_time in results:
            for group in result_by_time['Groups']:
                amount = group['Metrics']['UnblendedCost']['Amount']
                if ast.literal_eval(amount) != 0:
                    services.append(group['Keys'][1])

        return services

    def service_monthly_projected_spend(self):
        """
        Retrieves a forecast for how much Amazon Web Services predicts that you will spend over for each service
        for the forecast time period i.e from beginning of the month to last day of the month
        """

        self.logger.info("Getting forecast amount by service..")

        # Prometheus labels to be included in the service metric
        labels = {
            'account_id': '',
            'aws_service': ''
        }
        # Converting unicode service name to string
        active_services = [str(srv) for srv in self.get_active_services()]

        metric_service_projected_spend = PrometheusPushMetric(self.account_id, self.prom_endpoint,
                                                              'ce_aws_service_monthly_forecast',
                                                              'AWS Service monthly forecast',
                                                              **labels)

        for service in active_services:
            labels['aws_service'] = service
            labels['account_id'] = self.account_id
            try:
                response = self.client.get_cost_forecast(
                    TimePeriod={
                        'Start': self.next_day_of_month.isoformat(),
                        'End': self.first_day_next_month.isoformat()
                    },
                    Metric='UNBLENDED_COST',
                    Granularity='MONTHLY',
                    Filter={
                        'Dimensions': {
                            'Key': 'SERVICE',
                            'Values': [service]
                        }},
                    PredictionIntervalLevel=90  ## 51 - 99 Range
                )
                # Push metric to prometheus gateway instance
                metric_service_projected_spend.push(response['Total']['Amount'], **labels)

            except Exception as error:
                self.logger.error(error)
                # If there is exception and projected cost not found for a service, send projected spend as 0
                metric_service_projected_spend.push(0, **labels)
