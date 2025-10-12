variable "region" {
  default     = "eu-west-2"
  description = "AWS region"
}

variable "name" {
  default     = "openflow-postgres-demo"
  description = "Name prefix for resources"
}

variable "instance_class" {
  default     = "db.m7g.large"
  description = "RDS instance class"
}

variable "engine_version" {
  default     = "17.6"
  description = "PostgreSQL engine version"
}

variable "db_username" {
  default     = "postgres"
  description = "RDS root username"
  sensitive   = false
}

variable "create_vpc" {
  default     = false
  description = "Whether to create a new VPC or use an existing one"
  type        = bool
}

variable "existing_vpc_id" {
  default     = null
  description = "ID of existing VPC to use (required if create_vpc is false)"
  type        = string
  
  validation {
    condition = var.create_vpc || var.existing_vpc_id != null
    error_message = "existing_vpc_id must be provided when create_vpc is false."
  }
}

variable "existing_subnet_ids" {
  default     = []
  description = "List of existing subnet IDs to use for RDS (required if create_vpc is false)"
  type        = list(string)
  
  validation {
    condition = var.create_vpc || length(var.existing_subnet_ids) >= 2
    error_message = "At least 2 existing_subnet_ids must be provided when create_vpc is false (RDS requires subnets in multiple AZs)."
  }
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "CIDR block for VPC (only used if create_vpc is true)"
  type        = string
}

variable "public_subnets" {
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  description = "Public subnet CIDR blocks (only used if create_vpc is true)"
  type        = list(string)
}

variable "owner" {
  default     = null
  description = "Owner tag for AWS resources (defaults to local username)"
  type        = string
}

variable "db_password" {
  description = "RDS root user password"
  sensitive   = true
}
