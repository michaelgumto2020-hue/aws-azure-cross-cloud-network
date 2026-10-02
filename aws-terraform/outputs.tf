output "vpn_connection_id" {
  value = aws_vpn_connection.main.id
  description = "The VPN connection's ID"
}

output "vpn_tunnel1_address" {
  value       = aws_vpn_connection.main.tunnel1_address
  description = "AWS VPN tunnel 1 public IP — needed for Azure's Local Network Gateway"
}

output "vpn_tunnel2_address" {
  value       = aws_vpn_connection.main.tunnel2_address
  description = "AWS VPN tunnel 2 public IP — needed for Azure's Local Network Gateway"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "test_instance" {
  value = {
    id = aws_instance.test.id
    ip = aws_instance.test.private_ip
  }
}