---
display_name: USB/IP
description: Attach remote USB devices to a Coder workspace, or export workspace USB devices to remote hosts, via USB/IP.
icon: ../../../../.icons/usb.svg
verified: false
tags: [usb, usbip, hardware, linux, networking]
---

# USB/IP

Bridge USB devices in or out of a Coder workspace using [USB/IP](https://docs.kernel.org/usb/usbip_protocol.html). The module installs the USB/IP userspace tools (`usbip`, `usbipd`), loads the right kernel module for the chosen role, and optionally attaches or exports configured devices on workspace start.

It supports three modes:

- `client` (default): load `vhci-hcd` and attach remote USB devices from another host.
- `server`: load `usbip-host`, start `usbipd`, and bind local devices for remote attachment.
- `both`: enable client and server on the same workspace.

```tf
module "usbip" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/developmentcats/usbip/coder"
  version  = "1.0.0"
  agent_id = coder_agent.main.id
}
```

## Attaching a remote device on start

Set `remote_host` and `bus_ids` to auto-attach when the workspace starts. The bus IDs are the IDs reported by `usbip list -r <host>` on the exporting side (e.g. `1-1.4`).

```tf
module "usbip" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/developmentcats/usbip/coder"
  version     = "1.0.0"
  agent_id    = coder_agent.main.id
  mode        = "client"
  remote_host = "usbip-host.lan"
  bus_ids     = ["1-1.4"]
}
```

If `remote_host` is set but `bus_ids` is empty, the startup script runs `usbip list -r <host>` and writes the available devices to the log so you can pick a bus ID and re-attach manually.

## Exporting workspace devices

```tf
module "usbip" {
  count        = data.coder_workspace.me.start_count
  source       = "registry.coder.com/developmentcats/usbip/coder"
  version      = "1.0.0"
  agent_id     = coder_agent.main.id
  mode         = "server"
  bind_bus_ids = ["2-1"]
}
```

## Skipping package install

If your workspace image already ships `usbip`/`usbipd`, set `install_packages = false` to avoid the install step.

```tf
module "usbip" {
  count            = data.coder_workspace.me.start_count
  source           = "registry.coder.com/developmentcats/usbip/coder"
  version          = "1.0.0"
  agent_id         = coder_agent.main.id
  install_packages = false
}
```

> [!IMPORTANT]
> USB/IP is a Linux-kernel feature. The workspace must be able to load the `vhci-hcd` (client) or `usbip-host` (server) kernel modules, which usually requires a privileged container, a VM-backed workspace, or a bare-metal agent. If `modprobe` fails the script logs a warning and continues so the rest of workspace startup is not blocked; attach/bind operations will then fail at runtime until the kernel modules are available.

> [!NOTE]
> On Debian and Ubuntu the `usbip` binary is shipped in `linux-tools-$(uname -r)`. On kernels where that package does not exist, the module falls back to `linux-tools-generic`. You may need to add `/usr/lib/linux-tools/<kver>/` to `PATH` for the CLI to resolve.

> [!TIP]
> To bridge a Windows host's USB devices into a workspace, run [`usbipd-win`](https://github.com/dorssel/usbipd-win) on the Windows side as the server, and use `mode = "client"` here.

Logs are written to `/tmp/usbip.log` by default; override with `log_path`.
