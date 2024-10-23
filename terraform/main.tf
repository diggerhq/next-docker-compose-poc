# Provider configuration
provider "aws" {
  region = "us-east-2" # Change to your desired region
}

# VPC Data Source (assuming you're using default VPC)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # Inbound rules for the three ports (from ALB only)
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 8888
    to_port         = 8888
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }


  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["0.0.0.0/0"]
  }

  # Outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  # Inbound rules for the three ports (from internet)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami           = "ami-0276ce36440fa7224" # Amazon Linux 2 AMI - update with desired AMI
  instance_type = "m5.2xlarge"

  security_groups = [aws_security_group.ec2_sg.name]

  tags = {
    Name = "Digger-poc"
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "app-lb"
  }
}

# Target Group for port 8080
resource "aws_lb_target_group" "tg_8080" {
  name     = "tg-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    path                = "/"
    port                = "8080"
    unhealthy_threshold = 2
  }
}

# Target Group for port 8000
resource "aws_lb_target_group" "tg_8000" {
  name     = "tg-8000"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    path                = "/"
    port                = "8000"
    unhealthy_threshold = 2
  }
}

# Target Group for port 8888
resource "aws_lb_target_group" "tg_8888" {
  name     = "tg-8888"
  port     = 8888
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    path                = "/"
    port                = "8888"
    unhealthy_threshold = 2
  }
}

# Target Group Attachment for 8080
resource "aws_lb_target_group_attachment" "tg_attachment_8080" {
  target_group_arn = aws_lb_target_group.tg_8080.arn
  target_id        = aws_instance.app_server.id
  port             = 8080
}

# Target Group Attachment for 8000
resource "aws_lb_target_group_attachment" "tg_attachment_8000" {
  target_group_arn = aws_lb_target_group.tg_8000.arn
  target_id        = aws_instance.app_server.id
  port             = 8000
}

# Target Group Attachment for 8888
resource "aws_lb_target_group_attachment" "tg_attachment_8888" {
  target_group_arn = aws_lb_target_group.tg_8888.arn
  target_id        = aws_instance.app_server.id
  port             = 8888
}

# Listener for port 8080
resource "aws_lb_listener" "listener_8080" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_8080.arn
  }
}

# Listener for port 8000
resource "aws_lb_listener" "listener_8000" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_8000.arn
  }
}

# Listener for port 8888
resource "aws_lb_listener" "listener_8888" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "8888"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_8888.arn
  }
}

# Output the ALB DNS name
output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}
