variable "aws_region" {
  description = "AWS region where the infrastructure will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in tags and resource naming."
  type        = string
  default     = "catalog-services"
}

variable "environment" {
  description = "Environment name used in tags and resource naming."
  type        = string
  default     = "dev"
}

variable "resource_suffix" {
  description = "Suffix added to resource names to avoid collisions."
  type        = string
  default     = "v2"
}

variable "catalog_object_key" {
  description = "S3 key where the catalog CSV will be uploaded."
  type        = string
  default     = "catalog/servicios.csv"
}

variable "catalog_cache_key" {
  description = "Redis key used to store the latest parsed catalog."
  type        = string
  default     = "catalog:latest"
}

variable "vpc_id" {
  description = "VPC where Lambda and Redis will run."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by Lambda and Redis."
  type        = list(string)
}

variable "redis_node_type" {
  description = "ElastiCache node type for Redis."
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_port" {
  description = "Port exposed by Redis."
  type        = number
  default     = 6379
}

variable "redis_engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "lambda_runtime" {
  description = "Runtime used by both Lambda functions."
  type        = string
  default     = "nodejs18.x"
}
