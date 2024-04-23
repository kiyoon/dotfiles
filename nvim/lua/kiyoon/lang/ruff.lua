local lang = require("kiyoon.lang").lang

M = {}

M.translate_ruff_message = function(code, message)
  if lang ~= "es" then
    return message
  end

  if code == "F401" then
    local name = message:match "([^ ]+) imported but unused"
    return string.format(
      "%s importado pero nunca usado; considera usar `importlib.util.find_spec` para probar la disponibilidad",
      name
    )
  end

  if code == "F402" then
    -- message: Import {name} from {row} shadowed by loop variable
    local name, row = message:match "Import ([^ ]+) from line ([0-9]+) shadowed by loop variable"
    return string.format("Importación de %s desde la línea %s sombreada por variable de bucle", name, row)
  end

  if code == "F403" then
    -- message = `from {name} import *` used; unable to detect undefined names
    local name = message:match "from ([^ ]+) import"
    return string.format("`from %s import *` usado; incapaz de detectar nombres indefinido", name)
  end

  if code == "F404" then
    -- `from __future__` imports must occur at the beginning of the file
    return "Las importaciones de `from __future__` deben ocurrir al principio del archivo"
  end

  return message
end

return M
