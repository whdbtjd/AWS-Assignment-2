# ── 보안 그룹 (룰 없이 먼저 생성) ────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB: HTTP inbound only"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Web servers: app port from ALB only"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-sg" })
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "DB server: inbound from web servers only"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-sg" })
}

# ── ALB 룰 ────────────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_web" {
  type                     = "egress"
  description              = "Forward to web servers"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.alb.id
}

# ── Web Server 룰 ─────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "web_ingress_alb" {
  type                     = "ingress"
  description              = "App port from ALB only"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_egress_https" {
  type              = "egress"
  description       = "HTTPS for package installs / git"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_egress_db" {
  type                     = "egress"
  description              = "All traffic to DB"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.db.id
  security_group_id        = aws_security_group.web.id
}

# ── DB Server 룰 ──────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "db_ingress_web" {
  type                     = "ingress"
  description              = "From web servers only"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.db.id
}
