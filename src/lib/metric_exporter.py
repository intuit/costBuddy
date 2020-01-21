"""
This module has classes and definition to parse config file and push metrics to prometheus push gateway and uploades
metrics to s3
"""
import os
import tempfile

import boto3
import pandas as pd
from configobj import ConfigObj, SimpleVal
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

from lib.util import LOGGER
from lib.util import Utils


class OutputConfigParser:
    """
    This class uses configobj python library to download output config file from s3 and parse the output config file by
    reading the different sections in config files and returns section as dict object.

    Config file looks like a .ini file with different sections
    Example:
        [prometheus]
            gateway = ''
            port    = 0

        [s3]
            bucket = ''
    """

    def __init__(self):
        self.logger = LOGGER('__OutputConfig__').config()
        self.util = Utils()
        self.heir_dir = os.path.dirname(os.path.dirname(__file__))
        self.conf_dir = os.path.join(self.heir_dir, 'conf/output')
        self.output_spec = os.path.join(self.conf_dir, 'output.spec')
        self.costbuddy_output_bucket = os.getenv('s3_bucket')

        self.logger.info("Downloading conf file from s3")
        self.output_conf = self.util.download_s3_file(bucket=self.costbuddy_output_bucket, filename='conf/output.conf')

    def parse_output_config(self, config_name):
        """

        Args:
            config_name : ConfigObj section name, example prometheus or s3

        Returns:
            section as dict object

        """
        config_file_spec = ConfigObj(self.output_spec, interpolation=False, list_values=False, _inspec=True)
        config_file_obj = ConfigObj(self.output_conf, configspec=config_file_spec)

        # A simple validator used to check that all members expected in conf file are present.
        validator = SimpleVal()

        # test_pass would be True, If every member of a subsection passes, else False
        test_pass = config_file_obj.validate(validator)

        if test_pass is False:
            self.logger.error("Not all required output configs are passed")
            self.logger.error("Check src/conf/output/output.spec for required inputs")

        if config_name in config_file_obj:
            return config_file_obj[config_name]

        return {}


class PrometheusPushMetric:
    """
    This class pushes cost metrics to the given prometheus push gateway.
    """

    def __init__(self, aws_account_id, prom_gateway, metric_name, metric_desc, **labels):
        """
        Args:
            aws_account_id : 12 digit AWS account id without hyphen
            prom_gateway : IP or DNS name of push gateway instance
            metric_name : Name of the prometheus metric
            metric_desc : Short description about the metric
            **labels : Is a dict object with key as label name and value as label values
        """
        self.util = Utils()
        self.logger = LOGGER('__PrometheusPushMetric__').config()

        # Create a list of Metric objects
        self.registry = CollectorRegistry()
        self.account_id = aws_account_id
        self.prom_gateway = prom_gateway
        self.metric_name = metric_name

        self.labels = list(labels.keys())

        # Add year, month, day labels
        if not all(label in self.labels for label in ['year', 'month', 'day']):
            self.labels.extend(['year', 'month', 'day'])

        # Update labels dict with key account_id and value 12 digit account id, if account_id label is not passed
        # account_id is a mandatory label required for each metric
        if 'account_id' not in self.labels:
            self.labels.extend(['account_id'])

        self.metric = Gauge(metric_name, metric_desc, self.labels, registry=self.registry)

    def push(self, metric_value, **labels):
        """
        Push metrics to prometheus push gateway instance        
        Args:
            metric_value : string data type, prometheus metric name, examp
            **labels : Dict data type with promethous labels and values

        Returns:

        """
        today = self.util.get_day_month_year()

        # job label to be attached to all pushed metrics
        job_name = "AWS_%s_%s" % (self.account_id, self.metric_name)

        timestamp_labels = {'year': today.year,
                  'month': today.month,
                  'day': today.day
                  }

        labels.update(timestamp_labels)

        # Update the account_id label value
        if 'account_id' not in labels.keys():
            labels['account_id'] = self.account_id

        # Validate if metric has all required params:  name, documentation, type, unit
        self.metric.describe()
        self.logger.info(labels)
        # Update metrics labels
        self.metric.labels(**labels).set(metric_value)

        # Push metrics to Prometheus gateway instance
        push_to_gateway(self.prom_gateway, job=job_name, registry=self.registry)


class S3Upload:
    """
    This class uploads Cost explore metrics to s3 bucket as excel file, this excel file can be used and processed by
    tools like AWS Athena, QuickSight
    """

    def __init__(self, account_id, bucket, file_name):
        """
        Args:
            account_id : 12 digit AWS account id without hyphen
            bucket : S3 bucket name
            file_name : Complete S3 key name, like conf/example.com or example.com
        """
        self.logger = LOGGER('__S3Upload__').config()
        self.s3_client = boto3.client('s3')
        self.util = Utils()
        self.account_id = account_id
        self.file_name = file_name

        # Extract only bucket name, if bucket name passed with dir, example custbuddy-output/conf, self.bucket would be
        # just bucket name 'custbuddy-output'
        self.bucket = bucket.split('/')[0]
        # Dir name would be remaining, once s3 bucket name extracted
        self.dir = bucket.split('/')[1]
        self.rows = []

    def add_excel_row(self, date, amount, labels):
        """
        Create a list to be added as excel rows
        Args:
            date : Current date with format yyyy-mm-dd
            amount : Service or account usage cost
            labels : Is a dict object with key as label name and value as label values, key would be column header
            and value would be row value

        Returns:

        """
        if 'account_id' not in labels.keys():
            labels['account_id'] = self.account_id

        labels['amount'] = amount
        labels['date'] = date
        self.logger.info(labels)
        self.rows.append(labels)

    # TODO Upload function instead of destructor
    # TODO Cleanup function for clean up data

    def __del__(self):
        """
        Adds an rows to excel sheet and uploads to s3 bucket

        When this class is called for multiple accounts, destructor being used to delete the object once file is
        uploaded, so that it can be used for other accounts.
        """
        tmp_dir = tempfile.mkdtemp()
        self.file_name = self.file_name + ".xlsx"
        xlsx_file = os.path.join(tmp_dir, self.file_name)
        self.logger.info("File location :: %s", xlsx_file)
        writer = pd.ExcelWriter(xlsx_file, engine='xlsxwriter')

        account_df = pd.DataFrame(self.rows)
        account_df.set_index("date", inplace=True)
        account_df.fillna(0.0)
        account_df.to_excel(writer)
        writer.save()
        self.s3_client.upload_file(xlsx_file, self.bucket, '%s/%s' % (self.dir, self.file_name))
        self.logger.info('File has been uploaded to s3')
