variable "principal" {
  description = "Principal to share with"
  type        = string
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
}

variable "subnet_set" {
  description = "Subnet set to attach to"
  type        = string
}
