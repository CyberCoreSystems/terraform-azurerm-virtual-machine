variable "location" {
  description = "Azure region to deploy the example VM into."
  type        = string
  default     = "eastus"
}

variable "allowed_source_cidr" {
  description = "Source CIDR allowed inbound to SSH. Set to your own admin/VPN CIDR — never 0.0.0.0/0 in production."
  type        = string
  default     = "203.0.113.10/32"
}

variable "admin_ssh_public_key" {
  description = <<-EOT
    OpenSSH public key for the admin user. Supply YOUR OWN:
    `terraform apply -var 'admin_ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)'`.

    The placeholder below is deliberately not a valid key, so an apply that
    forgets to override it fails immediately instead of succeeding. A real key
    here would build a VM whose admin account trusts whoever holds the matching
    private half — which is exactly what this default used to do.
  EOT
  type        = string
  default     = "ssh-ed25519 REPLACE_ME_WITH_YOUR_OWN_PUBLIC_KEY you@example.com"
}
