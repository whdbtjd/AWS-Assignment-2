# ── Aurora DB Subnet Group ────────────────────────────────────────────────────
resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name_prefix}-aurora-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.db_private.id]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-aurora-subnet-group" })
}

# ── Aurora MySQL Cluster ──────────────────────────────────────────────────────
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${local.name_prefix}-aurora"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.12.0"
  database_name           = var.aurora_db_name
  master_username         = var.aurora_master_username
  master_password         = var.aurora_master_password
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.aurora.id]

  skip_final_snapshot     = true
  backup_retention_period = 1
  deletion_protection     = false

  # db.t3.* 는 Performance Insights 미지원 → Standard Database Insights 사용 (7일, 과제용 무료)
  database_insights_mode = "standard"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-aurora" })
}

# ── Aurora Instance (단일 인스턴스 — 최소 비용) ───────────────────────────────
resource "aws_rds_cluster_instance" "aurora" {
  identifier           = "${local.name_prefix}-aurora-instance"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = var.aurora_instance_class
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora.name

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-aurora-instance" })
}
