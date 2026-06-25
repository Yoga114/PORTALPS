variable "ami_id" {
  description = "AMI AWS ID"
  type        = string
}

variable "instance_type" {
  description = "Type of the Instance"
  type        = string
}

variable "key_name" {
  description = "SSH Key Name"
  type        = string
}

variable "instance_name" {
  description = "EC2 Instance Name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for EC2"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to attach security group"
  type        = string
}

variable "private_ip" {
  description = "Custom private IP untuk EC2 (opsional, harus dalam range subnet)"
  type        = string
  default     = null   # null = AWS assign otomatis
}

variable "volume_size" {
  type        = string
  description = "The size for the EBS volume"
}

variable "volume_type" {
  description = "The storage type of the EBS"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to EC2"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Rendered bootstrap script passed via templatefile()"
  type        = string
  default     = null
}

variable "ingress_rules" {
  description = "List of ingress rules for this EC2's security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}
