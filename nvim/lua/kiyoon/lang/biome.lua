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
    elseif code == "lint/style/useNamingConvention" then
      -- 🔗 [lint/style/useNamingConvention] This {const/let/object property} name should be in {camelCase} or {PascalCase}.
      -- 2nd form: This {} name should be in {}.
      local variable_type = message:match("This (.*) name should be in")
      if variable_type ~= nil then
        local naming_convention1, naming_convention2 = message:match("should be in (%w+) or (%w+)%.")
        if naming_convention1 == nil then
          local naming_convention = message:match("should be in ([A-Za-z0-9_-]+)%.")
          if lang == "es" then
            return "Este " .. variable_type .. " nombre debería estar en " .. naming_convention .. "."
          elseif lang == "pt-br" then
            return "Este " .. variable_type .. " nome deve estar em " .. naming_convention .. "."
          elseif lang == "fr" then
            return "Ce " .. variable_type .. " nom doit être en " .. naming_convention .. "."
          elseif lang == "it" then
            return "Questo " .. variable_type .. " nome deve essere in " .. naming_convention .. "."
          end
        else
          if lang == "es" then
            return "Este "
              .. variable_type
              .. " nombre debería estar en "
              .. naming_convention1
              .. " o "
              .. naming_convention2
              .. "."
          elseif lang == "pt-br" then
            return "Este "
              .. variable_type
              .. " nome deve estar em "
              .. naming_convention1
              .. " ou "
              .. naming_convention2
              .. "."
          elseif lang == "fr" then
            return "Ce "
              .. variable_type
              .. " nom doit être en "
              .. naming_convention1
              .. " ou "
              .. naming_convention2
              .. "."
          elseif lang == "it" then
            return "Questo "
              .. variable_type
              .. " nome deve essere in "
              .. naming_convention1
              .. " o "
              .. naming_convention2
              .. "."
          end
        end
      end
    end
  end

  return message
end

return M
