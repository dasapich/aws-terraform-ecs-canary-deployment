terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}


# AWS provider
provider "aws" {
  profile = "default"
  region  = "ap-southeast-1"
}


# VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "aws-terraform-demo-vpc"
  }
}


# Subnets
resource "aws_subnet" "demo_vpc_public_a" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "demo-vpc-public-a"
  }
}

resource "aws_subnet" "demo_vpc_public_b" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "demo-vpc-public-b"
  }
}

resource "aws_subnet" "demo_vpc_private_a" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "demo-vpc-private-a"
  }
}

resource "aws_subnet" "demo_vpc_private_b" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "demo-vpc-private-b"
  }
}


# Internet Gateway and NAT Gateways
resource "aws_internet_gateway" "demo_vpc_internet_gateway" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo-vpc-internet-gateway"
  }
}

resource "aws_eip" "demo_vpc_nat_a_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.demo_vpc_internet_gateway]
}

resource "aws_eip" "demo_vpc_nat_b_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.demo_vpc_internet_gateway]
}

resource "aws_nat_gateway" "demo_vpc_nat_gateway_a" {
  allocation_id = aws_eip.demo_vpc_nat_a_eip.id
  subnet_id     = aws_subnet.demo_vpc_public_a.id

  tags = {
    Name = "demo-vpc-nat-gateway-a"
  }

  depends_on = [aws_internet_gateway.demo_vpc_internet_gateway]
}

resource "aws_nat_gateway" "demo_vpc_nat_gateway_b" {
  allocation_id = aws_eip.demo_vpc_nat_b_eip.id
  subnet_id     = aws_subnet.demo_vpc_public_b.id

  tags = {
    Name = "demo-vpc-nat-gateway-b"
  }

  depends_on = [aws_internet_gateway.demo_vpc_internet_gateway]
}


# Route Tables
resource "aws_route_table" "demo_vpc_public_subnets_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_vpc_internet_gateway.id
  }

  tags = {
    Name = "demo-vpc-public-subnets-route-table"
  }
}

resource "aws_route_table_association" "demo_vpc_public_subnet_a_association" {
  subnet_id      = aws_subnet.demo_vpc_public_a.id
  route_table_id = aws_route_table.demo_vpc_public_subnets_route_table.id
}

resource "aws_route_table_association" "demo_vpc_public_subnet_b_association" {
  subnet_id      = aws_subnet.demo_vpc_public_b.id
  route_table_id = aws_route_table.demo_vpc_public_subnets_route_table.id
}

resource "aws_route_table" "demo_vpc_private_subnet_a_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.demo_vpc_nat_gateway_a.id
  }

  tags = {
    Name = "demo-vpc-private-a-route-table"
  }
}

resource "aws_route_table_association" "demo_vpc_private_subnet_a_association" {
  subnet_id      = aws_subnet.demo_vpc_private_a.id
  route_table_id = aws_route_table.demo_vpc_private_subnet_a_route_table.id
}

resource "aws_route_table" "demo_vpc_private_subnet_b_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.demo_vpc_nat_gateway_b.id
  }

  tags = {
    Name = "demo-vpc-private-b-route-table"
  }
}

resource "aws_route_table_association" "demo_vpc_private_subnet_b_association" {
  subnet_id      = aws_subnet.demo_vpc_private_b.id
  route_table_id = aws_route_table.demo_vpc_private_subnet_b_route_table.id
}


# Roles
data "aws_iam_policy_document" "ecs-assume-role-policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "ecs-task-execution-role-policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs-task-execution-policy" {
  name   = "ecs-task-execution-policy"
  policy = data.aws_iam_policy.ecs-task-execution-role-policy.policy
}

resource "aws_iam_role" "ecs-task-role" {
  name                = "ecs-task-role"
  assume_role_policy  = data.aws_iam_policy_document.ecs-assume-role-policy.json
  managed_policy_arns = [aws_iam_policy.ecs-task-execution-policy.arn]
}

data "aws_iam_policy_document" "codedeploy-assume-role-policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "codedeploy-ecs-role-policy" {
  name = "AWSCodeDeployRoleForECS"
}

resource "aws_iam_policy" "codedeploy-service-role-policy" {
  name   = "codedeploy-service-role-policy"
  policy = data.aws_iam_policy.codedeploy-ecs-role-policy.policy
}

resource "aws_iam_role" "codedeploy-service-role" {
  name                = "codedeploy-service-role"
  assume_role_policy  = data.aws_iam_policy_document.codedeploy-assume-role-policy.json
  managed_policy_arns = [aws_iam_policy.codedeploy-service-role-policy.arn]
}


