variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "The AWS profile to use for authentication."
  type        = string
  default     = "default"
}

variable "account_id" {
  description = "The AWS account ID."
  type        = string
}

variable "trusted_principal_arn" {
  description = "The ARN of the trusted principal."
  type        = string
}

variable "break_glass_principal_arn" {
  description = "The ARN of the break glass principal."
  type        = string
}
