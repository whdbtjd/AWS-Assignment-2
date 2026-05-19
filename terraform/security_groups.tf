# ── 공통 개별 포트 룰 (Prowler 포트별 체크 트리거용) ─────────────────────────
locals {
  exposed_port_rules = [
    { desc = "SSH",        from = 22,   to = 22   },
    { desc = "RDP",        from = 3389, to = 3389 },
    { desc = "MySQL",      from = 3306, to = 3306 },
    { desc = "PostgreSQL", from = 5432, to = 5432 },
  ]
}

# ── ALB 보안 그룹 ─────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "[Anti-pattern] ALB: all ports open"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = local.exposed_port_rules
    content {
      description = ingress.value.desc
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

# ── DB Server 보안 그룹 ───────────────────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "[Anti-pattern] DB server: all ports open"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = local.exposed_port_rules
    content {
      description = ingress.value.desc
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-sg" })
}

# ── Web Server 보안 그룹 ──────────────────────────────────────────────────────
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "[Anti-pattern] Web servers: all ports open"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = local.exposed_port_rules
    content {
      description = ingress.value.desc
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-sg" })
}
