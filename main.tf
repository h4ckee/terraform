provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
#  source = "../modules/terraform-aws-vpc"
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

#  azs             = ["eu-central-1a", "eu-central-1b"]
  azs             = ["${data.aws_availability_zones.available.names[0]}", "${data.aws_availability_zones.available.names[1]}"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "aws_security_group" {
#  source = "../modules/terraform-aws-security-group"
  source = "github.com/terraform-aws-modules/terraform-aws-security-group"

  name        = "asg"
  description = "Security group for ASG"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

module "asg_private" {
#  source = "../modules/terraform-aws-autoscaling"
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling"

  name = "service_private"

  # Launch configuration
  lc_name = "lc_private"

  image_id        = "ami-0bdf93799014acdc4"
  instance_type   = "t2.micro"
  security_groups = ["${module.aws_security_group.this_security_group_id}"]

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = "50"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name = "asg_private"

  vpc_zone_identifier = ["${module.vpc.private_subnets}"]

  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
}

module "asg_public" {
#  source = "../modules/terraform-aws-autoscaling"
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling"

  name = "service_public"

  # Launch configuration
  lc_name = "lc_public"

  image_id        = "ami-0bdf93799014acdc4"
  instance_type   = "t2.micro"
  security_groups = ["${module.aws_security_group.this_security_group_id}"]

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = "50"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name = "asg_public"

  vpc_zone_identifier = ["${module.vpc.public_subnets}"]

  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
}

resource "aws_lb" "nlb" {
  name               = "nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${module.vpc.private_subnets}"]
#  enable_deletion_protection = true
}

module "alb" {
#  source                   = "../modules/terraform-aws-alb"
  source                   = "github.com/terraform-aws-modules/terraform-aws-alb"
  load_balancer_name       = "my-alb"
  security_groups          = ["${module.aws_security_group.this_security_group_id}"]
  log_bucket_name          = "${aws_s3_bucket.log_bucket.id}"
  log_location_prefix      = "${var.log_location_prefix}"
  subnets                  = ["${module.vpc.public_subnets}"]
  tags                     = "${map("Environment", "test")}"
  vpc_id                   = "${module.vpc.vpc_id}"
  https_listeners          = "${local.https_listeners}"
  https_listeners_count    = "${local.https_listeners_count}"
  http_tcp_listeners       = "${local.http_tcp_listeners}"
  http_tcp_listeners_count = "${local.http_tcp_listeners_count}"
  target_groups            = "${local.target_groups}"
  target_groups_count      = "${local.target_groups_count}"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${local.log_bucket_name}"
  policy        = "${data.aws_iam_policy_document.bucket_policy.json}"
  force_destroy = true
  tags          = "${local.tags}"

  lifecycle_rule {
    id      = "log-expiration"
    enabled = "true"

    expiration {
      days = "7"
    }
  }
}

resource "aws_iam_server_certificate" "fixture_cert" {
  name_prefix      = "test_cert-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
#  certificate_body = "${file("../modules/terraform-aws-alb/examples/alb_test_fixture/certs/example.crt.pem")}"
#  private_key      = "${file("../modules/terraform-aws-alb/examples/alb_test_fixture/certs/example.key.pem")}"
  certificate_body = "${file("${path.module}/.terraform/modules/eaa6698e6db9aa6a1411efd6b34e4061/examples/alb_test_fixture/certs/example.crt.pem")}"
  private_key = "${file("${path.module}/.terraform/modules/eaa6698e6db9aa6a1411efd6b34e4061/examples/alb_test_fixture/certs/example.key.pem")}"

  lifecycle {
    create_before_destroy = true
  }

  count = 4
}
