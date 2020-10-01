terraform {
  backend "s3" {
    bucket = "terraform-apt"
    key    = "ecs/webservices/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

module "service" {
  source = "./service"

  service_name        = var.service_name
  vpc_id              = var.vpc_id
  lb_health_check     = var.lb_health_check
  cluster_name        = var.cluster_name
  policy_name         = var.policy_name
  policy_target_value = var.policy_target_value
  lb1_name            = var.lb1_name
  lb2_name            = var.lb2_name
  lb_path_pattern_values    = var.lb_path_pattern_values
  listener_port       = var.listener_port
  aws_region          = var.aws_region
  reserved_memory     = var.reserved_memory
  reserved_cpu        = var.reserved_cpu
  desired_count       = var.desired_count
  min_capacity        = var.min_capacity
  max_capacity        = var.max_capacity
}
