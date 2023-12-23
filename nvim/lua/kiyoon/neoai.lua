local conventional_commit_prompt = function(language)
  local prompt = [[
    Generate a concise git commit message written in present tense for the following specifications and code diff:
    Message language: ]] .. language .. [[
    Do not wrap your message in quotes.
    Commit message must be a maximum of 75 characters.
    Exclude anything unnecessary such as translation. Your entire response will be passed directly into git commit.
    Code diff:
    ```
    ]] .. vim.fn.system "git diff --cached" .. [[
    ```

    The output response must be in format:
      <type>(<optional scope>): <commit message>

    Choose a type from the type-to-description JSON below that best describes the git diff:
      {
        'docs': 'Documentation only changes',
        'style': 'Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)',
        'refactor': 'A code change that neither fixes a bug nor adds a feature',
        'perf': 'A code change that improves performance',
        'test': 'Adding missing tests or correcting existing tests',
        'build': 'Changes that affect the build system or external dependencies',
        'ci': 'Changes to our CI configuration files and scripts',
        'chore': "Other changes that don't modify src or test files",
        'revert': 'Reverts a previous commit',
        'feat': 'A new feature',
        'fix': 'A bug fix'
      }
    ]]

  return prompt
end

local generate_commit_message = function(language)
  local prompt = [[
      Using the following git diff generate a consise and
      clear git commit message, with a short title summary
      that is 75 characters or less
  ]] .. " and you should generate commit message in " .. language .. [[:
  ]] .. [[
  ```
  ]] .. vim.fn.system "git diff --cached" .. [[
  ```
  And you shoud give me commit message immediately.
  And you don't need to explain unnecessary things.
  ]]

  return prompt
end

local generate_modified_commit_message = function(language)
  local buffer = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

  local start_line = vim.fn.line "'<"
  local end_line = vim.fn.line "'>"

  local lines_to_modify = {}
  for i = start_line, end_line do
    table.insert(lines_to_modify, lines[i])
  end

  local prompt = [[
      Here is an incomplete commit message that you need to modify:

      ```
  ]] .. table.concat(lines_to_modify, "\n") .. [[

      ```

      Using the following git diff generate a consise and
      clear and appropriate git commit message, with a short title summary
      that is 75 characters or less
  ]] .. " and you should generate commit message in " .. language .. [[:
  ]] .. [[
  ```
  ]] .. vim.fn.system "git diff --cached" .. [[
  ```

  * You SHOULD give me commit message immediately.
  * You DON'T NEED TO explain unnecessary things.
  ]]

  return prompt
end

local inject_commit_message = function()
  -- `vim.ui.select` function's behavior is asyncronous.
  --
  -- So, In order to generate commit message by selected language,
  -- we have to place `generate_commit_message` inside of `vim.ui.select` function's callback
  vim.ui.select({ "english", "korean" }, {
    prompt = "Select language: ",
  }, function(language)
    if language ~= nil then
      local prompt = conventional_commit_prompt(language)
      require("neoai").context_inject(prompt, nil, -1, -1) -- line -1 means first line (why though?)
    end
  end)
end

local textify_commit_message = function()
  vim.ui.select({ "english", "korean" }, {
    prompt = "Select language: ",
  }, function(language)
    if language ~= nil then
      local prompt = generate_modified_commit_message(language)
      local start_line = vim.fn.line "'<"
      local end_line = vim.fn.line "'>"
      require("neoai").context_inject(prompt, nil, start_line, end_line)
    end
  end)
end

vim.api.nvim_create_user_command("InjectCommitMessage", inject_commit_message, {})
vim.api.nvim_create_user_command("TextifyCommitMessage", textify_commit_message, { range = true })
