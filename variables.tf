
variable "aws_region" {
  description = "The AWS region to deploy the infrastructure to"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (must be Free Tier eligible)"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Instance type must be t2.micro or t3.micro for Free Tier eligibility."
  }
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "rennan-tech"
}

variable "doppler_workspace_slug" {
  description = "Doppler workspace slug for External ID in IAM role trust policy"
  type        = string
  default     = "rennan-tech"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.doppler_workspace_slug))
    error_message = "Doppler workspace slug must contain only lowercase letters, numbers, and hyphens."
  }
}
