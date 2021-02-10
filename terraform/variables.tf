variable "private_key_file" {
  type    = string
  default = "private.key.pem"
}

variable "environment" {
  default = "prod"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Allowed values for environment are \"dev\", \"stage\", or \"prod\"."
  }
}

variable "customer_abbrevation" {
  default = "cst"
}

variable "service_name" {
  default = "Wireguard + PiHole"
}

variable "service_name_abbrevation" {
  default = "wgph"
}

variable "pihole_password" {
  default = "pihole_password"
}

variable "username" {
  default = "pihole_user"
}
