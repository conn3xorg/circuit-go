variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "go_version" {
  type        = string
  default     = "1.27.4"
  description = "Go release to install, such as \"1.27.4\". Change checksums with it."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.go_version))
    error_message = "go_version must look like \"1.27.4\", without a leading go."
  }
}

variable "checksums" {
  type        = map(string)
  description = "SHA-256 of the linux-amd64 and linux-arm64 .tar.gz tarballs, from https://go.dev/dl/. Change these with go_version."
  default = {
    amd64 = "7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840"
    arm64 = "3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92"
  }

  validation {
    condition     = alltrue([for c in values(var.checksums) : can(regex("^[0-9a-f]{64}$", c))])
    error_message = "Each of checksums must be a SHA-256 in lowercase hex."
  }
}

variable "tools" {
  type        = map(string)
  default     = {}
  description = "Commands to build with go install into /usr/local/bin, by package path, each at an exact version, such as { \"github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen\" = \"v2.8.1\" }."

  validation {
    condition     = alltrue([for path in keys(var.tools) : can(regex("^[A-Za-z0-9][A-Za-z0-9._~/-]*$", path))])
    error_message = "Each key of tools must be a Go package path, such as \"golang.org/x/tools/cmd/stringer\"."
  }

  validation {
    condition     = alltrue([for v in values(var.tools) : can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+([-+][0-9A-Za-z.+-]+)?$", v))])
    error_message = "Each version in tools must be exact, such as \"v2.8.1\", not latest or a range."
  }
}
