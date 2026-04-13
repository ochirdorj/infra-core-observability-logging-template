# OUTPUTS

output "fluent_bit_role_arn" {
  description = "ARN of the Fluent Bit IAM role"
  value       = aws_iam_role.fluent_bit.arn
}

output "application_log_group" {
  description = "CloudWatch log group for application logs"
  value       = aws_cloudwatch_log_group.application.name
}

output "dataplane_log_group" {
  description = "CloudWatch log group for dataplane logs"
  value       = aws_cloudwatch_log_group.dataplane.name
}

output "host_log_group" {
  description = "CloudWatch log group for host logs"
  value       = aws_cloudwatch_log_group.host.name
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.url
}