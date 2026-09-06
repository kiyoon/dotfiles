--- Run ~/.tmux/plugins/tmux-window-name/scripts/rename_session_windows.py on VimEnter and VimLeave
---   1. only if tmux-window-name plugin is installed,
---   2. using /usr/bin/python3, with libtmux installed by tmux/install-plugins.sh
local tmux_window_name_group = vim.api.nvim_create_augroup("tmux_window_name", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "VimLeave" }, {
  callback = function()
    local plugin_path = vim.env.TMUX_PLUGIN_MANAGER_PATH
    if not plugin_path then
      return
    end

    -- check if tmux-window-name is installed
    plugin_path = plugin_path .. "/tmux-window-name"
    if vim.fn.isdirectory(plugin_path) == 0 then
      return
    end

    local script = plugin_path .. "/scripts/rename_session_windows.py"
    local cmd = { "/usr/bin/python3", script }

    -- Run asynchronously so we don't block VimEnter/VimLeave
    vim.system(cmd, { text = true }, function(obj)
      -- obj: { code, signal, stdout, stderr }
      if obj.code ~= 0 then
        -- on_exit may be a "fast" callback, so schedule UI work
        vim.schedule(function()
          local err = obj.stderr
          if not err or err == "" then
            err = obj.stdout or ""
          end

          local msg =
            string.format("[tmux-window-name] command failed (code=%d, signal=%d)\n%s", obj.code, obj.signal, err)

          vim.notify(msg, vim.log.levels.ERROR, {
            title = "tmux-window-name",
          })
        end)
      end
    end)
  end,
  group = tmux_window_name_group,
})
