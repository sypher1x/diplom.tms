output "server_ip" {
  description = "Public IPv4 of the server"
  value       = hcloud_server.app.ipv4_address
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.app.id
}
