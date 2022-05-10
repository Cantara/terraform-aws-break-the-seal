#!/bin/bash
set -euo pipefail

read -p "Team Account ID: " TEAM_ACCOUNT_ID
read -p "Common Services Acocunt ID: " COMMON_ACCOUNT_ID

aws --profile "bts-team" configure set azure_tenant_id "$(aws configure get azure_tenant_id)"
aws --profile "bts-team" configure set azure_app_id_uri "$(aws configure get azure_app_id_uri)"
aws --profile "bts-team" configure set azure_default_username "$(aws configure get azure_default_username)"
aws --profile "bts-team" configure set azure_default_duration_hours "$(aws configure get azure_default_duration_hours)"
aws --profile "bts-team" configure set azure_default_role_arn "arn:aws:iam::${TEAM_ACCOUNT_ID}:role/SAML-AdministratorRole"

aws --profile "bts-common" configure set azure_tenant_id "$(aws configure get azure_tenant_id)"
aws --profile "bts-common" configure set azure_app_id_uri "$(aws configure get azure_app_id_uri)"
aws --profile "bts-common" configure set azure_default_username "$(aws configure get azure_default_username)"
aws --profile "bts-common" configure set azure_default_duration_hours "$(aws configure get azure_default_duration_hours)"
aws --profile "bts-common" configure set azure_default_role_arn "arn:aws:iam::${COMMON_ACCOUNT_ID}:role/SAML-AdministratorRole"

# If we're in WSL, azure-aws-login doesn't work. This has to be done by the user in PS
if grep -q WSL2 /proc/version; then
  echo "Run the following commands in PowerShell:"
  echo ""
  echo "  " aws-azure-login --no-prompt --profile "bts-team"
  echo "  " aws-azure-login --no-prompt --profile "bts-common"
  echo ""
  read -p "Please hit ENTER when you have RUN THE COMMANDS ABOVE IN POWERSHELL" HAS_RUN
else
  aws-azure-login --no-prompt --profile "bts-team"
  aws-azure-login --no-prompt --profile "bts-common"
fi

read -p "Team Name:" TEAM_NAME

read -p "Lastpass Username:" LASTPASS_USERNAME
lpass login $LASTPASS_USERNAME


if [ "`aws --profile "bts-team" iam list-users | jq '.Users[] | select(.UserName == "break.the.seal.user")'`" != "" ]
then
  echo "Removing Old User"
  aws --profile "bts-team" iam delete-login-profile --user-name break.the.seal.user
  mfa_device=`aws --profile "bts-team" iam list-mfa-devices --user-name break.the.seal.user | jq -r .MFADevices[].SerialNumber`
  aws --profile "bts-team" iam deactivate-mfa-device --user-name break.the.seal.user --serial-number $mfa_device
  aws --profile "bts-team" iam delete-virtual-mfa-device --serial-number $mfa_device
  aws --profile "bts-team" iam delete-user --user-name break.the.seal.user
fi

pip install -r requirements.txt
python create-user.py

awsaccountalias=`aws --profile "bts-team" iam list-account-aliases | jq -r '.AccountAliases[]'`

NEW_PASS=`lpass generate password 20`
echo "setting password for $awsaccountalias"
aws --profile "bts-team" iam create-login-profile --user-name break.the.seal.user --password $NEW_PASS --no-password-reset-required
echo "adding credentials to lastpass"
lpass share create Shared-Break-The-Seal-${TEAM_NAME}
lpass sync
if [ "`lpass ls Shared-Break-The-Seal-${TEAM_NAME}/${awsaccountalias}`" != ""  ]
then
  echo -ne "Name: Shared-Break-The-Seal-${TEAM_NAME}/${awsaccountalias}\nURL: https://${awsaccountalias}.signin.aws.amazon.com/console\nUsername: break.the.seal.user\nPassword: ${NEW_PASS}" | lpass edit --sync=now --non-interactive $(lpass show -j Shared-Break-The-Seal-infrastructure/infrademo-test|jq -r .[].id)
else
  echo -ne "Name: Shared-Break-The-Seal-${TEAM_NAME}/${awsaccountalias}\nURL: https://${awsaccountalias}.signin.aws.amazon.com/console\nUsername: break.the.seal.user\nPassword: ${NEW_PASS}" | lpass add --sync=now --non-interactive "Shared-Break-The-Seal-${TEAM_NAME}/${awsaccountalias}"
fi
sleep 10
lpass ls |grep Shared-Break-The-Seal-${TEAM_NAME}
echo "Credentials added to lastpass folder Shared-Break-The-Seal/$TEAM_NAME/$awsaccountalias"
