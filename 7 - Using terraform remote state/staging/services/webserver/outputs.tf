# Output the address and port of the EC2 instance
output "instance_address" {
  value = aws_instance.example.public_ip
}

output "instance_port" {
  value = var.server_port
}
