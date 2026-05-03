# ----------------------------------------
# VPC
# ----------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ----------------------------------------
# パブリックサブネット（ALB は 2 AZ 必須）
# ----------------------------------------
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "${var.aws_region}${["a", "c"][count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${["a", "c"][count.index]}"
  }
}

# ----------------------------------------
# インターネットゲートウェイ
# ----------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ----------------------------------------
# ルートテーブル（パブリック）
# ----------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ----------------------------------------
# セキュリティグループ — ALB
# ----------------------------------------
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ----------------------------------------
# セキュリティグループ — EC2
# ポート22なし。ALB SG からの 8080 のみ許可。
# ----------------------------------------
resource "aws_security_group" "ec2" {
  name   = "${var.project_name}-ec2"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

# ----------------------------------------
# EC2 インスタンス（2台）
# ----------------------------------------
resource "aws_instance" "web" {
  count         = 2
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-web0${count.index + 1}"
  }
}

# ----------------------------------------
# ALB + ターゲットグループ + リスナー
# ----------------------------------------
resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  ip_address_type = "ipv4"

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "alb" {
  name             = "${var.project_name}-tg"
  target_type      = "instance"
  protocol_version = "HTTP1"
  port             = 8080
  protocol         = "HTTP"

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-tg"
  }

  health_check {
    interval            = 30
    path                = "/index.html"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_lb_target_group_attachment" "alb" {
  count            = 2
  target_group_arn = aws_lb_target_group.alb.arn
  target_id        = aws_instance.web[count.index].id
}

resource "aws_lb_listener" "alb" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}
