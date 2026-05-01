variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "リソース名の prefix（例: zduo）"
  type        = string
  default     = "zduo"
}

variable "ami_id" {
  description = "EC2 に使用する Ubuntu 22.04 LTS の AMI ID（リージョンごとに異なる）"
  type        = string
}

variable "instance_type" {
  description = "EC2 インスタンスタイプ"
  type        = string
  default     = "t3.micro"
}

variable "github_org" {
  description = "GitHub 組織名またはユーザー名"
  type        = string
  default     = "tenpa7188"
}

variable "github_repo" {
  description = "GitHub リポジトリ名"
  type        = string
  default     = "zero-downtime-update-orchestrator"
}
