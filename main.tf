###NICO Erwan

provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

####VPC
resource "aws_vpc" "vpc_terraform_tp" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "terraform"
  }
}

####SUBNET
resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.vpc_terraform_tp.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "public-a-tf"
  }
}

resource "aws_subnet" "public-b" {
  vpc_id     = aws_vpc.vpc_terraform_tp.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "public-b-tf"
  }
}


####GTW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc_terraform_tp.id

  tags = {
    Name = "igw-tf"
  }
}

####ROUTE TABLE
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.vpc_terraform_tp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "internet-tf"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r.id
}

####PRIVATE KEY
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "ec2-key-tf"
  public_key = tls_private_key.pk.public_key_openssh
}

####ALB
resource "aws_lb" "alb_terraform" {
  name               = "alb_terraform"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.allow_http.id}"]
  subnets            = ["${aws_subnet.subnet_1_terraform.id}"]
}

resource "aws_lb_listener" "alb_listner_terraform" {
  load_balancer_arn = aws_lb.alb_terraform.arn
  port              = "80"
  protocol          = "HTTP"

  vpc_terraform_tp_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_tf.arn
  }
}


####TARGET GROUP
resource "aws_lb_target_group" "lb_target_group_tf" {
  name     = "lb_target_group_tf"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_terraform_tp.id
}
resource "aws_lb_target_group_attachment" "target_group_attachment_tf" {
  target_group_arn = aws_lb_target_group.lb_target_group_tf.arn
  target_id        = aws_instance.lb_target_group_tf.id
  port             = 80
}

####AUTOSCALING
resource "aws_autoscaling_group" "autoscaling_tf" {
  name                      = "as-terraform-tp"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 20
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = "${aws_placement_group.test.id}"
  launch_configuration      = "${aws_launch_configuration.foobar.name}"
  vpc_zone_identifier       = ["${aws_subnet.public-a.id}", "${aws_subnet.public-b.id}"]

  initial_lifecycle_hook {
    name                 = "autoscaling"
    vpc_terraform_tp_result       = "CONTINUE"
    heartbeat_timeout    = 2000
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    notification_target_arn = "arn:aws:sqs:us-east-1:444455556666:queue1*"
    role_arn                = "arn:aws:iam::123456789012:role/S3Access"
  }
} 

####LAUNCH CONFIGURATION
resource "aws_launch_configuration" "launch_configuration_terraform" {
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  security_groups = aws_security_group.allow_http.id
  user_data = file("${path.module}/post_install.sh")
}

