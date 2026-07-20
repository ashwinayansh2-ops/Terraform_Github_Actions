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

#create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "IGW_CICD"
  }
}

#associate the public subnets with the route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#associate ig to the public subnets
resource "aws_route_table_association" "public_subnet_1a_association" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_1b_association" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_rt.id
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

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "Dynatrace-ASG-Instance"
    propagate_at_launch = true
  }
}