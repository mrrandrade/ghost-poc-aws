
#
# Ghost's VPC
#
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "ghost"
  cidr = "10.0.0.0/16"

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_cidr
  public_subnets  = var.vpc_public_cidr
  database_subnets = var.vpc_database_cidr  
  create_database_subnet_group = true
  default_vpc_enable_dns_hostnames = true
  

  # I'd rather do my own VPC code here, but had to simplify to  try and achieve other objectives
  single_nat_gateway = true
  enable_nat_gateway = true

  tags = merge(
    local.tags,
    {"name": "ghost"}
  )
}

#
# Security Group
#

resource "aws_security_group" "ghost" {
  name        = "Ghost"
  description = "Allow HTTPS"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.tags,
    {"name": "ghost"}
  )
}

# TODO: Restrict origin
resource "aws_security_group_rule" "income_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ghost.id
}

resource "aws_security_group_rule" "income_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ghost.id
}

# add ips of the mirrors here.
resource "aws_security_group_rule" "outgoing_update" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # source_security_group_id = aws_security_group.ghost_elb.id
  security_group_id = aws_security_group.ghost.id
}

resource "aws_security_group_rule" "outgoing_update_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # source_security_group_id = aws_security_group.ghost_elb.id
  security_group_id = aws_security_group.ghost.id
}

resource "aws_security_group_rule" "outgoing_rds" {
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  source_security_group_id = aws_security_group.ghost_rds.id
  security_group_id = aws_security_group.ghost.id
}
#
# Which AMI to use?
#

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

#
# EC2 IAM
#

resource "aws_iam_role" "ghost_ec2_role" {
  name = "ghost_ec2_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.tags,
    {"name": "ghost_ec2_role"}
  )
}

# resource "aws_iam_role_policy_attachment" "ghost_ec2_policies" {
#   role       = aws_iam_role.role.name
#   policy_arn = aws_iam_policy.policy.arn
# }

#
# Ghost's Launch template
#
resource "aws_key_pair" "debug" {
  count =  fileexists("~/.ssh/id_rsa.pub") ? 1 : 0

  key_name   = "debug"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_launch_template" "ghost" {

  name_prefix   = "ghost-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.ghost_instance_type
  update_default_version = true
  user_data     = base64encode(
                    templatefile(
                      "templates/user_data.tmpl",
                      { 
                          "db_user" = var.db_admin_username,
                          "db_password" = var.db_admin_password,
                          "db_host" = aws_db_instance.ghost.address,
                          "url" = "http://${aws_lb.ghost_alb.dns_name}" 

                      }
                    )
                  )

  vpc_security_group_ids = [aws_security_group.ghost.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.tags,
      {"name": "ghost"}
    )
  }

  monitoring {
    enabled = true
  }

  #checkov:skip=CKV_AWS_79:Default requires metadata v2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }

  key_name = aws_key_pair.debug[0].key_name

}

resource "aws_autoscaling_group" "ghost" {
  name = "ghost"

  desired_capacity   = 1
  max_size           = 1
  min_size           = 1

  vpc_zone_identifier = module.vpc.private_subnets
  # health_check_type = "EC2"

  launch_template {
    id      = aws_launch_template.ghost.id
    version = aws_launch_template.ghost.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    # triggers = ["tag"]
  }

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

  dynamic "tag" {
    for_each = local.tags

    content {
      key    =  tag.key
      value   =  tag.value
      propagate_at_launch =  true
    }
  }
}

#
# Unnecessary Loadbalancer
#

resource "aws_security_group" "ghost_elb" {
  name        = "ghost_lb"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.ghost.id]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.ghost.id]
  }

  tags = merge(
    local.tags,
    {"name": "ghost_elb"}
  )
}

resource "aws_lb" "ghost_alb" {
  name = "ghost-alb"

  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.ghost_elb.id]
  subnets = module.vpc.public_subnets

  access_logs {
    bucket  = aws_s3_bucket.ghost_logs.bucket
    prefix  = "ghost/alb"
    enabled = true
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ghost_alb.arn
  port              = "80"
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  # certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost_instance.arn 
  }

  # TODO: debug why admin acess is not working.
  # default_action {
  # type             = "fixed-response"
  # fixed_response { 
  #    content_type     = "text/plain" 
  #    message_body     = "Forbidden. Sorry."
  #    status_code      = "403"
  #  }
  #}
}

resource "aws_lb_listener_rule" "require_header" {
  listener_arn = aws_lb_listener.front_end.arn
  # Goes from 1 to 50000
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost_instance.arn 
  }

  condition {
    http_header {
      http_header_name = "X-Allowed-Origin"
      values = ["ghost-poc-client-hHp7QRvVOP"]
    }
  }
}

resource "aws_lb_listener_rule" "admin_passthrough" {
  listener_arn = aws_lb_listener.front_end.arn
  # Goes from 1 to 50000
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost_instance.arn 
  }

  condition {
    path_pattern {
      values = ["/ghost/*"]
    }
  }
}

resource "aws_lb_target_group" "ghost_instance" {
  name     = "tgghostinstance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.ghost.id
  alb_target_group_arn   = aws_lb_target_group.ghost_instance.arn
}