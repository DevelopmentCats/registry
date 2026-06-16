terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.5"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "mode" {
  type        = string
  description = "USB/IP mode. 'client' attaches remote USB devices into the workspace (loads vhci-hcd). 'server' exports the workspace's USB devices to remote hosts (loads usbip-host and starts usbipd). 'both' enables both sides."
  default     = "client"

  validation {
    condition     = contains(["client", "server", "both"], var.mode)
    error_message = "mode must be one of: client, server, both."
  }
}

variable "remote_host" {
  type        = string
  description = "When mode is 'client' or 'both', the remote USB/IP host to attach from on workspace start. Leave empty to skip auto-attach and let the user run `usbip attach` manually."
  default     = ""
}

variable "remote_port" {
  type        = number
  description = "TCP port of the remote USB/IP daemon (usbipd) to connect to. Defaults to the USB/IP standard 3240."
  default     = 3240
}

variable "bus_ids" {
  type        = list(string)
  description = "When mode is 'client' or 'both' and remote_host is set, the list of remote bus IDs (e.g. \"1-1.4\") to attach on workspace start."
  default     = []
}

variable "server_port" {
  type        = number
  description = "When mode is 'server' or 'both', the TCP port usbipd listens on. Defaults to 3240."
  default     = 3240
}

variable "bind_bus_ids" {
  type        = list(string)
  description = "When mode is 'server' or 'both', local bus IDs to bind and export via usbipd on startup. Devices can also be bound manually with `usbip bind -b <busid>`."
  default     = []
}

variable "install_packages" {
  type        = bool
  description = "Attempt to install USB/IP userspace tools via the detected system package manager. Set to false if the tools are baked into the image."
  default     = true
}

variable "log_path" {
  type        = string
  description = "Path to the module log file inside the workspace."
  default     = "/tmp/usbip.log"
}

variable "order" {
  type        = number
  description = "The order determines the position of the script in the UI. The lowest order is shown first."
  default     = null
}

resource "coder_script" "usbip" {
  agent_id     = var.agent_id
  display_name = "USB/IP"
  icon         = "/icon/usb.svg"
  script = templatefile("${path.module}/run.sh", {
    MODE             = var.mode
    REMOTE_HOST      = var.remote_host
    REMOTE_PORT      = tostring(var.remote_port)
    BUS_IDS          = join(" ", var.bus_ids)
    SERVER_PORT      = tostring(var.server_port)
    BIND_BUS_IDS     = join(" ", var.bind_bus_ids)
    INSTALL_PACKAGES = tostring(var.install_packages)
    LOG_PATH         = var.log_path
  })
  run_on_start       = true
  run_on_stop        = false
  start_blocks_login = false
}
