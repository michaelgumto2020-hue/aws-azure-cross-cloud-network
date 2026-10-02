resource "aws_security_group" "test_instance" {
  name          = "${var.project_name}-test-instance"
  description   = "SSH and ping ingress with allow egress"
  vpc_id        = aws_vpc.main.id

  ingress {
    description = "ICMP from Azure VNET CIDR"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.azure_vnet_cidr]
    }

  egress {
    description = "Allow all outbound traffic to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # "-1" translates semantically to ALL protocols (TCP, UDP, ICMP, etc.)
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name          = "${var.project_name}-vpc-endpoints"
  description   = "Allow inbound HTTPS from VPC subnet"
  vpc_id        = aws_vpc.main.id

  ingress {
    description = "HTTPS inbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    }

  egress {
    description = "Allow all outbound traffic to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # "-1" translates semantically to ALL protocols (TCP, UDP, ICMP, etc.)
    cidr_blocks = ["0.0.0.0/0"]
  }
}