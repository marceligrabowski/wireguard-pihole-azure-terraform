terraform {
  required_version = ">= 0.13"
  required_providers {
    azurerm = {
      version = ">= 2.37.0"
    }
  }
}
provider "azurerm" {
  features {}
}
module "regions" {
  source  = "claranet/regions/azurerm"
  version = "4.1.0"
  azure_region = "eu-west"
}