local notify = require("kiyoon.notify").notify
-- require("lsp-inlayhints").setup()
--
-- vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
-- vim.api.nvim_create_autocmd("LspAttach", {
--   group = "LspAttach_inlayhints",
--   callback = function(args)
--     if not (args.data and args.data.client_id) then
--       return
--     end
--
--     local bufnr = args.buf
--     local client = vim.lsp.get_client_by_id(args.data.client_id)
--
--     if client.name == "null-ls" then
--       return
--     else
--       require("lsp-inlayhints").on_attach(client, bufnr)
--       -- if client.server_capabilities.inlayHintProvider then
--       --   vim.lsp.inlay_hint.enable(true)
--       -- end
--     end
--   end,
-- })

-- Bake inlay type hints into the buffer
-- Some functions taken from https://github.com/simrat39/inlay-hints.nvim
local function get_inlay_hint_params(client, bufnr, line)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = {
      start = {
        line = 0,
        character = 0,
      },
      ["end"] = {
        line = 0,
        character = 0,
      },
    },
  }

  if line == nil then
    local line_count = vim.api.nvim_buf_line_count(bufnr) - 1
    local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count, line_count + 1, true)

    params["range"]["end"]["line"] = line_count
    params["range"]["end"]["character"] =
      vim.lsp.util.character_offset(bufnr, line_count, #last_line[1], client.offset_encoding)
  else
    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, true)
    params["range"]["start"]["line"] = line
    params["range"]["end"]["line"] = line
    params["range"]["end"]["character"] =
      vim.lsp.util.character_offset(bufnr, line, #current_line[1], client.offset_encoding)
    -- vim.print(params)
  end

  return params
end

local function request_all_inlay_hints(client, bufnr, callback)
  client.request("textDocument/inlayHint", get_inlay_hint_params(client, bufnr), callback, bufnr)
end

local function request_current_line_inlay_hints(client, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  client.request("textDocument/inlayHint", get_inlay_hint_params(client, bufnr, current_line), callback, bufnr)
  -- output example:
  -- { {
  --   kind = 1,
  --   label = "-> list[Any]",
  --   paddingLeft = true,
  --   position = {
  --     character = 24,
  --     line = 29
  --   },
  --   textEdits = { {
  --       newText = " -> list[Any]",
  --       range = {
  --         ["end"] = {
  --           character = 24,
  --           line = 29
  --         },
  --         start = {
  --           character = 24,
  --           line = 29
  --         }
  --       }
  --     }, {
  --       newText = "\nfrom typing import Any",
  --       range = {
  --         ["end"] = {
  --           character = 9,
  --           line = 19
  --         },
  --         start = {
  --           character = 9,
  --           line = 19
  --         }
  --       }
  --     } }
  -- } }
end

-- Parses the result into a easily usable format
-- example:
-- {
--  ["12"] = { {
--      kind = "TypeHint",
--      label = "String"
--    } },
--  ["13"] = { {
--      kind = "TypeHint",
--      label = "usize"
--    } },
-- }
--
local function parse_hints(result)
  local map = {}

  if type(result) ~= "table" then
    return {}
  end

  for _, value in pairs(result) do
    local range = value.position
    local line = value.position.line
    local label = value.label

    local label_str = ""

    if type(label) == "string" then
      label_str = value.label
    elseif type(label) == "table" then
      for _, label_part in ipairs(label) do
        label_str = label_str .. label_part.value
      end
    end

    local kind = value.kind

    if map[line] ~= nil then
      table.insert(map[line], {
        label = label_str,
        kind = kind,
        range = range,
      })
    else
      map[line] = {
        { label = label_str, kind = kind, range = range },
      }
    end

    table.sort(map[line], function(a, b)
      return a.range.character < b.range.character
    end)
  end

  return map
end

local function inlay_type_hint_to_text_in_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if not next(clients) then
    notify("No active LSP clients", vim.log.levels.ERROR)
    return
  end

  for _, client in ipairs(clients) do
    if client.server_capabilities == nil or not client.server_capabilities.inlayHintProvider then
      goto continue
    end

    request_current_line_inlay_hints(client, function(err, result, ctx)
      if err then
        return
      end

      if not result or #result == 0 then
        notify("No inlay hints found", vim.log.levels.INFO)
        return
      end

      for _, value in ipairs(result) do
        vim.lsp.util.apply_text_edits(value.textEdits, bufnr, "utf-8")
      end
    end)

    ::continue::
  end
end

---Get the text of inlay hints and bake them into the current buffer without using textEdits
--- which will add imports if needed.
local function inlay_type_hint_to_text_in_buffer_wo_imports()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if not next(clients) then
    notify("No active LSP clients", vim.log.levels.ERROR)
    return
  end
  local current_line_num = vim.api.nvim_win_get_cursor(0)[1] - 1

  for _, client in ipairs(clients) do
    if client.server_capabilities == nil or not client.server_capabilities.inlayHintProvider then
      goto continue
    end

    request_current_line_inlay_hints(client, function(err, result, ctx)
      if err then
        return
      end

      local hints = parse_hints(result)
      if hints[current_line_num] == nil then
        return
      end

      for _, hint in ipairs(hints[current_line_num]) do
        if hint.kind == 1 then
          -- TypeHint
          local current_line = vim.api.nvim_buf_get_lines(ctx.bufnr, current_line_num, current_line_num + 1, true)[1]
          local line_with_hint = current_line:sub(1, hint.range.character)
            .. hint.label
            .. current_line:sub(hint.range.character + 1)
          vim.api.nvim_buf_set_lines(ctx.bufnr, current_line_num, current_line_num + 1, true, { line_with_hint })
        end
        break
      end
    end)

    ::continue::
  end
end

vim.keymap.set(
  "n",
  "<space>th",
  inlay_type_hint_to_text_in_buffer,
  { noremap = true, silent = true, desc = "Bake inlay type hints into the buffer" }
)
