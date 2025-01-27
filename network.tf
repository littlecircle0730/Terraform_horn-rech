data "aws_acm_certificate" "cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
  provider = aws.us-east-1
}

data "aws_route53_zone" "main" {
  name = "ut-wcwh.org."
}

resource "aws_route53_record" "domain" {
  name    = var.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.main.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.vpc.id
  count             = length(var.public_subnets_cidr)
  cidr_block        = element(var.public_subnets_cidr, count.index)
  availability_zone = element(var.azs, count.index)

  #checkov:skip=CKV_AWS_130:Public subnet
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = false
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_subnet" "igw" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.igw_cidr
  map_public_ip_on_launch = false
}

resource "aws_subnet" "nat" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.nat_cidr)
  cidr_block              = element(var.nat_cidr, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = false
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.igw.id
}

resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table_association" "nat" {
  count          = length(var.nat_cidr)
  subnet_id      = element(aws_subnet.nat.*.id, count.index)
  route_table_id = aws_route_table.nat.id
}

resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "igw" {
  subnet_id      = aws_subnet.igw.id
  route_table_id = aws_route_table.igw.id
}

# resource "aws_cloudfront_distribution" "cf_distribution" {
#   enabled         = true
#   is_ipv6_enabled = true
#   price_class     = "PriceClass_100"
#   aliases         = [var.domain_name]

#   origin {
#     domain_name = aws_api_gateway_domain_name.api.domain_name
#     origin_id   = "${local.project_stage}_api_gateway"

#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "https-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }

#     custom_header {
#       name  = "X-Forwarded-Host"
#       value = var.domain_name
#     }
#   }

#   default_cache_behavior {
#     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
#     cached_methods   = ["GET", "HEAD"]
#     target_origin_id = "${local.project_stage}_api_gateway"
#     compress         = true

#     forwarded_values {
#       query_string = true

#       headers = [
#         "X-CSRFToken",
#         "Referer",
#       ]

#       cookies {
#         forward = "all"
#       }
#     }

#     viewer_protocol_policy = "redirect-to-https"
#     min_ttl                = 0
#     default_ttl            = 0
#     max_ttl                = 86400
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#       locations        = []
#     }
#   }

#   viewer_certificate {
#     acm_certificate_arn = element(data.aws_acm_certificate.cert.*.arn, count.index)
#     ssl_support_method  = "sni-only"
#   }

#   logging_config {
#     include_cookies = false
#     bucket          = "${local.project_stage}_logs_api_gateway.s3.amazonaws.com"
#   }

#   depends_on = [
#     aws_s3_bucket.logs_api_gateway
#   ]
# }
