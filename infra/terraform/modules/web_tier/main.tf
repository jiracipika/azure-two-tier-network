# Public web tier: Standard Load Balancer fronting N Nginx VMs in the web
# subnet. VM NICs have NO public IP addresses — inbound client traffic arrives
# only through the load-balanced port 80, and egress flows through the NAT
# gateway (see modules/hub_network).

locals {
  nginx_cloud_init = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /var/www/html/index.html
        permissions: '0644'
        content: |
          <html><body><h1>web-two-tier nginx</h1></body></html>
    runcmd:
      - systemctl enable --now nginx
  EOT
}

# --- Load balancer -----------------------------------------------------------

resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-web"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "two-tier-web"
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "lb-web"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "fe-web"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "be-web"
  loadbalancer_id = azurerm_lb.this.id
}

# Health probe: HTTP GET / every 15s; 2 failures remove a VM from rotation.
resource "azurerm_lb_probe" "http" {
  name                = "probe-http"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# Client routing rule: Internet :80 -> backend pool :80 (valid web path).
resource "azurerm_lb_rule" "http" {
  name                           = "rule-http-80"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fe-web"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  idle_timeout_in_minutes        = 4
  tcp_reset_enabled              = true
}

# --- Nginx VMs ----------------------------------------------------------------

resource "azurerm_network_interface" "web" {
  count               = var.web_vm_count
  name                = "nic-web-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig-web"
    subnet_id                     = var.web_subnet_id
    private_ip_address_allocation = "Dynamic"
    # No public_ip_address_id: workload NICs are private; the LB owns the
    # public endpoint and the NAT gateway owns outbound.
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  count                 = var.web_vm_count
  name                  = "vm-web-${count.index}"
  computer_name         = "vm-web-${count.index}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web[count.index].id]
  custom_data           = base64encode(local.nginx_cloud_init)
  tags                  = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # Security invariant: SSH-key authentication only.
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

  depends_on = [azurerm_lb_rule.http]
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count                   = var.web_vm_count
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "ipconfig-web"
}
