locals {
  environment_abb = substr(var.environment, 0, 1)
  prefix = "${var.customer_abbrevation}-${local.environment_abb}-${module.regions.location_short}-${var.service_name_abbrevation}"
}