output "msk_bootstrap_brokers" {
  description = "Comma-separated list of MSK bootstrap brokers"
  value       = aws_msk_cluster.msk.bootstrap_brokers
}

output "msk_bootstrap_brokers_tls" {
  description = "Comma-separated list of TLS bootstrap brokers"
  value       = aws_msk_cluster.msk.bootstrap_brokers_tls
}

output "msk_bootstrap_brokers_sasl_scram" {
  description = "Comma-separated list of SASL/SCRAM bootstrap brokers"
  value       = aws_msk_cluster.msk.bootstrap_brokers_sasl_scram
}

output "msk_zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.msk.zookeeper_connect_string
}

output "kafka_username" {
  description = "SASL/SCRAM username for Kafka client authentication"
  value       = var.enable_sasl_scram ? var.kafka_username : null
}

output "kafka_password" {
  description = "SASL/SCRAM password for Kafka client authentication"
  value       = var.enable_sasl_scram ? var.kafka_password : null
  sensitive   = true
}