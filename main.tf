resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "VPC_CICD"
  }
}

#Create a public subnet1
resource "aws_subnet" "public_subnet_1a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}



/*
resource "aws_instance" "ec2_instance_1" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1a.id
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  key_name = "Dynatrace"
  user_data = file("${path.module}/userdata.sh")
  tags = {
    Name = "CICD_EC2_Instance_1"
  } 
  
}
*/

resource "aws_instance" "ec2_instance_2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1b.id
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  key_name = "Dynatrace"
  user_data = file("${path.module}/userdata.sh")
  tags = {
    Name = "CICD_EC2_Instance_2"
  } 
}


resource "aws_launch_template" "dynatrace_lt" {

  name_prefix   = "dynatrace-lt-"

  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  key_name = "Dynatrace"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_profile.name
  }

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  user_data = base64encode(
    file("${path.module}/userdata.sh")
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Dynatrace-ASG-Instance"
    }
  }

  update_default_version = true
}

resource "aws_security_group" "ec2_sg" {
  name        = "dynatrace-ec2-sg"
  description = "Security Group for EC2"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "EC2-SG"
  }
}

resource "aws_autoscaling_group" "dynatrace_asg" {

  name = "dynatrace-asg"

  desired_capacity = 2
  min_size         = 2
  max_size         = 4

  vpc_zone_identifier = [
    aws_subnet.public_subnet_1a.id,
    aws_subnet.public_subnet_1b.id
  ]

  launch_template {
    id      = aws_launch_template.dynatrace_lt.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.dynatrace_tg.arn
  ]

  health_check_type = "ELB"

  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "Dynatrace-ASG-Instance"
    propagate_at_launch = true
  }
}

resource "aws_lb_target_group" "dynatrace_tg" {
  name     = "dynatrace-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "Dynatrace-TG"
  }
}


resource "aws_lb" "dynatrace_alb" {

  name               = "dynatrace-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.ec2_sg.id
  ]

  subnets = [
    aws_subnet.public_subnet_1a.id,
    aws_subnet.public_subnet_1b.id
  ]

  tags = {
    Name = "Dynatrace-ALB"
  }
}

resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.dynatrace_alb.arn

  port     = 80
  protocol = "HTTP"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.dynatrace_tg.arn
  }
}


resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public_subnet_1.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name = "main-nat"
  }
}

resource "aws_route" "private_default" {

  route_table_id = aws_route_table.private.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private1" {

  subnet_id = aws_subnet.private_subnet_1.id

  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {

  subnet_id = aws_subnet.private_subnet_2.id

  route_table_id = aws_route_table.private.id
}