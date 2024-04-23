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

  if code == "F405" then
    -- {name} may be undefined, or defined from star imports
    local name = message:match "([^ ]+) may be undefined"
    return string.format("%s puede ser indefinido, o definido desde importaciones de estrella", name)
  end

  if code == "F406" then
    -- from {name} import * only allowed at module level
    local name = message:match "from ([^ ]+) import"
    return string.format("`from %s import *` solo permitido a nivel de módulo", name)
  end

  if code == "F407" then
    -- Future feature {name} is not defined
    local name = message:match "Future feature ([^ ]+) is not defined"
    return string.format("La característica futura %s no está definida", name)
  end

  return message
end

return M
