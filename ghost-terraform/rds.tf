resource "aws_security_group" "ghost_rds" {
  name        = "Ghost RDS"
  description = "Allow connections from Ghost to RDS"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.tags,
    {"name": "ghost"}
  )
}

# TODO: Restrict origin
resource "aws_security_group_rule" "income_mysql" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.ghost_rds.id
  source_security_group_id = aws_security_group.ghost.id
}

resource "aws_db_instance" "ghost" {

  name = "ghost"
  identifier = "ghost"  
  multi_az = true  
  iam_database_authentication_enabled = true  

  instance_class = "db.t3.micro"
  engine         = "mysql"  
  engine_version = "8.0"  
  parameter_group_name   = "default.mysql8.0"  
  copy_tags_to_snapshot = true
  enabled_cloudwatch_logs_exports  = ["audit", "error", "general", "slowquery"]    

  vpc_security_group_ids = [aws_security_group.ghost_rds.id]  
  # TODO: hardcoded on VPC module.
  # db_subnet_group_name   = "ghost"  
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  username = var.db_admin_username
  password = var.db_admin_password

  # TODO: create variables.
  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"
  allocated_storage = 50  

  # TODO: create the required objects to implement encryption at rest.
  # Not prioritizing this in order to fulfill all the work.
  # storage_encrypted = var.storage_encrypted
  # kms_key_id = var.kms_key_id

  # These should be different if not an exercise
  # deletion_protection = true  
  # iops = var.iops   
  # final_snapshot_identifier = var.final_snapshot_identifier  
  # monitoring_interval = var.monitoring_interval
  # monitoring_role_arn = var.monitoring_role_arn  
  # If used with read replicas, this parameter is required to be > 0
  # backup_retention_period = 1  
  skip_final_snapshot = true

  tags = merge(
      local.tags,
      {"name": "ghost"}
  )

  lifecycle {
    ignore_changes = [password]
  }
}