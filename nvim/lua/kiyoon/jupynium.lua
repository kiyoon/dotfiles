local status_ok, jupynium = pcall(require, "jupynium")
if not status_ok then
  return
end

jupynium.setup {
  python_host = { "conda", "run", "--no-capture-output", "-n", "jupynium", "python" },
  -- jupyter_command = "~/bin/miniconda3/bin/jupyter",
  jupyter_command = { "conda", "run", "--no-capture-output", "-n", "base", "jupyter" },

  -- Open the Jupynium server if it is not already running
  -- which means that it will open the Selenium browser when you open this file.
  -- Related command :JupyniumStartAndAttachToServer
  auto_start_server = {
    enable = false,
    file_pattern = { "*.ju.*" },
  },

  -- Attach current nvim to the Jupynium server
  -- Without this step, you can't use :JupyniumStartSync
  -- Related command :JupyniumAttachToServer
  auto_attach_to_server = {
    enable = true,
    file_pattern = { "*.ju.*" },
  },

  -- Automatically open an Untitled.ipynb file on Notebook
  -- when you open a .ju.py file on nvim.
  -- Related command :JupyniumStartSync
  auto_start_sync = {
    enable = false,
    file_pattern = { "*.ju.*" },
  },

  auto_close_tab = true,
}
