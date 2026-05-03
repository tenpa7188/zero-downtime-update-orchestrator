output "alb_dns_name" {
  description = "ALB の DNS 名（動作確認用）"
  value       = aws_lb.alb.dns_name
}

output "web_instance_ids" {
  description = "EC2 インスタンス ID（SSM 接続の確認用）"
  value       = aws_instance.web[*].id
}

output "web_public_ips" {
  description = "EC2 パブリック IP（参考）"
  value       = aws_instance.web[*].public_ip
}
