provider "aws" {
  version = "2.70.0"
  region  = "eu-west-1"
}

module "init" {
  source      = "../../../modules/init"
  name_prefix = "break-the-seal-example"
}

output "key_arn" {
  value = module.init.key_arn
}