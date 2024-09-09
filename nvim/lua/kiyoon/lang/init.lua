-- check environment variable

M = {}

local lang_env = os.getenv "LANG"

if lang_env == nil then
  M.lang = "en"
else
  if vim.startswith(lang_env, "es") then
    M.lang = "es"
  elseif vim.startswith(lang_env, "fr") then
    M.lang = "fr"
  elseif vim.startswith(lang_env, "pt_BR") then
    M.lang = "pt-br"
  else
    M.lang = "en"
  end
end

return M
