# EC2 が SSM Agent を動作させるための IAM ロール
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# SSM Agent の動作に必要な最小権限（AWS 管理ポリシー）
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Ansible SSM 接続プラグインのステージング用 S3 バケットへのアクセス権限
resource "aws_iam_role_policy" "ec2_ssm_s3" {
  name   = "${var.project_name}-ec2-ssm-s3"
  role   = aws_iam_role.ec2_ssm.id
  policy = data.aws_iam_policy_document.ec2_ssm_s3.json
}

data "aws_iam_policy_document" "ec2_ssm_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.ansible_ssm.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.ansible_ssm.arn}/*"]
  }
}

# EC2 に IAM ロールを紐付けるためのインスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm"
  role = aws_iam_role.ec2_ssm.name
}
