output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.rds-pg.address
  sensitive   = false
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.rds-pg.port
  sensitive   = false
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.rds-pg.username
  sensitive   = false
}
