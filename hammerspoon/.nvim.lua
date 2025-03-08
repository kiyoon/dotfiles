require("kiyoon.lsp.patcher").patch_lsp_settings("lua_ls", function(settings)
	settings.Lua.diagnostics.globals = { "hs", "spoon" }

	if settings.Lua.workspace == nil then
		settings.Lua.workspace = {}
	end
	settings.Lua.workspace.library = {}

	local hammerspoon_emmpylua_annotations = vim.fn.expand("~/.config/hammerspoon/Spoons/EmmyLua.spoon/annotations")
	if vim.fn.isdirectory(hammerspoon_emmpylua_annotations) == 1 then
		table.insert(settings.Lua.workspace.library, hammerspoon_emmpylua_annotations)
	end

	return settings
end)
