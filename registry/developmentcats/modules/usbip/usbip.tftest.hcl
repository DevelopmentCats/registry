run "required_variables" {
  command = plan

  variables {
    agent_id = "test-agent-id"
  }

  assert {
    condition     = var.agent_id == "test-agent-id"
    error_message = "agent_id should be set"
  }

  assert {
    condition     = var.mode == "client"
    error_message = "mode should default to client"
  }

  assert {
    condition     = var.remote_port == 3240
    error_message = "remote_port should default to 3240"
  }

  assert {
    condition     = var.server_port == 3240
    error_message = "server_port should default to 3240"
  }

  assert {
    condition     = var.install_packages == true
    error_message = "install_packages should default to true"
  }
}

run "server_mode" {
  command = plan

  variables {
    agent_id     = "test-agent-id"
    mode         = "server"
    bind_bus_ids = ["1-1", "2-1.4"]
    server_port  = 3241
  }

  assert {
    condition     = var.mode == "server"
    error_message = "mode should be server"
  }

  assert {
    condition     = length(var.bind_bus_ids) == 2
    error_message = "bind_bus_ids should accept multiple entries"
  }
}

run "client_with_remote" {
  command = plan

  variables {
    agent_id    = "test-agent-id"
    mode        = "client"
    remote_host = "usbip.example.com"
    bus_ids     = ["1-1.4"]
  }

  assert {
    condition     = var.remote_host == "usbip.example.com"
    error_message = "remote_host should propagate"
  }

  assert {
    condition     = length(var.bus_ids) == 1 && var.bus_ids[0] == "1-1.4"
    error_message = "bus_ids should propagate"
  }
}

run "both_mode" {
  command = plan

  variables {
    agent_id     = "test-agent-id"
    mode         = "both"
    remote_host  = "usbip.example.com"
    bus_ids      = ["1-1.4"]
    bind_bus_ids = ["2-1"]
  }

  assert {
    condition     = var.mode == "both"
    error_message = "mode should be both"
  }
}

run "invalid_mode_rejected" {
  command = plan

  variables {
    agent_id = "test-agent-id"
    mode     = "nope"
  }

  expect_failures = [
    var.mode,
  ]
}

run "script_resource_uses_run_sh" {
  command = plan

  variables {
    agent_id    = "test-agent-id"
    mode        = "client"
    remote_host = "usbip.example.com"
    bus_ids     = ["1-1.4", "1-1.5"]
  }

  assert {
    condition     = resource.coder_script.usbip.display_name == "USB/IP"
    error_message = "coder_script display_name should be USB/IP"
  }

  assert {
    condition     = resource.coder_script.usbip.icon == "/icon/usb.svg"
    error_message = "coder_script icon should be /icon/usb.svg"
  }

  assert {
    condition     = resource.coder_script.usbip.run_on_start == true
    error_message = "script should run on start"
  }

  assert {
    condition     = length(regexall("MODE=\"client\"", resource.coder_script.usbip.script)) == 1
    error_message = "script should render MODE=client"
  }

  assert {
    condition     = length(regexall("REMOTE_HOST=\"usbip.example.com\"", resource.coder_script.usbip.script)) == 1
    error_message = "script should render remote_host"
  }

  assert {
    condition     = length(regexall("BUS_IDS=\"1-1.4 1-1.5\"", resource.coder_script.usbip.script)) == 1
    error_message = "script should join bus_ids with spaces"
  }
}
