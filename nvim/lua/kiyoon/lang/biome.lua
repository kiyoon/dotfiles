local lang = require("kiyoon.lang").lang

local M = {}

---Ensure translations are always in the order: es, pt-br, and fr
---@param code string
---@param message string
---@return string
M.translate_biome_message = function(code, message)
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
    elseif code == "lint/suspicious/noConsole" then
      -- 🔗 [lint/suspicious/noConsole] Don't use console.
      if lang == "es" then
        return "No uses console."
      elseif lang == "pt-br" then
        return "Não use console."
      elseif lang == "fr" then
        return "Ne pas utiliser console."
      elseif lang == "it" then
        return "Non usare console."
      end
    elseif code == "lint/correctness/useImportExtensions" then
      -- 🔗 [lint/correctness/useImportExtensions] Add a file extension for relative imports.
      if lang == "es" then
        return "Agrega una extensión de archivo para las importaciones relativas."
      elseif lang == "pt-br" then
        return "Adicione uma extensão de arquivo para importações relativas."
      elseif lang == "fr" then
        return "Ajouter une extension de fichier pour les importations relatives."
      elseif lang == "it" then
        return "Aggiungi un'estensione di file per le importazioni relative."
      end
    elseif code == "lint/correctness/noUndeclaredVariables" then
      -- 🔗 [lint/correctness/noUndeclaredVariables] The {} variable is undeclared.
      local variable = message:match("The (.*) variable is undeclared")
      if lang == "es" then
        return "La variable " .. variable .. " no está declarada."
      elseif lang == "pt-br" then
        return "A variável " .. variable .. " não está declarada."
      elseif lang == "fr" then
        return "La variable " .. variable .. " n'est pas déclarée."
      elseif lang == "it" then
        return "La variabile " .. variable .. " non è dichiarata."
      end
    elseif code == "lint/suspicious/noConsoleLog" then
      -- 🔗 [lint/suspicious/noConsoleLog] Don't use console.log.
      if lang == "es" then
        return "No uses console.log."
      elseif lang == "pt-br" then
        return "Não use console.log."
      elseif lang == "fr" then
        return "Ne pas utiliser console.log."
      elseif lang == "it" then
        return "Non usare console.log."
      end
    elseif code == "lint/style/noDefaultExport" then
      -- 🔗 [lint/style/noDefaultExport] Avoid default exports.
      if lang == "es" then
        return "Evita las exportaciones predeterminadas."
      elseif lang == "pt-br" then
        return "Evite exportações padrão."
      elseif lang == "fr" then
        return "Évitez les exportations par défaut."
      elseif lang == "it" then
        return "Evita le esportazioni predefinite."
      end
    elseif code == "lint/style/useTemplate" then
      -- 🔗 [lint/style/useTemplate] Template literals are preferred over string concatenation.
      if lang == "es" then
        return "Se prefieren las literales de plantilla sobre la concatenación de cadenas."
      elseif lang == "pt-br" then
        return "As literais de modelo são preferidas em relação à concatenação de strings."
      elseif lang == "fr" then
        return "Les littéraux de modèle sont préférés à la concaténation de chaînes."
      elseif lang == "it" then
        return "Le letterali del modello sono preferiti rispetto alla concatenazione di stringhe."
      end
    elseif code == "lint/style/useNumberNamespace" then
      -- 🔗 [lint/style/useNumberNamespace] Use {Number.parseInt} instead of the equivalent global.
      local method_name = message:match("Use (.*) instead of the equivalent global")
      if lang == "es" then
        return "Usa " .. method_name .. " en lugar del equivalente global."
      elseif lang == "pt-br" then
        return "Use " .. method_name .. " em vez do equivalente global."
      elseif lang == "fr" then
        return "Utilisez " .. method_name .. " au lieu de l'équivalent global."
      elseif lang == "it" then
        return "Usa " .. method_name .. " invece dell'equivalente globale."
      end
    elseif code == "lint/style/useExplicitLengthCheck" then
      -- 🔗 [lint/style/useExplicitLengthCheck] Use .length === 0 when checking .length is zero.
      if lang == "es" then
        return "Usa .length === 0 al verificar que .length es cero."
      elseif lang == "pt-br" then
        return "Use .length === 0 ao verificar que .length é zero."
      elseif lang == "fr" then
        return "Utilisez .length === 0 lors de la vérification que .length est zéro."
      elseif lang == "it" then
        return "Usa .length === 0 quando controlli che .length sia zero."
      end
    elseif code == "lint/suspicious/noEvolvingTypes" then
      -- 🔗 [lint/suspicious/noEvolvingTypes] The type of this variable may evolve implicitly to any type, including the any type.
      if lang == "es" then
        return "El tipo de esta variable puede evolucionar implícitamente a cualquier tipo, incluido el tipo any."
      elseif lang == "pt-br" then
        return "O tipo desta variável pode evoluir implicitamente para qualquer tipo, incluindo o tipo any."
      elseif lang == "fr" then
        return "Le type de cette variable peut évoluer implicitement vers n'importe quel type, y compris le type any."
      elseif lang == "it" then
        return "Il tipo di questa variabile può evolversi implicitamente in qualsiasi tipo, incluso il tipo any."
      end
    elseif code == "lint/style/useConst" then
      -- 🔗 [lint/style/useConst] This let declares a variable that is only assigned once.
      if lang == "es" then
        return "Este let declara una variable que solo se asigna una vez."
      elseif lang == "pt-br" then
        return "Este let declara uma variável que é atribuída apenas uma vez."
      elseif lang == "fr" then
        return "Ce let déclare une variable qui n'est assignée qu'une seule fois."
      elseif lang == "it" then
        return "Questo let dichiara una variabile che viene assegnata solo una volta."
      end
    elseif code == "lint/complexity/noExcessiveCognitiveComplexity" then
      -- 🔗 [lint/complexity/noExcessiveCognitiveComplexity] Excessive complexity of 95 detected (max: 30).
      local complexity, max = message:match("Excessive complexity of (%d+) detected %(max: (%d+)%)")
      if lang == "es" then
        return string.format("Complejidad excesiva de %s detectada (máx: %s).", complexity, max)
      elseif lang == "pt-br" then
        return string.format("Complexidade excessiva de %s detectada (máx: %s).", complexity, max)
      elseif lang == "fr" then
        return string.format("Complexité excessive de %s détectée (max: %s).", complexity, max)
      elseif lang == "it" then
        return string.format("Complessità eccessiva di %s rilevata (max: %s).", complexity, max)
      end
    elseif code == "lint/style/useBlockStatements" then
      -- 🔗 [use-block-statements] Block statements are preferred in this position.
      if lang == "es" then
        return "Se prefieren las declaraciones de bloque en esta posición."
      elseif lang == "pt-br" then
        return "As declarações de bloco são preferidas nesta posição."
      elseif lang == "fr" then
        return "Les déclarations de bloc sont préférées à cette position."
      elseif lang == "it" then
        return "Le dichiarazioni di blocco sono preferite in questa posizione."
      end
    elseif code == "lint/correctness/noUnusedFunctionParameters" then
      -- 🔗 [no-unused-function-parameters] This parameter is unused.
      if lang == "es" then
        return "Este parámetro no se usa."
      elseif lang == "pt-br" then
        return "Este parâmetro não é usado."
      elseif lang == "fr" then
        return "Ce paramètre n'est pas utilisé."
      elseif lang == "it" then
        return "Questo parametro non è usato."
      end
    elseif code == "lint/style/useImportType" then
      -- 🔗 [use-import-type] All these imports are only used as types.
      if lang == "es" then
        return "Todas estas importaciones solo se usan como tipos."
      elseif lang == "pt-br" then
        return "Todas essas importações são usadas apenas como tipos."
      elseif lang == "fr" then
        return "Toutes ces importations ne sont utilisées qu'en tant que types."
      elseif lang == "it" then
        return "Tutte queste importazioni sono utilizzate solo come tipi."
      end
    elseif code == "lint/style/useNamingConvention" then
      -- 🔗 [lint/style/useNamingConvention] This {const/let/object property} name should be in {camelCase} or {PascalCase}.
      vim.print(message)
      local naming_conventions = message:match("should be in (.*).")
      local variable_type = message:match("This (.*) name should be in")
      if variable_type ~= nil then
        if lang == "es" then
          return "Este "
            .. variable_type
            .. " nombre debería estar en "
            .. naming_conventions:gsub(" or ", " o ")
            .. "."
        elseif lang == "pt-br" then
          return "Este " .. variable_type .. " nome deve estar em " .. naming_conventions:gsub(" or ", " ou ") .. "."
        elseif lang == "fr" then
          return "Ce " .. variable_type .. " nom doit être en " .. naming_conventions:gsub(" or ", " ou ") .. "."
        elseif lang == "it" then
          return "Questo " .. variable_type .. " nome deve essere in " .. naming_conventions:gsub(" or ", " o ") .. "."
        end
      end
    end
  end

  return message
end

return M
