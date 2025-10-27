variable "region" {
  default     = "eu-west-2"
  description = "AWS region"
  type        = string
}

variable "name" {
  default     = "openflow-sftp-demo"
  description = "Name prefix for resources"
  type        = string
}

variable "owner" {
  default     = null
  description = "Owner tag for AWS resources (defaults to local username)"
  type        = string
}

