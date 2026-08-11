variable "region" {
  type        = string
  description = "AWS region where resources will be created"
  default     = "us-east-1"

  validation {
    condition     = length(var.region) > 0
    error_message = "The region value must not be empty."
  }
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for storing Terraform state"
  nullable    = false

  validation {
    condition     = length(var.bucket_name) > 0
    error_message = "The bucket_name value must not be empty."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "The vpc_cidr value must be a valid CIDR block."
  }
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the subnet"
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "The subnet_cidr value must be a valid CIDR block."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type to deploy"
  default     = "t2.micro"

  validation {
    condition     = length(var.instance_type) > 0
    error_message = "The instance_type value must not be empty."
  }
}