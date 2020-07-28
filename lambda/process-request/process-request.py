#!/usr/bin/env python 3
import json
from yaml import load
import boto3
import logging
import zipfile
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

try:
    from yaml import CLoader as Loader
except ImportError:
    from yaml import Loader


class Request:
    requester_name = None
    requester_email = None
    account_number = None
    reason = None

    def __init__(self, params):
        for k, v in params.items():
            if hasattr(self, k):
                setattr(self, k, v)

    def __repr__(self):
        return "%s(Requester Name=%r, Requester Email=%r, AccountNumber=%r, Reason=%r)" % (
            self.__class__.__name__, self.requester_name, self.requester_email,
            self.account_number, self.reason
        )


def process_file(input_file):
    file_data = load(input_file, Loader=Loader)
    request_data = file_data["request"]
    try:
        request = Request(request_data)
        print(request)
    except Exception as e:
        logger.error(e.__class__)
        return ()
    ssm_client = boto3.client('ssm', region_name='eu-west-1')
    try:
        mfa_seed = ssm_client.get_parameter(
            Name='/break-the-seal/' + str(request.account_number) + '-mfa-seed',
            WithDecryption=True)['Parameter']['Value']
    except Exception as e:
        logger.info(e.__class__)
        mfa_seed = "Sorry an MFA seed for that account cannot be found."

    ses = boto3.client('ses', region_name='eu-west-1')
    response = ses.send_email(
        Source='cco@capraconsulting.no',
        Destination={
            'ToAddresses': [
                request.requester_email,
            ],
        },
        Message={
            'Subject': {
                'Data': 'Break The Seal Request',
                'Charset': 'UTF-8'
            },
            'Body': {
                'Text': {
                    'Data': 'The MFA seed for account ' + str(request.account_number) + ' is ' + str(mfa_seed),
                    'Charset': 'UTF-8'
                },
            }
        },
    )

    logger.info(json.dumps(response))


def lambda_handler(event, context):
    try:
        temp_zip = '/tmp/file.zip'
        s3_bucket = event["Records"][0]["s3"]["bucket"]["name"]
        s3_key = event["Records"][0]["s3"]["object"]["key"]
        s3_client = boto3.client('s3')
        s3_client.download_file(s3_bucket, s3_key, temp_zip)
        zfile = zipfile.ZipFile(temp_zip)
        for name in zfile.namelist():
            if name.startswith("requests/") and name.endswith(".yml"):
                data = zfile.read(name)
                process_file(data)
    except Exception as e:
        logger.error(e.__class__)
        return ()
    push_repo_back_config = json.loads(os.environ['config_for_next_lambda'])
    s3_path = f"s3://{s3_bucket}/{s3_key}"
    push_repo_back_config.update({"content": s3_path})

    lamdba_client = boto3.client('lambda')
    response = lamdba_client.invoke(
        FunctionName=push_repo_back_config['fargate_lambda_name'],
        InvocationType='Event',
        Payload=json.dumps(push_repo_back_config)
    )
    response = {
        "statusCode": 200,
        "body": json.dumps('Request Processed')
    }
    return response
