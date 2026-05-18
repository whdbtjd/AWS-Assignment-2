output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_a_id" {
  description = "Public Subnet A ID"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "Public Subnet B ID"
  value       = aws_subnet.public_b.id
}

output "private_subnet_id" {
  description = "Private Subnet ID (DB 배치용)"
  value       = aws_subnet.private.id
}

output "alb_dns_name" {
  description = "ALB DNS (접속 URL)"
  value       = aws_lb.this.dns_name
}

output "asg_name" {
  description = "Auto Scaling Group 이름"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.web.id
}

output "web_security_group_id" {
  description = "웹 서버 보안 그룹 ID (DB SG 인바운드 규칙에 사용)"
  value       = aws_security_group.web.id
}
