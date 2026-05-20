# ── 시나리오: WAF BLOCK 경보 → EventBridge → Lambda → IP Set 동적 차단 ─────────

resource "aws_wafv2_ip_set" "blocked" {
  provider           = aws.us_east_1
  name               = "${local.name_prefix}-blocked-ips"
  description        = "EventBridge/Lambda auto-blocked attacker IPs"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = []

  lifecycle {
    ignore_changes = [addresses]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-blocked-ips" })
}

# ── Lambda IAM ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_waf_ip_block" {
  name = "${local.name_prefix}-lambda-waf-ip-block-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-lambda-waf-ip-block-role" })
}

resource "aws_iam_role_policy" "lambda_waf_ip_block" {
  name = "${local.name_prefix}-lambda-waf-ip-block-policy"
  role = aws_iam_role.lambda_waf_ip_block.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:us-east-1:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery",
        ]
        Resource = [
          aws_cloudwatch_log_group.waf.arn,
          "${aws_cloudwatch_log_group.waf.arn}:*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups", "logs:DescribeQueries"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet",
        ]
        Resource = aws_wafv2_ip_set.blocked.arn
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.waf_alert.arn
      },
    ]
  })
}

data "archive_file" "waf_ip_block" {
  type        = "zip"
  source_file = "${path.module}/lambda/waf_ip_block.py"
  output_path = "${path.module}/lambda/waf_ip_block.zip"
}

resource "aws_lambda_function" "waf_ip_block" {
  provider         = aws.us_east_1
  function_name    = "${local.name_prefix}-waf-ip-block"
  filename         = data.archive_file.waf_ip_block.output_path
  source_code_hash = data.archive_file.waf_ip_block.output_base64sha256
  role             = aws_iam_role.lambda_waf_ip_block.arn
  handler          = "waf_ip_block.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      WAF_LOG_GROUP   = aws_cloudwatch_log_group.waf.name
      IP_SET_ID       = aws_wafv2_ip_set.blocked.id
      IP_SET_NAME     = aws_wafv2_ip_set.blocked.name
      WAF_SCOPE       = "CLOUDFRONT"
      SNS_TOPIC_ARN    = aws_sns_topic.waf_alert.arn
      LOOKBACK_MINUTES = "5"
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-ip-block" })
}

# ── EventBridge: CloudWatch 경보 ALARM → Lambda ───────────────────────────────
resource "aws_cloudwatch_event_rule" "waf_block_remediate" {
  provider      = aws.us_east_1
  name          = "${local.name_prefix}-waf-block-remediate"
  description   = "WAF BLOCK 경보 시 공격 IP를 IP Set에 등록"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [aws_cloudwatch_metric_alarm.waf_block.alarm_name]
      state = {
        value = ["ALARM"]
      }
    }
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-block-remediate" })
}

resource "aws_cloudwatch_event_target" "waf_ip_block" {
  provider  = aws.us_east_1
  rule      = aws_cloudwatch_event_rule.waf_block_remediate.name
  target_id = "WafIpBlockLambda"
  arn       = aws_lambda_function.waf_ip_block.arn
}

resource "aws_lambda_permission" "waf_ip_block_eventbridge" {
  provider      = aws.us_east_1
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_ip_block.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.waf_block_remediate.arn
}
