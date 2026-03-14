variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key in Hetzner account"
  type        = string
}

variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "diplom-app"
}
