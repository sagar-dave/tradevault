variable "aws_region" {
  description = "AWS region where dev infrastracture will be created"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name used for naming AWS resources"
  type        = string
  default     = "tradevault"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the TradeVault dev VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for dev infrastructure"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "sagar-dave"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "tradevault"
}

variable "db_name" {
  description = "Initial database name for Tradevault"
  type        = string
  default     = "tradevault"
}

variable "db_username" {
  description = "Master username for TradeVault RDS PostgreSQL"
  type        = string
  default     = "tradevaultadmin"
}

variable "db_password" {
  description = "Master password for TradeVault RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 3
}