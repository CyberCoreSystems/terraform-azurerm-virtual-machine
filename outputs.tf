output "vm_id" {
  description = "Resource ID of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "public_ip" {
  description = "Public IP address of the VM (null when create_public_ip = false)."
  value       = var.create_public_ip ? azurerm_public_ip.this[0].ip_address : null
}

output "private_ip" {
  description = "Private IP address of the VM NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "ssh_command" {
  description = "Ready-to-use SSH command (uses the public IP when present, otherwise the private IP reachable via bastion/VPN)."
  value       = "ssh -p ${var.ssh_port} ${var.admin_username}@${var.create_public_ip ? azurerm_public_ip.this[0].ip_address : azurerm_network_interface.this.private_ip_address}"
}

output "nsg_id" {
  description = "Resource ID of the network security group guarding the VM."
  value       = azurerm_network_security_group.this.id
}

output "resource_group_name" {
  description = "Name of the resource group this module created."
  value       = azurerm_resource_group.this.name
}

output "identity_principal_id" {
  description = "Principal ID of the VM's system-assigned managed identity (grant it least-privilege roles as needed)."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
