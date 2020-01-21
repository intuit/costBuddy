import boto3
import boto3.exceptions
import os


def lambda_handler(event, context):
    s3_bucket = os.getenv('s3_bucket')
    s3_client = boto3.client('s3')
    account_list = []
    s3_dir = "accounts"
    response = s3_client.list_objects(Bucket=s3_bucket, Prefix=s3_dir)
    if 'Contents' in response:
        for key in response['Contents']:
            account_list.append({"account_id": str((key['Key'].split('/')[1]))})
    return {"accounts": account_list}
