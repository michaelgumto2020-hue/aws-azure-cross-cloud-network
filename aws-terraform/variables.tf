variable aws_region {
  type        = string
  default     = "us-east-1"
  description = "Default region for AWS"
}

variable project_name {
  type        = string
  default     = "cross-cloud"
  description = "Default project name"
}

variable vpc_cidr {
  type        = string
  default     = "10.2.0.0/16"
  description = "Default subnet"
}

variable private_subnet_cidr {
  type        = string
  default     = "10.2.1.0/24"
  description = "Default private subnet"
}
variable azure_vnet_cidr {
  type        = string
  default     = "10.3.0.0/16"
  description = "Azure VNet CIDR range, for the AWS-side route table"
}

variable "my_ip_cidr" {
  type        = string
  description = "Your IP in CIDR notation (e.g. 1.2.3.4/32), required explicitly — no default"
}