output "region" {
  description = "AWS region where the broker is deployed"
  value       = var.region
}

output "broker_id" {
  description = "ID of the Amazon MQ broker"
  value       = aws_mq_broker.broker.id
}

output "broker_arn" {
  description = "ARN of the Amazon MQ broker"
  value       = aws_mq_broker.broker.arn
}

output "broker_engine_type" {
  description = "Engine type of the broker"
  value       = var.engine_type
}

# RabbitMQ endpoints
output "rabbitmq_endpoint" {
  description = "RabbitMQ AMQP endpoint (amqps://)"
  value       = var.engine_type == "RabbitMQ" ? aws_mq_broker.broker.instances[0].endpoints[0] : null
}

output "rabbitmq_console_url" {
  description = "RabbitMQ web console URL"
  value       = var.engine_type == "RabbitMQ" ? aws_mq_broker.broker.instances[0].console_url : null
}

# ActiveMQ endpoints
output "activemq_endpoints" {
  description = "ActiveMQ endpoints (OpenWire, AMQP, STOMP, MQTT, WSS)"
  value       = var.engine_type == "ActiveMQ" ? aws_mq_broker.broker.instances[0].endpoints : null
}

output "activemq_console_url" {
  description = "ActiveMQ web console URL"
  value       = var.engine_type == "ActiveMQ" ? aws_mq_broker.broker.instances[0].console_url : null
}

# Generic outputs
output "console_url" {
  description = "Web console URL for the broker"
  value       = aws_mq_broker.broker.instances[0].console_url
}

output "mq_username" {
  description = "Username for broker authentication"
  value       = var.mq_username
}

output "mq_password" {
  description = "Password for broker authentication"
  value       = var.mq_password
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the security group for the broker"
  value       = aws_security_group.mq.id
}

output "vpc_id" {
  description = "VPC ID where the broker is deployed"
  value       = local.vpc_id
}

