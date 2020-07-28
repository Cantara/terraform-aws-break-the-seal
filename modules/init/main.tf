resource "aws_kms_key" "break-the-seal-parameters" {
  description = "KMS key for encrypting parameters needed by break the seal."
}

resource "aws_kms_alias" "key-alias" {
  name          = "alias/${var.name_prefix}-parameters"
  target_key_id = aws_kms_key.break-the-seal-parameters.id
}