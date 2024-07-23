output "public_ip" {
  description = "172.168.0.1"
  value       = azurerm_public_ip.public_ip.ip_address
}
