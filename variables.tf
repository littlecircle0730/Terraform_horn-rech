variable "project" {
  description = "Project name"
  default     = "horn"
}

variable "stage" {
  type        = string
  description = "Stage"
  default     = "rech"
}

variable "region" {
  type        = string
  description = "region"
}

variable "domain_name" {
  type        = string
  description = "Domain name"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
}

variable "igw_cidr" {
  description = "VPC Internet Gateway CIDR"
}

variable "public_subnets_cidr" {
  description = "Public Subnets CIDR"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "Private Subnets CIDR"
  type        = list(string)
}

variable "nat_cidr" {
  description = "VPC NAT Gateway CIDR"
  type        = list(string)
}

variable "azs" {
  description = "VPC Availability Zones"
  type        = list(string)
}

variable "bastion_public_key_path" {
  type        = string
  description = "Bastion SSH public key"
  default     = "~/.ssh/hs_bastion.pub"
}

variable "bastion_deploy_public_key_path" {
  type        = string
  description = "Bastion SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "bastion_backend_git" {
  type    = string
  default = ""
}

variable "bastion_backend_git_branch" {
  type    = string
  default = "main"
}
