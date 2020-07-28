data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "main" {}


locals {
  current_account_id = data.aws_caller_identity.current.account_id
  current_region     = data.aws_region.current.name
  tags = {
    terraform   = "true"
    environment = "service"
    application = var.name_prefix
  }
  public_cidr_blocks = [for k, v in data.aws_availability_zones.main.names :
  cidrsubnet(var.vpc_cidr_block, 4, k)]
}

module "vpc" {
  source               = "github.com/nsbno/terraform-aws-vpc?ref=ec7f57f"
  name_prefix          = var.name_prefix
  cidr_block           = var.vpc_cidr_block
  availability_zones   = data.aws_availability_zones.main.names
  public_subnet_cidrs  = local.public_cidr_blocks
  create_nat_gateways  = false
  enable_dns_hostnames = true
  tags                 = local.tags
}

resource "aws_iam_role" "push_ssm_params" {
  name               = "${var.name_prefix}-push-ssm-params"
  description        = "This role enables the trusted accounts to push parameters (MFA seed values) to Parameter Store"
  assume_role_policy = data.aws_iam_policy_document.push_ssm_params_assume.json
}

resource "aws_iam_role_policy" "push_params_to_push_ssm_params" {
  policy = data.aws_iam_policy_document.push_params_for_push_ssm_params.json
  role   = aws_iam_role.push_ssm_params.id
}

resource "aws_lambda_function" "process_unlock_request" {
  function_name    = "${var.name_prefix}-process-unlock-request"
  handler          = "process-request.lambda_handler"
  role             = aws_iam_role.process_unlock.arn
  runtime          = "python3.8"
  filename         = "${path.module}/lambda/process-request/process-request.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/process-request/process-request.py")
  timeout          = 20
  environment {
    variables = {
      config_for_next_lambda = local.push_repo_input_single_use_fargate_task
    }
  }
}

resource "aws_iam_role" "process_unlock" {
  name               = "${var.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lamda_assume.json
}

resource "aws_iam_role_policy" "permissions_to_process_unlock" {
  policy = data.aws_iam_policy_document.permissions_for_process_unlock.json
  role   = aws_iam_role.process_unlock.id
}

resource "aws_iam_role_policy" "lambda_invoke_to_process_unlock" {
  policy = data.aws_iam_policy_document.lambda_invoke_for_process_unlock.json
  role = aws_iam_role.process_unlock.id
}

resource "aws_iam_role_policy_attachment" "base_permissions_to_lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.process_unlock.id
}

module "push_back_task" {
  source      = "github.com/nsbno/terraform-aws-single-use-fargate-task?ref=6f324e0"
  name_prefix = var.name_prefix
}

resource "aws_iam_role" "push_back_task_role" {
  name               = "${var.name_prefix}-single-use-tasks"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy" "logs_to_ecs" {
  policy = data.aws_iam_policy_document.logs_for_ecs.json
  role   = aws_iam_role.push_back_task_role.id
}

resource "aws_iam_role_policy" "pass_role_to_push_back_task" {
  policy = data.aws_iam_policy_document.pass_role_for_push_back_task.json
  role = module.push_back_task.lambda_exec_role_id
}

resource "aws_iam_role_policy" "s3_to_push_back_task" {
  policy = data.aws_iam_policy_document.s3_for_push_back_task.json
  role = aws_iam_role.push_back_task_role.id
}

resource "aws_iam_role_policy" "ssm_and_kms_to_push_back_task" {
  policy = data.aws_iam_policy_document.ssm_and_kms_for_push_back_task.json
  role = aws_iam_role.push_back_task_role.id
}

locals {
  push_repo_input_single_use_fargate_task = jsonencode(
    {
      "cmd_to_run"            = "mkdir -p ~/.ssh && aws ssm get-parameter --name break-the-seal-git-deploy-key --region eu-west-1 --with-decryption --query Parameter.Value --output text > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa &&ssh-keyscan -H github.com >> ~/.ssh/known_hosts && git config --global user.email 'machine-user@vy.no' && git config --global user.name 'machine-user' && sed -i.bak '/sshCommand/d' .git/config && mv requests/*.yml processed-requests/ && git add .&& git commit -m \"[skip ci] Move requests to processed-requests\" && git push"
      ecs_cluster             = "${var.name_prefix}-single-tasks"
      subnets                 = module.vpc.public_subnet_ids
      task_execution_role_arn = "${var.name_prefix}-ECSTaskExecutionRole"
      "task_role_arn"         = "${var.name_prefix}-single-use-tasks"
      "image"                 = "vydev/awscli:1.18.105"
      "fargate_lambda_name"    = module.push_back_task.function_name
    }
  )
}

resource "aws_s3_bucket" "unlock_requests" {
  bucket = "${local.current_account_id}-${var.name_prefix}-requests"
}

module "github_actions_machine_user" {
  source      = "github.com/nsbno/terraform-aws-circleci-repository-user?ref=2eaa652"
  name_prefix = var.name_prefix
  allowed_s3_arns = [
    aws_s3_bucket.unlock_requests.arn
  ]
  allowed_s3_count  = 1
  ci_parameters_key = aws_kms_alias.key-alias.id
}

resource "aws_kms_key" "github_actions-parameters" {
  description = "KMS key for encrypting parameters shared with CircleCI."
}

resource "aws_kms_alias" "key-alias" {
  name          = "alias/${var.name_prefix}-ci-parameters"
  target_key_id = aws_kms_key.github_actions-parameters.id
}

resource "aws_lambda_permission" "allow_bucket" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_unlock_request.id
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.unlock_requests.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.unlock_requests.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.process_unlock_request.arn
    events              = ["s3:ObjectCreated:*"]
  }
}