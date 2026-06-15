variable "aws_region" {
    description = "AWS region where dev infrastracture will be created"
    type = string
    default = "us-east-2"
}

variable "project_name" {
    description = "Project name used for naming AWS resources"
    type = string
    default = "tradevault"   
}

variable "environment" {
    description = "Environment name"
    type = string
    default = "dev"
}