# ── CloudWatch Logs (WAF 로그 저장) ───────────────────────────────────────────
resource "aws_cloudwatch_log_group" "waf" {
  provider          = aws.us_east_1
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = 30

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-logs" })
}

# ── WAF 로그 → CloudWatch 연결 ────────────────────────────────────────────────
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  provider                = aws.us_east_1
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn
}

# ── CloudWatch Metric Filter (BLOCK 이벤트만) ─────────────────────────────────
resource "aws_cloudwatch_log_metric_filter" "waf_block" {
  provider       = aws.us_east_1
  name           = "${local.name_prefix}-waf-block"
  log_group_name = aws_cloudwatch_log_group.waf.name
  pattern        = "{ $.action = \"BLOCK\" }"

  metric_transformation {
    name      = "BlockedRequests"
    namespace = "WAFSecurity"
    value     = "1"
  }
}

# ── CloudWatch Alarm ──────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "waf_block" {
  provider            = aws.us_east_1
  alarm_name          = "${local.name_prefix}-waf-block-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "WAFSecurity"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "WAF BLOCK 이벤트 발생"
  alarm_actions       = [aws_sns_topic.waf_alert.arn]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-alarm" })
}

# ── SNS Topic ─────────────────────────────────────────────────────────────────
resource "aws_sns_topic" "waf_alert" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-waf-alert"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-alert" })
}

resource "aws_sns_topic_subscription" "waf_alert_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.waf_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── Lambda IAM Role ───────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_waf" {
  name = "${local.name_prefix}-lambda-waf-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-lambda-waf-role" })
}

resource "aws_iam_role_policy" "lambda_waf" {
  name = "${local.name_prefix}-lambda-waf-policy"
  role = aws_iam_role.lambda_waf.id

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
        Action   = "sns:Publish"
        Resource = aws_sns_topic.waf_alert.arn
      }
    ]
  })
}

# ── Lambda 함수 ───────────────────────────────────────────────────────────────
data "archive_file" "waf_alert" {
  type        = "zip"
  source_file = "${path.module}/lambda/waf_alert.py"
  output_path = "${path.module}/lambda/waf_alert.zip"
}

resource "aws_lambda_function" "waf_alert" {
  provider         = aws.us_east_1
  function_name    = "${local.name_prefix}-waf-alert"
  filename         = data.archive_file.waf_alert.output_path
  source_code_hash = data.archive_file.waf_alert.output_base64sha256
  role             = aws_iam_role.lambda_waf.arn
  handler          = "waf_alert.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.waf_alert.arn
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-alert" })
}

# ── CloudWatch Logs → Lambda Subscription Filter ──────────────────────────────
resource "aws_lambda_permission" "waf_logs" {
  provider      = aws.us_east_1
  statement_id  = "AllowCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_alert.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.waf.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "waf_to_lambda" {
  provider        = aws.us_east_1
  name            = "${local.name_prefix}-waf-to-lambda"
  log_group_name  = aws_cloudwatch_log_group.waf.name
  filter_pattern  = "{ $.action = \"BLOCK\" }"
  destination_arn = aws_lambda_function.waf_alert.arn

  depends_on = [aws_lambda_permission.waf_logs]
}
