provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "all" {}

resource "aws_launch_configuration" "cluster" {
  image_id        = "ami-0bdf93799014acdc4"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.cluster-sg.id}"]

  user_data = <<-EOF
	#!/bin/bash
	echo "Hello, World" > index.html
	nohup busybox httpd -f -p "${var.server_port}" &
	EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "cluster-sg" {
  name = "cluster-sg"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb-sg" {
  name = "elb-sg"

  ingress {
    from_port   = "${var.lb_ingress_port}"
    to_port     = "${var.lb_ingress_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "${var.lb_egress_port}"
    to_port     = "${var.lb_egress_port}"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "cluster-elb" {
  name               = "cluster-elb"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.elb-sg.id}"]

  listener {
    lb_port           = "${var.lb_ingress_port}"
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "cluster-asg" {
  launch_configuration = "${aws_launch_configuration.cluster.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  load_balancers    = ["${aws_elb.cluster-elb.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "cluster-asg"
    propagate_at_launch = true
  }
}

output "elb_dns_name" {
  value = "${aws_elb.cluster-elb.dns_name}"
}
