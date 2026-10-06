output "endpoint" {
  value = aws_db_instance.demo.address
}

output "jdbc_url" {
  description = "JDBC URL for Flyway (RDS requires SSL on Postgres 15+)"
  value       = "jdbc:postgresql://${aws_db_instance.demo.address}:${aws_db_instance.demo.port}/${var.db_name}?sslmode=require"
}

output "username" {
  value = var.db_username
}

output "password_secret_arn" {
  description = "Secrets Manager secret holding the master password"
  value       = aws_db_instance.demo.master_user_secret[0].secret_arn
}

output "region" {
  value = var.region
}
