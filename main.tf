# A general-purpose Linux VM on Azure, fully self-contained: it creates its own
# resource group, virtual network, subnet, NSG, NIC, optional public IP and the
# VM. One `tofu apply` => a running, SSH-reachable Linux VM; `tofu destroy`
# removes everything (including the resource group).
#
# Secure defaults:
# - SSH-key auth only; password authentication disabled.
# - NSG admits SSH (ssh_port) ONLY from allowed_source_cidr (a required input,
#   no 0.0.0.0/0 default), with an explicit catch-all DenyAllInbound.
# - System-assigned managed identity for least-privilege role grants, consumed by
#   workloads on the VM via the Azure Instance Metadata Service (IMDS).
# - OS disk encrypted at rest with platform-managed keys (always on in Azure);
#   optional host-based encryption via encryption_at_host_enabled.
# - Optional Trusted Launch (Secure Boot + vTPM) for capable VM sizes.

locals {
  resource_group_name = coalesce(var.resource_group_name, "rg-${var.name}")
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-${var.name}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  security_rule {
    name                       = "AllowSshInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.ssh_port)
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
    description                = "Inbound SSH permitted only from allowed_source_cidr."
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit default deny for all other inbound traffic."
  }
}

resource "azurerm_public_ip" "this" {
  count = var.create_public_ip ? 1 : 0

  name                = "pip-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.this[0].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# The same NSG is also associated at the subnet level (defense-in-depth): the
# SSH-only/deny-all rule set then covers any future NICs placed in this subnet,
# not just this VM's NIC. For this module's single NIC the effective policy is
# identical to the NIC-level association above.
resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "this" {
  # checkov:skip=CKV_AZURE_50: extension operations are a deliberate buyer knob via var.allow_extension_operations (default true — core platform tooling such as the Azure Monitor agent and AAD SSH login ships as VM extensions); set false for hardened images
  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Guest-extension operations (Azure Monitor agent, AAD SSH login, custom
  # script, ...). Set false to shrink the guest attack surface on hardened images.
  allow_extension_operations = var.allow_extension_operations

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  # Secure-by-default: SSH key only, no password authentication.
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # Optional first-boot bootstrap (base64-encoded as Azure requires). Null = none.
  custom_data = var.custom_data != null ? base64encode(var.custom_data) : null

  # Optional host-based encryption (off by default; needs the subscription
  # EncryptionAtHost feature + a supporting VM size).
  encryption_at_host_enabled = var.encryption_at_host_enabled

  # Optional Trusted Launch (off by default for broad size compatibility).
  secure_boot_enabled = var.secure_boot_enabled
  vtpm_enabled        = var.vtpm_enabled

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.source_image.publisher
    offer     = var.source_image.offer
    sku       = var.source_image.sku
    version   = var.source_image.version
  }

  tags = var.tags
}
