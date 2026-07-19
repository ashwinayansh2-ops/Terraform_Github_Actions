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

resource "aws_instance" "ec2_instance_1" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1a.id
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  key_name = "Dynatrace"
  tags = {
    Name = "CICD_EC2_Instance_1"
  } 
  
}

resource "aws_instance" "ec2_instance_2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1b.id
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  key_name = "Dynatrace"
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
