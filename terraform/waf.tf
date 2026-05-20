# ── WAF v2 (CloudFront용 — us-east-1) ────────────────────────────────────────
resource "aws_wafv2_web_acl" "this" {
  provider    = aws.us_east_1
  name        = "${local.name_prefix}-waf"
  scope       = "CLOUDFRONT"
  description = "SQLi and XSS protection - AWS Managed Rules"

  default_action {
    allow {}
  }

  # ── Rule 0: Lambda/EventBridge가 추가한 공격 IP 차단 ─────────────────────────
  rule {
    name     = "BlockedIpSet"
    priority = 0

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-blocked-ip-set"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 1: 한국 외 국가 차단 (Geo) ───────────────────────────────────────────
  dynamic "rule" {
    for_each = var.waf_geo_block_enabled ? [1] : []
    content {
      name     = "BlockNonAllowedCountries"
      priority = 1

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = var.waf_allowed_country_codes
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Rule 2: Core Rule Set (XSS 포함) ────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

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

  # ── Rule 3: SQL Injection Rule Set ──────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

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
