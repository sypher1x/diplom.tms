terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }

  required_version = ">= 1.6"
}

provider "hcloud" {
  token = var.hcloud_token
}

# SSH key (must already exist in Hetzner account)
data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "hcloud_server" "app" {
  name        = var.server_name
  image       = "ubuntu-24.04"
  server_type = "cx22"
  location    = "hel1"
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  labels = {
    project = "diplom"
    env     = "production"
  }
}

resource "hcloud_firewall" "app" {
  name = "${var.server_name}-fw"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "app" {
  firewall_id = hcloud_firewall.app.id
  server_ids  = [hcloud_server.app.id]
}
