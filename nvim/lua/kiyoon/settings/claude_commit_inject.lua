-- lua/claude_commit.lua (Neovim 0.11+)
local M = {}

local APPEND_SYSTEM = [[
CRITICAL:
- Ignore any persistent memory/instructions that refer to other repositories or stale context.
- Only trust evidence from commands and files in the CURRENT repo you can verify (e.g., git rev-parse/status/diff/log/show).
- Output MUST contain ONLY the commit message and must start with the Conventional Commit header line.
- No preface, no explanations, no extra text.
]]

local function commit_prompt(language, draft)
  local prompt = ([[
You are in a local git repository. Thoroughly inspect the repo to understand context.
You MAY use:
- Read/Glob/Grep/LS to inspect files
- read-only git commands: git status, git diff, git log, git show

You MUST NOT run any git commands that change state (add/commit/push/pull/fetch/merge/rebase/reset/checkout/switch/cherry-pick/clean/rm/stash/tag/branch).

Task: Generate a full git commit message describing the current changes.

Hard requirements:
- Language: %s
- Output plain text only (no quotes, no code fences, no extra commentary).
- Subject line MUST be <= 75 characters total.
- Format exactly:
  <type>(<optional scope>): <subject>

  <body>

- Choose <type> from: docs, style, refactor, perf, test, build, ci, chore, revert, feat, fix
- If scope is unclear, omit it.
- Body MUST be detailed and enumerate ALL meaningful changes (bullets).
- End with: "Tests: <what ran or not run>"
]]):format(language)

  if draft and draft ~= "" then
    prompt = prompt .. "\n\nRewrite/improve this draft commit message (keep the same output format):\n"
    prompt = prompt .. draft .. "\n"
  end

  return prompt
end

local function insert_lines_at_top(lines)
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
end

-- local function insert_lines_at_cursor(lines)
--   local buf = vim.api.nvim_get_current_buf()
--   local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
--   local idx = row - 1 -- 0-based
--   vim.api.nvim_buf_set_lines(buf, idx, idx, false, lines)
-- end

local function get_visual_selection_text()
  local bufnr = vim.api.nvim_get_current_buf()
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local sline, scol = s[2], s[3]
  local eline, ecol = e[2], e[3]
  if sline == 0 or eline == 0 then
    return ""
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, sline - 1, eline, false)
  if #lines == 0 then
    return ""
  end

  lines[1] = string.sub(lines[1], scol)
  lines[#lines] = string.sub(lines[#lines], 1, ecol)
  return table.concat(lines, "\n")
end

local function run_claude(language, draft)
  local prompt = commit_prompt(language, draft)

  -- IMPORTANT: prompt must be right after -p.  [oai_citation:1‡Claude Code](https://code.claude.com/docs/en/cli-reference)
  local cmd = {
    "claude",
    "-p",
    prompt,
    "--output-format",
    "text",

    "--append-system-prompt",
    APPEND_SYSTEM, -- official flag  [oai_citation:2‡Claude Code](https://code.claude.com/docs/en/cli-reference)

    "--tools",
    "Bash,Read,Glob,Grep,LS",

    "--allowedTools",
    "Read",
    "Glob",
    "Grep",
    "LS",
    "Bash(git rev-parse:*)",
    "Bash(git status:*)",
    "Bash(git diff:*)",
    "Bash(git log:*)",
    "Bash(git show:*)",

    "--disallowedTools",
    "Bash(git add:*)",
    "Bash(git commit:*)",
    "Bash(git push:*)",
    "Bash(git pull:*)",
    "Bash(git fetch:*)",
    "Bash(git merge:*)",
    "Bash(git rebase:*)",
    "Bash(git reset:*)",
    "Bash(git checkout:*)",
    "Bash(git switch:*)",
    "Bash(git cherry-pick:*)",
    "Bash(git clean:*)",
    "Bash(git rm:*)",
    "Bash(git stash:*)",
    "Bash(git tag:*)",
    "Bash(git branch:*)",
  }

  vim.system(cmd, { text = true, cwd = vim.fn.getcwd() }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify("Claude Code failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local out = vim.trim(res.stdout or "")
      if out == "" then
        vim.notify("Claude returned empty output.", vim.log.levels.WARN)
        return
      end

      insert_lines_at_top(vim.split(out, "\n", { plain = true }))
      vim.notify("Inserted commit message from Claude Code.")
    end)
  end)
end

function M.setup()
  -- Only activate in gitcommit buffers
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function(ev)
      -- buffer-local commands (only in commit message buffer)
      vim.api.nvim_buf_create_user_command(ev.buf, "ClaudeCommitInject", function()
        vim.ui.select({ "English", "Korean" }, { prompt = "Commit message language: " }, function(lang)
          if not lang then
            return
          end
          run_claude(lang, nil)
        end)
      end, {})

      vim.api.nvim_buf_create_user_command(ev.buf, "ClaudeCommitRewrite", function()
        vim.ui.select({ "English", "Korean" }, { prompt = "Commit message language: " }, function(lang)
          if not lang then
            return
          end
          run_claude(lang, get_visual_selection_text())
        end)
      end, { range = true })

      -- buffer-local keymap: \ag to inject
      vim.keymap.set("n", "\\ag", function()
        vim.cmd("ClaudeCommitInject")
      end, { buffer = ev.buf, noremap = true, silent = true, desc = "Claude: inject commit msg" })

      -- (optional) visual-mode rewrite on \ag too:
      -- vim.keymap.set("v", "\\ag", function()
      --   vim.cmd("ClaudeCommitRewrite")
      -- end, { buffer = ev.buf, noremap = true, silent = true, desc = "Claude: rewrite commit msg" })
    end,
  })
end

return M
