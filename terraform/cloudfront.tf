# ── CloudFront Distribution ───────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  enabled     = true
  comment     = "${local.name_prefix} distribution"
  price_class = "PriceClass_200"

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
    viewer_protocol_policy = "allow-all"

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

  # ── 기본 CloudFront 인증서 (*.cloudfront.net) ────────────────────────────────
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cf" })
}
