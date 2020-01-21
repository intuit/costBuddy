"""
This module has common date time functions and logger module
"""
import datetime
import logging
import os
import sys
import time
import shutil
import boto3
import botocore.exceptions


class LOGGER:
    """
    Costbuddy logging class, writes lambda logs to cloudwatch log group
    """
    def __init__(self, loggerid=None, debug=False):
        self.loggerid = loggerid
        self.debug = debug

    def config(self):
        """
        Logger configuration

        Returns:
            logger: Return a logger with the specified name, if no name is specified, return the root logger.
        """
        level = logging.DEBUG if self.debug else logging.INFO
        logger = logging.getLogger(self.loggerid)
        logger.handlers = []
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter("%(asctime)s  - %(name)s  %(levelname)s  %(message)s")
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.setLevel(level)
        logger.propagate = False
        return logger


class Utils:
    """
    Common functions used across different modules
    """
    def __init__(self):
        self.logger = LOGGER('__utils__').config()
        self.temp_dir = "/tmp"

    @staticmethod
    def day_of_month():
        """
        Get current day of the month
        Returns:
            A datetime data type of current day
        """
        today = datetime.date.today()
        days = today.day
        if today.day > 25:
            today += datetime.timedelta(7)
        return today.replace(day=1) + datetime.timedelta(days=days)

    @staticmethod
    def first_day_of_month():
        """
        Get first day of the month
        Returns:
            Return a new date with day as first day of the month
        """
        return datetime.date.today().replace(day=1)

    @staticmethod
    def preceding_day():
        """
        Get the yesterday date
        Returns:
            yesterday: A datetime data type wih prior date information.

        """
        yesterday = datetime.date.today() - datetime.timedelta(days=1)
        return yesterday

    @staticmethod
    def last_day_of_month(any_day):
        """
           Get last day of the month
           Returns:
               Return a new date with day as last day of the month
        """
        next_month = any_day.replace(day=28) + datetime.timedelta(days=4)  # this will never fail
        return next_month - datetime.timedelta(days=next_month.day)

    @staticmethod
    def get_date(as_of_date):
        # date format 2019-02-10 20:00:00
        as_of_date_format = time.strptime(as_of_date, '%Y-%m-%d %H:%M:%S')

        as_of_month_date = "%d-%d-%d" % (as_of_date_format.tm_year, as_of_date_format.tm_mon,
                                         as_of_date_format.tm_mday)
        year, month, day = as_of_date_format.tm_year, as_of_date_format.tm_mon, as_of_date_format.tm_mday
        return as_of_month_date, year, month, day

    @staticmethod
    def get_previous_month_year():
        """
        Get previous month and previous year
        if Year is same for current month and previous month return same year

        return:
            @prev_month: 11 [if current month is 12]
            @prev_year: 2019 [if current year is 2019]
        """
        today = datetime.date.today()
        first_day_cur_month = today.replace(day=1)
        last_day_prev_month = first_day_cur_month - datetime.timedelta(days=1)
        prev_month = last_day_prev_month.strftime("%m").lstrip('0')
        prev_year = last_day_prev_month.strftime("%Y")
        return prev_month, prev_year

    @staticmethod
    def get_current_month_year():
        """
        Get current month year
        Return:
            @current_mon_year: 201912
        """
        today = datetime.date.today()
        current_mon_year = today.strftime("%Y%m")
        return current_mon_year

    @staticmethod
    def get_day_month_year():
        """
        Get the todays date
        Returns:
            today: A datetime data type wih current date information.

        """
        today = datetime.date.today()
        return today

    def download_s3_file(self, bucket=None, filename=None):
        """
        Download an S3 object to local /tmp dir

        arg:
            @bucket: an AWS s3 bucket
            @filename: The name of the file to be downloaded

        return:
            @downloaded_file: local path of downloaded file /tmp/example.txt
        """

        s3_resource = boto3.resource('s3')
        # Downloaded file name will be /tmp/example.txt, if filename passed as conf/example.txt
        downloaded_file = os.path.join(self.temp_dir, filename.split('/')[-1])

        try:
            s3_resource.Bucket(bucket).download_file(filename, downloaded_file)
            return downloaded_file
        except botocore.exceptions.ClientError as error:
            if error.response['Error']['Code'] == "404":
                self.logger.exception("The object does not exist.")
                raise TypeError(botocore.exceptions.ClientError)

            # any other error just raise an exception
            self.logger.exception(error)
            raise

    def clean_up_tmp_dir(self):
        """
        Clean up lambda /tmp dir
        Returns:

        """
        if os.path.isdir(self.temp_dir):
            shutil.rmtree(self.temp_dir+"/*",  ignore_errors=True, onerror=None)