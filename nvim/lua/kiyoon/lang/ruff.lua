local lang = require("kiyoon.lang").lang

M = {}

---Ensure translations are always in the order: es, pt-br, and fr
M.translate_ruff_message = function(code, message)
  if lang ~= "en" then
    if code == "F401" then
      local name = message:match "([^ ]+) imported but unused"
      if lang == "es" then
        return string.format(
          "%s importado pero nunca usado; considera usar `importlib.util.find_spec` para probar la disponibilidad",
          name
        )
      elseif lang == "pt-br" then
        return string.format(
          "%s importado mas nunca usado; considere usar `importlib.util.find_spec` para testar a disponibilidade",
          name
        )
      elseif lang == "fr" then
        return string.format(
          "%s importé mais jamais utilisé; considérez utiliser `importlib.util.find_spec` pour tester la disponibilité",
          name
        )
      end
    elseif code == "F402" then
      -- message: Import {name} from {row} shadowed by loop variable
      local name, row = message:match "Import ([^ ]+) from line ([0-9]+) shadowed by loop variable"
      if lang == "es" then
        return string.format("Importación de %s desde la línea %s sombreada por variable de bucle", name, row)
      elseif lang == "pt-br" then
        return string.format("Importação de %s da linha %s sombreada por variável de loop", name, row)
      elseif lang == "fr" then
        return string.format("Importation de %s depuis la ligne %s masquée par une variable de boucle", name, row)
      end
    elseif code == "F403" then
      -- message = `from {name} import *` used; unable to detect undefined names
      local name = message:match "from ([^ ]+) import"
      if lang == "es" then
        return string.format("`from %s import *` usado; incapaz de detectar nombres indefinido", name)
      elseif lang == "pt-br" then
        return string.format("`from %s import *` usado; incapaz de detectar nomes indefinidos", name)
      elseif lang == "fr" then
        return string.format("`from %s import *` utilisé; impossible de détecter les noms indéfinis", name)
      end
    elseif code == "F404" then
      -- `from __future__` imports must occur at the beginning of the file
      if lang == "es" then
        return "Las importaciones de `from __future__` deben ocurrir al principio del archivo"
      elseif lang == "pt-br" then
        return "As importações `from __future__` devem ocorrer no início do arquivo"
      elseif lang == "fr" then
        return "Les importations `from __future__` doivent se produire au début du fichier"
      end
    elseif code == "F405" then
      -- {name} may be undefined, or defined from star imports
      local name = message:match "([^ ]+) may be undefined"
      if lang == "es" then
        return string.format("%s puede ser indefinido, o definido desde importaciones de estrella", name)
      end
    elseif code == "F406" then
      -- from {name} import * only allowed at module level
      local name = message:match "from ([^ ]+) import"
      if lang == "es" then
        return string.format("`from %s import *` solo permitido a nivel de módulo", name)
      end
    elseif code == "F407" then
      -- Future feature {name} is not defined
      local name = message:match "Future feature ([^ ]+) is not defined"
      if lang == "es" then
        return string.format("La característica futura %s no está definida", name)
      end
    elseif code == "F501" then
      -- %-format string has invalid format string: {message}
      local mes = message:match "string has invalid format string: (.*)"
      if lang == "es" then
        return string.format("Cadena de formato %% tiene una cadena de formato inválida: %s", mes)
      end
    elseif code == "F502" then
      if lang == "es" then
        return "Cadena de formato %% esperaba un mapeo pero obtuvo una secuencia"
      end
    elseif code == "F503" then
      if lang == "es" then
        return "Cadena de formato %% esperaba una secuencia pero obtuvo un mapeo"
      end
    elseif code == "F504" then
      -- %-format string has unused named argument(s): {message}
      local mes = message:match "string has unused named argument[(]s[)]: (.*)"
      if lang == "es" then
        return string.format("Cadena de formato %% tiene argumento(s) con nombre no usado: %s", mes)
      end
    elseif code == "F505" then
      -- %-format string is missing argument(s) for placeholder(s): {message}
      local mes = message:match "string is missing argument[(]s[)] for placeholder[(]s[)]: (.*)"
      if lang == "es" then
        return string.format("Cadena de formato %% falta argumento(s) para marcador(es): %s", mes)
      end
    elseif code == "F506" then
      if lang == "es" then
        return "Cadena de formato %% tiene marcadores posicionales y con nombre mezclados"
      end
    elseif code == "F507" then
      -- %-format string has {wanted} placeholder(s) but {got} substitution(s)
      local wanted, got = message:match "string has ([0-9]+) placeholder[(]s[)] but ([0-9]+) substitution[(]s[)]"
      if lang == "es" then
        return string.format("Cadena de formato %% tiene %s marcador(es) pero %s sustitución(es)", wanted, got)
      end
    elseif code == "F508" then
      if lang == "es" then
        return "Cadena de formato %% con especificador * requiere secuencia"
      end
    elseif code == "F509" then
      -- %-format string has unsupported format character {char}
      local char = message:match "string has unsupported format character (.*)"
      if lang == "es" then
        return string.format("Cadena de formato %% tiene carácter de formato %s no soportado", char)
      end
    elseif code == "F521" then
      -- 🔗🐍 [F521]	string-dot-format-invalid-format	.format call has invalid format string: {message}	✔️ 🛠️
      local mes = message:match "call has invalid format string: (.*)"
      if lang == "es" then
        return string.format("`.format` tiene una cadena de formato inválida: %s", mes)
      end
    elseif code == "F522" then
      -- 🔗🐍 [F522]	string-dot-format-extra-named-arguments	.format call has unused named argument(s): {message}	✔️ 🛠️
      local mes = message:match "call has unused named argument[(]s[)]: (.*)"
      if lang == "es" then
        return string.format("`.format` tiene argumento(s) con nombre no usado: %s", mes)
      end
    elseif code == "F523" then
      -- 🔗🐍 [F523]	string-dot-format-extra-positional-arguments	.format call has unused arguments at position(s): {message}	✔️ 🛠️
      local mes = message:match "call has unused arguments at position[(]s[)]: (.*)"
      if lang == "es" then
        return string.format("`.format` tiene argumento(s) no usado en posición(es): %s", mes)
      end
    elseif code == "F524" then
      -- 🔗🐍 [F524]	string-dot-format-missing-arguments	.format call is missing argument(s) for placeholder(s): {message}	✔️ 🛠️
      local mes = message:match "call is missing argument[(]s[)] for placeholder[(]s[)]: (.*)"
      if lang == "es" then
        return string.format("`.format` falta argumento(s) para marcador(es): %s", mes)
      end
    elseif code == "F525" then
      -- 🔗🐍 [F525]	string-dot-format-mixing-automatic	.format string mixes automatic and manual numbering	✔️ 🛠️
      if lang == "es" then
        return "Cadena de formato `.format` mezcla numeración automática y manual"
      end
    elseif code == "F541" then
      -- 🔗🐍 [F541]	f-string-missing-placeholders	f-string without any placeholders	✔️ 🛠️
      if lang == "es" then
        return "f-cadena sin marcadores"
      elseif lang == "fr" then
        return "f-chaîne sans aucun marqueur"
      elseif lang == "pt-br" then
        return "f-string sem marcadores"
      end
    -- 🔗🐍 [F601]	multi-value-repeated-key-literal	Dictionary key literal {name} repeated	✔️ 🛠️
    -- 🔗🐍 [F602]	multi-value-repeated-key-variable	Dictionary key {name} repeated	✔️ 🛠️
    -- 🔗🐍 [F621]	expressions-in-star-assignment	Too many expressions in star-unpacking assignment	✔️ 🛠️
    -- 🔗🐍 [F622]	multiple-starred-expressions	Two starred expressions in assignment	✔️ 🛠️
    -- 🔗🐍 [F631]	assert-tuple	Assert test is a non-empty tuple, which is always True	✔️ 🛠️
    -- 🔗🐍 [F632]	is-literal	Use == to compare constant literals	✔️ 🛠️
    -- 🔗🐍 [F633]	invalid-print-syntax	Use of >> is invalid with print function	✔️ 🛠️
    -- 🔗🐍 [F634]	if-tuple	If test is a tuple, which is always True	✔️ 🛠️
    -- 🔗🐍 [F701]	break-outside-loop	break outside loop	✔️ 🛠️
    -- 🔗🐍 [F702]	continue-outside-loop	continue not properly in loop	✔️ 🛠️
    -- 🔗🐍 [F704]	yield-outside-function	{keyword} statement outside of a function	✔️ 🛠️
    -- 🔗🐍 [F706]	return-outside-function	return statement outside of a function/method	✔️ 🛠️
    -- 🔗🐍 [F707]	default-except-not-last	An except block as not the last exception handler	✔️ 🛠️
    -- 🔗🐍 [F722]	forward-annotation-syntax-error	Syntax error in forward annotation: {body}	✔️ 🛠️
    elseif code == "F811" then
      -- 🔗🐍 [F811]	redefined-while-unused	Redefinition of unused {name} from {row}	✔️ 🛠️
      local name, row = message:match "Redefinition of unused ([^ ]+) from line ([0-9]+)"
      if lang == "es" then
        return string.format("Redefinición de %s no usado desde la línea %s", name, row)
      end
    elseif code == "F821" then
      -- 🔗🐍 [F821]	undefined-name	Undefined name {name}	✔️ 🛠️
      local name = message:match "Undefined name ([^ ]+)"
      if lang == "es" then
        return string.format("Nombre %s indefinido", name)
      end
    elseif code == "F822" then
      -- 🔗🐍 [F822]	undefined-export	Undefined name {name} in __all__	✔️ 🛠️
      local name = message:match "Undefined name ([^ ]+) in"
      if lang == "es" then
        return string.format("Nombre %s indefinido en `__all__`", name)
      end
    elseif code == "F823" then
      -- 🔗🐍 [F823]	undefined-local	Local variable {name} referenced before assignment	✔️ 🛠️
      local name = message:match "Local variable ([^ ]+) referenced before assignment"
      if lang == "es" then
        return string.format("Variable local %s referenciada antes de asignación", name)
      end
    elseif code == "F841" then
      -- 🔗🐍 [F841]	unused-variable	Local variable {name} is assigned to but never used	✔️ 🛠️
      local name = message:match "Local variable ([^ ]+) is assigned to but never used"
      if lang == "es" then
        return string.format("Variable local %s asignada pero nunca usada", name)
      end
    elseif code == "F842" then
      -- 🔗🐍 [F842]	unused-annotation	Local variable {name} is annotated but never used	✔️ 🛠️
      local name = message:match "Local variable ([^ ]+) is annotated but never used"
      if lang == "es" then
        return string.format("Variable local %s anotada pero nunca usada", name)
      end
    elseif code == "F901" then
      -- 🔗🐍 [F901]	raise-not-implemented	raise NotImplemented should be raise NotImplementedError
      if lang == "es" then
        return "`raise NotImplemented` debería ser `raise NotImplementedError`"
      end
    -- 🔗🐍 [E101]	mixed-spaces-and-tabs	Indentation contains mixed spaces and tabs	✔️ 🛠️
    -- 🔗🐍 [E111]	indentation-with-invalid-multiple	Indentation is not a multiple of {indent_width}	🧪 🛠️
    -- 🔗🐍 [E112]	no-indented-block	Expected an indented block	🧪 🛠️
    -- 🔗🐍 [E113]	unexpected-indentation	Unexpected indentation	🧪 🛠️
    -- 🔗🐍 [E114]	indentation-with-invalid-multiple-comment	Indentation is not a multiple of {indent_width} (comment)	🧪 🛠️
    -- 🔗🐍 [E115]	no-indented-block-comment	Expected an indented block (comment)	🧪 🛠️
    -- 🔗🐍 [E116]	unexpected-indentation-comment	Unexpected indentation (comment)	🧪 🛠️
    -- 🔗🐍 [E117]	over-indented	Over-indented (comment)	🧪 🛠️
    -- 🔗🐍 [E201]	whitespace-after-open-bracket	Whitespace after '{symbol}'	🧪 🛠️
    -- 🔗🐍 [E202]	whitespace-before-close-bracket	Whitespace before '{symbol}'	🧪 🛠️
    -- 🔗🐍 [E203]	whitespace-before-punctuation	Whitespace before '{symbol}'	🧪 🛠️
    -- 🔗🐍 [E211]	whitespace-before-parameters	Whitespace before '{bracket}'	🧪 🛠️
    -- 🔗🐍 [E221]	multiple-spaces-before-operator	Multiple spaces before operator	🧪 🛠️
    -- 🔗🐍 [E222]	multiple-spaces-after-operator	Multiple spaces after operator	🧪 🛠️
    -- 🔗🐍 [E223]	tab-before-operator	Tab before operator	🧪 🛠️
    -- 🔗🐍 [E224]	tab-after-operator	Tab after operator	🧪 🛠️
    -- 🔗🐍 [E225]	missing-whitespace-around-operator	Missing whitespace around operator	🧪 🛠️
    -- 🔗🐍 [E226]	missing-whitespace-around-arithmetic-operator	Missing whitespace around arithmetic operator	🧪 🛠️
    -- 🔗🐍 [E227]	missing-whitespace-around-bitwise-or-shift-operator	Missing whitespace around bitwise or shift operator	🧪 🛠️
    -- 🔗🐍 [E228]	missing-whitespace-around-modulo-operator	Missing whitespace around modulo operator	🧪 🛠️
    -- 🔗🐍 [E231]	missing-whitespace	Missing whitespace after '{token}'	🧪 🛠️
    -- 🔗🐍 [E241]	multiple-spaces-after-comma	Multiple spaces after comma	🧪 🛠️
    -- 🔗🐍 [E242]	tab-after-comma	Tab after comma	🧪 🛠️
    -- 🔗🐍 [E251]	unexpected-spaces-around-keyword-parameter-equals	Unexpected spaces around keyword / parameter equals	🧪 🛠️
    -- 🔗🐍 [E252]	missing-whitespace-around-parameter-equals	Missing whitespace around parameter equals	🧪 🛠️
    -- 🔗🐍 [E261]	too-few-spaces-before-inline-comment	Insert at least two spaces before an inline comment	🧪 🛠️
    -- 🔗🐍 [E262]	no-space-after-inline-comment	Inline comment should start with #	🧪 🛠️
    -- 🔗🐍 [E265]	no-space-after-block-comment	Block comment should start with #	🧪 🛠️
    -- 🔗🐍 [E266]	multiple-leading-hashes-for-block-comment	Too many leading # before block comment	🧪 🛠️
    -- 🔗🐍 [E271]	multiple-spaces-after-keyword	Multiple spaces after keyword	🧪 🛠️
    -- 🔗🐍 [E272]	multiple-spaces-before-keyword	Multiple spaces before keyword	🧪 🛠️
    -- 🔗🐍 [E273]	tab-after-keyword	Tab after keyword	🧪 🛠️
    -- 🔗🐍 [E274]	tab-before-keyword	Tab before keyword	🧪 🛠️
    -- 🔗🐍 [E275]	missing-whitespace-after-keyword	Missing whitespace after keyword	🧪 🛠️
    -- 🔗🐍 [E301]	blank-line-between-methods	Expected {BLANK_LINES_NESTED_LEVEL:?} blank line, found 0	🧪 🛠️
    -- 🔗🐍 [E302]	blank-lines-top-level	Expected {expected_blank_lines:?} blank lines, found {actual_blank_lines}	🧪 🛠️
    -- 🔗🐍 [E303]	too-many-blank-lines	Too many blank lines ({actual_blank_lines})	🧪 🛠️
    -- 🔗🐍 [E304]	blank-line-after-decorator	Blank lines found after function decorator ({lines})	🧪 🛠️
    -- 🔗🐍 [E305]	blank-lines-after-function-or-class	Expected 2 blank lines after class or function definition, found ({blank_lines})	🧪 🛠️
    -- 🔗🐍 [E306]	blank-lines-before-nested-definition	Expected 1 blank line before a nested definition, found 0	🧪 🛠️
    -- 🔗🐍 [E401]	multiple-imports-on-one-line	Multiple imports on one line	✔️ 🛠️
    elseif code == "E401" then
      if lang == "es" then
        return "Múltiples importaciones en una línea"
      elseif lang == "pt-br" then
        return "Múltiplas importações em uma linha"
      elseif lang == "fr" then
        return "Importations multiples sur une ligne"
      end
    -- 🔗🐍 [E402]	module-import-not-at-top-of-file	Module level import not at top of cell	✔️ 🛠️
    elseif code == "E402" then
      if lang == "es" then
        return "Importación a nivel de módulo no al principio del archivo"
      elseif lang == "pt-br" then
        return "Importação de nível de módulo não no início do arquivo"
      elseif lang == "fr" then
        return "Importation de niveau de module pas au début du fichier"
      end
    elseif code == "E501" then
      local width, limit = message:match "Line too long %((%d+) > (%d+)%)"
      if lang == "es" then
        return string.format("Línea demasiado larga (%s > %s)", width, limit)
      elseif lang == "pt-br" then
        return string.format("Linha muito longa (%s > %s)", width, limit)
      elseif lang == "fr" then
        return string.format("Ligne trop longue (%s > %s)", width, limit)
      end
    elseif code == "E502" then
      if lang == "es" then
        return "Barra invertida redundante"
      end
    elseif code == "E701" then
      if lang == "es" then
        return "Múltiples declaraciones en una línea (dos puntos)"
      end
    elseif code == "E702" then
      if lang == "es" then
        return "Múltiples declaraciones en una línea (punto y coma)"
      end
    elseif code == "E703" then
      if lang == "es" then
        return "La declaración termina con un punto y coma innecesario"
      end
    elseif code == "E711" then
      if lang == "es" then
        return "Comparación a `None` debería ser `cond is None`"
      end
    elseif code == "E712" then
      local cond = message:match "use `if (.*):` for truth checks"
      if lang == "es" then
        return string.format(
          "Evita comparaciones de igualdad a `True`; usa `if %s:` para comprobaciones de verdad",
          cond
        )
      end
    elseif code == "E713" then
      -- 🔗🐍 [E713]	not-in-test	Test for membership should be not in	✔️ 🛠️
      if lang == "es" then
        return "Prueba de membresía debería ser `not in`"
      end
    elseif code == "E714" then
      -- 🔗🐍 [E714]	not-is-test	Test for object identity should be is not	✔️ 🛠️
      if lang == "es" then
        return "Prueba de identidad de objeto debería ser `is not`"
      end
    elseif code == "E721" then
      -- 🔗🐍 [E721]	type-comparison	Do not compare types, use isinstance()	✔️ 🛠️
      if lang == "es" then
        return "No compares tipos, usa `isinstance()`"
      end
    elseif code == "E722" then
      -- 🔗🐍 [E722]	bare-except	Do not use bare except	✔️ 🛠️
      if lang == "es" then
        return "No uses `except` sin especificar la excepción"
      end
    elseif code == "E731" then
      -- 🔗🐍 [E731]	lambda-assignment	Do not assign a lambda expression, use a def	✔️ 🛠️
      if lang == "es" then
        return "No asignes una expresión lambda, usa un `def`"
      end
    elseif code == "E741" then
      -- 🔗🐍 [E741]	ambiguous-variable-name	Ambiguous variable name: {name}	✔️ 🛠️
      local name = message:match "Ambiguous variable name: (.*)"
      if lang == "es" then
        return string.format("Nombre de variable ambiguo: %s", name)
      elseif lang == "fr" then
        return string.format("Nom de variable ambigu: %s", name)
      elseif lang == "pt-br" then
        return string.format("Nome de variável ambíguo: %s", name)
      end
    elseif code == "E742" then
      -- 🔗🐍 [E742]	ambiguous-class-name	Ambiguous class name: {name}	✔️ 🛠️
      local name = message:match "Ambiguous class name: (.*)"
      if lang == "es" then
        return string.format("Nombre de clase ambiguo: %s", name)
      end
    elseif code == "E743" then
      -- 🔗🐍 [E743]	ambiguous-function-name	Ambiguous function name: {name}	✔️ 🛠️
      local name = message:match "Ambiguous function name: (.*)"
      if lang == "es" then
        return string.format("Nombre de función ambiguo: %s", name)
      end
    -- 🔗🐍 [E902]	io-error	{message}	✔️ 🛠️
    -- 🔗🐍 [E999]	syntax-error	SyntaxError: {message}

    -- 🔗🐍 [W191]	tab-indentation	Indentation contains tabs	✔️ 🛠️
    -- 🔗🐍 [W291]	trailing-whitespace	Trailing whitespace	✔️ 🛠️
    -- 🔗🐍 [W292]	missing-newline-at-end-of-file	No newline at end of file	✔️ 🛠️
    -- 🔗🐍 [W293]	blank-line-with-whitespace	Blank line contains whitespace	✔️ 🛠️
    -- 🔗🐍 [W391]	too-many-newlines-at-end-of-file	Too many newlines at end of file	🧪 🛠️
    -- 🔗🐍 [W505]	doc-line-too-long	Doc line too long ({width} > {limit})	✔️ 🛠️
    -- 🔗🐍 [W605]	invalid-escape-sequence	Invalid escape sequence: \{ch}	✔️ 🛠️
    -- 🔗🐍 [C901]	complex-structure	{name} is too complex ({complexity} > {max_complexity})
    -- 🔗🐍 [I001]	unsorted-imports	Import block is un-sorted or un-formatted	✔️ 🛠️
    -- 🔗🐍 [I002]	missing-required-import	Missing required import: {name}	✔️ 🛠️
    -- 🔗🐍 [N801]	invalid-class-name	Class name {name} should use CapWords convention	✔️ 🛠️
    -- 🔗🐍 [N802]	invalid-function-name	Function name {name} should be lowercase	✔️ 🛠️
    -- 🔗🐍 [N803]	invalid-argument-name	Argument name {name} should be lowercase	✔️ 🛠️
    -- 🔗🐍 [N804]	invalid-first-argument-name-for-class-method	First argument of a class method should be named cls	✔️ 🛠️
    elseif code == "N804" then
      if lang == "es" then
        return "El primer argumento de un método debería llamarse `cls`"
      end
    -- 🔗🐍 [N805]	invalid-first-argument-name-for-method	First argument of a method should be named self	✔️ 🛠️
    elseif code == "N805" then
      if lang == "es" then
        return "El primer argumento de un método debería llamarse `self`"
      end
    -- 🔗🐍 [N806]	non-lowercase-variable-in-function	Variable {name} in function should be lowercase	✔️ 🛠️
    -- 🔗🐍 [N807]	dunder-function-name	Function name should not start and end with __	✔️ 🛠️
    -- 🔗🐍 [N811]	constant-imported-as-non-constant	Constant {name} imported as non-constant {asname}	✔️ 🛠️
    -- 🔗🐍 [N812]	lowercase-imported-as-non-lowercase	Lowercase {name} imported as non-lowercase {asname}	✔️ 🛠️
    -- 🔗🐍 [N813]	camelcase-imported-as-lowercase	Camelcase {name} imported as lowercase {asname}	✔️ 🛠️
    -- 🔗🐍 [N814]	camelcase-imported-as-constant	Camelcase {name} imported as constant {asname}	✔️ 🛠️
    -- 🔗🐍 [N815]	mixed-case-variable-in-class-scope	Variable {name} in class scope should not be mixedCase	✔️ 🛠️
    -- 🔗🐍 [N816]	mixed-case-variable-in-global-scope	Variable {name} in global scope should not be mixedCase	✔️ 🛠️
    -- 🔗🐍 [N817]	camelcase-imported-as-acronym	CamelCase {name} imported as acronym {asname}	✔️ 🛠️
    -- 🔗🐍 [N818]	error-suffix-on-exception-name	Exception name {name} should be named with an Error suffix	✔️ 🛠️
    -- 🔗🐍 [N999]	invalid-module-name	Invalid module name: '{name}'	✔️ 🛠️
    -- 🔗🐍 [D100]	undocumented-public-module	Missing docstring in public module	✔️ 🛠️
    -- 🔗🐍 [D101]	undocumented-public-class	Missing docstring in public class	✔️ 🛠️
    -- 🔗🐍 [D102]	undocumented-public-method	Missing docstring in public method	✔️ 🛠️
    -- 🔗🐍 [D103]	undocumented-public-function	Missing docstring in public function	✔️ 🛠️
    -- 🔗🐍 [D104]	undocumented-public-package	Missing docstring in public package	✔️ 🛠️
    -- 🔗🐍 [D105]	undocumented-magic-method	Missing docstring in magic method	✔️ 🛠️
    -- 🔗🐍 [D106]	undocumented-public-nested-class	Missing docstring in public nested class	✔️ 🛠️
    -- 🔗🐍 [D107]	undocumented-public-init	Missing docstring in __init__	✔️ 🛠️
    -- 🔗🐍 [D200]	fits-on-one-line	One-line docstring should fit on one line	✔️ 🛠️
    elseif code == "D200" then
      if lang == "es" then
        return "Docstring de una línea debería caber en una línea"
      end
    -- 🔗🐍 [D201]	no-blank-line-before-function	No blank lines allowed before function docstring (found {num_lines})	✔️ 🛠️
    elseif code == "D201" then
      local num_lines = message:match "No blank lines allowed before function docstring %(found ([0-9]+)%)"
      if lang == "es" then
        return string.format(
          "No se permiten líneas en blanco antes de la docstring de la función (encontrado %s)",
          num_lines
        )
      end
    -- 🔗🐍 [D202]	no-blank-line-after-function	No blank lines allowed after function docstring (found {num_lines})	✔️ 🛠️
    elseif code == "D202" then
      local num_lines = message:match "No blank lines allowed after function docstring %(found ([0-9]+)%)"
      if lang == "es" then
        return string.format(
          "No se permiten líneas en blanco después de la docstring de la función (encontrado %s)",
          num_lines
        )
      end
    -- 🔗🐍 [D203]	one-blank-line-before-class	1 blank line required before class docstring	✔️ 🛠️
    elseif code == "D203" then
      if lang == "es" then
        return "Se requiere 1 línea en blanco antes de la docstring de la clase"
      end
    -- 🔗🐍 [D204]	one-blank-line-after-class	1 blank line required after class docstring	✔️ 🛠️
    elseif code == "D204" then
      if lang == "es" then
        return "Se requiere 1 línea en blanco después de la docstring de la clase"
      end
    -- 🔗🐍 [D205]	blank-line-after-summary	1 blank line required between summary line and description	✔️ 🛠️
    elseif code == "D205" then
      if lang == "es" then
        return "Se requiere 1 línea en blanco entre la línea de resumen y la descripción"
      end
    -- 🔗🐍 [D206]	indent-with-spaces	Docstring should be indented with spaces, not tabs	✔️ 🛠️
    elseif code == "D206" then
      if lang == "es" then
        return "La docstring debería estar indentada con espacios, no con tabulaciones"
      end
    -- 🔗🐍 [D207]	under-indentation	Docstring is under-indented	✔️ 🛠️
    elseif code == "D207" then
      if lang == "es" then
        return "Docstring está sub-indentada"
      end
    -- 🔗🐍 [D208]	over-indentation	Docstring is over-indented	✔️ 🛠️
    elseif code == "D208" then
      if lang == "es" then
        return "Docstring está sobre-indentada"
      end
    -- 🔗🐍 [D209]	new-line-after-last-paragraph	Multi-line docstring closing quotes should be on a separate line	✔️ 🛠️
    elseif code == "D209" then
      if lang == "es" then
        return "Las comillas de cierre de la docstring de varias líneas deberían estar en una línea separada"
      end
    -- 🔗🐍 [D210]	surrounding-whitespace	No whitespaces allowed surrounding docstring text	✔️ 🛠️
    elseif code == "D210" then
      if lang == "es" then
        return "No se permiten espacios en blanco alrededor del texto de la docstring"
      end
    -- 🔗🐍 [D211]	blank-line-before-class	No blank lines allowed before class docstring	✔️ 🛠️
    elseif code == "D211" then
      if lang == "es" then
        return "No se permiten líneas en blanco antes de la docstring de la clase"
      end
    -- 🔗🐍 [D212]	multi-line-summary-first-line	Multi-line docstring summary should start at the first line	✔️ 🛠️
    elseif code == "D212" then
      if lang == "es" then
        return "El resumen de la docstring de varias líneas debería empezar en la primera línea"
      end
    -- 🔗🐍 [D213]	multi-line-summary-second-line	Multi-line docstring summary should start at the second line	✔️ 🛠️
    elseif code == "D213" then
      if lang == "es" then
        return "El resumen de la docstring de varias líneas debería empezar en la segunda línea"
      end
    -- 🔗🐍 [D214]	section-not-over-indented	Section is over-indented ("{name}")	✔️ 🛠️
    elseif code == "D214" then
      local name = message:match 'Section is over-indented %("(.*)"%)'
      if lang == "es" then
        return string.format("La sección está sobre-indentada (%s)", name)
      end
    -- 🔗🐍 [D215]	section-underline-not-over-indented	Section underline is over-indented ("{name}")	✔️ 🛠️
    elseif code == "D215" then
      local name = message:match 'Section underline is over-indented %("(.*)"%)'
      if lang == "es" then
        return string.format("La subrayado de la sección está sobre-indentado (%s)", name)
      end
    -- 🔗🐍 [D300]	triple-single-quotes	Use triple double quotes """	✔️ 🛠️
    elseif code == "D300" then
      if lang == "es" then
        return 'Usa comillas triples dobles `"""`'
      end
    -- 🔗🐍 [D301]	escape-sequence-in-docstring	Use r""" if any backslashes in a docstring	✔️ 🛠️
    elseif code == "D301" then
      if lang == "es" then
        return 'Usa `r"""` si hay barras invertidas en una docstring'
      end
    -- 🔗🐍 [D400]	ends-in-period	First line should end with a period	✔️ 🛠️
    elseif code == "D400" then
      if lang == "es" then
        return "La primera línea debería terminar con un punto"
      end
    -- 🔗🐍 [D401]	non-imperative-mood	First line of docstring should be in imperative mood: "{first_line}"	✔️ 🛠️
    elseif code == "D401" then
      local first_line = message:match 'First line of docstring should be in imperative mood: "(.*)"'
      if lang == "es" then
        return string.format('La primera línea de la docstring debería estar en modo imperativo: "%s"', first_line)
      end
    -- 🔗🐍 [D402]	no-signature	First line should not be the function's signature	✔️ 🛠️
    elseif code == "D402" then
      if lang == "es" then
        return "La primera línea no debería ser la firma de la función"
      end
    -- 🔗🐍 [D403]	first-line-capitalized	First word of the first line should be capitalized: {} -> {}	✔️ 🛠️
    elseif code == "D403" then
      local first_word, capitalized = message:match "First word of the first line should be capitalized: (.*) -> (.*)"
      if lang == "es" then
        return string.format(
          "La primera palabra de la primera línea debería estar capitalizada: %s -> %s",
          first_word,
          capitalized
        )
      end
    -- 🔗🐍 [D404]	docstring-starts-with-this	First word of the docstring should not be "This"	✔️ 🛠️
    elseif code == "D404" then
      if lang == "es" then
        return 'La primera palabra de la docstring no debería ser "This"'
      end
    -- 🔗🐍 [D405]	capitalize-section-name	Section name should be properly capitalized ("{name}")	✔️ 🛠️
    elseif code == "D405" then
      local name = message:match 'Section name should be properly capitalized %("(.*)"%)'
      if lang == "es" then
        return string.format("El nombre de la sección debería estar capitalizado correctamente (%s)", name)
      end
    -- 🔗🐍 [D406]	new-line-after-section-name	Section name should end with a newline ("{name}")	✔️ 🛠️
    elseif code == "D406" then
      local name = message:match 'Section name should end with a newline %("(.*)"%)'
      if lang == "es" then
        return string.format("El nombre de la sección debería terminar con una nueva línea (%s)", name)
      end
    -- 🔗🐍 [D407]	dashed-underline-after-section	Missing dashed underline after section ("{name}")	✔️ 🛠️
    elseif code == "D407" then
      local name = message:match 'Missing dashed underline after section %("(.*)"%)'
      if lang == "es" then
        return string.format("Falta subrayado punteado después de la sección (%s)", name)
      end
    -- 🔗🐍 [D408]	section-underline-after-name	Section underline should be in the line following the section's name ("{name}")	✔️ 🛠️
    elseif code == "D408" then
      local name = message:match 'Section underline should be in the line following the section\'s name %("(.*)"%)'
      if lang == "es" then
        return string.format(
          "El subrayado de la sección debería estar en la línea siguiente al nombre de la sección (%s)",
          name
        )
      end
    -- 🔗🐍 [D409]	section-underline-matches-section-length	Section underline should match the length of its name ("{name}")	✔️ 🛠️
    elseif code == "D409" then
      local name = message:match 'Section underline should match the length of its name %("(.*)"%)'
      if lang == "es" then
        return string.format("El subrayado de la sección debería coincidir con la longitud de su nombre (%s)", name)
      end
    -- 🔗🐍 [D410]	no-blank-line-after-section	Missing blank line after section ("{name}")	✔️ 🛠️
    elseif code == "D410" then
      local name = message:match 'Missing blank line after section %("(.*)"%)'
      if lang == "es" then
        return string.format("Falta línea en blanco después de la sección (%s)", name)
      end
    -- 🔗🐍 [D411]	no-blank-line-before-section	Missing blank line before section ("{name}")	✔️ 🛠️
    elseif code == "D411" then
      local name = message:match 'Missing blank line before section %("(.*)"%)'
      if lang == "es" then
        return string.format("Falta línea en blanco antes de la sección (%s)", name)
      end
    -- 🔗🐍 [D412]	blank-lines-between-header-and-content	No blank lines allowed between a section header and its content ("{name}")	✔️ 🛠️
    elseif code == "D412" then
      local name = message:match 'No blank lines allowed between a section header and its content %("(.*)"%)'
      if lang == "es" then
        return string.format(
          "No se permiten líneas en blanco entre un encabezado de sección y su contenido (%s)",
          name
        )
      end
    -- 🔗🐍 [D413]	blank-line-after-last-section	Missing blank line after last section ("{name}")	✔️ 🛠️
    elseif code == "D413" then
      local name = message:match 'Missing blank line after last section %("(.*)"%)'
      if lang == "es" then
        return string.format("Falta línea en blanco después de la última sección (%s)", name)
      end
    -- 🔗🐍 [D414]	empty-docstring-section	Section has no content ("{name}")	✔️ 🛠️
    elseif code == "D414" then
      local name = message:match 'Section has no content %("(.*)"%)'
      if lang == "es" then
        return string.format("La sección no tiene contenido (%s)", name)
      end
    -- 🔗🐍 [D415]	ends-in-punctuation	First line should end with a period, question mark, or exclamation point	✔️ 🛠️
    elseif code == "D415" then
      if lang == "es" then
        return "La primera línea debería terminar con un punto, signo de interrogación o signo de exclamación"
      end
    -- 🔗🐍 [D416]	section-name-ends-in-colon	Section name should end with a colon ("{name}")	✔️ 🛠️
    elseif code == "D416" then
      local name = message:match 'Section name should end with a colon %("(.*)"%)'
      if lang == "es" then
        return string.format("El nombre de la sección debería terminar con dos puntos (%s)", name)
      end
    -- 🔗🐍 [D417]	undocumented-param	Missing argument description in the docstring for {definition}: {name}	✔️ 🛠️
    elseif code == "D417" then
      local definition, name = message:match "Missing argument description in the docstring for ([^:]+): (.*)"
      if lang == "es" then
        return string.format("Descripción de argumento faltante en la docstring para %s: %s", definition, name)
      end
    -- 🔗🐍 [D418]	overload-with-docstring	Function decorated with @overload shouldn't contain a docstring	✔️ 🛠️
    elseif code == "D418" then
      if lang == "es" then
        return "La función decorada con @overload no debería contener una docstring"
      end
    -- 🔗🐍 [D419]	empty-docstring	Docstring is empty	✔️ 🛠️
    elseif code == "D419" then
      if lang == "es" then
        return "Docstring está vacía"
      end
    -- 🔗🐍 [UP001]	useless-metaclass-type	__metaclass__ = type is implied	✔️ 🛠️
    -- 🔗🐍 [UP003]	type-of-primitive	Use {} instead of type(...)	✔️ 🛠️
    -- 🔗🐍 [UP004]	useless-object-inheritance	Class {name} inherits from object	✔️ 🛠️
    -- 🔗🐍 [UP005]	deprecated-unittest-alias	{alias} is deprecated, use {target}	✔️ 🛠️
    -- 🔗🐍 [UP006]	non-pep585-annotation	Use {to} instead of {from} for type annotation	✔️ 🛠️
    -- 🔗🐍 [UP007]	non-pep604-annotation	Use X | Y for type annotations	✔️ 🛠️
    -- 🔗🐍 [UP008]	super-call-with-parameters	Use super() instead of super(__class__, self)	✔️ 🛠️
    -- 🔗🐍 [UP009]	utf8-encoding-declaration	UTF-8 encoding declaration is unnecessary	✔️ 🛠️
    -- 🔗🐍 [UP010]	unnecessary-future-import	Unnecessary __future__ import {import} for target Python version	✔️ 🛠️
    -- 🔗🐍 [UP011]	lru-cache-without-parameters	Unnecessary parentheses to functools.lru_cache	✔️ 🛠️
    -- 🔗🐍 [UP012]	unnecessary-encode-utf8	Unnecessary call to encode as UTF-8	✔️ 🛠️
    -- 🔗🐍 [UP013]	convert-typed-dict-functional-to-class	Convert {name} from TypedDict functional to class syntax	✔️ 🛠️
    -- 🔗🐍 [UP014]	convert-named-tuple-functional-to-class	Convert {name} from NamedTuple functional to class syntax	✔️ 🛠️
    -- 🔗🐍 [UP015]	redundant-open-modes	Unnecessary open mode parameters	✔️ 🛠️
    elseif code == "UP015" then
      if lang == "es" then
        return "Parámetros de modo de apertura innecesarios"
      elseif lang == "fr" then
        return "Paramètres de mode d'ouverture inutiles"
      elseif lang == "pt-br" then
        return "Parâmetros de modo de abertura desnecessários"
      end
    -- 🔗🐍 [UP017]	datetime-timezone-utc	Use datetime.UTC alias	✔️ 🛠️
    -- 🔗🐍 [UP018]	native-literals	Unnecessary {literal_type} call (rewrite as a literal)	✔️ 🛠️
    -- 🔗🐍 [UP019]	typing-text-str-alias	typing.Text is deprecated, use str	✔️ 🛠️
    -- 🔗🐍 [UP020]	open-alias	Use builtin open	✔️ 🛠️
    -- 🔗🐍 [UP021]	replace-universal-newlines	universal_newlines is deprecated, use text	✔️ 🛠️
    -- 🔗🐍 [UP022]	replace-stdout-stderr	Prefer capture_output over sending stdout and stderr to PIPE	✔️ 🛠️
    -- 🔗🐍 [UP023]	deprecated-c-element-tree	cElementTree is deprecated, use ElementTree	✔️ 🛠️
    -- 🔗🐍 [UP024]	os-error-alias	Replace aliased errors with OSError	✔️ 🛠️
    -- 🔗🐍 [UP025]	unicode-kind-prefix	Remove unicode literals from strings	✔️ 🛠️
    -- 🔗🐍 [UP026]	deprecated-mock-import	mock is deprecated, use unittest.mock	✔️ 🛠️
    -- 🔗🐍 [UP027]	unpacked-list-comprehension	Replace unpacked list comprehension with a generator expression	✔️ 🛠️
    -- 🔗🐍 [UP028]	yield-in-for-loop	Replace yield over for loop with yield from	✔️ 🛠️
    -- 🔗🐍 [UP029]	unnecessary-builtin-import	Unnecessary builtin import: {import}	✔️ 🛠️
    -- 🔗🐍 [UP030]	format-literals	Use implicit references for positional format fields	✔️ 🛠️
    -- 🔗🐍 [UP031]	printf-string-formatting	Use format specifiers instead of percent format	✔️ 🛠️
    -- 🔗🐍 [UP032]	f-string	Use f-string instead of format call	✔️ 🛠️
    -- 🔗🐍 [UP033]	lru-cache-with-maxsize-none	Use @functools.cache instead of @functools.lru_cache(maxsize=None)	✔️ 🛠️
    -- 🔗🐍 [UP034]	extraneous-parentheses	Avoid extraneous parentheses	✔️ 🛠️
    -- 🔗🐍 [UP035]	deprecated-import	Import from {target} instead: {names}	✔️ 🛠️
    elseif code == "UP035" then
      local target, names = message:match "Import from (.*) instead: (.*)"
      if target == nil then
        names, target = message:match "(.*) is deprecated, use (.*) instead"
        if lang == "es" then
          return string.format("%s está obsoleto, usa %s en su lugar", names, target)
        end
      end

      if lang == "es" then
        return string.format("Importa desde %s en lugar de: %s", target, names)
      end
      -- 🔗🐍 [UP036	outdated-version-block	Version block is outdated for minimum Python version	✔️ 🛠️
      -- 🔗🐍 [UP037	quoted-annotation	Remove quotes from type annotation	✔️ 🛠️
      -- 🔗🐍 [UP038	non-pep604-isinstance	Use X | Y in {} call instead of (X, Y)	✔️ 🛠️
      -- 🔗🐍 [UP039	unnecessary-class-parentheses	Unnecessary parentheses after class definition	✔️ 🛠️
      -- 🔗🐍 [UP040	non-pep695-type-alias	Type alias {name} uses TypeAlias annotation instead of the type keyword	✔️ 🛠️
      -- 🔗🐍 [UP041	timeout-error-alias	Replace aliased errors with TimeoutError	✔️ 🛠️
      -- 🔗🐍 [UP042	replace-str-enum	Class {name} inherits from both str and enum.Enum	🧪 🛠️
      -- 🔗🐍 [YTT101	sys-version-slice3	sys.version[:3] referenced (python3.10), use sys.version_info	✔️ 🛠️
      -- 🔗🐍 [YTT102	sys-version2	sys.version[2] referenced (python3.10), use sys.version_info	✔️ 🛠️
      -- 🔗🐍 [YTT103	sys-version-cmp-str3	sys.version compared to string (python3.10), use sys.version_info	✔️ 🛠️
      -- 🔗🐍 [YTT201	sys-version-info0-eq3	sys.version_info[0] == 3 referenced (python4), use >=	✔️ 🛠️
      -- 🔗🐍 [YTT202	six-py3	six.PY3 referenced (python4), use not six.PY2	✔️ 🛠️
      -- 🔗🐍 [YTT203	sys-version-info1-cmp-int	sys.version_info[1] compared to integer (python4), compare sys.version_info to tuple	✔️ 🛠️
      -- 🔗🐍 [YTT204	sys-version-info-minor-cmp-int	sys.version_info.minor compared to integer (python4), compare sys.version_info to tuple	✔️ 🛠️
      -- 🔗🐍 [YTT301	sys-version0	sys.version[0] referenced (python10), use sys.version_info	✔️ 🛠️
      -- 🔗🐍 [YTT302	sys-version-cmp-str10	sys.version compared to string (python10), use sys.version_info	✔️ 🛠️
      -- 🔗🐍 [YTT303	sys-version-slice1	sys.version[:1] referenced (python10), use sys.version_info	✔️ 🛠️
      -- 🔗🐍 [ANN001	missing-type-function-argument	Missing type annotation for function argument {name}	✔️ 🛠️
      -- 🔗🐍 [ANN002	missing-type-args	Missing type annotation for *{name}	✔️ 🛠️
      -- 🔗🐍 [ANN003	missing-type-kwargs	Missing type annotation for **{name}	✔️ 🛠️
      -- 🔗🐍 [ANN101	missing-type-self	Missing type annotation for {name} in method	⚠️ 🛠️
      -- 🔗🐍 [ANN102	missing-type-cls	Missing type annotation for {name} in classmethod	⚠️ 🛠️
      -- 🔗🐍 [ANN201	missing-return-type-undocumented-public-function	Missing return type annotation for public function {name}	✔️ 🛠️
      -- 🔗🐍 [ANN202	missing-return-type-private-function	Missing return type annotation for private function {name}	✔️ 🛠️
      -- 🔗🐍 [ANN204	missing-return-type-special-method	Missing return type annotation for special method {name}	✔️ 🛠️
      -- 🔗🐍 [ANN205	missing-return-type-static-method	Missing return type annotation for staticmethod {name}	✔️ 🛠️
      -- 🔗🐍 [ANN206	missing-return-type-class-method	Missing return type annotation for classmethod {name}	✔️ 🛠️
      -- 🔗🐍 [ANN401	any-type	Dynamically typed expressions (typing.Any) are disallowed in {name}	✔️ 🛠️
      -- 🔗🐍 [ASYNC100	blocking-http-call-in-async-function	Async functions should not call blocking HTTP methods	✔️ 🛠️
      -- 🔗🐍 [ASYNC101	open-sleep-or-subprocess-in-async-function	Async functions should not call open, time.sleep, or subprocess methods	✔️ 🛠️
      -- 🔗🐍 [ASYNC102	blocking-os-call-in-async-function	Async functions should not call synchronous os methods	✔️ 🛠️
      -- 🔗🐍 [TRIO100	trio-timeout-without-await	A with {method_name}(...): context does not contain any await statements. This makes it pointless, as the timeout can only be triggered by a checkpoint.	✔️ 🛠️
      -- 🔗🐍 [TRIO105	trio-sync-call	Call to {method_name} is not immediately awaited	✔️ 🛠️
      -- 🔗🐍 [TRIO109	trio-async-function-with-timeout	Prefer trio.fail_after and trio.move_on_after over manual async timeout behavior	✔️ 🛠️
      -- 🔗🐍 [TRIO110	trio-unneeded-sleep	Use trio.Event instead of awaiting trio.sleep in a while loop	✔️ 🛠️
      -- 🔗🐍 [TRIO115	trio-zero-sleep-call	Use trio.lowlevel.checkpoint() instead of trio.sleep(0)	✔️ 🛠️
      -- 🔗🐍 [S101	assert	Use of assert detected	✔️ 🛠️
      -- 🔗🐍 [S102	exec-builtin	Use of exec detected	✔️ 🛠️
      -- 🔗🐍 [S103	bad-file-permissions	os.chmod setting a permissive mask {mask:#o} on file or directory	✔️ 🛠️
      -- 🔗🐍 [S104	hardcoded-bind-all-interfaces	Possible binding to all interfaces	✔️ 🛠️
      -- 🔗🐍 [S105	hardcoded-password-string	Possible hardcoded password assigned to: "{}"	✔️ 🛠️
      -- 🔗🐍 [S106	hardcoded-password-func-arg	Possible hardcoded password assigned to argument: "{}"	✔️ 🛠️
      -- 🔗🐍 [S107	hardcoded-password-default	Possible hardcoded password assigned to function default: "{}"	✔️ 🛠️
      -- 🔗🐍 [S108	hardcoded-temp-file	Probable insecure usage of temporary file or directory: "{}"	✔️ 🛠️
      -- 🔗🐍 [S110	try-except-pass	try-except-pass detected, consider logging the exception	✔️ 🛠️
      -- 🔗🐍 [S112	try-except-continue	try-except-continue detected, consider logging the exception	✔️ 🛠️
      -- 🔗🐍 [S113	request-without-timeout	Probable use of requests call without timeout	✔️ 🛠️
      -- 🔗🐍 [S201	flask-debug-true	Use of debug=True in Flask app detected	✔️ 🛠️
      -- 🔗🐍 [S202	tarfile-unsafe-members	Uses of tarfile.extractall()	✔️ 🛠️
      -- 🔗🐍 [S301	suspicious-pickle-usage	pickle and modules that wrap it can be unsafe when used to deserialize untrusted data, possible security issue	✔️ 🛠️
      -- 🔗🐍 [S302	suspicious-marshal-usage	Deserialization with the marshal module is possibly dangerous	✔️ 🛠️
      -- 🔗🐍 [S303	suspicious-insecure-hash-usage	Use of insecure MD2, MD4, MD5, or SHA1 hash function	✔️ 🛠️
      -- 🔗🐍 [S304	suspicious-insecure-cipher-usage	Use of insecure cipher, replace with a known secure cipher such as AES	✔️ 🛠️
      -- 🔗🐍 [S305	suspicious-insecure-cipher-mode-usage	Use of insecure block cipher mode, replace with a known secure mode such as CBC or CTR	✔️ 🛠️
      -- 🔗🐍 [S306	suspicious-mktemp-usage	Use of insecure and deprecated function (mktemp)	✔️ 🛠️
      -- 🔗🐍 [S307	suspicious-eval-usage	Use of possibly insecure function; consider using ast.literal_eval	✔️ 🛠️
      -- 🔗🐍 [S308	suspicious-mark-safe-usage	Use of mark_safe may expose cross-site scripting vulnerabilities	✔️ 🛠️
      -- 🔗🐍 [S310	suspicious-url-open-usage	Audit URL open for permitted schemes. Allowing use of file: or custom schemes is often unexpected.	✔️ 🛠️
      -- 🔗🐍 [S311	suspicious-non-cryptographic-random-usage	Standard pseudo-random generators are not suitable for cryptographic purposes	✔️ 🛠️
      -- 🔗🐍 [S312	suspicious-telnet-usage	Telnet-related functions are being called. Telnet is considered insecure. Use SSH or some other encrypted protocol.	✔️ 🛠️
      -- 🔗🐍 [S313	suspicious-xmlc-element-tree-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S314	suspicious-xml-element-tree-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S315	suspicious-xml-expat-reader-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S316	suspicious-xml-expat-builder-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S317	suspicious-xml-sax-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S318	suspicious-xml-mini-dom-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S319	suspicious-xml-pull-dom-usage	Using xml to parse untrusted data is known to be vulnerable to XML attacks; use defusedxml equivalents	✔️ 🛠️
      -- 🔗🐍 [S320	suspicious-xmle-tree-usage	Using lxml to parse untrusted data is known to be vulnerable to XML attacks	✔️ 🛠️
      -- 🔗🐍 [S321	suspicious-ftp-lib-usage	FTP-related functions are being called. FTP is considered insecure. Use SSH/SFTP/SCP or some other encrypted protocol.	✔️ 🛠️
      -- 🔗🐍 [S323	suspicious-unverified-context-usage	Python allows using an insecure context via the _create_unverified_context that reverts to the previous behavior that does not validate certificates or perform hostname checks.	✔️ 🛠️
      -- 🔗🐍 [S324	hashlib-insecure-hash-function	Probable use of insecure hash functions in {library}: {string}	✔️ 🛠️
      -- 🔗🐍 [S401	suspicious-telnetlib-import	telnetlib and related modules are considered insecure. Use SSH or another encrypted protocol.	🧪 🛠️
      -- 🔗🐍 [S402	suspicious-ftplib-import	ftplib and related modules are considered insecure. Use SSH, SFTP, SCP, or another encrypted protocol.	🧪 🛠️
      -- 🔗🐍 [S403	suspicious-pickle-import	pickle, cPickle, dill, and shelve modules are possibly insecure	🧪 🛠️
      -- 🔗🐍 [S404	suspicious-subprocess-import	subprocess module is possibly insecure	🧪 🛠️
      -- 🔗🐍 [S405	suspicious-xml-etree-import	xml.etree methods are vulnerable to XML attacks	🧪 🛠️
      -- 🔗🐍 [S406	suspicious-xml-sax-import	xml.sax methods are vulnerable to XML attacks	🧪 🛠️
      -- 🔗🐍 [S407	suspicious-xml-expat-import	xml.dom.expatbuilder is vulnerable to XML attacks	🧪 🛠️
      -- 🔗🐍 [S408	suspicious-xml-minidom-import	xml.dom.minidom is vulnerable to XML attacks	🧪 🛠️
      -- 🔗🐍 [S409	suspicious-xml-pulldom-import	xml.dom.pulldom is vulnerable to XML attacks	🧪 🛠️
      -- 🔗🐍 [S410	suspicious-lxml-import	lxml is vulnerable to XML attacks	❌ 🛠️
      -- 🔗🐍 [S411	suspicious-xmlrpc-import	XMLRPC is vulnerable to remote XML attacks	🧪 🛠️
      -- 🔗🐍 [S412	suspicious-httpoxy-import	httpoxy is a set of vulnerabilities that affect application code running inCGI, or CGI-like environments. The use of CGI for web applications should be avoided	🧪 🛠️
      -- 🔗🐍 [S413	suspicious-pycrypto-import	pycrypto library is known to have publicly disclosed buffer overflow vulnerability	🧪 🛠️
      -- 🔗🐍 [S415	suspicious-pyghmi-import	An IPMI-related module is being imported. Prefer an encrypted protocol over IPMI.	🧪 🛠️
      -- 🔗🐍 [S501	request-with-no-cert-validation	Probable use of {string} call with verify=False disabling SSL certificate checks	✔️ 🛠️
      -- 🔗🐍 [S502	ssl-insecure-version	Call made with insecure SSL protocol: {protocol}	✔️ 🛠️
      -- 🔗🐍 [S503	ssl-with-bad-defaults	Argument default set to insecure SSL protocol: {protocol}	✔️ 🛠️
      -- 🔗🐍 [S504	ssl-with-no-version	ssl.wrap_socket called without an `ssl_version``	✔️ 🛠️
      -- 🔗🐍 [S505	weak-cryptographic-key	{cryptographic_key} key sizes below {minimum_key_size} bits are considered breakable	✔️ 🛠️
      -- 🔗🐍 [S506	unsafe-yaml-load	Probable use of unsafe loader {name} with yaml.load. Allows instantiation of arbitrary objects. Consider yaml.safe_load.	✔️ 🛠️
      -- 🔗🐍 [S507	ssh-no-host-key-verification	Paramiko call with policy set to automatically trust the unknown host key	✔️ 🛠️
      -- 🔗🐍 [S508	snmp-insecure-version	The use of SNMPv1 and SNMPv2 is insecure. Use SNMPv3 if able.	✔️ 🛠️
      -- 🔗🐍 [S509	snmp-weak-cryptography	You should not use SNMPv3 without encryption. noAuthNoPriv & authNoPriv is insecure.	✔️ 🛠️
      -- 🔗🐍 [S601	paramiko-call	Possible shell injection via Paramiko call; check inputs are properly sanitized	✔️ 🛠️
      -- 🔗🐍 [S602	subprocess-popen-with-shell-equals-true	subprocess call with shell=True seems safe, but may be changed in the future; consider rewriting without shell	✔️ 🛠️
      -- 🔗🐍 [S603	subprocess-without-shell-equals-true	subprocess call: check for execution of untrusted input	✔️ 🛠️
      -- 🔗🐍 [S604	call-with-shell-equals-true	Function call with shell=True parameter identified, security issue	✔️ 🛠️
      -- 🔗🐍 [S605	start-process-with-a-shell	Starting a process with a shell: seems safe, but may be changed in the future; consider rewriting without shell	✔️ 🛠️
      -- 🔗🐍 [S606	start-process-with-no-shell	Starting a process without a shell	✔️ 🛠️
      -- 🔗🐍 [S607	start-process-with-partial-path	Starting a process with a partial executable path	✔️ 🛠️
      -- 🔗🐍 [S608	hardcoded-sql-expression	Possible SQL injection vector through string-based query construction	✔️ 🛠️
      -- 🔗🐍 [S609	unix-command-wildcard-injection	Possible wildcard injection in call due to * usage	✔️ 🛠️
      -- 🔗🐍 [S610	django-extra	Use of Django extra can lead to SQL injection vulnerabilities	🧪 🛠️
      -- 🔗🐍 [S611	django-raw-sql	Use of RawSQL can lead to SQL injection vulnerabilities	✔️ 🛠️
      -- 🔗🐍 [S612	logging-config-insecure-listen	Use of insecure logging.config.listen detected	✔️ 🛠️
      -- 🔗🐍 [S701	jinja2-autoescape-false	Using jinja2 templates with autoescape=False is dangerous and can lead to XSS. Ensure autoescape=True or use the select_autoescape function.	✔️ 🛠️
      -- 🔗🐍 [S702	mako-templates	Mako templates allow HTML and JavaScript rendering by default and are inherently open to XSS attacks	✔️ 🛠️
      -- 🔗🐍 [BLE001	blind-except	Do not catch blind exception: {name}	✔️ 🛠️
      -- 🔗🐍 [FBT001	boolean-type-hint-positional-argument	Boolean-typed positional argument in function definition	✔️ 🛠️
      -- 🔗🐍 [FBT002	boolean-default-value-positional-argument	Boolean default positional argument in function definition	✔️ 🛠️
      -- 🔗🐍 [FBT003	boolean-positional-value-in-call	Boolean positional value in function call	✔️ 🛠️
      -- 🔗🐍 [B002	unary-prefix-increment-decrement	Python does not support the unary prefix increment operator (++)	✔️ 🛠️
      -- 🔗🐍 [B003	assignment-to-os-environ	Assigning to os.environ doesn't clear the environment	✔️ 🛠️
      -- 🔗🐍 [B004	unreliable-callable-check	Using hasattr(x, "__call__") to test if x is callable is unreliable. Use callable(x) for consistent results.	✔️ 🛠️
      -- 🔗🐍 [B005	strip-with-multi-characters	Using .strip() with multi-character strings is misleading	✔️ 🛠️
      -- 🔗🐍 [B006	mutable-argument-default	Do not use mutable data structures for argument defaults	✔️ 🛠️
    elseif code == "B007" then
      -- 🔗🐍 [B007]	unused-loop-control-variable	Loop control variable {name} not used within loop body	✔️ 🛠️
      local name = message:match "Loop control variable ([^']+) not used within loop body"
      if lang == "es" then
        return string.format("El variable de control del bucle %s no se usa dentro del cuerpo del bucle", name)
      end
      -- 🔗🐍 [B008	function-call-in-default-argument	Do not perform function call {name} in argument defaults; instead, perform the call within the function, or read the default from a module-level singleton variable	✔️ 🛠️
      -- 🔗🐍 [B009	get-attr-with-constant	Do not call getattr with a constant attribute value. It is not any safer than normal property access.	✔️ 🛠️
      -- 🔗🐍 [B010	set-attr-with-constant	Do not call setattr with a constant attribute value. It is not any safer than normal property access.	✔️ 🛠️
      -- 🔗🐍 [B011	assert-false	Do not assert False (python -O removes these calls), raise AssertionError()	✔️ 🛠️
      -- 🔗🐍 [B012	jump-statement-in-finally	{name} inside finally blocks cause exceptions to be silenced	✔️ 🛠️
      -- 🔗🐍 [B013	redundant-tuple-in-exception-handler	A length-one tuple literal is redundant in exception handlers	✔️ 🛠️
      -- 🔗🐍 [B014	duplicate-handler-exception	Exception handler with duplicate exception: {name}	✔️ 🛠️
      -- 🔗🐍 [B015	useless-comparison	Pointless comparison. Did you mean to assign a value? Otherwise, prepend assert or remove it.	✔️ 🛠️
      -- 🔗🐍 [B016	raise-literal	Cannot raise a literal. Did you intend to return it or raise an Exception?	✔️ 🛠️
      -- 🔗🐍 [B017	assert-raises-exception	{assertion}({exception}) should be considered evil	✔️ 🛠️
      -- 🔗🐍 [B018	useless-expression	Found useless expression. Either assign it to a variable or remove it.	✔️ 🛠️
    elseif code == "B018" then
      if lang == "es" then
        return "Se encontró una expresión inútil. Asígnala a una variable o elimínala."
      elseif lang == "fr" then
        return "Expression inutile trouvée. Attribuez-la à une variable ou supprimez-la."
      end
      -- 🔗🐍 [B019	cached-instance-method	Use of functools.lru_cache or functools.cache on methods can lead to memory leaks	✔️ 🛠️
      -- 🔗🐍 [B020	loop-variable-overrides-iterator	Loop control variable {name} overrides iterable it iterates	✔️ 🛠️
      -- 🔗🐍 [B021	f-string-docstring	f-string used as docstring. Python will interpret this as a joined string, rather than a docstring.	✔️ 🛠️
      -- 🔗🐍 [B022	useless-contextlib-suppress	No arguments passed to contextlib.suppress. No exceptions will be suppressed and therefore this context manager is redundant	✔️ 🛠️
      -- 🔗🐍 [B023	function-uses-loop-variable	Function definition does not bind loop variable {name}	✔️ 🛠️
      -- 🔗🐍 [B024	abstract-base-class-without-abstract-method	{name} is an abstract base class, but it has no abstract methods	✔️ 🛠️
      -- 🔗🐍 [B025	duplicate-try-block-exception	try-except block with duplicate exception {name}	✔️ 🛠️
      -- 🔗🐍 [B026	star-arg-unpacking-after-keyword-arg	Star-arg unpacking after a keyword argument is strongly discouraged	✔️ 🛠️
      -- 🔗🐍 [B027	empty-method-without-abstract-decorator	{name} is an empty method in an abstract base class, but has no abstract decorator	✔️ 🛠️
      -- 🔗🐍 [B028	no-explicit-stacklevel	No explicit stacklevel keyword argument found	✔️ 🛠️
      -- 🔗🐍 [B029	except-with-empty-tuple	Using except (): with an empty tuple does not catch anything; add exceptions to handle	✔️ 🛠️
      -- 🔗🐍 [B030	except-with-non-exception-classes	except handlers should only be exception classes or tuples of exception classes	✔️ 🛠️
      -- 🔗🐍 [B031	reuse-of-groupby-generator	Using the generator returned from itertools.groupby() more than once will do nothing on the second usage	✔️ 🛠️
      -- 🔗🐍 [B032	unintentional-type-annotation	Possible unintentional type annotation (using :). Did you mean to assign (using =)?	✔️ 🛠️
      -- 🔗🐍 [B033	duplicate-value	Sets should not contain duplicate item {value}	✔️ 🛠️
      -- 🔗🐍 [B034	re-sub-positional-args	{method} should pass {param_name} and flags as keyword arguments to avoid confusion due to unintuitive argument positions	✔️ 🛠️
      -- 🔗🐍 [B035	static-key-dict-comprehension	Dictionary comprehension uses static key: {key}	✔️ 🛠️
      -- 🔗🐍 [B904	raise-without-from-inside-except	Within an except clause, raise exceptions with raise ... from err or raise ... from None to distinguish them from errors in exception handling	✔️ 🛠️
      -- 🔗🐍 [B905]	zip-without-explicit-strict	zip() without an explicit strict= parameter	✔️ 🛠️
    elseif code == "B905" then
      if lang == "es" then
        return "`zip()` sin un parámetro `strict=` explícito"
      elseif lang == "fr" then
        return "`zip()` sans un paramètre `strict=` explicite"
      elseif lang == "pt-br" then
        return "`zip()` sem um parâmetro `strict=` explícito"
      end
    -- 🔗🐍 [B909	loop-iterator-mutation	Mutation to loop iterable {name} during iteration	🧪 🛠️
    -- 🔗🐍 [A001	builtin-variable-shadowing	Variable {name} is shadowing a Python builtin	✔️ 🛠️
    -- 🔗🐍 [A002	builtin-argument-shadowing	Argument {name} is shadowing a Python builtin	✔️ 🛠️
    -- 🔗🐍 [A003	builtin-attribute-shadowing	Python builtin is shadowed by class attribute {name} from {row}	✔️ 🛠️
    -- 🔗🐍 [COM812	missing-trailing-comma	Trailing comma missing	✔️ 🛠️
    -- 🔗🐍 [COM818	trailing-comma-on-bare-tuple	Trailing comma on bare tuple prohibited	✔️ 🛠️
    -- 🔗🐍 [COM819	prohibited-trailing-comma	Trailing comma prohibited	✔️ 🛠️
    -- 🔗🐍 [CPY001	missing-copyright-notice	Missing copyright notice at top of file	🧪 🛠️
    -- 🔗🐍 [C400	unnecessary-generator-list	Unnecessary generator (rewrite using list())	✔️ 🛠️
    elseif code == "C400" then
      if lang == "es" then
        return "Generador innecesario (reescribe usando `list()`)"
      elseif lang == "pt-br" then
        return "Gerador desnecessário (reescreva usando `list()`)"
      elseif lang == "fr" then
        return "Générateur inutile (réécrire en utilisant `list()`)"
      end
    -- 🔗🐍 [C401	unnecessary-generator-set	Unnecessary generator (rewrite using set()	✔️ 🛠️
    elseif code == "C401" then
      if lang == "es" then
        return "Generador innecesario (reescribe usando `set()`)"
      elseif lang == "pt-br" then
        return "Gerador desnecessário (reescreva usando `set()`)"
      elseif lang == "fr" then
        return "Générateur inutile (réécrire en utilisant `set()`)"
      end
    -- 🔗🐍 [C402	unnecessary-generator-dict	Unnecessary generator (rewrite as a dict comprehension)	✔️ 🛠️
    elseif code == "C402" then
      if lang == "es" then
        return "Generador innecesario (reescribe como una comprensión de diccionario)"
      elseif lang == "pt-br" then
        return "Gerador desnecessário (reescreva como uma compreensão de dicionário)"
      elseif lang == "fr" then
        return "Générateur inutile (réécrire comme une compréhension de dictionnaire)"
      end
    -- 🔗🐍 [C403]	unnecessary-list-comprehension-set	Unnecessary list comprehension (rewrite as a set comprehension)	✔️ 🛠️
    elseif code == "C403" then
      if lang == "es" then
        return "Comprensión de lista innecesaria (reescribe como una comprensión de conjunto)"
      elseif lang == "pt-br" then
        return "Compreensão de lista desnecessária (reescreva como uma compreensão de conjunto)"
      elseif lang == "fr" then
        return "Compréhension de liste inutile (réécrire comme une compréhension d'ensemble)"
      end
    -- 🔗🐍 [C404]	unnecessary-list-comprehension-dict	Unnecessary list comprehension (rewrite as a dict comprehension)	✔️ 🛠️
    elseif code == "C404" then
      if lang == "es" then
        return "Comprensión de lista innecesaria (reescribe como una comprensión de diccionario)"
      elseif lang == "pt-br" then
        return "Compreensão de lista desnecessária (reescreva como uma compreensão de dicionário)"
      elseif lang == "fr" then
        return "Compréhension de liste inutile (réécrire comme une compréhension de dictionnaire)"
      end
    -- 🔗🐍 [C405	unnecessary-literal-set	Unnecessary {obj_type} literal (rewrite as a set literal)	✔️ 🛠️
    -- 🔗🐍 [C406	unnecessary-literal-dict	Unnecessary {obj_type} literal (rewrite as a dict literal)	✔️ 🛠️
    -- 🔗🐍 [C408	unnecessary-collection-call	Unnecessary {obj_type} call (rewrite as a literal)	✔️ 🛠️
    -- 🔗🐍 [C409	unnecessary-literal-within-tuple-call	Unnecessary {literal} literal passed to tuple() (rewrite as a tuple literal)	✔️ 🛠️
    -- 🔗🐍 [C410	unnecessary-literal-within-list-call	Unnecessary {literal} literal passed to list() (remove the outer call to list())	✔️ 🛠️
    -- 🔗🐍 [C411	unnecessary-list-call	Unnecessary list call (remove the outer call to list())	✔️ 🛠️
    -- 🔗🐍 [C413	unnecessary-call-around-sorted	Unnecessary {func} call around sorted()	✔️ 🛠️
    -- 🔗🐍 [C414	unnecessary-double-cast-or-process	Unnecessary {inner} call within {outer}()	✔️ 🛠️
    -- 🔗🐍 [C415	unnecessary-subscript-reversal	Unnecessary subscript reversal of iterable within {func}()	✔️ 🛠️
    -- 🔗🐍 [C416	unnecessary-comprehension	Unnecessary {obj_type} comprehension (rewrite using {obj_type}())	✔️ 🛠️
    -- 🔗🐍 [C417	unnecessary-map	Unnecessary map usage (rewrite using a {object_type})	✔️ 🛠️
    -- 🔗🐍 [C418	unnecessary-literal-within-dict-call	Unnecessary dict {kind} passed to dict() (remove the outer call to dict())	✔️ 🛠️
    -- 🔗🐍 [C419	unnecessary-comprehension-in-call	Unnecessary list comprehension	✔️ 🛠️
    -- 🔗🐍 [DTZ001	call-datetime-without-tzinfo	datetime.datetime() called without a tzinfo argument	✔️ 🛠️
    -- 🔗🐍 [DTZ002	call-datetime-today	datetime.datetime.today() used	✔️ 🛠️
    -- 🔗🐍 [DTZ003	call-datetime-utcnow	datetime.datetime.utcnow() used	✔️ 🛠️
    -- 🔗🐍 [DTZ004	call-datetime-utcfromtimestamp	datetime.datetime.utcfromtimestamp() used	✔️ 🛠️
    -- 🔗🐍 [DTZ005	call-datetime-now-without-tzinfo	datetime.datetime.now() called without a tz argument	✔️ 🛠️
    -- 🔗🐍 [DTZ006	call-datetime-fromtimestamp	datetime.datetime.fromtimestamp() called without a tz argument	✔️ 🛠️
    -- 🔗🐍 [DTZ007	call-datetime-strptime-without-zone	Naive datetime constructed using datetime.datetime.strptime() without %z	✔️ 🛠️
    -- 🔗🐍 [DTZ011	call-date-today	datetime.date.today() used	✔️ 🛠️
    -- 🔗🐍 [DTZ012	call-date-fromtimestamp	datetime.date.fromtimestamp() used	✔️ 🛠️
    -- 🔗🐍 [T100	debugger	Trace found: {name} used	✔️ 🛠️
    -- 🔗🐍 [DJ001	django-nullable-model-string-field	Avoid using null=True on string-based fields such as {field_name}	✔️ 🛠️
    -- 🔗🐍 [DJ003	django-locals-in-render-function	Avoid passing locals() as context to a render function	✔️ 🛠️
    -- 🔗🐍 [DJ006	django-exclude-with-model-form	Do not use exclude with ModelForm, use fields instead	✔️ 🛠️
    -- 🔗🐍 [DJ007	django-all-with-model-form	Do not use __all__ with ModelForm, use fields instead	✔️ 🛠️
    -- 🔗🐍 [DJ008	django-model-without-dunder-str	Model does not define __str__ method	✔️ 🛠️
    -- 🔗🐍 [DJ012	django-unordered-body-content-in-model	Order of model's inner classes, methods, and fields does not follow the Django Style Guide: {element_type} should come before {prev_element_type}	✔️ 🛠️
    -- 🔗🐍 [DJ013	django-non-leading-receiver-decorator	@receiver decorator must be on top of all the other decorators	✔️ 🛠️
    -- 🔗🐍 [EM101	raw-string-in-exception	Exception must not use a string literal, assign to variable first	✔️ 🛠️
    -- 🔗🐍 [EM102	f-string-in-exception	Exception must not use an f-string literal, assign to variable first	✔️ 🛠️
    -- 🔗🐍 [EM103	dot-format-in-exception	Exception must not use a .format() string directly, assign to variable first	✔️ 🛠️
    -- 🔗🐍 [EXE001	shebang-not-executable	Shebang is present but file is not executable	✔️ 🛠️
    -- 🔗🐍 [EXE002	shebang-missing-executable-file	The file is executable but no shebang is present	✔️ 🛠️
    -- 🔗🐍 [EXE003	shebang-missing-python	Shebang should contain python	✔️ 🛠️
    -- 🔗🐍 [EXE004	shebang-leading-whitespace	Avoid whitespace before shebang	✔️ 🛠️
    -- 🔗🐍 [EXE005	shebang-not-first-line	Shebang should be at the beginning of the file	✔️ 🛠️
    -- 🔗🐍 [FA100	future-rewritable-type-annotation	Missing from __future__ import annotations, but uses {name}	✔️ 🛠️
    -- 🔗🐍 [FA102	future-required-type-annotation	Missing from __future__ import annotations, but uses {reason}	✔️ 🛠️
    -- 🔗🐍 [ISC001	single-line-implicit-string-concatenation	Implicitly concatenated string literals on one line	✔️ 🛠️
    -- 🔗🐍 [ISC002	multi-line-implicit-string-concatenation	Implicitly concatenated string literals over multiple lines	✔️ 🛠️
    -- 🔗🐍 [ISC003	explicit-string-concatenation	Explicitly concatenated string should be implicitly concatenated	✔️ 🛠️
    -- 🔗🐍 [ICN001	unconventional-import-alias	{name} should be imported as {asname}	✔️ 🛠️
    -- 🔗🐍 [ICN002	banned-import-alias	{name} should not be imported as {asname}	✔️ 🛠️
    -- 🔗🐍 [ICN003	banned-import-from	Members of {name} should not be imported explicitly	✔️ 🛠️
    -- 🔗🐍 [LOG001	direct-logger-instantiation	Use logging.getLogger() to instantiate loggers	✔️ 🛠️
    -- 🔗🐍 [LOG002	invalid-get-logger-argument	Use __name__ with logging.getLogger()	✔️ 🛠️
    -- 🔗🐍 [LOG007	exception-without-exc-info	Use of logging.exception with falsy exc_info	✔️ 🛠️
    -- 🔗🐍 [LOG009	undocumented-warn	Use of undocumented logging.WARN constant	✔️ 🛠️
    -- 🔗🐍 [G001	logging-string-format	Logging statement uses str.format	✔️ 🛠️
    -- 🔗🐍 [G002	logging-percent-format	Logging statement uses %	✔️ 🛠️
    -- 🔗🐍 [G003	logging-string-concat	Logging statement uses +	✔️ 🛠️
    -- 🔗🐍 [G004	logging-f-string	Logging statement uses f-string	✔️ 🛠️
    -- 🔗🐍 [G010	logging-warn	Logging statement uses warn instead of warning	✔️ 🛠️
    -- 🔗🐍 [G101	logging-extra-attr-clash	Logging statement uses an extra field that clashes with a LogRecord field: {key}	✔️ 🛠️
    -- 🔗🐍 [G201	logging-exc-info	Logging .exception(...) should be used instead of .error(..., exc_info=True)	✔️ 🛠️
    -- 🔗🐍 [G202	logging-redundant-exc-info	Logging statement has redundant exc_info	✔️ 🛠️
    -- 🔗🐍 [INP001	implicit-namespace-package	File {filename} is part of an implicit namespace package. Add an __init__.py.	✔️ 🛠️
    -- 🔗🐍 [PIE790	unnecessary-placeholder	Unnecessary pass statement	✔️ 🛠️
    -- 🔗🐍 [PIE794	duplicate-class-field-definition	Class field {name} is defined multiple times	✔️ 🛠️
    -- 🔗🐍 [PIE796	non-unique-enums	Enum contains duplicate value: {value}	✔️ 🛠️
    -- 🔗🐍 [PIE800	unnecessary-spread	Unnecessary spread **	✔️ 🛠️
    -- 🔗🐍 [PIE804	unnecessary-dict-kwargs	Unnecessary dict kwargs	✔️ 🛠️
    -- 🔗🐍 [PIE807	reimplemented-container-builtin	Prefer {container} over useless lambda	✔️ 🛠️
    -- 🔗🐍 [PIE808	unnecessary-range-start	Unnecessary start argument in range	✔️ 🛠️
    -- 🔗🐍 [PIE810	multiple-starts-ends-with	Call {attr} once with a tuple	✔️ 🛠️
    elseif code == "T201" then
      -- 🔗🐍 [T201	print	print found	✔️ 🛠️
      if lang == "es" then
        return "`print` encontrado"
      elseif lang == "pt-br" then
        return "`print` encontrado"
      elseif lang == "fr" then
        return "`print` trouvé"
      end
    elseif code == "T203" then
      -- 🔗🐍 [T203	p-print	pprint found	✔️ 🛠️
      if lang == "es" then
        return "`pprint` encontrado"
      end
    elseif code == "PTH100" then
      -- 🔗🐍 [PTH100]	os-path-abspath	os.path.abspath() should be replaced by Path.resolve()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.abspath()` debería ser reemplazado por `Path.resolve()`"
      end
    elseif code == "PTH101" then
      -- 🔗🐍 [PTH101]	os-chmod	os.chmod() should be replaced by Path.chmod()	✔️ 🛠️
      if lang == "es" then
        return "`os.chmod()` debería ser reemplazado por `Path.chmod()`"
      end
    elseif code == "PTH102" then
      -- 🔗🐍 [PTH102]	os-mkdir	os.mkdir() should be replaced by Path.mkdir()	✔️ 🛠️
      if lang == "es" then
        return "`os.mkdir()` debería ser reemplazado por `Path.mkdir()`"
      end
    elseif code == "PTH103" then
      -- 🔗🐍 [PTH103]	os-makedirs	os.makedirs() should be replaced by Path.mkdir(parents=True)	✔️ 🛠️
      if lang == "es" then
        return "`os.makedirs()` debería ser reemplazado por `Path.mkdir(parents=True)`"
      end
    elseif code == "PTH104" then
      -- 🔗🐍 [PTH104]	os-rename	os.rename() should be replaced by Path.rename()	✔️ 🛠️
      if lang == "es" then
        return "`os.rename()` debería ser reemplazado por `Path.rename()`"
      end
    -- 🔗🐍 [PTH105]	os-replace	os.replace() should be replaced by Path.replace()	✔️ 🛠️
    elseif code == "PTH106" then
      -- 🔗🐍 [PTH106]	os-rmdir	os.rmdir() should be replaced by Path.rmdir()	✔️ 🛠️
      if lang == "es" then
        return "`os.rmdir()` debería ser reemplazado por `Path.rmdir()`"
      end
    elseif code == "PTH107" then
      -- 🔗🐍 [PTH107]	os-remove	os.remove() should be replaced by Path.unlink()	✔️ 🛠️
      if lang == "es" then
        return "`os.remove()` debería ser reemplazado por `Path.unlink()`"
      end
    elseif code == "PTH108" then
      -- 🔗🐍 [PTH108]	os-unlink	os.unlink() should be replaced by Path.unlink()	✔️ 🛠️
      if lang == "es" then
        return "`os.unlink()` debería ser reemplazado por `Path.unlink()`"
      end
    elseif code == "PTH109" then
      -- 🔗🐍 [PTH109]	os-getcwd	os.getcwd() should be replaced by Path.cwd()	✔️ 🛠️
      if lang == "es" then
        return "`os.getcwd()` debería ser reemplazado por `Path.cwd()`"
      end
    elseif code == "PTH110" then
      -- 🔗🐍 [PTH110]	os-path-exists	os.path.exists() should be replaced by Path.exists()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.exists()` debería ser reemplazado por `Path.exists()`"
      end
    elseif code == "PTH111" then
      -- 🔗🐍 [PTH111]	os-path-expanduser	os.path.expanduser() should be replaced by Path.expanduser()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.expanduser()` debería ser reemplazado por `Path.expanduser()`"
      end
    elseif code == "PTH112" then
      -- 🔗🐍 [PTH112]	os-path-isdir	os.path.isdir() should be replaced by Path.is_dir()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.isdir()` debería ser reemplazado por `Path.is_dir()`"
      end
    elseif code == "PTH113" then
      -- 🔗🐍 [PTH113]	os-path-isfile	os.path.isfile() should be replaced by Path.is_file()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.isfile()` debería ser reemplazado por `Path.is_file()`"
      end
    elseif code == "PTH114" then
      -- 🔗🐍 [PTH114]	os-path-islink	os.path.islink() should be replaced by Path.is_symlink()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.islink()` debería ser reemplazado por `Path.is_symlink()`"
      end
    elseif code == "PTH115" then
      -- 🔗🐍 [PTH115]	os-readlink	os.readlink() should be replaced by Path.readlink()	✔️ 🛠️
      if lang == "es" then
        return "`os.readlink()` debería ser reemplazado por `Path.readlink()`"
      end
    elseif code == "PTH116" then
      -- 🔗🐍 [PTH116]	os-stat	os.stat() should be replaced by Path.stat(), Path.owner(), or Path.group()	✔️ 🛠️
      if lang == "es" then
        return "`os.stat()` debería ser reemplazado por `Path.stat()`, `Path.owner()`, o `Path.group()`"
      end
    elseif code == "PTH117" then
      -- 🔗🐍 [PTH117]	os-path-isabs	os.path.isabs() should be replaced by Path.is_absolute()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.isabs()` debería ser reemplazado por `Path.is_absolute()`"
      end
    elseif code == "PTH118" then
      -- 🔗🐍 [PTH118]	os-path-join	os.{module}.join() should be replaced by Path with / operator	✔️ 🛠️
      if lang == "es" then
        return "`os.path.join()` debería ser reemplazado por `Path` con el operador `/`"
      end
    elseif code == "PTH119" then
      -- 🔗🐍 [PTH119]	os-path-basename	os.path.basename() should be replaced by Path.name	✔️ 🛠️
      if lang == "es" then
        return "`os.path.basename()` debería ser reemplazado por `Path.name`"
      end
    elseif code == "PTH120" then
      -- 🔗🐍 [PTH120]	os-path-dirname	os.path.dirname() should be replaced by Path.parent	✔️ 🛠️
      if lang == "es" then
        return "`os.path.dirname()` debería ser reemplazado por `Path.parent`"
      end
    elseif code == "PTH121" then
      -- 🔗🐍 [PTH121]	os-path-samefile	os.path.samefile() should be replaced by Path.samefile()	✔️ 🛠️
      if lang == "es" then
        return "`os.path.samefile()` debería ser reemplazado por `Path.samefile()`"
      end
    elseif code == "PTH122" then
      -- 🔗🐍 [PTH122]	os-path-splitext	os.path.splitext() should be replaced by Path.suffix, Path.stem, and Path.parent	✔️ 🛠️
      if lang == "es" then
        return "`os.path.splitext()` debería ser reemplazado por `Path.suffix`, `Path.stem`, y `Path.parent`"
      end
    elseif code == "PTH123" then
      -- 🔗🐍 [PTH123]	builtin-open	open() should be replaced by Path.open()	✔️ 🛠️
      if lang == "es" then
        return "`open()` debería ser reemplazado por `Path.open()`"
      end
    elseif code == "PTH124" then
      -- 🔗🐍 [PTH124]	py-path	py.path is in maintenance mode, use pathlib instead	✔️ 🛠️
      if lang == "es" then
        return "`py.path` está en modo de mantenimiento, use `pathlib` en su lugar"
      end
    elseif code == "PTH201" then
      -- 🔗🐍 [PTH201]	path-constructor-current-directory	Do not pass the current directory explicitly to Path	✔️ 🛠️
      if lang == "es" then
        return "No pase el directorio actual explícitamente a `Path`"
      end
    elseif code == "PTH202" then
      -- 🔗🐍 [PTH202]	os-path-getsize	os.path.getsize should be replaced by Path.stat().st_size	✔️ 🛠️
      if lang == "es" then
        return "`os.path.getsize` debería ser reemplazado por `Path.stat().st_size`"
      end
    elseif code == "PTH203" then
      -- 🔗🐍 [PTH203]	os-path-getatime	os.path.getatime should be replaced by Path.stat().st_atime	✔️ 🛠️
      if lang == "es" then
        return "`os.path.getatime` debería ser reemplazado por `Path.stat().st_atime`"
      end
    elseif code == "PTH204" then
      -- 🔗🐍 [PTH204]	os-path-getmtime	os.path.getmtime should be replaced by Path.stat().st_mtime	✔️ 🛠️
      if lang == "es" then
        return "`os.path.getmtime` debería ser reemplazado por `Path.stat().st_mtime`"
      end
    elseif code == "PTH205" then
      -- 🔗🐍 [PTH205]	os-path-getctime	os.path.getctime should be replaced by Path.stat().st_ctime	✔️ 🛠️
      if lang == "es" then
        return "`os.path.getctime` debería ser reemplazado por `Path.stat().st_ctime`"
      end
    elseif code == "PTH206" then
      -- 🔗🐍 [PTH206]	os-sep-split	Replace .split(os.sep) with Path.parts	✔️ 🛠️
      if lang == "es" then
        return "Reemplace `.split(os.sep)` con `Path.parts`"
      end
    elseif code == "PTH207" then
      -- 🔗🐍 [PTH207]	glob	Replace {function} with Path.glob or Path.rglob	✔️ 🛠️
      local function_name = message:match "Replace `(.*)` with"
      if lang == "es" then
        return string.format("Reemplace `%s` con `Path.glob` o `Path.rglob`", function_name)
      end
    -- NPY001	numpy-deprecated-type-alias	Type alias np.{type_name} is deprecated, replace with builtin type	✔️ 🛠️
    -- NPY002	numpy-legacy-random	Replace legacy np.random.{method_name} call with np.random.Generator	✔️ 🛠️
    -- NPY003	numpy-deprecated-function	np.{existing} is deprecated; use np.{replacement} instead	✔️ 🛠️
    -- NPY201	numpy2-deprecation	np.{existing} will be removed in NumPy 2.0. {migration_guide}	✔️ 🛠️
    elseif code == "NPY201" then
      local existing, migration_guide = message:match "np%.(.*) will be removed in NumPy 2%.0%. (.*)"
      if lang == "es" then
        return string.format("np.%s será eliminado en NumPy 2.0. %s", existing, migration_guide)
      elseif lang == "pt-br" then
        return string.format("np.%s será removido no NumPy 2.0. %s", existing, migration_guide)
      elseif lang == "fr" then
        return string.format("np.%s sera supprimé dans NumPy 2.0. %s", existing, migration_guide)
      end
    -- RUF001	ambiguous-unicode-character-string	String contains ambiguous {}. Did you mean {}?	✔️ 🛠️
    -- RUF002	ambiguous-unicode-character-docstring	Docstring contains ambiguous {}. Did you mean {}?	✔️ 🛠️
    -- RUF003	ambiguous-unicode-character-comment	Comment contains ambiguous {}. Did you mean {}?	✔️ 🛠️
    -- RUF005	collection-literal-concatenation	Consider {expression} instead of concatenation	✔️ 🛠️
    -- RUF006	asyncio-dangling-task	Store a reference to the return value of {expr}.{method}	✔️ 🛠️
    -- RUF007	zip-instead-of-pairwise	Prefer itertools.pairwise() over zip() when iterating over successive pairs	✔️ 🛠️
    -- RUF008	mutable-dataclass-default	Do not use mutable default values for dataclass attributes	✔️ 🛠️
    -- RUF009	function-call-in-dataclass-default-argument	Do not perform function call {name} in dataclass defaults	✔️ 🛠️
    -- RUF010	explicit-f-string-type-conversion	Use explicit conversion flag	✔️ 🛠️
    -- RUF011	ruff-static-key-dict-comprehension	Dictionary comprehension uses static key	❌ 🛠️
    -- RUF012	mutable-class-default	Mutable class attributes should be annotated with typing.ClassVar	✔️ 🛠️
    -- RUF013	implicit-optional	PEP 484 prohibits implicit Optional	✔️ 🛠️
    elseif code == "RUF013" then
      if lang == "es" then
        return "PEP 484 prohíbe el uso implícito de `Optional`"
      end
      -- RUF015	unnecessary-iterable-allocation-for-first-element	Prefer next({iterable}) over single element slice	✔️ 🛠️
      -- RUF016	invalid-index-type	Slice in indexed access to type {value_type} uses type {index_type} instead of an integer	✔️ 🛠️
      -- RUF017	quadratic-list-summation	Avoid quadratic list summation	✔️ 🛠️
      -- RUF018	assignment-in-assert	Avoid assignment expressions in assert statements	✔️ 🛠️
      -- RUF019	unnecessary-key-check	Unnecessary key check before dictionary access	✔️ 🛠️
      -- RUF020	never-union	{never_like} | T is equivalent to T	✔️ 🛠️
      -- RUF021	parenthesize-chained-operators	Parenthesize a and b expressions when chaining and and or together, to make the precedence clear	🧪 🛠️
      -- RUF022	unsorted-dunder-all	__all__ is not sorted	🧪 🛠️
      -- RUF023	unsorted-dunder-slots	{}.__slots__ is not sorted	🧪 🛠️
      -- RUF024	mutable-fromkeys-value	Do not pass mutable objects as values to dict.fromkeys	✔️ 🛠️
      -- RUF025	unnecessary-dict-comprehension-for-iterable	Unnecessary dict comprehension for iterable; use dict.fromkeys instead	🧪 🛠️
      -- RUF026	default-factory-kwarg	default_factory is a positional-only argument to defaultdict	✔️ 🛠️
      -- RUF027	missing-f-string-syntax	Possible f-string without an f prefix	🧪 🛠️
      -- RUF028	invalid-formatter-suppression-comment	This suppression comment is invalid because {}	🧪 🛠️
      -- RUF029	unused-async	Function {name} is declared async, but doesn't await or use async features.	🧪 🛠️
      -- RUF030	assert-with-print-message	print() expression in assert statement is likely unintentional	🧪 🛠️
      -- RUF100	unused-noqa	Unused noqa directive	✔️ 🛠️
      -- RUF101	redirected-noqa	{original} is a redirect to {target}	🧪 🛠️
      -- RUF200	invalid-pyproject-toml	Failed to parse pyproject.toml: {message}	✔️ 🛠️
    end
  end

  return message
end

return M