# Network
resource "aws_security_group" "ecs_cluster_security_group" {
  name        = "ecs_cluster_security_group"
  description = "Security group for ECS Cluster"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "Allow HTTP inbound from VPC"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [aws_vpc.demo_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_security_group" {
  name        = "alb_security_group"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "HTTP public access"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP public access on port 8080"
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ALB
resource "aws_lb" "ecs_canary_alb" {
  name               = "ecs-canary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [aws_subnet.demo_vpc_public_a.id, aws_subnet.demo_vpc_public_b.id]
}

resource "aws_lb_target_group" "ecs_canary_target_group_a" {
  name        = "ecs-canary-target-group-a"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.demo_vpc.id
  health_check {
    path     = "/"
    timeout  = 30
    interval = 60
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "ecs_canary_target_group_b" {
  name        = "ecs-canary-target-group-b"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.demo_vpc.id
  health_check {
    path     = "/"
    timeout  = 30
    interval = 60
    matcher  = "200"
  }
}

resource "aws_lb_listener" "ecs_canary_alb_main_listener" {
  load_balancer_arn = aws_lb.ecs_canary_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_canary_target_group_a.arn
  }

  depends_on = [aws_lb_target_group.ecs_canary_target_group_a, aws_lb_target_group.ecs_canary_target_group_b]
}

resource "aws_lb_listener" "ecs_canary_alb_test_listener" {
  load_balancer_arn = aws_lb.ecs_canary_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_canary_target_group_a.arn
  }

  depends_on = [aws_lb_target_group.ecs_canary_target_group_a, aws_lb_target_group.ecs_canary_target_group_b]
}


# ECR
resource "aws_ecr_repository" "ecs-canary-demo" {
  name                 = "ecs-canary-demo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}


# ECS Cluster
resource "aws_ecs_cluster" "ecs_canary_cluster" {
  name               = "ecs_canary_cluster"
  capacity_providers = ["FARGATE"]
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "ecs_canary_service" {
  name                              = "ecs-canary-service"
  cluster                           = aws_ecs_cluster.ecs_canary_cluster.id
  task_definition                   = aws_ecs_task_definition.demo_taskdef.arn
  desired_count                     = 3
  scheduling_strategy               = "REPLICA"
  force_new_deployment              = true
  health_check_grace_period_seconds = 60
  launch_type                       = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_canary_target_group_a.arn
    container_name   = "ecs-canary-demo"
    container_port   = 80
  }

  network_configuration {
    subnets = [aws_subnet.demo_vpc_private_a.id, aws_subnet.demo_vpc_private_b.id]
  }

  /*
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  */

  depends_on = [aws_lb_listener.ecs_canary_alb_main_listener]
}

resource "aws_ecs_task_definition" "demo_taskdef" {
  family                   = "ecs-canary-demo-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs-task-role.arn
  task_role_arn            = aws_iam_role.ecs-task-role.arn
  container_definitions = jsonencode([
    {
      name      = "ecs-canary-demo"
      image     = "docker.io/library/nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      dockerLabels = {
        name = "ecs-canary-demo"
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs-canary/ecs-canary-demo"
          awslogs-region        = "ap-southeast-1"
          awslogs-stream-prefix = "ecs-canary-demo"
        }
      }
    }
  ])
}


# CloudWatch Logs
resource "aws_cloudwatch_log_group" "ecs_canary_demo_log_group" {
  name              = "/ecs-canary/ecs-canary-demo"
  retention_in_days = 7
}


/*
# AWS CodeDeploy Blue/Green deployments
resource "aws_codedeploy_app" "ecs_canary_codedeploy_app" {
  name             = "ecs-canary-deployment-demo"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "ecs_canary_deployment_group" {
  app_name               = aws_codedeploy_app.ecs_canary_codedeploy_app.name
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"
  deployment_group_name  = "ecs-canary-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy-service-role.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  # TODO Add alarms

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 2880
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_canary_cluster.name
    service_name = aws_ecs_service.ecs_canary_service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.ecs_canary_alb_main_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.ecs_canary_target_group_a.name
      }

      target_group {
        name = aws_lb_target_group.ecs_canary_target_group_b.name
      }

      test_traffic_route {
        listener_arns = [aws_lb_listener.ecs_canary_alb_test_listener.arn]
      }
    }
  }
}
*/

# TODO: Add lifecycle hook lambda functions
