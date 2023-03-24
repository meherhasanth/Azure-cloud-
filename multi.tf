
provider "azurerm" {
    features {
      resource_group {
      prevent_deletion_if_contains_resources = true
    }
    }
  
}


resource "azurerm_resource_group" "MeherTest" {
  name     = "Meher"
  location = "West Europe"
}

resource "azurerm_virtual_network" "VN" {
  name                = "meher-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.MeherTest.location
  resource_group_name = azurerm_resource_group.MeherTest.name
}

resource "azurerm_subnet" "meherh-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.MeherTest.name
  virtual_network_name = azurerm_virtual_network.VN.name
  address_prefixes     = ["10.0.2.0/24"]


}
resource "azurerm_public_ip" "pubip" {
  count = 3
  name                         = "pubip.${count.index}"
  location                     = azurerm_resource_group.MeherTest.location
  resource_group_name          = azurerm_resource_group.MeherTest.name
  idle_timeout_in_minutes      = 30
  allocation_method            = "Static"

}

resource "azurerm_network_interface" "meher-nic" {
  count = 3
  name                = "meher-nic.${count.index}"
  location            = azurerm_resource_group.MeherTest.location
  resource_group_name = azurerm_resource_group.MeherTest.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.meherh-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubip.*.id[count.index]
  }
}

resource "azurerm_linux_virtual_machine" "HPC-test" {
  count = 3
  name                = "HPC-machine-${count.index}-rcac"
  resource_group_name = azurerm_resource_group.MeherTest.name
  location            = azurerm_resource_group.MeherTest.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.meher-nic.*.id[count.index]
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  
}
resource "azurerm_virtual_machine_extension" "example_extension" {
  count = 3
  name                 = "example_extension"
  virtual_machine_id   = azurerm_linux_virtual_machine.HPC-test.*.id[count.index]
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
        "commandToExecute": "hostnamectl set-hostname c00${count.index}.anvil.rcac.purdue.edu"
    }
SETTINGS
}