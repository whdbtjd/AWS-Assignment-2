# ── CloudFront Distribution ───────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  enabled     = true
  comment     = "${local.name_prefix} distribution"
  price_class = "PriceClass_200"
  web_acl_id  = aws_wafv2_web_acl.this.arn

  # ── Origin (ALB) ────────────────────────────────────────────────────────────
  origin {
    domain_name = aws_lb.this.dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── 기본 캐시 동작 (API = 캐시 없음, 모든 메서드 허용) ─────────────────────
  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
    compress    = true
  }

  # ── 지역 제한 없음 ───────────────────────────────────────────────────────────
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ── 커스텀 도메인 ────────────────────────────────────────────────────────────
  aliases = [var.domain_name, "www.${var.domain_name}"]

  # ── ACM 인증서 (us-east-1) ───────────────────────────────────────────────────
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cf" })
}
