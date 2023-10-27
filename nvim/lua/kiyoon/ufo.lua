-- nvim-ufo (folding) configuration

-- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
vim.keymap.set("n", "zR", require("ufo").openAllFolds)
vim.keymap.set("n", "zM", require("ufo").closeAllFolds)

local handler = function(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = (" 󰁂 %d "):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, { chunkText, hlGroup })
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2nd argument, need padding
      if curWidth + chunkWidth < targetWidth then
        suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, { suffix, "MoreMsg" })
  return newVirtText
end

local ufo = require "ufo"
local function get_cell_folds(bufnr)
  local function handleFallbackException(err, providerName)
    if type(err) == "string" and err:match "UfoFallbackException" then
      return ufo.getFolds(bufnr, providerName)
    else
      return require("promise").reject(err)
    end
  end
  return ufo
    .getFolds(bufnr, "lsp")
    :catch(function(err)
      return handleFallbackException(err, "treesitter")
    end)
    :catch(function(err)
      return handleFallbackException(err, "indent")
    end)
    :thenCall(function(ufo_folds)
      local ok, jupynium = pcall(require, "jupynium")
      if ok then
        for _, fold in ipairs(jupynium.get_folds()) do
          table.insert(ufo_folds, fold)
        end
      end
      -- print(vim.inspect(ufo_folds))
      return ufo_folds
    end)
end

-- Option 3: treesitter as a main provider instead
-- Only depend on `nvim-treesitter/queries/filetype/folds.scm`,
-- performance and stability are better than `foldmethod=nvim_treesitter#foldexpr()`
ufo.setup {
  fold_virt_text_handler = handler,
  provider_selector = function(bufnr, filetype, buftype)
    if filetype == "python" then
      return get_cell_folds
    end
    return { "treesitter", "indent" }
  end,
}
