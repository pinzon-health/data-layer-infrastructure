variable "profile" {
  description = "AWS profile to use"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "master_username" {
  description = "Aurora Serverless username"
  type        = string
  default     = "master"
}

variable "db_password" {
  description = "Aurora Serverless password"
  type        = string
  default     = "password"
}

variable "min_capacity" {
  description = "The minimum capacity for an Aurora Serverless DB cluster in Aurora capacity units (ACU)."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "The maximum capacity for an Aurora Serverless DB cluster in Aurora capacity units (ACU)."
  type        = number
  default     = 8
}

variable "bastion_cidr" {
  type        = string
  description = "The IP address range that is allowed to connect to the bastion host"
  default     = "0.0.0.0/0"
}

variable "bastion_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "bastion_ami_id" {
  type    = string
  default = "ami-0499632f10efc5a62" # Amazon Linux 2 LTS
}
