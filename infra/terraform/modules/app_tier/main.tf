# Private app tier: a single API VM reachable ONLY from the web subnet
# (TCP/8080) and from the bastion subnet (SSH). It has no public IP, no load
# balancer, and no NSG rule admitting any other source.
locals {
  api_cloud_init = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /var/www/html/index.html
        permissions: '0644'
        content: |
          <html><body><h1>app-two-tier api</h1></body></html>
    runcmd:
      - sed -i 's/listen \[::\]:80 default_server;/listen [::\]:${var.app_port} default_server;/; s/listen 80 default_server;/listen ${var.app_port} default_server;/' /etc/nginx/sites-enabled/default
      - systemctl restart nginx
  EOT
}

resource "azurerm_network_interface" "app" {
  name                = "nic-app-0"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig-app"
    subnet_id                     = var.app_subnet_id
    private_ip_address_allocation = "Dynamic"
    # No public_ip_address_id: the app tier is and stays private.
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                  = "vm-app-0"
  computer_name         = "vm-app-0"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.app.id]
  custom_data           = base64encode(local.api_cloud_init)
  tags                  = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  disable_password_authentication = true

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
