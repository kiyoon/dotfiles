-- check environment variable

M = {}

-- begins with "es-ES"
if string.match(os.getenv "LANG", "^es%-ES") then
  M.lang = "es"
else
  M.lang = "en"
end

return M
