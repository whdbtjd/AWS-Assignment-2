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
  description = "Private Subnet CIDR (웹 서버 ASG)"
  type        = string
  default     = "10.0.2.0/24"
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
  default     = 1
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

# ── 태그 ──────────────────────────────────────────────────────────────────────
variable "tags" {
  description = "모든 리소스에 공통 적용할 태그"
  type        = map(string)
  default     = { Owner = "ACME-Team" }
}
