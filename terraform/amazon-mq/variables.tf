variable "region" {
  default     = "eu-west-2"
  description = "AWS region"
}

variable "name" {
  default     = "openflow-mq-demo"
  description = "Name prefix for resources"
}

variable "engine_type" {
  default     = "ActiveMQ"
  description = "Broker engine type: RabbitMQ or ActiveMQ"
  type        = string

  validation {
    condition     = contains(["RabbitMQ", "ActiveMQ"], var.engine_type)
    error_message = "engine_type must be either RabbitMQ or ActiveMQ."
  }
}

variable "engine_version" {
  default     = "5.18"
  description = "Broker engine version (5.18 for ActiveMQ, 3.13 for RabbitMQ)"
}

variable "host_instance_type" {
  default     = "mq.t3.micro"
  description = "Instance type for the broker"
}

variable "deployment_mode" {
  default     = "SINGLE_INSTANCE"
  description = "Deployment mode: SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ, or CLUSTER_MULTI_AZ"
  type        = string

  validation {
    condition     = contains(["SINGLE_INSTANCE", "ACTIVE_STANDBY_MULTI_AZ", "CLUSTER_MULTI_AZ"], var.deployment_mode)
    error_message = "deployment_mode must be one of: SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ, CLUSTER_MULTI_AZ."
  }
}

variable "publicly_accessible" {
  default     = true
  description = "Whether the broker should be publicly accessible"
  type        = bool
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
    condition     = var.create_vpc || var.existing_vpc_id != null
    error_message = "existing_vpc_id must be provided when create_vpc is false."
  }
}

variable "existing_subnet_ids" {
  default     = []
  description = "List of existing subnet IDs to use (required if create_vpc is false)"
  type        = list(string)

  validation {
    condition     = var.create_vpc || length(var.existing_subnet_ids) >= 1
    error_message = "At least 1 existing_subnet_id must be provided when create_vpc is false."
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

variable "mq_username" {
  default     = "mqadmin"
  description = "Username for broker authentication"
  type        = string
}

variable "mq_password" {
  description = "Password for broker authentication (min 12 chars, must include uppercase, lowercase, number, special char)"
  type        = string
  sensitive   = true
}

variable "auto_minor_version_upgrade" {
  default     = true
  description = "Whether to automatically upgrade to new minor versions"
  type        = bool
}

variable "maintenance_day_of_week" {
  default     = "SUNDAY"
  description = "Day of the week for maintenance window"
  type        = string
}

variable "maintenance_time_of_day" {
  default     = "03:00"
  description = "Time of day (UTC) for maintenance window"
  type        = string
}

variable "maintenance_time_zone" {
  default     = "UTC"
  description = "Time zone for maintenance window"
  type        = string
}

