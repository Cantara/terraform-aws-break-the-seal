"""Create an IAM user with MFA and place the seed in SSM in common services"""
import time

import boto3
import pyotp

team_session = boto3.session.Session(
    profile_name="bts-team",
    region_name="eu-west-1"
)
common_services_session = boto3.session.Session(
    profile_name="bts-common",
    region_name="eu-west-1"
)

iam_client = team_session.client('iam')
sts_client = team_session.client('sts')
ssm_client = common_services_session.client('ssm')


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
    account_id = sts_client.get_caller_identity()['Account']
    ssm_client.put_parameter(
        Name=f"/break-the-seal/{account_id}-mfa-seed",
        Description=f'MFA Seed for break.the.seal.user in {account_id}',
        Type='SecureString',
        KeyId="alias/Break-the-seal-parameters",
        Overwrite=True,
        Value=seed,
    )


if __name__ == "__main__":
    username = "break.the.seal.user"
    mfa_device = create_user_with_mfa(username)

    print("Enabling MFA - takes 30s...")
    enable_mfa(username, mfa_device)

    publish_mfa_seed(str(mfa_device['VirtualMFADevice']['Base32StringSeed']))
