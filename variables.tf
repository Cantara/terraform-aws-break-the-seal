variable "name_prefix" {
  description = "Typically the name of the application. This value is used as a prefix to the name of most resources created including the public URL"
  type        = string
  default     = "break-the-seal"
}
variable "github_org" {
  description = "The name of the github organisation where the access request repo resides"
  type        = string
}
variable "github_repo" {
  description = "The name of the github repo (excluding the organisation) where access requests are made"
  type        = string
}

variable "trusted_accounts" {
  description = "A list of account numbers for the accounts that are set up to use break-the-seal"
  type        = list(string)
}

variable "parameters_key_arn" {
  description = "The arn of the kms key used to encrypt the application parameters stored in SSM"
  type        = string
}

variable "vpc_cidr_block" {
  description = "cidr block to use for VPC"
  type        = string
  default     = "192.168.51.0/24"
}