# ── Phase 3 실습: AWS Config (SSH 0.0.0.0/0 탐지 + 자동 수정) ─────────────────
# 예방은 SG/SSM·SCP(Phase 1·2). Config 자동 수정은 최후 수단 — TCP/22 + 0.0.0.0/0 만 제거 (ALB 80/443 유지).

data "aws_caller_identity" "config" {}

# ── S3 (설정 스냅샷 저장) ─────────────────────────────────────────────────────
resource "aws_s3_bucket" "config" {
  bucket        = "${local.name_prefix}-config-${data.aws_caller_identity.config.account_id}"
  force_destroy = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-config" })
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = { "AWS:SourceAccount" = data.aws_caller_identity.config.account_id }
        }
      },
      {
        Sid       = "AWSConfigBucketExistenceCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = { "AWS:SourceAccount" = data.aws_caller_identity.config.account_id }
        }
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.config.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.config.account_id
          }
        }
      },
    ]
  })
}

# ── IAM (Config 서비스 역할) ──────────────────────────────────────────────────
resource "aws_iam_role" "config" {
  name = "${local.name_prefix}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-config-role" })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# ── Recorder + Delivery Channel ─────────────────────────────────────────────
resource "aws_config_configuration_recorder" "this" {
  name     = "${local.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = false
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${local.name_prefix}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket

  depends_on = [aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

# ── 관리형 규칙: 전 세계 0.0.0.0/0 → TCP 22 인바운드 금지 ─────────────────────
resource "aws_config_config_rule" "incoming_ssh_denied" {
  name = "${local.name_prefix}-incoming-ssh-denied"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# ── 자동 수정 Lambda (22번 + 0.0.0.0/0 만 제거, AWS 기본 SSM 문서는 ALB까지 막아서 미사용) ─
resource "aws_iam_role" "config_ssh_remediate" {
  name = "${local.name_prefix}-config-ssh-remediate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-config-ssh-remediate-role" })
}

resource "aws_iam_role_policy" "config_ssh_remediate" {
  name = "${local.name_prefix}-config-ssh-remediate-policy"
  role = aws_iam_role.config_ssh_remediate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress",
        ]
        Resource = "*"
      },
    ]
  })
}

data "archive_file" "config_ssh_remediate" {
  type        = "zip"
  source_file = "${path.module}/lambda/config_ssh_remediate.py"
  output_path = "${path.module}/lambda/config_ssh_remediate.zip"
}

resource "aws_lambda_function" "config_ssh_remediate" {
  function_name    = "${local.name_prefix}-config-ssh-remediate"
  filename         = data.archive_file.config_ssh_remediate.output_path
  source_code_hash = data.archive_file.config_ssh_remediate.output_base64sha256
  role             = aws_iam_role.config_ssh_remediate.arn
  handler          = "config_ssh_remediate.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-config-ssh-remediate" })
}

resource "aws_lambda_permission" "config_ssh_remediate_ssm" {
  statement_id  = "AllowSSMAutomationInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_ssh_remediate.function_name
  principal     = "ssm.amazonaws.com"
}

resource "aws_iam_role" "config_ssm_automation" {
  name = "${local.name_prefix}-config-ssm-automation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-config-ssm-automation-role" })
}

resource "aws_iam_role_policy_attachment" "config_ssm_automation" {
  role       = aws_iam_role.config_ssm_automation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role_policy" "config_ssm_automation_lambda" {
  name = "${local.name_prefix}-config-ssm-automation-policy"
  role = aws_iam_role.config_ssm_automation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.config_ssh_remediate.arn
    }]
  })
}

resource "aws_ssm_document" "revoke_open_ssh" {
  name            = "${local.name_prefix}-revoke-open-ssh"
  document_type   = "Automation"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: '0.3'
    description: Revoke 0.0.0.0/0 or ::/0 ingress on TCP port 22 only
    assumeRole: '{{ AutomationAssumeRole }}'
    parameters:
      GroupId:
        type: String
      AutomationAssumeRole:
        type: String
    mainSteps:
      - name: InvokeRevokeOpenSshLambda
        action: aws:invokeLambdaFunction
        isEnd: true
        inputs:
          FunctionName: ${aws_lambda_function.config_ssh_remediate.arn}
          Payload: '{"GroupId": "{{ GroupId }}"}'
    DOC

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-revoke-open-ssh" })
}

resource "aws_config_remediation_configuration" "incoming_ssh_denied" {
  config_rule_name = aws_config_config_rule.incoming_ssh_denied.name
  target_type      = "SSM_DOCUMENT"
  target_id        = aws_ssm_document.revoke_open_ssh.name
  target_version   = "1"
  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
  resource_type              = "AWS::EC2::SecurityGroup"

  parameter {
    name           = "AutomationAssumeRole"
    static_value   = aws_iam_role.config_ssm_automation.arn
  }

  parameter {
    name           = "GroupId"
    resource_value = "RESOURCE_ID"
  }

  depends_on = [
    aws_lambda_permission.config_ssh_remediate_ssm,
    aws_ssm_document.revoke_open_ssh,
  ]
}
