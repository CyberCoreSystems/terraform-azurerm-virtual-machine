module "vm" {
  source = "../../"

  name     = "iacbazaar-vm"
  location = var.location

  # Lock SSH to your own CIDR — never 0.0.0.0/0 in production.
  allowed_source_cidr  = var.allowed_source_cidr
  admin_ssh_public_key = var.admin_ssh_public_key

  vm_size = "Standard_B1s"

  tags = {
    Environment = "example"
    ManagedBy   = "iac-bazaar"
  }
}
