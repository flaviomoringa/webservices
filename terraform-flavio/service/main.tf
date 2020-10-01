data "aws_ecs_cluster" "main" {
  cluster_name = var.cluster_name
}

data "aws_lb" "main" {
  name = var.lb1_name
}

data "aws_lb" "secondary" {
  name = var.lb2_name
}

data "aws_lb_listener" "main" {
  load_balancer_arn = data.aws_lb.main.arn
  port              = var.listener_port
}

data "aws_lb_listener" "secondary" {
  load_balancer_arn = data.aws_lb.secondary.arn
  port              = var.listener_port
}

data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.main.family
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = data.aws_lb_listener.main.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = var.lb_path_pattern_values
    }
  }

  condition {
    host_header {
      values = var.lb_host_header_values
    }
}

resource "aws_lb_listener_rule" "secondary" {
  listener_arn = data.aws_lb_listener.secondary.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.secondary.arn
  }

  condition {
    path_pattern {
      values = var.lb_path_pattern_values
    }
  }

  condition {
    host_header {
      values = var.lb_host_header_values
    }
  }

}

resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "bridge"
  cpu                      = var.reserved_cpu
  memory                   = var.reserved_memory
  requires_compatibilities = ["EC2"]
  container_definitions    = <<EOF
[
  {
    "name": "${var.service_name}",
    "image": "XXXXXXXXXXXX.dkr.ecr.eu-west-1.amazonaws.com/${var.service_name}:latest",
    "cpu": ${var.reserved_cpu},
    "memory": ${var.reserved_memory},
    "essential": true,
    "portMappings": [
      {
        "hostPort": 0,
        "containerPort": 80,
        "protocol": "tcp"
      }
    ]
  }
]
EOF

}

resource "aws_alb_target_group" "main" {
  lifecycle {
    create_before_destroy = true
  }

  name                 = var.lb1_name
  port                 = "80"
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = "3"

  health_check {
    path                = var.lb_health_check
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = var.service_name
  }
  /* Environment = "${var.environment}"
    Application = "${var.service_name}" */
}

resource "aws_alb_target_group" "secondary" {
  lifecycle {
    create_before_destroy = true
  }

  name                 = var.lb2_name
  port                 = "80"
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = "3"

  health_check {
    path                = var.lb_health_check
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = var.service_name
  }
  // Environment = "${var.environment}"
  //  Application = "${var.service_name}"
}

resource "aws_ecs_service" "microservice" {
  name          = var.service_name
  cluster       = var.cluster_name
  desired_count = var.desired_count

  task_definition = "arn:aws:ecs:eu-west-1:829420787451:task-definition/${aws_ecs_task_definition.main.family}:${max(
    aws_ecs_task_definition.main.revision,
    data.aws_ecs_task_definition.main.revision,
  )}"

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  // mobile-multi-a LB
  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = var.service_name
    container_port   = "80"
  }

  // mobile-multi-b LB
  load_balancer {
    target_group_arn = aws_alb_target_group.secondary.arn
    container_name   = var.service_name
    container_port   = "80"
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  role_arn           = "arn:aws:iam::829420787451:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.microservice]
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu_utilization" {
  name               = var.policy_name
  policy_type        = "TargetTrackingScaling"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      dimensions {
        name = "ClusterName"
        value = var.cluster_name
      }
      dimensions {
        name = "ServiceName"
        value = var.service_name
      }
      metric_name = "CPUUtilization"
      namespace = "AWS/ECS"
      statistic = "Maximum"
      unit = "Percent"
    }

    target_value = var.policy_target_value
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }

  depends_on = [aws_appautoscaling_target.ecs_target]
}
