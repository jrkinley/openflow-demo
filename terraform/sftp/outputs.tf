output "server_id" {
  description = "The ID of the Transfer Family server"
  value       = aws_transfer_server.sftp.id
}

output "server_arn" {
  description = "The ARN of the Transfer Family server"
  value       = aws_transfer_server.sftp.arn
}

output "server_endpoint" {
  description = "The endpoint of the Transfer Family server"
  value       = aws_transfer_server.sftp.endpoint
}

output "transfer_role_arn" {
  description = "The ARN of the IAM role used by Transfer Family to access S3"
  value       = aws_iam_role.transfer_role.arn
}

output "transfer_role_name" {
  description = "The name of the IAM role used by Transfer Family to access S3"
  value       = aws_iam_role.transfer_role.name
}

