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

output "cloudfront_domain" {
  description = "CloudFront 배포 도메인"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "site_url" {
  description = "실제 접속 URL (커스텀 도메인)"
  value       = "https://${var.domain_name}"
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

output "aurora_slowquery_log_group" {
  description = "슬로우 쿼리 CloudWatch Logs 그룹 (Logs Insights에서 선택)"
  value       = "/aws/rds/cluster/${aws_rds_cluster.aurora.cluster_identifier}/slowquery"
}

output "aurora_master_secret_arn" {
  description = "Aurora 마스터 자격 증명 Secrets Manager ARN (시나리오 3)"
  value       = local.aurora_master_secret_arn
}

output "credential_ir_sns_topic_arn" {
  description = "자격 증명 IR 알림 SNS Topic ARN"
  value       = aws_sns_topic.credential_ir.arn
}

output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch Logs 그룹 (GetSecretValue 메트릭)"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "waf_blocked_ip_set_name" {
  description = "자동 차단 IP Set 이름 (us-east-1)"
  value       = aws_wafv2_ip_set.blocked.name
}

output "waf_ip_block_lambda" {
  description = "WAF 공격 IP 자동 차단 Lambda"
  value       = aws_lambda_function.waf_ip_block.function_name
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
