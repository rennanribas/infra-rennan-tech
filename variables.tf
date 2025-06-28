
variable "aws_region" {
  description = "The AWS region to deploy the infrastructure to."
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "The GitHub repository to grant access to."
  type        = string
  default     = "RennanRibas/rennan-tech"
}
