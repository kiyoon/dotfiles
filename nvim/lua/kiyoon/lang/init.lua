-- check environment variable

local M = {}

local lang_env = os.getenv("LANG")

if lang_env == nil then
  M.lang = "en"
else
  if vim.startswith(lang_env, "es") then
    M.lang = "es"
  elseif vim.startswith(lang_env, "fr") then
    M.lang = "fr"
  elseif vim.startswith(lang_env, "pt_BR") then
    M.lang = "pt-br"
  elseif vim.startswith(lang_env, "pt_PT") then
    M.lang = "pt-pt"
  elseif vim.startswith(lang_env, "it") then
    M.lang = "it"
  elseif vim.startswith(lang_env, "de") then
    M.lang = "de"
  elseif vim.startswith(lang_env, "ru") then
    M.lang = "ru"
  else
    M.lang = "en"
  end
end

return M
