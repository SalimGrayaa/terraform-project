variable "region" {
  type        = string
  description = "AWS region where resources will be created"
  default     = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for storing Terraform state"
  nullable    = false
}