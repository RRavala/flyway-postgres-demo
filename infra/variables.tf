variable "region" {
  description = "AWS region for the demo database"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "flyway-demo"
}

variable "allowed_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to reach Postgres on 5432, e.g. ["203.0.113.7/32"].
    Use your own public IP (curl https://checkip.amazonaws.com) with /32.
    Do not use 0.0.0.0/0.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidrs) > 0 && !contains(var.allowed_cidrs, "0.0.0.0/0")
    error_message = "Provide at least one CIDR and do not use 0.0.0.0/0."
  }
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "demo"
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "demo"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage in GiB"
  type        = number
  default     = 20
}
