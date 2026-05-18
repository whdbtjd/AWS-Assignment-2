# 리소스 이름 변경 (public → public_a) — 재생성 방지
moved {
  from = aws_subnet.public
  to   = aws_subnet.public_a
}

moved {
  from = aws_route_table_association.public
  to   = aws_route_table_association.public_a
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}
