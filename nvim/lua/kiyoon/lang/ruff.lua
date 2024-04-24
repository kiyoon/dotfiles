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
  elseif code == "F501" then
    -- %-format string has invalid format string: {message}
    local mes = message:match "string has invalid format string: (.*)"
    return string.format("Cadena de formato %% tiene una cadena de formato inválida: %s", mes)
  elseif code == "F502" then
    return "Cadena de formato %% esperaba un mapeo pero obtuvo una secuencia"
  elseif code == "F503" then
    return "Cadena de formato %% esperaba una secuencia pero obtuvo un mapeo"
  elseif code == "F504" then
    -- %-format string has unused named argument(s): {message}
    local mes = message:match "string has unused named argument[(]s[)]: (.*)"
    return string.format("Cadena de formato %% tiene argumento(s) con nombre no usado: %s", mes)
  elseif code == "F505" then
    -- %-format string is missing argument(s) for placeholder(s): {message}
    local mes = message:match "string is missing argument[(]s[)] for placeholder[(]s[)]: (.*)"
    return string.format("Cadena de formato %% falta argumento(s) para marcador(es): %s", mes)
  elseif code == "F506" then
    return "Cadena de formato %% tiene marcadores posicionales y con nombre mezclados"
  elseif code == "F507" then
    -- %-format string has {wanted} placeholder(s) but {got} substitution(s)
    local wanted, got = message:match "string has ([0-9]+) placeholder[(]s[)] but ([0-9]+) substitution[(]s[)]"
    return string.format("Cadena de formato %% tiene %s marcador(es) pero %s sustitución(es)", wanted, got)
  elseif code == "F508" then
    return "Cadena de formato %% con especificador * requiere secuencia"
  elseif code == "F509" then
    -- %-format string has unsupported format character {char}
    local char = message:match "string has unsupported format character (.*)"
    return string.format("Cadena de formato %% tiene carácter de formato %s no soportado", char)

    -- F521	string-dot-format-invalid-format	.format call has invalid format string: {message}	✔️ 🛠️
    -- F522	string-dot-format-extra-named-arguments	.format call has unused named argument(s): {message}	✔️ 🛠️
    -- F523	string-dot-format-extra-positional-arguments	.format call has unused arguments at position(s): {message}	✔️ 🛠️
    -- F524	string-dot-format-missing-arguments	.format call is missing argument(s) for placeholder(s): {message}	✔️ 🛠️
    -- F525	string-dot-format-mixing-automatic	.format string mixes automatic and manual numbering	✔️ 🛠️
    -- F541	f-string-missing-placeholders	f-string without any placeholders	✔️ 🛠️
    -- F601	multi-value-repeated-key-literal	Dictionary key literal {name} repeated	✔️ 🛠️
    -- F602	multi-value-repeated-key-variable	Dictionary key {name} repeated	✔️ 🛠️
    -- F621	expressions-in-star-assignment	Too many expressions in star-unpacking assignment	✔️ 🛠️
    -- F622	multiple-starred-expressions	Two starred expressions in assignment	✔️ 🛠️
    -- F631	assert-tuple	Assert test is a non-empty tuple, which is always True	✔️ 🛠️
    -- F632	is-literal	Use == to compare constant literals	✔️ 🛠️
    -- F633	invalid-print-syntax	Use of >> is invalid with print function	✔️ 🛠️
    -- F634	if-tuple	If test is a tuple, which is always True	✔️ 🛠️
    -- F701	break-outside-loop	break outside loop	✔️ 🛠️
    -- F702	continue-outside-loop	continue not properly in loop	✔️ 🛠️
    -- F704	yield-outside-function	{keyword} statement outside of a function	✔️ 🛠️
    -- F706	return-outside-function	return statement outside of a function/method	✔️ 🛠️
    -- F707	default-except-not-last	An except block as not the last exception handler	✔️ 🛠️
    -- F722	forward-annotation-syntax-error	Syntax error in forward annotation: {body}	✔️ 🛠️
    -- F811	redefined-while-unused	Redefinition of unused {name} from {row}	✔️ 🛠️
    -- F821	undefined-name	Undefined name {name}	✔️ 🛠️
    -- F822	undefined-export	Undefined name {name} in __all__	✔️ 🛠️
    -- F823	undefined-local	Local variable {name} referenced before assignment	✔️ 🛠️
    -- F841	unused-variable	Local variable {name} is assigned to but never used	✔️ 🛠️
    -- F842	unused-annotation	Local variable {name} is annotated but never used	✔️ 🛠️
    -- F901	raise-not-implemented	raise NotImplemented should be raise NotImplementedError
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

  return message
end

return M
