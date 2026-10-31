# Facts give each host's architecture, which picks the release tarball.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = contains(keys(local.go_arch), self.arch)
      error_message = "Host ${each.key} is ${self.arch}. This circuit installs the linux-amd64 and linux-arm64 builds."
    }
  }
}

locals {
  go_arch = { x86_64 = "amd64", aarch64 = "arm64" }
  arch    = { for name in keys(var.hosts) : name => lookup(local.go_arch, data.conn3x_host.facts[name].arch, data.conn3x_host.facts[name].arch) }
  home    = "/opt/go/${var.go_version}/go"
}

circuit "go" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "tool" {
    for_each = ["curl", "tar", "gzip"]
    package {
      name = item.value
    }
  }

  step "dir" {
    for_each = ["/opt/go", "/opt/go/${var.go_version}"]
    directory {
      path = item.value
    }
  }

  # The download step keeps the tarball only if it matches the checksum.
  step "download" {
    download {
      url    = "https://go.dev/dl/go${var.go_version}.linux-${local.arch[each.key]}.tar.gz"
      sha256 = var.checksums[local.arch[each.key]]
      dest   = "/opt/go/go${var.go_version}.linux-${local.arch[each.key]}.tar.gz"
    }
  }

  step "unpack" {
    archive {
      src     = "/opt/go/go${var.go_version}.linux-${local.arch[each.key]}.tar.gz"
      dest    = "/opt/go/${var.go_version}"
      creates = "${local.home}/bin/go"
    }
  }

  step "link" {
    for_each = ["go", "gofmt"]
    link {
      path   = "/usr/local/bin/${item.value}"
      target = "${local.home}/bin/${item.value}"
    }
  }

  # GOTOOLCHAIN=local, because otherwise a tool's go.mod could fetch a newer
  # Go than the one you pinned to build itself. The command name is the last
  # path element, skipping a major version suffix such as /v2. The check reads
  # the Go release and the module version from the binary, so a new go_version
  # builds the tool again.
  step "tool_install" {
    for_each = var.tools
    command {
      command = "GOTOOLCHAIN=local GOBIN=/usr/local/bin /usr/local/bin/go install '${item.key}@${item.value}'"
      unless  = "b='/usr/local/bin/${regex("([^/]+)(/v[0-9]+)?$", item.key)[0]}'; [ \"$(/usr/local/bin/go version -m \"$b\" 2>/dev/null | head -n1)\" = \"$b: go${var.go_version}\" ] && /usr/local/bin/go version -m \"$b\" | grep -Eq '^[[:space:]]+mod[[:space:]]+[^[:space:]]+[[:space:]]+${item.value}([[:space:]]|$)'"
    }
  }
}
