output "go_home" {
  description = "GOROOT of the installed Go release on each host, by host name."
  value       = { for name in keys(var.hosts) : name => local.home }
}
