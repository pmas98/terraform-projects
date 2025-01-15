provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "asg_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.asg_vpc.id
}

# Create Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.asg_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.asg_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true  # Changed to true for public access
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.asg_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true  # Changed to true for public access
}

resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow inbound traffic on port 80 from anywhere"
  vpc_id      = aws_vpc.asg_vpc.id

  ingress {
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
}

resource "aws_security_group" "instance_sg" {  # Changed name to match reference
  name        = "instance_sg"
  description = "Allow inbound traffic only from load balancer on port 80"
  vpc_id      = aws_vpc.asg_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "app_template" {
  name          = "app_template"
  image_id      = "ami-09115b7bffbe3c5e4"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.instance_sg.id]  # Changed to use VPC security group IDs

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "Hello from EC2" > /usr/share/nginx/html/index.html
              EOF
  )
}

resource "aws_lb" "app_lb" {
  name                       = "app-lb"
  internal                   = false
  load_balancer_type        = "application"
  security_groups           = [aws_security_group.lb_sg.id]
  subnets                   = [aws_subnet.subnet.id, aws_subnet.subnet_2.id]
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app_target_group" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.asg_vpc.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = 1
  max_size           = 3
  min_size           = 1
  vpc_zone_identifier = [aws_subnet.subnet.id, aws_subnet.subnet_2.id]
  
  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  health_check_type          = "EC2"
  health_check_grace_period  = 300
  force_delete              = true

  target_group_arns         = [aws_lb_target_group.app_target_group.arn]
  wait_for_capacity_timeout = "0"

  tag {
    key                 = "Name"
    value              = "app-instance"
    propagate_at_launch = true
  }
}