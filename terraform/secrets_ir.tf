# ── 시나리오 3: 비정상 GetSecretValue → CloudTrail 메트릭 → SNS + RotateSecret ─
# RotateSecret 이 DB까지 반영되려면 SM 콘솔에서 해당 시크릿 "자동 로테이션" 1회 켜기 (AWS 관리형)

data "aws_caller_identity" "current" {}

data "aws_rds_cluster" "aurora_for_secret" {
  cluster_identifier = aws_rds_cluster.aurora.cluster_identifier
  depends_on         = [aws_rds_cluster.aurora]
}

locals {
  aurora_master_secret_arn = coalesce(
    try(aws_rds_cluster.aurora.master_user_secret[0].secret_arn, null),
    try(data.aws_rds_cluster.aurora_for_secret.master_user_secret[0].secret_arn, null),
  )
  credential_ir_secret_resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:rds!cluster-*"
}

# ── CloudTrail → CloudWatch Logs (GetSecretValue 메트릭) ─────────────────────
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cloudtrail" })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSCloudTrailAclCheck"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:GetBucketAcl"
      Resource  = aws_s3_bucket.cloudtrail.arn
    }, {
      Sid       = "AWSCloudTrailWrite"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      Condition = {
        StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
      }
    }]
  })
}

resource "aws_iam_role" "cloudtrail_logs" {
  name = "${local.name_prefix}-cloudtrail-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cloudtrail-logs-role" })
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  name = "${local.name_prefix}-cloudtrail-logs-policy"
  role = aws_iam_role.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = 7

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cloudtrail-logs" })
}

resource "aws_cloudtrail" "this" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_logs.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-trail" })
}

resource "aws_cloudwatch_log_metric_filter" "get_secret_value" {
  name           = "${local.name_prefix}-get-secret-value"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  # 패턴 고정(apply 중 변경 시 provider 오류 방지). 이 계정 Aurora 시크릿만 테스트할 때 충분.
  pattern = "{ ($.eventName = \"GetSecretValue\") && ($.requestParameters.secretId = \"*rds!cluster*\") }"

  metric_transformation {
    name      = "GetSecretValueCount"
    namespace = "CredentialSecurity"
    value     = "1"
  }
}

resource "aws_sns_topic" "credential_ir" {
  name = "${local.name_prefix}-credential-ir"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-credential-ir" })
}

resource "aws_sns_topic_subscription" "credential_ir_email" {
  topic_arn = aws_sns_topic.credential_ir.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "get_secret_value" {
  alarm_name          = "${local.name_prefix}-get-secret-value"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GetSecretValueCount"
  namespace           = "CredentialSecurity"
  period              = 300
  statistic           = "Sum"
  threshold           = var.credential_getsecret_threshold
  treat_missing_data  = "notBreaching"
  alarm_description   = "Scenario 3: abnormal GetSecretValue on Aurora master secret (5 min window)"

  alarm_actions = [
    aws_sns_topic.credential_ir.arn,
    aws_lambda_function.credential_ir.arn,
  ]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-get-secret-alarm" })
}

# ── IR Lambda: RotateSecret + SNS ─────────────────────────────────────────────
data "archive_file" "credential_ir" {
  type        = "zip"
  source_file = "${path.module}/lambda/credential_ir.py"
  output_path = "${path.module}/lambda/credential_ir.zip"
}

resource "aws_iam_role" "credential_ir" {
  name = "${local.name_prefix}-credential-ir-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-credential-ir-role" })
}

resource "aws_iam_role_policy" "credential_ir" {
  name = "${local.name_prefix}-credential-ir-policy"
  role = aws_iam_role.credential_ir.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:RotateSecret", "secretsmanager:DescribeSecret"]
        Resource = local.credential_ir_secret_resource
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.credential_ir.arn
      },
    ]
  })
}

resource "aws_lambda_function" "credential_ir" {
  function_name    = "${local.name_prefix}-credential-ir"
  filename         = data.archive_file.credential_ir.output_path
  source_code_hash = data.archive_file.credential_ir.output_base64sha256
  role             = aws_iam_role.credential_ir.arn
  handler          = "credential_ir.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      SECRET_ARN    = local.aurora_master_secret_arn
      SNS_TOPIC_ARN = aws_sns_topic.credential_ir.arn
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-credential-ir" })

  depends_on = [aws_rds_cluster.aurora, data.aws_rds_cluster.aurora_for_secret]
}

resource "aws_lambda_permission" "credential_ir_alarm" {
  statement_id  = "AllowExecutionFromCloudWatchAlarm"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.credential_ir.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.get_secret_value.arn
}
