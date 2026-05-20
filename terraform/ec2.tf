# ── IAM Role (Session Manager) ───────────────────────────────────────────────
resource "aws_iam_role" "ec2_ssm" {
  name = "${local.name_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2-ssm-role" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_aurora_secret" {
  name = "${local.name_prefix}-ec2-aurora-secret-read"
  role = aws_iam_role.ec2_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = coalesce(
        try(aws_rds_cluster.aurora.master_user_secret[0].secret_arn, null),
        "arn:aws:secretsmanager:${var.aws_region}:*:secret:rds!cluster-*",
      )
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${local.name_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# ── Launch Template (ASG 재활성화 시 재사용) ──────────────────────────────────
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_port       = var.app_port
    app_git_repo   = var.app_git_repo
    app_subdir     = var.app_subdir
    db_host        = aws_rds_cluster.aurora.endpoint
    db_name        = aws_rds_cluster.aurora.database_name
    db_user        = var.aurora_master_username
    db_secret_arn  = try(aws_rds_cluster.aurora.master_user_secret[0].secret_arn, "")
    aws_region     = var.aws_region
  }))

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web-server"
      Role = "WebServer"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── 웹 서버는 ASG가 관리합니다 (asg.tf 참고) ─────────────────────────────────
# ── DB는 Aurora가 관리합니다 (aurora.tf 참고) ─────────────────────────────────
