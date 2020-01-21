"""
This module overwrites the default AWS session and creates a custom session with assumed role credentials
"""

import boto3


class SessionCreds:
    """
    Generates custom boto3 session for an aws service by assuming custbuddy access role for cross account communication
    """

    def __init__(self):
        pass

    @staticmethod
    def get_client(account_id, service):
        """

        Args:
            account_id : 12 digit AWS account id without hyphen
            service : AWS service name, example ce, s3

        Returns:
            client: Boto3 session client with role credentials

        """
        session = boto3.Session()

        # create an STS client object that represents a live connection to the
        sts_client = session.client('sts')

        # Cross account Role to assume to access cost explore API
        role_to_assume_arn = 'arn:aws:iam::%s:role/costbuddy_access_role' % account_id

        # Call the assume_role method of the STSConnection object and pass the role
        # ARN and a role session name.
        response = sts_client.assume_role(RoleArn=role_to_assume_arn, RoleSessionName='costbuddy')

        credentials = response['Credentials']

        # Retrieve the token STS token and create a session client with :param service
        client = session.client(service, aws_access_key_id=credentials.get("AccessKeyId"),
                                aws_secret_access_key=credentials.get("SecretAccessKey"),
                                aws_session_token=credentials.get("SessionToken"))
        return client
