output "vm_id" {
  description = "Resource ID of the example VM."
  value       = module.vm.vm_id
}

output "public_ip" {
  description = "Public IP address of the example VM."
  value       = module.vm.public_ip
}

output "ssh_command" {
  description = "Ready-to-use SSH command for the example VM."
  value       = module.vm.ssh_command
}
