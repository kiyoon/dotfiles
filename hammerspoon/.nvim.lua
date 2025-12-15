require("kiyoon.lsp.patcher").patch_lsp_settings("lua_ls", function(settings)
  settings.Lua.diagnostics.globals = { "hs", "spoon" }

  if settings.Lua.workspace == nil then
    settings.Lua.workspace = {}
  end
  settings.Lua.workspace.library = {}

  local hs_root = vim.fn.expand("~/.config/hammerspoon")
  local spoons_dir = hs_root .. "/Spoons"

  local hammerspoon_emmpylua_annotations = hs_root .. spoons_dir .. "/EmmyLua.spoon/annotations"
  if vim.fn.isdirectory(hammerspoon_emmpylua_annotations) == 1 then
    table.insert(settings.Lua.workspace.library, hammerspoon_emmpylua_annotations)
  end

  --- Add Spoons to the workspace library
  -- runtime.path is what lua_ls uses to resolve `require(...)`
  settings.Lua.runtime = settings.Lua.runtime or {}
  settings.Lua.runtime.path = settings.Lua.runtime.path or vim.split(package.path, ";")

  -- Let lua_ls resolve plain requires in your main config too
  table.insert(settings.Lua.runtime.path, hs_root .. "/?.lua")
  table.insert(settings.Lua.runtime.path, hs_root .. "/?/init.lua")
  table.insert(settings.Lua.workspace.library, hs_root)

  -- Scan all spoons and add each spoon root to runtime.path + library
  local uv = vim.uv or vim.loop
  local handle = uv.fs_scandir(spoons_dir)
  if handle then
    while true do
      local name, t = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if t == "directory" and name:sub(-6) == ".spoon" then
        local root = spoons_dir .. "/" .. name
        table.insert(settings.Lua.runtime.path, root .. "/?.lua")
        table.insert(settings.Lua.runtime.path, root .. "/?/init.lua")
        table.insert(settings.Lua.workspace.library, root)
      end
    end
  end

  return settings
end)
