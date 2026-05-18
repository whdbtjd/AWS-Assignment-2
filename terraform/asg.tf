# ══════════════════════════════════════════════════════════════════════════════
# [비활성화] Auto Scaling Group 및 관련 리소스
#
# 현재 아키텍처에서는 고정 EC2 2대(web) + 1대(db)로 운영합니다.
# 트래픽 증가에 따른 자동 스케일링이 필요할 경우 아래 블록의 주석을 해제하고
# alb.tf의 aws_lb_target_group_attachment 및 ec2.tf의 aws_instance 리소스를
# 제거한 뒤 terraform apply 하면 ASG 방식으로 전환됩니다.
# ══════════════════════════════════════════════════════════════════════════════

# # ── Auto Scaling Group ────────────────────────────────────────────────────────
# resource "aws_autoscaling_group" "web" {
#   name                = "${local.name_prefix}-web-asg"
#   min_size            = var.asg_min_size
#   max_size            = var.asg_max_size
#   desired_capacity    = var.asg_desired_capacity
#   vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
#   target_group_arns   = [aws_lb_target_group.web.arn]
#   health_check_type   = "ELB"
#   health_check_grace_period = 120
#
#   launch_template {
#     id      = aws_launch_template.web.id
#     version = "$Latest"
#   }
#
#   instance_refresh {
#     strategy = "Rolling"
#     preferences {
#       min_healthy_percentage = 50
#     }
#   }
#
#   tag {
#     key                 = "Name"
#     value               = "${local.name_prefix}-web-asg"
#     propagate_at_launch = false
#   }
#
#   dynamic "tag" {
#     for_each = local.common_tags
#     content {
#       key                 = tag.key
#       value               = tag.value
#       propagate_at_launch = true
#     }
#   }
#
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ── Scale Out (CPU 높을 때) ───────────────────────────────────────────────────
# resource "aws_autoscaling_policy" "scale_out" {
#   name                   = "${local.name_prefix}-scale-out"
#   autoscaling_group_name = aws_autoscaling_group.web.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = 1
#   cooldown               = 120
# }
#
# resource "aws_cloudwatch_metric_alarm" "cpu_high" {
#   alarm_name          = "${local.name_prefix}-cpu-high"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 60
#   statistic           = "Average"
#   threshold           = var.asg_cpu_scale_out_threshold
#   alarm_description   = "CPU > ${var.asg_cpu_scale_out_threshold}% → scale out"
#   alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
#
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.web.name
#   }
#
#   tags = local.common_tags
# }

# # ── Scale In (CPU 낮을 때) ────────────────────────────────────────────────────
# resource "aws_autoscaling_policy" "scale_in" {
#   name                   = "${local.name_prefix}-scale-in"
#   autoscaling_group_name = aws_autoscaling_group.web.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = -1
#   cooldown               = 180
# }
#
# resource "aws_cloudwatch_metric_alarm" "cpu_low" {
#   alarm_name          = "${local.name_prefix}-cpu-low"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = 3
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 60
#   statistic           = "Average"
#   threshold           = var.asg_cpu_scale_in_threshold
#   alarm_description   = "CPU < ${var.asg_cpu_scale_in_threshold}% → scale in"
#   alarm_actions       = [aws_autoscaling_policy.scale_in.arn]
#
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.web.name
#   }
#
#   tags = local.common_tags
# }
