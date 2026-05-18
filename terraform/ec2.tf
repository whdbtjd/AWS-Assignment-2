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
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_port     = var.app_port
    app_git_repo = var.app_git_repo
    app_subdir   = var.app_subdir
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

# ── Web Server EC2 (Public Subnet A/B, 각 1대) ───────────────────────────────
#
# Launch Template과 동일한 스펙으로 고정 인스턴스 2대를 생성합니다.
# ASG로 전환할 경우 이 블록을 제거하고 asg.tf의 주석을 해제하세요.

locals {
  web_subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_instance" "web" {
  count         = var.web_server_count
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null
  subnet_id     = local.web_subnets[count.index]

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_port     = var.app_port
    app_git_repo = var.app_git_repo
    app_subdir   = var.app_subdir
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
    Role = "WebServer"
  })
}

# ── DB Server EC2 (Private Subnet) ───────────────────────────────────────────
#
# 의도된 안티 아키텍처: EC2 인스턴스를 DB 서버로 사용합니다.
# 프라이빗 서브넷에 배치하여 외부 직접 접근을 차단하고,
# 웹 서버 보안 그룹에서만 접근 가능하도록 제한합니다.

resource "aws_instance" "db" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null
  subnet_id     = aws_subnet.private.id

  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.db.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-server"
    Role = "Database"
  })
}
