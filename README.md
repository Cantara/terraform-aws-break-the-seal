## Terraform AWS Break-The-Seal

A module that pre-provisions emergency access users.

Users provisioned with this module have usernames and passwords automatically generated and saved to LastPass and
have MFA enabled, and the MFA seed encrypted and saved to the parameter store of a central account.

In the event of emergency access users that have access to the account credentials in LastPass and have access to push
to a specified GitHub repository can request to have the MFA seed emailed to them.


### Sealing Accounts
##### Pre-requisites:
* Access to a Premium Lastpass account
* Admin (IAM Full Access) Access to the account to be sealed
* Docker installed

###### Instructions:
1. Obtain AWS credentials / temporary credentials (aws-azure-login, vaulted, aws-vault).
2. Clone this repo.
3. (Optional) if you are going to seal many accounts export your LastPass 
username `export LASTPASS_USERNAME=<mylastpass_username>` so that you don't have to enter it each time.
3. From the root of this repo run `make seal`and follow the dialogue.
    1. Enter a Team Name - this is used to specify which LastPass folder to add the credentials to. You must have access
     to write to this folder if it already exists. 
    2. Enter your LastPass username (skipped if you have exported your LastPass username)
    3. Enter your LastPass password
    4. Enter your LastPass MFA
    
