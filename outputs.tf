output "KMS_KEY_ID" {
  value       = aws_kms_key.github_actions-parameters.id
  description = "The ID of the KMS key used to encrypt MFA seeds"
}
output "ROLE_ARN" {
  value       = aws_iam_role.push_ssm_params.arn
  description = "The ARN of the role to assume to push MFA seeds to parameter store in the central account"
}