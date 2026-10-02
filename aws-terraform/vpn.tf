# Represents physical on-prem router
resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65000
  ip_address = "20.102.44.202"
  type       = "ipsec.1"

  tags = {
    Name     = "${var.project_name}-customer-gw"
  }
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vpn-gateway"
  }
}

# Ties the customer gateway and VPN gateway together
resource "aws_vpn_connection" "main" {
  customer_gateway_id = aws_customer_gateway.azure.id
  vpn_gateway_id      = aws_vpn_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name              = "${var.project_name}-vpn-connection"
  }
}

# Only if you are running a static VPN
resource "aws_vpn_connection_route" "azure" {
  vpn_connection_id      = aws_vpn_connection.main.id
  destination_cidr_block = var.azure_vnet_cidr
}