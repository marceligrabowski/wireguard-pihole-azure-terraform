resource "azurerm_resource_group" "current" {
  name     = format("%s-%s", local.prefix, "rg")
  location = module.regions.location_cli

  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }
}

resource "azurerm_virtual_network" "current" {
  name                = format("%s-%s", local.prefix, "vn")
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.current.location
  resource_group_name = azurerm_resource_group.current.name
  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }
}

resource "azurerm_subnet" "current" {
  name                 = format("%s-%s", local.prefix, "sub")
  resource_group_name  = azurerm_resource_group.current.name
  virtual_network_name = azurerm_virtual_network.current.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "current" {
  name                = format("%s-%s", local.prefix, "pip")
  location            = azurerm_resource_group.current.location
  resource_group_name = azurerm_resource_group.current.name
  allocation_method   = "Static"
  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }
}

resource "azurerm_network_security_group" "current" {
  name                = format("%s-%s", local.prefix, "nsg")
  location            = azurerm_resource_group.current.location
  resource_group_name = azurerm_resource_group.current.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "6537"
    direction                  = "Inbound"
    priority                   = 1002
    protocol                   = "udp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    name                       = "vpn-inbound"
  }

  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }
}

output "public-ip" {
  value = azurerm_public_ip.current.ip_address
}

resource "azurerm_network_interface" "current" {
  name                = format("%s-%s", local.prefix, "nif")
  location            = azurerm_resource_group.current.location
  resource_group_name = azurerm_resource_group.current.name

  ip_configuration {
    name                          = format("%s-%s", local.prefix, "nif-conf")
    subnet_id                     = azurerm_subnet.current.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.current.id
  }

  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "current" {
  network_interface_id      = azurerm_network_interface.current.id
  network_security_group_id = azurerm_network_security_group.current.id
}

resource "azurerm_storage_account" "current" {
  name                     = replace(format("%s-%s", local.prefix, "stg"), "-", "")
  resource_group_name      = azurerm_resource_group.current.name
  location                 = azurerm_resource_group.current.location
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }
}

resource "tls_private_key" "current" {
  algorithm = "RSA"
  rsa_bits  = 4096
  provisioner "local-exec" {
    command = "echo '${tls_private_key.current.private_key_pem}' > '${var.private_key_file}' && chmod 600 '${var.private_key_file}'"
  }
}

resource "azurerm_linux_virtual_machine" "current" {
  name                  = format("%s-%s", local.prefix, "vm")
  location              = azurerm_resource_group.current.location
  resource_group_name   = azurerm_resource_group.current.name
  network_interface_ids = [azurerm_network_interface.current.id]
  size                  = "Standard_B1LS"

  os_disk {
    name                 = format("%s-%s", local.prefix, "dsk")
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = format("%s-%s", local.prefix, "vm")
  admin_username                  = var.username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.current.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.current.primary_blob_endpoint
  }

  tags = {
    environment = var.environment
    customer    = var.customer_abbrevation
    service     = var.service_name
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = azurerm_public_ip.current.ip_address
      type        = "ssh"
      user        = var.username
      private_key = file(var.private_key_file)
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.username} -i '${azurerm_public_ip.current.ip_address},' --private-key ${var.private_key_file} --extra-vars 'username=${var.username}' ../ansible/install-pivpn.yml"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.username} -i '${azurerm_public_ip.current.ip_address},' --private-key ${var.private_key_file} --extra-vars 'password=${var.pihole_password}' ../ansible/install-pihole.yml"
  }
}