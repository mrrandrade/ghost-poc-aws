locals {
    ghost_cloudfront_origin_id = "ghost"

}

resource "aws_cloudfront_distribution" "ghost" {
  origin {
    domain_name = aws_lb.ghost_alb.dns_name
    origin_id   = local.ghost_cloudfront_origin_id

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }

    custom_header {
      name = "X-Allowed-Origin"
      value = "ghost-client-hHp7QRvVOP"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Ghost POC - Ghost Cloudfront Distribution"
  # default_root_object = "index.html"
  # aliases = ["ghost.cient-domain.com""]  

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.ghost_logs.bucket_domain_name
    prefix          = "ghost/cloudfront"
  }

  ordered_cache_behavior {
    path_pattern     = "/ghost/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.ghost_cloudfront_origin_id

    forwarded_values {
      query_string = true
      
      cookies {
        forward = "all"
      }
    }
    default_ttl = 0
    min_ttl = 0
    max_ttl = 0
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.ghost_cloudfront_origin_id

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }    

  # PriceClass_200: no Latin America or Australia
  # PriceClass_100: only USA and Europe
  price_class = "PriceClass_All"

  tags = merge(
    local.tags
  )

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}