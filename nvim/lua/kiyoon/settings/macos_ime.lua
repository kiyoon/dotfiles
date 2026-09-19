--- Force the macOS input source to English when the `:` command line opens.
---
--- Korean inside nvim is typed with Korean-IME.nvim (<f12>), so the macOS input source
--- is meant to stay English here. Hammerspoon forces it when a terminal app is activated,
--- but that never fires while the terminal already has focus: switching tmux windows, or
--- pressing F18 in command mode (there Hammerspoon toggles the macOS IME on purpose),
--- leaves it in Korean and the next `:` types 한글 into the command line.
---
--- Calls Hammerspoon's forceDefaultEnglish() -- see hammerspoon/init.lua, exposed to
--- `hs -c` through hs.ipc. It respects DEFAULT_IME there, so Gureum/PriType/Ongeul all work.
--- F18 in command mode still switches to Korean, so `:s/한글/.../` stays possible.
---
--- Only for an nvim running locally on macOS: over ssh the keys are typed on the *client*,
--- so switching this machine's input source would be wrong (and there is no `hs` on Linux).

-- SSH_AUTH_SOCK/SSH_AGENT_PID are set by a local ssh-agent too, so they must not be used here.
local over_ssh = vim.env.SSH_TTY or vim.env.SSH_CONNECTION or vim.env.SSH_CLIENT
if vim.fn.has("mac") == 0 or over_ssh then
  return
end

local hs_bin = nil ---@type string? resolved on first use; "" when `hs` is not installed
local warned = false

local function force_english()
  if hs_bin == nil then
    hs_bin = vim.fn.exepath("hs")
  end
  if hs_bin == "" then
    return
  end

  -- Async on purpose: the IME converts keys before nvim ever sees the bytes, so blocking
  -- here would not protect the keystrokes typed during the switch -- it would only stall nvim.
  vim.system({ hs_bin, "-c", "forceDefaultEnglish()" }, { text = true }, function(obj)
    if obj.code == 0 or warned then
      return
    end
    -- Warn once per session (Hammerspoon not running / hs.ipc missing), never on every `:`.
    warned = true
    vim.schedule(function()
      vim.notify(
        ("[macos_ime] hs -c forceDefaultEnglish() failed (code=%d)\n%s"):format(obj.code, obj.stderr or ""),
        vim.log.levels.WARN
      )
    end)
  end)
end

-- Only the `:` command line. `/` and `?` are left alone so Korean text stays searchable.
vim.api.nvim_create_autocmd("CmdlineEnter", {
  pattern = ":",
  group = vim.api.nvim_create_augroup("macos_ime", { clear = true }),
  callback = force_english,
})
