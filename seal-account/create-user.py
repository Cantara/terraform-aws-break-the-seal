"""Usage: create-user.py TEAM_NAME ACCOUNT_ALIAS KMS_KEY_ID ROLE_ARN

Provisions admin user and stores credentials.
Arguments:
  TEAM_NAME     Name of the team that owns the account.
  ACCOUNT_ALIAS Account alias of the account.
  KMS_KEY_ID    Key ID of the KMS key to encrypt the MFA seed with.
  ROLE_ARN      ARN of the role to assume in the central account for pushing MFA seeds
Options:
  -h --help
"""
import boto3
import pyotp
import time
from docopt import docopt

arguments = docopt(__doc__)
kms_key_id = arguments['KMS_KEY_ID']
role_arn = arguments['ROLE_ARN']

iam_client = boto3.client('iam', region_name='eu-west-1')
sts_client = boto3.client('sts')

assumed_role_object = sts_client.assume_role(
    RoleArn=role_arn,
    RoleSessionName='BreakTheSeal'
)
credentials = assumed_role_object['Credentials']
ssm_client = boto3.client(
    'ssm',
    region_name='eu-west-1',
    aws_access_key_id=credentials['AccessKeyId'],
    aws_secret_access_key=credentials['SecretAccessKey'],
    aws_session_token=credentials['SessionToken'],
)


def create_user_with_mfa(username):
    iam_client.create_user(UserName=username)
    virtual_mfa_device = iam_client.create_virtual_mfa_device(
        VirtualMFADeviceName="break.the.seal.user.virtual.mfa.device"
    )

    return virtual_mfa_device


def enable_mfa(username, mfa_device):
    totp = pyotp.TOTP(mfa_device['VirtualMFADevice']['Base32StringSeed'])

    value_1 = totp.now()
    time.sleep(30)
    value_2 = totp.now()

    iam_client.enable_mfa_device(
        UserName=username,
        SerialNumber=mfa_device['VirtualMFADevice']['SerialNumber'],
        AuthenticationCode1=value_1,
        AuthenticationCode2=value_2
    )


def publish_mfa_seed(seed: str):
    account_id = boto3.client('sts').get_caller_identity()['Account']
    ssm_client.put_parameter(
        Name=f"/break-the-seal/{account_id}-mfa-seed",
        Description=f'MFA Seed for break.the.seal.user in {account_id}',
        Type='SecureString',
        KeyId=kms_key_id,
        Overwrite=True,
        Value=seed,
    )


if __name__ == "__main__":
    username = "break.the.seal.user"
    mfa_device = create_user_with_mfa(username)

    print("Enabling MFA - takes 30s...")
    enable_mfa(username, mfa_device)

    publish_mfa_seed(str(mfa_device['VirtualMFADevice']['Base32StringSeed']))
