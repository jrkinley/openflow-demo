variable "region" {
  default     = "eu-west-2"
  description = "AWS region"
}

variable "name" {
  default     = "openflow-msk-demo"
  description = "Name prefix for resources"
}

variable "kafka_version" {
  default     = "3.5.1"
  description = "Kafka version for the MSK cluster"
}

variable "number_of_broker_nodes" {
  default     = 3
  description = "Number of broker nodes in the MSK cluster (must be multiple of number of AZs)"
  type        = number
}

variable "broker_instance_type" {
  default     = "kafka.t3.small"
  description = "Instance type for the broker nodes"
}

variable "ebs_volume_size" {
  default     = 100
  description = "Size of the EBS volumes for the broker nodes (in GB)"
  type        = number
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
  description = "List of existing subnet IDs to use for MSK (required if create_vpc is false, must be in different AZs)"
  type        = list(string)
  
  validation {
    condition = var.create_vpc || length(var.existing_subnet_ids) >= 2
    error_message = "At least 2 existing_subnet_ids must be provided when create_vpc is false (MSK requires subnets in multiple AZs)."
  }
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "CIDR block for VPC (only used if create_vpc is true)"
  type        = string
}

variable "private_subnets" {
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  description = "Private subnet CIDR blocks for MSK brokers (only used if create_vpc is true)"
  type        = list(string)
}

variable "public_subnets" {
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  description = "Public subnet CIDR blocks for client access (only used if create_vpc is true)"
  type        = list(string)
}

variable "owner" {
  default     = null
  description = "Owner tag for AWS resources (defaults to local username)"
  type        = string
}

variable "encryption_in_transit_client_broker" {
  default     = "TLS"
  description = "Encryption setting for data in transit between clients and brokers. Valid values: TLS, TLS_PLAINTEXT, PLAINTEXT"
  type        = string
  
  validation {
    condition = contains(["TLS", "TLS_PLAINTEXT", "PLAINTEXT"], var.encryption_in_transit_client_broker)
    error_message = "encryption_in_transit_client_broker must be one of: TLS, TLS_PLAINTEXT, PLAINTEXT."
  }
}

variable "encryption_in_transit_in_cluster" {
  default     = true
  description = "Whether to enable encryption in transit for communication within the cluster"
  type        = bool
}

variable "enhanced_monitoring" {
  default     = "DEFAULT"
  description = "Enhanced monitoring level. Valid values: DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION"
  type        = string
  
  validation {
    condition = contains(["DEFAULT", "PER_BROKER", "PER_TOPIC_PER_BROKER", "PER_TOPIC_PER_PARTITION"], var.enhanced_monitoring)
    error_message = "enhanced_monitoring must be one of: DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION."
  }
}

variable "enable_sasl_scram" {
  default     = true
  description = "Enable SASL/SCRAM authentication for the MSK cluster"
  type        = bool
}

variable "kafka_username" {
  default     = "kafka-user"
  description = "Username for SASL/SCRAM authentication"
  type        = string
}

variable "kafka_password" {
  description = "Password for SASL/SCRAM authentication"
  type        = string
  sensitive   = true
}
