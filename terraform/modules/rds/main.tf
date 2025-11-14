# RDS Module Main Configuration

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}


# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}


# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-${var.environment}-mysql"
  engine                 = "mysql"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_type           = "gp2"
  storage_encrypted      = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  multi_az               = true
  publicly_accessible    = false
  
  backup_retention_period = 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  skip_final_snapshot    = true
  deletion_protection    = false
  
  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
  }
}


# AWS Secrets Manager Secret for RDS
resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.project_name}-${var.environment}-rds-credentials"
  description             = "RDS MySQL credentials for ${var.project_name}"
  recovery_window_in_days = 0  # Force delete immediately without recovery window

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-credentials"
  }
}

# Store RDS connection details in Secrets Manager
resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
    username = var.db_username
    password = var.db_password
  })
}
