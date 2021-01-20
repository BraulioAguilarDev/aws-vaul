output "instance_public_ip" {
  value = aws_instance.vault_testing.public_ip
}
