local url_utils = require("kiyoon.utils.url")
local ls = require("luasnip")
local fmt = require("luasnip.extras.fmt").fmt
local extras = require("luasnip.extras")
local l = extras.lambda
local i = ls.insert_node
local c = ls.choice_node
local func_node = ls.function_node

local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node

-- require snippets
return {
  -- Get the directory of the script
  s("sdir", {
    t({
      [[SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )]],
      [[]],
    }),
  }),
  s("waitp", {
    t({
      [[# wait for shell's child process to exit]],
      [[shell_pid=]],
    }),
    i(1, "pid"),
    t({
      "",
      [[child_pid=$(ps -ef | awk -v shell_pid=$shell_pid '$3==shell_pid {print $2}')]],
      [[echo "child_pid: $child_pid"]],
      'while [[ -n "$child_pid" ]] && ps -p "$child_pid" > /dev/null; do',
      "\tsleep 1",
      [[done]],
      "",
    }),
    i(0),
  }),
  s("tmuxrun", {
    t({
      [[# Run multiple commands in a tmux session]],
      [[script_dir=$(dirname "$(realpath -s "$0")")]],
      [[sess=]],
    }),
    i(1, "session_name"),
    t({
      "",
      [[tmux new -d -s "$sess" -c "$script_dir"   # Use default directory as this script directory]],
      "",
      [[for window in {0..2}]],
      [[do]],
      "\t" .. [[# Window 0 or 1 may already exist so it will print error. Ignore that.]],
      "\t" .. [[tmux new-window -t "$sess:$window"]],
      "\t" .. [[command="CUDA_VISIBLE_DEVICES=$window ]],
    }),
    i(2, [[python train.py --arg $((window+1))]]),
    t({
      [["]],
      "\t" .. [[tmux send-keys -t "$sess:$window" "$command" Enter]],
      [[done]],
      [[]],
    }),
    i(0),
  }),
  s("tmuxp", {
    func_node(function()
      local content = url_utils.read_from_url(
        "https://gist.githubusercontent.com/kiyoon/8d9ab895d2f478cde2c7fec214d55dbb/raw/run_tmux_parallel.sh"
      )
      return content
    end, {}),
  }),
  s("tmuxps", {
    func_node(function()
      local content = url_utils.read_from_url(
        "https://gist.githubusercontent.com/kiyoon/8d9ab895d2f478cde2c7fec214d55dbb/raw/tmux_parallel_status.sh"
      )
      return content
    end, {}),
  }),
  s("orx", {
    -- For safe cd
    -- https://www.shellcheck.net/wiki/SC2164
    t({
      [[|| { echo "Failure"; exit 1; }]],
    }),
  }),
}
