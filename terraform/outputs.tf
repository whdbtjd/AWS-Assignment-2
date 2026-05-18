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

output "web_instance_ids" {
  description = "웹 서버 EC2 인스턴스 ID 목록"
  value       = aws_instance.web[*].id
}

output "web_instance_public_ips" {
  description = "웹 서버 퍼블릭 IP 목록"
  value       = aws_instance.web[*].public_ip
}

output "db_instance_id" {
  description = "DB 서버 EC2 인스턴스 ID"
  value       = aws_instance.db.id
}

output "db_instance_private_ip" {
  description = "DB 서버 프라이빗 IP (웹 서버에서 접근 시 사용)"
  value       = aws_instance.db.private_ip
}

output "launch_template_id" {
  description = "Launch Template ID (ASG 재활성화 시 사용)"
  value       = aws_launch_template.web.id
}

output "web_security_group_id" {
  description = "웹 서버 보안 그룹 ID"
  value       = aws_security_group.web.id
}

output "db_security_group_id" {
  description = "DB 서버 보안 그룹 ID"
  value       = aws_security_group.db.id
}
