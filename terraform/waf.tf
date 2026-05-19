# ── WAF v2 (CloudFront용 — us-east-1) ────────────────────────────────────────
resource "aws_wafv2_web_acl" "this" {
  provider    = aws.us_east_1
  name        = "${local.name_prefix}-waf"
  scope       = "CLOUDFRONT"
  description = "SQLi and XSS protection - AWS Managed Rules"

  default_action {
    allow {}
  }

  # ── Rule 1: Core Rule Set (XSS 포함) ────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-crs"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 2: SQL Injection Rule Set ──────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf" })
}
