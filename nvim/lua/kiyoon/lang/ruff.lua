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
  elseif code == "F402" then
    -- message: Import {name} from {row} shadowed by loop variable
    local name, row = message:match "Import ([^ ]+) from line ([0-9]+) shadowed by loop variable"
    return string.format("Importación de %s desde la línea %s sombreada por variable de bucle", name, row)
  elseif code == "F403" then
    -- message = `from {name} import *` used; unable to detect undefined names
    local name = message:match "from ([^ ]+) import"
    return string.format("`from %s import *` usado; incapaz de detectar nombres indefinido", name)
  elseif code == "F404" then
    -- `from __future__` imports must occur at the beginning of the file
    return "Las importaciones de `from __future__` deben ocurrir al principio del archivo"
  elseif code == "F405" then
    -- {name} may be undefined, or defined from star imports
    local name = message:match "([^ ]+) may be undefined"
    return string.format("%s puede ser indefinido, o definido desde importaciones de estrella", name)
  elseif code == "F406" then
    -- from {name} import * only allowed at module level
    local name = message:match "from ([^ ]+) import"
    return string.format("`from %s import *` solo permitido a nivel de módulo", name)
  elseif code == "F407" then
    -- Future feature {name} is not defined
    local name = message:match "Future feature ([^ ]+) is not defined"
    return string.format("La característica futura %s no está definida", name)

  -- E713	not-in-test	Test for membership should be not in	✔️ 🛠️
  -- E714	not-is-test	Test for object identity should be is not	✔️ 🛠️
  -- E721	type-comparison	Do not compare types, use isinstance()	✔️ 🛠️
  -- E722	bare-except	Do not use bare except	✔️ 🛠️
  -- E731	lambda-assignment	Do not assign a lambda expression, use a def	✔️ 🛠️
  -- E741	ambiguous-variable-name	Ambiguous variable name: {name}	✔️ 🛠️
  -- E742	ambiguous-class-name	Ambiguous class name: {name}	✔️ 🛠️
  -- E743	ambiguous-function-name	Ambiguous function name: {name}	✔️ 🛠️
  -- E902	io-error	{message}	✔️ 🛠️
  -- E999	syntax-error	SyntaxError: {message}
  elseif code == "E501" then
    local width, limit = message:match "Line too long %((%d+) > (%d+)%)"
    return string.format("Línea demasiado larga (%s > %s)", width, limit)
  elseif code == "E502" then
    return "Barra invertida redundante"
  elseif code == "E701" then
    return "Múltiples declaraciones en una línea (dos puntos)"
  elseif code == "E702" then
    return "Múltiples declaraciones en una línea (punto y coma)"
  elseif code == "E703" then
    return "La declaración termina con un punto y coma innecesario"
  elseif code == "E711" then
    return "Comparación a `None` debería ser `cond is None`"
  elseif code == "E712" then
    local cond = message:match "use `if (.*):` for truth checks"
    return string.format("Evita comparaciones de igualdad a `True`; usa `if %s:` para comprobaciones de verdad", cond)
  end

  return message
end

return M
