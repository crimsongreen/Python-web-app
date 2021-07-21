# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
# Builds ec2 launch configuration, autoscale group, loadbalancer, 
# ECS cluster, security group, relevant IAM role/policy attachment. 
# Limited by free tier.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}


# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2" # London
}


# Create ECR
resource "aws_ecr_repository" "ecr_python_web_app" {
  name = "python-web-app"
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_subnet
resource "aws_default_vpc" "default_vpc" {
}

# default subnets different AZ.
resource "aws_default_subnet" "subnet_eu_west_2a" {
  availability_zone = "eu-west-2a"
}

resource "aws_default_subnet" "subnet_eu_west_2b" {
  availability_zone = "eu-west-2b"
}


# Create ECS cluster
resource "aws_ecs_cluster" "lon01-cluster" {
  name = "lon01-cluster"
}


# create auto scaling group
resource "aws_autoscaling_group" "ecs_pool" {
  name                 = "ecs-pool"
  vpc_zone_identifier  = ["${aws_default_subnet.subnet_eu_west_2a.id}", "${aws_default_subnet.subnet_eu_west_2b.id}"]
  launch_configuration = "${aws_launch_configuration.ec2.name}"

  desired_capacity = 1
  min_size         = 1
  max_size         = 1
}


# ec2 instance config 
resource "aws_launch_configuration" "ec2" {
  name                 = "ec2_launch"
  image_id             = "ami-05db1ea966500fa94"
  iam_instance_profile = "${aws_iam_instance_profile.ecs_agent.name}"
  security_groups      = ["${aws_security_group.service_security_group.id}"]
  user_data            = "${data.template_file.user_data.rendered}"
  instance_type = "t2.micro"
}

# Required to register ec2 to ecs cluster.
data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.yaml")}"
}


# Create IAM role.
resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_agent.json}"
}

# Allow EC2 service access
data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Required to use ECS feature set 
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/instance_IAM_role.html
resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = "${aws_iam_role.ecs_agent.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html
resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = "${aws_iam_role.ecs_agent.name}"
}


# Define ECS service.
resource "aws_ecs_service" "webserver" {
  name            = "webserver"
  cluster         = aws_ecs_cluster.lon01-cluster.id
  task_definition = aws_ecs_task_definition.python_app.arn
  desired_count   = 1 # elastic network interface resource constraint because of free tier.

  network_configuration {
    subnets          = ["${aws_default_subnet.subnet_eu_west_2a.id}", "${aws_default_subnet.subnet_eu_west_2b.id}"]
    assign_public_ip = false
    security_groups  = ["${aws_security_group.service_security_group.id}"]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_target_group.arn
    container_name   = "webserver"
    container_port   = 8000
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [eu-west-2a, eu-west-2b]"
  }
}


resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}


# Define ECS task.
resource "aws_ecs_task_definition" "python_app" {
  family = "service"
  network_mode             = "awsvpc"
  container_definitions = jsonencode([
    {
      name      = "webserver"
      image     = "${aws_ecr_repository.ecr_python_web_app.repository_url}",
      cpu       = 1
      memory    = 128
      essential = true
      network_mode = "awsvpc"
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
    }
  ])

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [eu-west-2a, eu-west-2b]"
  }
}


# Loadbalancer
resource "aws_alb" "frontend" {
  name               = "frontendlb" 
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.subnet_eu_west_2a.id}",
    "${aws_default_subnet.subnet_eu_west_2b.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}


# Security Groups
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80 
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}


# create target group to route traffic to containers
resource "aws_lb_target_group" "frontend_target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" # Referencing the default VPC
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}


# create a listener for lb to point to target group.
resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.frontend_target_group.arn}" 
  }
}

