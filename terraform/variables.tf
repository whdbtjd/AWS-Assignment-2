# ── 프로젝트 ──────────────────────────────────────────────────────────────────
variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍에 사용)"
  type        = string
  default     = "acme"
}

variable "environment" {
  description = "배포 환경 (dev / staging / prod)"
  type        = string
  default     = "prod"
}

# ── 네트워크 ──────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zone" {
  description = "가용 영역 A"
  type        = string
  default     = "ap-northeast-2a"
}

variable "availability_zone_b" {
  description = "가용 영역 B (ALB 두 번째 서브넷용)"
  type        = string
  default     = "ap-northeast-2c"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet A CIDR (웹 서버)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_b" {
  description = "Public Subnet B CIDR (ALB 두 번째 AZ)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr" {
  description = "Private Subnet A CIDR (웹 서버 ASG AZ-A)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_b" {
  description = "Private Subnet B CIDR (웹 서버 ASG AZ-B)"
  type        = string
  default     = "10.0.5.0/24"
}

variable "db_subnet_cidr_b" {
  description = "DB Private Subnet CIDR (AZ-B, Aurora용)"
  type        = string
  default     = "10.0.4.0/24"
}

# ── EC2 ───────────────────────────────────────────────────────────────────────
variable "instance_type" {
  description = "웹 서버 EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "web_server_count" {
  description = "웹 서버 인스턴스 수"
  type        = number
  default     = 2
}

variable "ami_id" {
  description = "EC2 AMI ID (Ubuntu 22.04 LTS ap-northeast-2)"
  type        = string
  default     = "ami-042e76978adeb8c48"
}

variable "key_name" {
  description = "EC2 SSH 키 페어 이름 (없으면 빈 문자열)"
  type        = string
  default     = ""
}

# ── 앱 배포 ───────────────────────────────────────────────────────────────────
variable "app_port" {
  description = "Node.js 앱 포트"
  type        = number
  default     = 3001
}

variable "app_git_repo" {
  description = "앱 소스 Git 저장소 URL (비워두면 인라인 코드 사용)"
  type        = string
  default     = "https://github.com/whdbtjd/AWS-Assignment-2.git"
}

variable "app_subdir" {
  description = "Git 클론 후 package.json이 있는 하위 디렉토리"
  type        = string
  default     = "app"
}

# ── Auto Scaling ─────────────────────────────────────────────────────────────
variable "asg_min_size" {
  description = "ASG 최소 인스턴스 수"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "ASG 최대 인스턴스 수"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "ASG 희망 인스턴스 수"
  type        = number
  default     = 2
}

variable "asg_cpu_scale_out_threshold" {
  description = "스케일 아웃 CPU 임계값 (%)"
  type        = number
  default     = 70
}

variable "asg_cpu_scale_in_threshold" {
  description = "스케일 인 CPU 임계값 (%)"
  type        = number
  default     = 30
}

# ── ALB ───────────────────────────────────────────────────────────────────────
variable "health_check_path" {
  description = "ALB 헬스 체크 경로"
  type        = string
  default     = "/"
}

# ── Aurora ───────────────────────────────────────────────────────────────────
variable "aurora_instance_class" {
  description = "Aurora 인스턴스 클래스 (최소: db.t3.medium)"
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_db_name" {
  description = "Aurora 데이터베이스 이름"
  type        = string
  default     = "acmedb"
}

variable "aurora_master_username" {
  description = "Aurora 마스터 사용자명"
  type        = string
  default     = "acmeadmin"
}

variable "aurora_master_password" {
  description = "Aurora 마스터 패스워드 (민감 정보 — tfvars로 관리 권장)"
  type        = string
  sensitive   = true
  default     = "AcmePassword123!"
}

# ── 도메인 / ACM ──────────────────────────────────────────────────────────────
variable "domain_name" {
  description = "Route53에 등록된 도메인 이름"
  type        = string
  default     = "ussung.com"
}

variable "acm_certificate_arn" {
  description = "ALB HTTPS 리스너용 ACM 인증서 ARN (acm.tf에서 자동 설정됨)"
  type        = string
  default     = ""
}

# ── WAF Geo ───────────────────────────────────────────────────────────────────
variable "waf_geo_block_enabled" {
  description = "허용 국가 외 트래픽 WAF BLOCK (CloudFront)"
  type        = bool
  default     = true
}

variable "waf_allowed_country_codes" {
  description = "허용 국가 ISO 3166-1 alpha-2 코드 (이 외 국가 BLOCK)"
  type        = list(string)
  default     = ["KR"]
}

# ── 알림 ──────────────────────────────────────────────────────────────────────
variable "alert_email" {
  description = "WAF / 자격 증명 IR 알림 수신 이메일"
  type        = string
  default     = "cys990617@gmail.com"
}

# ── 시나리오 3: 비정상 GetSecretValue 탐지 ────────────────────────────────────
variable "credential_getsecret_threshold" {
  description = "5분 내 GetSecretValue 허용 횟수 (초과 시 IR 로테이션)"
  type        = number
  default     = 2
}

# ── GuardDuty 격리 실습 ───────────────────────────────────────────────────────
variable "guardduty_isolation_min_severity" {
  description = "자동 격리 GuardDuty finding 최소 severity (0~8.9, Medium≈4)"
  type        = number
  default     = 4.0
}

variable "guardduty_isolation_finding_types" {
  description = "격리 대상 finding type 목록 (비우면 Instance + severity만 필터)"
  type        = list(string)
  default     = []
}

variable "guardduty_isolation_limit_to_asg" {
  description = "true면 acme-prod-web-asg 인스턴스만 격리"
  type        = bool
  default     = true
}

# ── 태그 ──────────────────────────────────────────────────────────────────────
variable "tags" {
  description = "모든 리소스에 공통 적용할 태그"
  type        = map(string)
  default     = { Owner = "ACME-Team" }
}
