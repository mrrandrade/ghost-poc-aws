output jumpbox {
  value = aws_instance.jumpbox.public_ip
}

output lb {
  value = aws_lb.ghost_alb.dns_name
}

output cloudfront {
  value = aws_cloudfront_distribution.ghost.domain_name
}

resource "aws_instance" "jumpbox" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id   = module.vpc.public_subnets[0]
  key_name = aws_key_pair.debug[0].key_name
  vpc_security_group_ids = [aws_security_group.ghost.id]

}

resource "aws_security_group_rule" "incoming_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ghost.id
}

resource "aws_security_group_rule" "outgoing_ssh" {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ghost.id
}

