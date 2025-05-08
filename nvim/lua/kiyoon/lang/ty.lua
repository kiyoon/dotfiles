local lang = require("kiyoon.lang").lang

local M = {}

---Ensure translations are always in the order: es, pt-br, and fr
---@param code string
---@param message string
---@return string
M.translate_ty_message = function(code, message)
  if lang ~= "en" then
    if code == "lint/style/noInferrableTypes" then
      -- 🔗 [lint/style/noInferrableTypes] This type annotation is trivially inferred from its initialization.
      if lang == "es" then
        return "Esta anotación de tipo es trivialmente inferida de su inicialización."
      elseif lang == "pt-br" then
        return "Esta anotação de tipo é trivialmente inferida de sua inicialização."
      elseif lang == "fr" then
        return "Cette annotation de type est trivialement inférée de son initialisation."
      elseif lang == "it" then
        return "Questa annotazione di tipo è trivialmente inferita dalla sua inizializzazione."
      end
    end
  end

  return message
end

return M
