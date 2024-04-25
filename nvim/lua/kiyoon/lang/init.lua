-- check environment variable

M = {}

-- begins with "es"
if string.match(os.getenv "LANG", "^es") then
  M.lang = "es"
else
  M.lang = "en"
end

return M
