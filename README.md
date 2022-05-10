## Terraform AWS Break-The-Seal

A module that pre-provisions emergency access users.

Users provisioned with this module have usernames and passwords automatically generated and saved to LastPass and
have MFA enabled. The MFA seed is encrypted and saved to the parameter store of a central account.

In the event of emergency access users that have access to the account credentials in LastPass and have access to push
to a specified GitHub repository can request to have the MFA seed emailed to them and gain access to the sealed account.

# Sealing Accounts

To run this, you need:

* A Premium LastPass account
* Admin (IAM Full Access) Access to the account to be sealed
* Docker
* The ARN of the role to assume in the central account in order to push SSM params (output from terraform)
* KMS Key ID of the KMS key in the central account used to encrypt MFA seed (output from terraform)

## Seal an account

To seal an account, just run `make seal` and follow the instructions.


# Initial Setup

1. Create a GitHub repository for making break-the-seal requests from
1. Create a key pair for this repository and add the public key to the Deploy keys
1. Create a folder for the environment <your_environment>
1. Create an init subfolder in that folder
1. In the init folder Create a terraform script that uses the modules/init submodule and run it once (and only once) 
to create a key for encrypting parameters
1. Note the parameters_key_arn output from the last step
1. Add the private part of the key pair as a secure string encrypted with the parameters key to parameter store in 
the central account to a parameter called break-the-seal-git-deploy-key
1. In the <your_environment> folder create a terraform script that uses the main module and use the value recorded 
in step 4 for the parameters_key_arn parameter
1. Add the account numbers of any accounts you wish to use break-the-seal with to the trusted accounts parameter
1. Run terraform apply to deploy Break-The-Seal
1. Add the following secrets to the GitHub break-the-seal requests repository - terraform created a limited CI user
and recorded the credentials in parameter store
    * AWS_ACCESS_KEY_ID (get this value from parameter store where the terraform put it)
    * AWS_SECRET_ACCESS_KEY (get this value from parameter store where the terraform put it)
    * DEPLOY_KEY (this is the private! part of the deploy key you added earlier)
1. Add the file below to the break-the-seal requests repository and update the  <AWS ACCOUNT NUMBER> and <BUCKET NAME> 
values to the central account number and the bucket created by the terraform script.
1. Add `requests` and `processed-requests` folders to the break-the-seal requests repository
1. Add empty placeholder files `placeholder` to the directories created so that the directories exist when checked out
of git.
1. Give access to write to the repository to anyone you wish to have access to request MFA seeds from break-the-seal

`.github/workflows/upload-to-s3.yml`
```

name: Upload to S3

on:
  push:
    branches: [ master ]

jobs:
  upload:
    if: "!contains(github.event.head_commit.message, '[skip ci]')"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ssh-key: ${{ secrets.DEPLOY_KEY }}
          ssh-strict: no
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY}}
          aws-region: eu-west-1
      - name: Zip Repo
        run: |
          zip -r ${GITHUB_SHA::7}.zip .
      - name: Upload to S3
        run: |
          aws s3 cp ${GITHUB_SHA::7}.zip s3://<AWS ACCOUNT NUMBER>-<BUCKET NAME>/${GITHUB_SHA::7}.zip
```
