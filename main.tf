terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
}

# vpc
resource "aws_vpc" "mb_vpc_tf" {
  cidr_block = "10.0.0.0/16"

  tags = {
    name = "mb_vpc_tf"
    User = "marcos.bianchi"
  }
}

resource "aws_internet_gateway" "mb_igw_terraform" {
  vpc_id = aws_vpc.mb_vpc_tf.id
  tags = {
    User = "marcos.bianchi"
  }
}

resource "aws_route_table" "mb_route_table_terraform" {
  vpc_id = aws_vpc.mb_vpc_tf.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mb_igw_terraform.id
  }
  tags = {
    name = "mb_route_table_terraform"
  }
}

# subnet for AZ-2  us-east-1a
resource "aws_subnet" "mb_subnet_az1_tf" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.mb_vpc_tf.id
  availability_zone = "us-east-1a"
  tags = {
    Name = "mb_subnet_az1_tf"
    User = "marcos.bianchi"
  }
}

# subnet for AZ-2  us-east-1b
resource "aws_subnet" "mb_subnet_az2_tf" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.mb_vpc_tf.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "mb_subnet_az2_tf"
    User = "marcos.bianchi"
  }
}

# route association
resource "aws_route_table_association" "mb_rt_assoc_subnet1_tf" {
  subnet_id = aws_subnet.mb_subnet_az1_tf.id
  route_table_id = aws_route_table.mb_route_table_terraform.id
}

resource "aws_route_table_association" "mb_rt_assoc_subnet2_tf" {
  subnet_id = aws_subnet.mb_subnet_az2_tf.id
  route_table_id = aws_route_table.mb_route_table_terraform.id
}

# security group
resource "aws_security_group" "mb_sg_tf" {
  name = "mb_sg_tf"
  description = "Allow HTTP/S inbound traffic"
  vpc_id = aws_vpc.mb_vpc_tf.id

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    name = "mb_sg_tf"
    User = "marcos.bianchi"
  }
}

resource "aws_alb" "mb-alb-terraform" {
  name = "mb-alb-terraform"
  internal = false
  ip_address_type = "ipv4"
  security_groups = [aws_security_group.mb_sg_tf.id]
  subnets = [aws_subnet.mb_subnet_az1_tf.id, aws_subnet.mb_subnet_az2_tf.id]
  tags = {
    User = "marcos.bianchi"
  }
}

resource "aws_alb_target_group" "mb-alb-target-group-terraform" {
  name = "mb-alb-target-group-terraform"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.mb_vpc_tf.id
  tags = {
    User = "marcos.bianchi"
  }
}

resource "aws_alb_listener" "mb_alb_listener_terraform" {
  load_balancer_arn = aws_alb.mb-alb-terraform.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.mb-alb-target-group-terraform.arn
  }
}

resource "aws_instance" "mb_ec2_instance1_tf" {
  ami                         = "ami-0885b1f6bd170450c"
  instance_type               = "t2.micro"
  subnet_id = aws_subnet.mb_subnet_az1_tf.id
  security_groups = [aws_security_group.mb_sg_tf.id]
  associate_public_ip_address = true
  key_name                    = "mb-keys"
  availability_zone = "us-east-1a"

  tags = {
    Name = "mb_ec2_instance1_tf"
    User = "marcos.bianchi"
  }
}

resource "aws_instance" "mb_ec2_instance2_tf" {
  ami                         = "ami-0885b1f6bd170450c"
  instance_type               = "t2.micro"
  subnet_id = aws_subnet.mb_subnet_az2_tf.id
  security_groups = [aws_security_group.mb_sg_tf.id]
  associate_public_ip_address = true
  key_name                    = "mb-keys"
  availability_zone = "us-east-1b"

  tags = {
    Name = "mb_ec2_instance2_tf"
    User = "marcos.bianchi"
  }
}

resource "aws_launch_configuration" "mb_launch_config_terraform" {
  name = "mb_launch_config_terraform"
  image_id = "ami-04d29b6f966df1537"
  instance_type = "t2.micro"
  key_name = "mb-keys"
  associate_public_ip_address = true
  security_groups = [aws_security_group.mb_sg_tf.id]
  user_data_base64 = "IyEvYmluL2Jhc2gKeXVtIGluc3RhbGwgaHR0cGQgLXkKc3lzdGVtY3RsIHN0YXJ0IGh0dHBkCnN5c3RlbWN0bCBzdG9wIGZpcmV3YWxsZApzdWRvIGVjaG8gIkhlbGxvIFdvcmxkIGZyb20gJChob3N0bmFtZSAtZikiID4gL3Zhci93d3cvaHRtbC9pbmRleC5odG1s"
}

resource "aws_autoscaling_group" "mb_as_group_terraform" {
  name = "mb_as_group_terraform"
  vpc_zone_identifier = [aws_subnet.mb_subnet_az1_tf.id, aws_subnet.mb_subnet_az2_tf.id]
  launch_configuration = aws_launch_configuration.mb_launch_config_terraform.id
  max_size = 4
  min_size = 2
  target_group_arns = [aws_alb_target_group.mb-alb-target-group-terraform.arn]
  tag {
    key = "User"
    propagate_at_launch = true
    value = "marcos.bianchi"
  }
}

