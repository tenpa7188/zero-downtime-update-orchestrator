resource "aws_s3_bucket" "ansible_ssm" {
  bucket = "${var.project_name}-ansible-ssm"
  tags   = merge(local.common_tags, { Name = "${var.project_name}-ansible-ssm" })
}

resource "aws_s3_bucket_public_access_block" "ansible_ssm" {
  bucket = aws_s3_bucket.ansible_ssm.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
