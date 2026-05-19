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

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.web.id
}

output "asg_name" {
  description = "Auto Scaling Group 이름"
  value       = aws_autoscaling_group.web.name
}

output "aurora_endpoint" {
  description = "Aurora 클러스터 Write 엔드포인트"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora 클러스터 Read 엔드포인트"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_db_name" {
  description = "Aurora 데이터베이스 이름"
  value       = aws_rds_cluster.aurora.database_name
}

output "nat_gateway_ip" {
  description = "NAT Gateway 퍼블릭 IP"
  value       = aws_eip.nat.public_ip
}

output "web_security_group_id" {
  description = "웹 서버 보안 그룹 ID"
  value       = aws_security_group.web.id
}

output "aurora_security_group_id" {
  description = "Aurora 보안 그룹 ID"
  value       = aws_security_group.aurora.id
}
