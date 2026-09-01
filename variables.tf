variable "name" {
  description = "Base name for the deployment; prefixes the VM, NIC, NSG, public IP, VNet and (when derived) the resource group. Also used as the Linux computer name."
  type        = string
  default     = "linux-vm"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]$", var.name))
    error_message = "name must be 2-32 chars: lowercase letters, digits and hyphens; start and end alphanumeric (keeps the Linux computer name valid)."
  }
}

variable "location" {
  description = "Azure region for all resources (e.g. eastus, westeurope)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create. Null derives \"rg-<name>\". This module is self-contained and creates (and on destroy removes) this resource group."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the virtual network created for the VM."
  type        = list(string)
  default     = ["10.30.0.0/16"]

  validation {
    condition     = length(var.vnet_address_space) > 0
    error_message = "vnet_address_space must contain at least one CIDR block."
  }
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the subnet the VM NIC lives in (must fall within vnet_address_space)."
  type        = list(string)
  default     = ["10.30.1.0/24"]

  validation {
    condition     = length(var.subnet_address_prefixes) > 0
    error_message = "subnet_address_prefixes must contain at least one CIDR block."
  }
}

variable "allowed_source_cidr" {
  description = <<-EOT
    REQUIRED. Source CIDR permitted inbound to SSH (22). There is deliberately
    NO default — set it to your office / VPN / admin CIDR (e.g.
    "203.0.113.10/32"). Avoid "0.0.0.0/0" outside of short-lived throwaway
    tests.
  EOT
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_source_cidr))
    error_message = "allowed_source_cidr must be a valid IPv4 CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "create_public_ip" {
  description = "Attach a Standard static public IP to the VM so it is reachable from the internet (still gated by allowed_source_cidr). Set false to keep the VM private-only (reach it via bastion/VPN/private peering)."
  type        = bool
  default     = true
}

variable "ssh_port" {
  description = "TCP port SSH listens on (opened in the NSG from allowed_source_cidr). The OS sshd still defaults to 22 unless you reconfigure it via custom_data."
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "ssh_port must be between 1 and 65535."
  }
}

# -----------------------------------------------------------------------------
# Virtual machine
# -----------------------------------------------------------------------------

variable "vm_size" {
  description = "VM size. Standard_B1s is the cheapest burstable size for light/general-purpose workloads; bump to Standard_B2s / Standard_D2s_v5+ for real workloads."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Local admin username on the VM (SSH-key auth only; password auth is disabled)."
  type        = string
  default     = "azureuser"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.admin_username))
    error_message = "admin_username must be a valid Linux username (lowercase, starts with a letter/underscore)."
  }
}

variable "admin_ssh_public_key" {
  description = "REQUIRED. OpenSSH public key for the admin user (password auth is disabled, so this is the only way in). E.g. file(\"~/.ssh/id_ed25519.pub\")."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-) ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be an OpenSSH public key (starts with ssh-ed25519, ssh-rsa or ecdsa-sha2-)."
  }
}

variable "os_disk_type" {
  description = "Managed-disk SKU for the OS disk. StandardSSD_LRS is a cheap, durable default; Premium_LRS for production IOPS."
  type        = string
  default     = "StandardSSD_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "StandardSSD_ZRS", "Premium_ZRS"], var.os_disk_type)
    error_message = "os_disk_type must be a valid managed-disk SKU."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB (must be >= the image's minimum, typically 30)."
  type        = number
  default     = 32

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "os_disk_size_gb must be between 30 and 4095."
  }
}

variable "source_image" {
  description = "Marketplace image for the VM. Defaults to Ubuntu 22.04 LTS (Gen2)."
  type = object({
    publisher = optional(string, "Canonical")
    offer     = optional(string, "0001-com-ubuntu-server-jammy")
    sku       = optional(string, "22_04-lts-gen2")
    version   = optional(string, "latest")
  })
  default = {}
}

variable "encryption_at_host_enabled" {
  description = "Encrypt the VM's temp disk and OS/data disk caches on the host (in addition to the always-on at-rest disk encryption). Off by default because it requires the subscription-level EncryptionAtHost feature to be registered and a supporting VM size; enable for production where supported."
  type        = bool
  default     = false
}

variable "secure_boot_enabled" {
  description = "Enable UEFI Secure Boot (Trusted Launch). Off by default for broad VM-size compatibility (incl. the cheapest B1s); enable on a Trusted-Launch-capable size for production."
  type        = bool
  default     = false
}

variable "vtpm_enabled" {
  description = "Enable the virtual TPM (Trusted Launch). Off by default; enable together with secure_boot_enabled on a Trusted-Launch-capable size."
  type        = bool
  default     = false
}

variable "allow_extension_operations" {
  description = "Allow VM extension operations on the guest. On by default because core platform tooling (Azure Monitor agent, AAD SSH login, custom-script bootstrap) is delivered as VM extensions; set false to reduce the guest attack surface on hardened images."
  type        = bool
  default     = true
}

variable "custom_data" {
  description = "Optional bootstrap cloud-init / shell script run on first boot. Null means no bootstrap (a plain general-purpose VM). Provide raw (un-encoded) content; the module base64-encodes it."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
