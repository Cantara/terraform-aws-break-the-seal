#!/bin/bash
set -euo pipefail
if [ "`aws iam list-users | jq '.Users[] | select(.UserName == "break.the.seal.user")'`" != "" ]
then
  echo "Removing Old User"
  aws iam delete-login-profile --user-name break.the.seal.user
  mfa_device=`aws iam list-mfa-devices --user-name break.the.seal.user |jq -r .MFADevices[].SerialNumber`
  aws iam deactivate-mfa-device --user-name break.the.seal.user --serial-number $mfa_device
  aws iam delete-virtual-mfa-device --serial-number $mfa_device
  aws iam delete-user --user-name break.the.seal.user
fi

if [ -z ${CENTRAL_ACCOUNT_NUMBER} ]; then read -p "Central Account Number:" CENTRAL_ACCOUNT_NUMBER; fi
if [ -z ${KMS_KEY_ID} ]; then read -p "KMS KEY ID:" KMS_KEY_ID; fi
read -p "Team Name:" TEAM_NAME
if [ -z ${LASTPASS_USERNAME} ]; then read -p "Lastpass Username:" LASTPASS_USERNAME; fi
lpass login $LASTPASS_USERNAME
pip install -r requirements.txt
awsaccountalias=`aws iam list-account-aliases | jq -r '.AccountAliases[]'`
python create-user.py $TEAM_NAME $awsaccountalias $CENTRAL_ACCOUNT_NUMBER $KMS_KEY_ID
NEW_PASS=`lpass generate password 20`
echo "setting password for $awsaccountalias"
aws iam create-login-profile --user-name break.the.seal.user --password $NEW_PASS --no-password-reset-required
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