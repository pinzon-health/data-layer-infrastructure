output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
output "bastion_host" {
  value = aws_instance.bastion.public_dns
}
# bastion user data
output "bastion_user_data" {
  value = aws_instance.bastion.user_data
}
output "aurora_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "Aurora endpoint"
}
output "aurora_writer_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}
output "aurora_reader_endpoint" {
  value = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_database_name" {
  value = aws_rds_cluster.aurora.database_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "lambda_subnet_ids" {
  value = aws_subnet.private.*.id
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}
