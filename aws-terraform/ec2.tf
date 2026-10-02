data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name      = "name"
    values    = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "test" {
  ami                    = data.aws_ami.amazon_linux.id
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.test_instance.id]
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  tags = {
    Name = "${var.project_name}-test-instance"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}