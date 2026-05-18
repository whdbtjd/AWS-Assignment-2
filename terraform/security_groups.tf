# ── ALB 보안 그룹 ─────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "[안티 아키텍처] ALB: 모든 포트 전체 개방"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "ALL inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  description = "[안티 아키텍처] DB server: 모든 포트 전체 개방"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "ALL inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  description = "[안티 아키텍처] Web servers: 모든 포트 전체 개방"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "ALL inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-sg" })
}
