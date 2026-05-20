# ── GuardDuty 탐지 → EventBridge → Lambda 격리 (ALB TG 해제 + 격리 SG) ───────
# NFW 없이 egress 이상 탐지 후 대응 실습. 리전당 detector 1개 — 기존 계정은 data로 참조.

# ── GuardDuty (이미 활성화된 detector 참조; 신규 계정은 콘솔에서 1회 Enable 후 apply) ─
data "aws_guardduty_detector" "this" {}

# ── 격리 SG (SSM Session Manager용 443 egress만) ─────────────────────────────
resource "aws_security_group" "quarantine" {
  name        = "${local.name_prefix}-quarantine-sg"
  description = "GuardDuty IR: isolated instance, no app/DB traffic, SSM egress 443 only"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-quarantine-sg" })
}

resource "aws_security_group_rule" "quarantine_egress_ssm" {
  type              = "egress"
  description       = "HTTPS for SSM / investigation"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.quarantine.id
}

# ── SNS 알림 ─────────────────────────────────────────────────────────────────
resource "aws_sns_topic" "guardduty_isolation" {
  name = "${local.name_prefix}-guardduty-isolation"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-guardduty-isolation" })
}

resource "aws_sns_topic_subscription" "guardduty_isolation_email" {
  topic_arn = aws_sns_topic.guardduty_isolation.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── EventBridge: EC2 Instance finding (severity >= threshold) ─────────────────
resource "aws_cloudwatch_event_rule" "guardduty_isolation" {
  name        = "${local.name_prefix}-guardduty-isolation"
  description = "GuardDuty EC2 findings → auto-isolate workload"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = merge(
      {
        severity = [{ numeric = [">=", var.guardduty_isolation_min_severity] }]
        resource = {
          resourceType = ["Instance"]
        }
      },
      length(var.guardduty_isolation_finding_types) > 0 ? {
        type = var.guardduty_isolation_finding_types
      } : {}
    )
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-guardduty-isolation" })
}

# ── Lambda IAM ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "guardduty_isolate" {
  name = "${local.name_prefix}-guardduty-isolate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-guardduty-isolate-role" })
}

resource "aws_iam_role_policy" "guardduty_isolate" {
  name = "${local.name_prefix}-guardduty-isolate-policy"
  role = aws_iam_role.guardduty_isolate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:CreateTags",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeTargetHealth",
        ]
        Resource = aws_lb_target_group.web.arn
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.guardduty_isolation.arn
      },
    ]
  })
}

data "archive_file" "guardduty_isolate" {
  type        = "zip"
  source_file = "${path.module}/lambda/guardduty_isolate.py"
  output_path = "${path.module}/lambda/guardduty_isolate.zip"
}

resource "aws_lambda_function" "guardduty_isolate" {
  function_name    = "${local.name_prefix}-guardduty-isolate"
  filename         = data.archive_file.guardduty_isolate.output_path
  source_code_hash = data.archive_file.guardduty_isolate.output_base64sha256
  role             = aws_iam_role.guardduty_isolate.arn
  handler          = "guardduty_isolate.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      TARGET_GROUP_ARN = aws_lb_target_group.web.arn
      QUARANTINE_SG_ID = aws_security_group.quarantine.id
      SNS_TOPIC_ARN    = aws_sns_topic.guardduty_isolation.arn
      ASG_NAME         = var.guardduty_isolation_limit_to_asg ? aws_autoscaling_group.web.name : ""
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-guardduty-isolate" })
}

resource "aws_lambda_permission" "guardduty_isolate_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardduty_isolate.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_isolation.arn
}

resource "aws_cloudwatch_event_target" "guardduty_isolate" {
  rule      = aws_cloudwatch_event_rule.guardduty_isolation.name
  target_id = "GuardDutyIsolateLambda"
  arn       = aws_lambda_function.guardduty_isolate.arn
}
