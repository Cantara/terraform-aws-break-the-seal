data "aws_iam_policy_document" "lamda_assume" {
  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "permissions_for_process_unlock" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ses:SendEmail"
    ]
  }
  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.unlock_requests.arn,
      "${aws_s3_bucket.unlock_requests.arn}/*"
    ]
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
  }
  statement {
    effect    = "Allow"
    resources = [var.parameters_key_arn]
    actions   = ["kms:Decrypt"]
  }
}
#######
data "aws_iam_policy_document" "push_params_for_push_ssm_params" {
  statement {
    effect = "Allow"
    actions = ["ssm:PutParameter"]
    resources = ["arn:aws:ssm:eu-west-1:${data.aws_caller_identity.current.account_id}:parameter/break-the-seal/*"]
  }
  statement {
    effect = "Allow"
    actions = ["kms:Encrypt"]
    resources = [var.parameters_key_arn]
  }
}

data "aws_iam_policy_document" "push_ssm_params_assume" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = formatlist("arn:aws:iam::%s:root",var.trusted_accounts)
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "lambda_invoke_for_process_unlock" {
  statement {
    effect = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:${local.current_region}:${data.aws_caller_identity.current.account_id}:function:${module.push_back_task.function_name}"]
  }
}

data "aws_iam_policy_document" "pass_role_for_push_back_task" {
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
      "iam:GetRole"
    ]
    resources = [
      aws_iam_role.push_back_task_role.arn,
      module.push_back_task.task_execution_role_arn
    ]
  }
}

data "aws_iam_policy_document" "logs_for_ecs" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${local.current_region}:${local.current_account_id}:*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${local.current_region}:${local.current_account_id}:log-group:/aws/ecs/*"
    ]
  }
}

data "aws_iam_policy_document" "s3_for_push_back_task" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListObjects"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.unlock_requests.arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.unlock_requests.arn]
  }
}

data "aws_iam_policy_document" "ssm_and_kms_for_push_back_task" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
  }
  statement {
    effect    = "Allow"
    resources = [var.parameters_key_arn]
    actions   = ["kms:Decrypt"]
  }
}
