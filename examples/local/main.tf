variable "port" {
  type    = number
  default = 2332
}

module "go" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  tools = { "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen" = "v2.8.1" }
}

output "go_home" {
  value = module.go.go_home
}
