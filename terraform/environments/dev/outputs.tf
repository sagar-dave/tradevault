output "name_prefix" {
  description = "Common name prefix for dev resources"
  value       = local.name_prefix
}

output "vpc_id" {
  description = "ID of the Tradevault dev VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "app_security_group_id" {
  description = "Security group ID for TradeVault application"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group ID for TradeVault database"
  value       = aws_security_group.db.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for TradeVault API image"
  value       = aws_ecr_repository.api.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN used by GitHub Actions to push images to ECR"
  value       = aws_iam_role.github_actions_ecr.arn
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.poatgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.poatgres.port
}

output "rds_database_name" {
  description = "RDS PostgreSQL database name"
  value       = aws_db_instance.poatgres.db_name
}