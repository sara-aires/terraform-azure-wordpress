provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "wordpress-rg"
  location = ""
}

resource "azurerm_virtual_network" "vnet" {
  name                = "wordpress-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "wordpress-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "wordpress-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "wordpress-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "wordpress-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B1s"

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "maquiv"
    admin_username = admin
    admin_password = admin
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "testing"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ${var.admin_username}",
      "curl -L \"docker-compose.yml",
      "chmod +x /usr/local/bin/docker-compose",
      "sudo mv /usr/local/bin/docker-compose /usr/bin/docker-compose",
      "mkdir /home/${var.admin_username}/wordpress",
      "sudo chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/wordpress",
      "echo '${file("docker-compose.yml")}' > /home/${var.admin_username}/wordpress/docker-compose.yml",
      "cd /home/${var.admin_username}/wordpress",
      "docker-compose up -d"
    ]

    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_public_ip.public_ip.ip_address
    }
  }
}

output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
