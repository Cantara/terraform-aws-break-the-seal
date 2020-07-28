provider "aws" {
  version             = "2.70.0"
  region              = "eu-west-1"
}

module "breaktheseal" {
  source      = "../../"
  name_prefix = "break-the-seal"
  github_org = "nsbno"
  github_repo = "break-the-seal-requests"
  parameters_key_arn = "<key_arn_from_init>"
  trusted_accounts = [
    "111222333444",   # dummy account
    "222333444555",   # dummy account
    "333444555666"    # dummy account
  ]
}