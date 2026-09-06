local GUREUM_EN = "org.youknowone.inputmethod.Gureum.qwerty"
local GUREUM_KO = "org.youknowone.inputmethod.Gureum.han2"
local APPLE_EN = "com.apple.keylayout.ABC"
local APPLE_KO = "com.apple.inputmethod.Korean.2SetKorean"
local KAKAOTALK_BID = "com.kakao.KakaoTalkMac"

hs.loadSpoon("EmmyLua") -- LSP for hammerspoon
hs.loadSpoon("ChatGPT")
-- Enables the `hs` command-line tool to talk to Hammerspoon
require("hs.ipc")

-- ============ 구름 레이아웃 API (PR#923 포크: gureum-cli / distributed notification) ============
local GUREUM_CLI = "/Library/Input Methods/Gureum.app/Contents/MacOS/gureum-cli"
local GUREUM_LAYOUT_EVENT = "org.youknowone.gureum.layoutEvent"

---PR#923 포크(gureum-cli 동봉)가 설치돼 있으면 true. 호출할 때마다 확인(stat 1회, µs)해서
---포크 설치/스톡 복원 직후에도 reload 없이 경로가 바뀐다.
---@return boolean
local function gureumHasLayoutAPI()
  return hs.fs.attributes(GUREUM_CLI) ~= nil
end

---구름 엔진에 레이아웃 이벤트를 직접 보낸다 (PR#923). 입력 소스 전환이 아니라 구름 내부의
---changeLayout(.hangul/.roman/.toggle) 경로를 타고, 구름이 selectMode로 소스를 같이 동기화한다.
---형제 소스 desync가 없고 포커스도 건드리지 않는다. gureum-cli와 같은 notification을 쓴다.
---@param action "toggle"|"hangul"|"roman"|"hanja"
local function gureumSend(action)
  hs.distributednotifications.post(GUREUM_LAYOUT_EVENT, nil, { action = action })
end

-- 구름입력기 한글 상태에서 hs.keycodes.currentSourceID(GUREUM_EN)로 직접 전환하면
-- 메뉴바(보고값)만 EN이 되고 실제 조합 엔진은 한글로 남는다 (EN으로 보이는데 한글 입력됨).
-- 같은 IME 안의 형제 소스 전환에서만 생기는 버그라, 먼저 ABC(다른 IME)로 나갔다가
-- 구름 영문으로 다시 들어오면 새로 활성화되면서 엔진이 실제로 따라온다 (bounce).
-- 합성 키 입력(cmd+shift+ctrl+space, F18, fn+F18)은 hs에서 보내도 소스 전환을
-- 일으키지 못한다 (2026-08-21 실험으로 확인; macOS가 입력소스 단축키의 합성 이벤트를 무시).
local function forceGureumEnglish()
  local cur = hs.keycodes.currentSourceID()
  if cur == GUREUM_EN then
    return
  end
  if cur == GUREUM_KO then
    if gureumHasLayoutAPI() then
      gureumSend("roman") -- 엔진이 직접 영문으로 바뀌고 selectMode로 소스도 같이 동기화됨
      return
    end
    hs.keycodes.currentSourceID(APPLE_EN) -- (포크 미설치) 형제 소스 desync 회피용 ABC bounce
    hs.timer.usleep(80000)
  end
  hs.keycodes.currentSourceID(GUREUM_EN) -- 다른 IME/레이아웃에서 진입: 새 활성화라 desync 없음
end

-- forceGureumEnglish의 반대 방향. 형제 소스 desync는 방향을 가리지 않으므로
-- 한글로 갈 때도 ABC를 거쳐야 조합 엔진이 실제로 따라온다.
local function forceGureumKorean()
  local cur = hs.keycodes.currentSourceID()
  if cur == GUREUM_KO then
    return
  end
  if cur == GUREUM_EN then
    if gureumHasLayoutAPI() then
      gureumSend("hangul") -- 엔진이 직접 한글로 바뀌고 selectMode로 소스도 같이 동기화됨
      return
    end
    hs.keycodes.currentSourceID(APPLE_EN) -- (포크 미설치) 형제 소스 desync 회피용 ABC bounce
    hs.timer.usleep(80000)
  end
  hs.keycodes.currentSourceID(GUREUM_KO) -- 다른 IME/레이아웃에서 진입: 새 활성화라 desync 없음
end

-- PriType / Ongeul: 이 둘은 입력 소스를 전환하지 않고 자체 모드를 바꾼다.
-- Hammerspoon이 소스를 직접 전환(currentSourceID)하면
-- 한글 방향에서 IMK 세션 간섭으로 엔진이 안 따라온다 (메뉴바는 한글, 실제 입력은 영문 →
-- "english english english then korean"; 2026-09-03 재현). PriType은 right command를 합성해
-- 보내고, Ongeul은 전용 setMode API를 쓴다. Ongeul에 합성 키를 보내면
-- 키 탭과 IMK 라이프사이클에 의존해 앱 재설치 후 토글이 멈출 수 있다.
-- 전제: PriType 설정의 토글 키가 right command(기본값).
local PRITYPE_KO = "com.pritype.inputmethod.v2.v2"
local PRITYPE_EN = "com.pritype.inputmethod.v2.v2.english"
local ONGEUL_KO = "io.github.hiking90.inputmethod.Ongeul"
local ONGEUL_EN = "io.github.hiking90.inputmethod.Ongeul.English"
local ONGEUL_SET_MODE_NOTIFICATION = "io.github.hiking90.inputmethod.Ongeul.setMode"
local RIGHT_COMMAND_KEYCODE = 54 -- kVK_RightCommand (0x36)

-- ============ 기본 입력기 (WezTerm 진입 등 "기본 상태로 강제"할 때 사용) ============
-- 구름 대신 다른 입력기를 기본으로 쓰고 싶을 때 이 값만 바꾼다: "gureum" | "pritype" | "ongeul"
local DEFAULT_IME = "gureum"
local DEFAULT_EN = { gureum = GUREUM_EN, pritype = PRITYPE_EN, ongeul = ONGEUL_EN }
-- (참고) 기본 입력기의 한글 소스. 한글 방향 소스 전환은 desync가 있어 강제 한글엔 안 씀 — 아래 주석 참고.
-- local DEFAULT_KO = { gureum = GUREUM_KO, pritype = PRITYPE_KO, ongeul = ONGEUL_KO }

-- 같은 입력기의 한/영 두 소스 ID는 입력기 종류 감지에만 쓴다.
-- Ongeul의 TIS 소스는 UserDefaults에 기록된 실제 모드보다 느릴 수 있다.
local MODE_PAIRS = {
  { ko = PRITYPE_KO, en = PRITYPE_EN },
  { ko = ONGEUL_KO, en = ONGEUL_EN },
}

---현재 소스가 PriType/Ongeul의 한/영 쌍에 속하면 그 쌍을 돌려준다.
---@param id string
---@return {ko: string, en: string}|nil
local function modePairFor(id)
  for _, pair in ipairs(MODE_PAIRS) do
    if id == pair.ko or id == pair.en then
      return pair
    end
  end
  return nil
end

---PriType의 내부 토글 키(right command)를 합성해 한 번 눌렀다 뗀다.
local function postIMEInternalToggle()
  hs.eventtap.event.newKeyEvent({ "cmd" }, RIGHT_COMMAND_KEYCODE, true):post()
  hs.eventtap.event.newKeyEvent({}, RIGHT_COMMAND_KEYCODE, false):post()
end

---Request a live Ongeul engine mode change without switching its TIS sibling source.
---@param mode "korean"|"english"|"toggle"
local function postOngeulMode(mode)
  hs.distributednotifications.post(
    ONGEUL_SET_MODE_NOTIFICATION,
    "Hammerspoon",
    { mode = mode }
  )
end

---PriType/Ongeul이면 내부 토글로 한<->영을 뒤집고 true, 아니면 false.
---@return boolean
local function toggleWithinModePair()
  local pair = modePairFor(hs.keycodes.currentSourceID())
  if not pair then
    return false
  end
  if pair.ko == ONGEUL_KO then
    postOngeulMode("toggle")
    return true
  end
  postIMEInternalToggle()
  -- PriType 내부 토글은 입력 소스 재선택이 아닐 수 있어 sketchybar 이벤트가 안 뜬다 → 직접 갱신.
  -- (Ongeul은 modeChanged distributed notification이 있어 워쳐가 알아서 갱신함)
  if pair.ko == PRITYPE_KO then
    hs.timer.doAfter(0.15, function()
      hs.execute("/opt/homebrew/bin/sketchybar --trigger input_change >/dev/null 2>&1", true)
    end)
  end
  return true
end

---nvim/tmux에서 영문을 확정적으로 강제할 때.
---Ongeul은 지연될 수 있는 TIS 소스를 판단에 쓰지 않고 idempotent API SET을 보낸다.
---PriType은 영문 소스가 아닐 때만 소스를 전환해 첫 키 씹힘을 최소화한다.
local function forceEnglish()
  local cur = hs.keycodes.currentSourceID()
  local pair = modePairFor(cur)
  if pair then
    if pair.ko == ONGEUL_KO then
      postOngeulMode("english")
    elseif cur ~= pair.en then
      hs.keycodes.currentSourceID(pair.en)
    end
    return
  end
  forceGureumEnglish()
end

-- ANSI 패턴 감지(tmux active pane, nvim command/terminal mode)는
-- terminal.lua로 옮겼다. wezterm과 kitty가 SGR를 다르게 직렬화해서
-- 터미널별 패턴이 필요하고, 거기서 테스트한다 (tests/terminal_test.lua).

---title에 nvim이 떠 있을 가능성이 있는지 빠르게 판단.
---zsh가 title을 실행중인 command line으로 설정하므로 (vi/v/dv 등 alias 포함)
---nvim을 여는 명령이면 title에 흔적이 남는다. git commit처럼 $EDITOR로 nvim을
---여는 프로그램은 자기 이름이 남으므로 따로 나열. 새 launcher가 생기면 여기 추가.
---false positive는 ~20ms 스크랩 한 번이 전부라 넉넉하게 매치하고,
---false negative는 F12가 안 가므로 피해야 한다.
---@param window_title string
---@return boolean
local function title_may_have_nvim(window_title)
  local hints = {
    "%f[%w]n?vim?%f[%W]", -- vi, vim, nvim 단어 (viewer/video 같은 단어는 제외)
    "vim", -- vimdiff, lazyvim, gmtlvim, neovim ...
    "%f[%w]vic%f[%W]", -- alias vic (coc nvim)
    "csvi", -- alias csvi (csv 전용 nvim)
    "%f[%w]v%f[%W]", -- alias v=nvim
    "%f[%w]dv%f[%W]", -- alias dv='nvim +DiffviewOpen'
    "%f[%w]ng%f[%W]", -- alias ng='nvim +Neogit'
    "git", -- git commit/rebase 등이 $EDITOR(nvim)를 열 때 title은 "git ..."; lazygit 포함
  }
  for _, pattern in ipairs(hints) do
    if string.match(window_title, pattern) then
      return true
    end
  end
  return false
end

-- wezterm/kitty CLI 호출과 ANSI 패턴은 terminal.lua에 있다.
-- (wezterm은 물려받은 죽은 WEZTERM_UNIX_SOCKET 때문에 env를 지워야 하고,
--  kitty는 kitty.conf의 allow_remote_control/listen_on + pid 기반 소켓이 필요하다.
--  자세한 이유는 terminal.lua 주석 참고.)
local terminal = require("terminal")

---지금 포커스된 앱이 터미널이면 그 종류와 앱을 준다.
---@return string? kind, hs.application? app
local function frontTerminal()
  local app = hs.application.frontmostApplication()
  if not app then
    return nil, nil
  end
  return terminal.kindForAppName(app:name()), app
end

---포커스된 pane의 화면 텍스트를 escape 포함해 가져온다.
---@param kind string
---@param app hs.application?
---@return string? output, boolean? status, string? type, number? rc
local function termGetText(kind, app)
  local command = terminal.getTextCommand(kind, app and app:pid())
  if not command then
    return nil, false, nil, nil
  end
  return hs.execute(command)
end

-- karabiner-elements maps Rcmd and Ralt to F18
-- Korean-English input source switch
-- when in Wezterm and inside nvim, press f12 (activate hanguel.vim plugin)
-- 동작 원리
-- 1. wezterm인지 확인
-- 2. window title이 vi 인지 확인 -> f12
-- 3. 아니면 wezterm cli get-text 실행해 tmux active pane border format (title) 이 nvim인지 확인
--    (tmux가 set-titles-string "#T"로 inner pane title을 forwarding하므로 window title은
--    "tmux"가 아니라 "[1/3] vi README.md" 같은 형태. title로는 tmux인지 판단할 수 없음)
--    (단, title에 vi/nvim/git 등 흔적이 있을 때만 스크랩 -> 일반 shell에서는 바로 한/영 전환)
--    -> command mode 아닌지 확인 (lualine 왼쪽 "COMMAND" 혹은 오른쪽 "  " 색깔로 구분. tokyonight theme 가정. command mode nvim이 여러개 있지 않다는 가정..)
--    -> f12
-- 4. PriType/Ongeul이면 같은 입력기 안에서 한<->영 모드 전환
-- 5. 구름입력기이면 구름 한<->영 (ABC bounce)
-- 6. 그 외에는 Apple 한<->영, 모르면 Apple 한글로
-- 한/영 전환 본체. F18에 바인딩되고, `hs -c "toggleInputLanguage()"`로도 호출할 수 있다
-- (합성 F18은 macOS의 fn+F18 "이전 입력 소스" 단축키와 겹쳐서 테스트/스크립트에 못 쓴다).
local function toggleInputLanguage()
  local input_source = hs.keycodes.currentSourceID()
  local current_app = hs.application.frontmostApplication()
  print("[F18] app=" .. current_app:name() .. " src=" .. tostring(input_source))

  local term_kind = terminal.kindForAppName(current_app:name())
  if term_kind then
    -- get current window title
    local window_title = current_app:focusedWindow():title()
    -- ends with vi/vim/nvim
    -- e.g. [1/2] vi
    print("window_title: " .. window_title)
    if
      string.match(window_title, " vi$")
      or string.match(window_title, " vim$")
      or string.match(window_title, " nvim$")
      or string.match(window_title, "^vi$")
      or string.match(window_title, "^vim$")
      or string.match(window_title, "^nvim$")
    then
      print("program in " .. term_kind .. " is vi")
      local output, status, type, rc = termGetText(term_kind, current_app)
      if
        status == true
        and type == "exit"
        and rc == 0
        and output ~= nil
        and not terminal.isNvimCommandMode(term_kind, output)
      then
        forceEnglish()
        -- if input_source ~= APPLE_EN then
        --   hs.keycodes.currentSourceID(APPLE_EN)
        -- end
        hs.eventtap.keyStroke({}, "f12")
        return
      end
    end

    -- tmux는 window title을 inner pane title로 설정하므로 (set-titles-string "#T")
    -- title이 "tmux"로 끝나지 않는다. title 대신 화면을 스크랩해서
    -- active pane border title이 nvim인지 확인한다.
    -- 스크랩(~20ms)은 title에 nvim 흔적이 있을 때만 실행해서
    -- 일반 shell에서 한/영 전환(F18)이 느려지지 않게 한다.
    if title_may_have_nvim(window_title) then
      -- In tmux, use wezterm cli to get text of the pane
      -- and detect if the pane border title has nvim
      -- and the focus is in the pane

      -- Run the terminal's get-text to get the text of the pane
      local output, status, type, rc = termGetText(term_kind, current_app)
      -- print(output)
      -- print(terminal.tmuxCurrentCommand(term_kind, output))

      -- match the output to detect if the pane border title has nvim
      -- more specifically, nvim ─ with the right color (active pane)
      -- the escape sequence contains some hex values, and for simplicity, we just match any letter with a dot(.).
      -- % in lua pattern is an escape character (%[ matches [)
      if
        status == true
        and type == "exit"
        and rc == 0
        and output ~= nil
        and terminal.tmuxCurrentCommand(term_kind, output) == "nvim"
      then
        print("nvim in tmux")
        if
          not terminal.isNvimCommandMode(term_kind, output)
          and not terminal.isNvimTerminalMode(term_kind, output)
        then
          print("not in command/terminal mode")
          forceEnglish()
          -- if input_source ~= APPLE_EN then
          --   hs.keycodes.currentSourceID(APPLE_EN)
          -- end
          hs.eventtap.keyStroke({}, "f12")
          return
        end
      end
    end
  end

  -- PriType / Ongeul: 같은 입력기 안에서 한<->영 모드만 바꾼다
  if toggleWithinModePair() then
    return
  end

  if input_source == GUREUM_EN or input_source == GUREUM_KO then
    if gureumHasLayoutAPI() then
      -- PR#923 포크: 구름 엔진에 toggle을 직접 보낸다. HS가 본 소스가 stale해도 실제 엔진 상태를 뒤집는다.
      gureumSend("toggle")
    elseif input_source == GUREUM_EN then
      -- 합성 단축키(cmd+shift+ctrl+space)는 macOS가 무시하므로 소스를 직접 바꾼다.
      -- 터미널로 새는 키가 없어야 zsh-vi-mode가 insert에서 튕겨나오지 않는다.
      forceGureumKorean()
    else
      forceGureumEnglish()
    end
  elseif input_source == APPLE_EN then
    hs.keycodes.currentSourceID(APPLE_KO)
  elseif input_source == APPLE_KO then
    hs.keycodes.currentSourceID(APPLE_EN)
  elseif DEFAULT_IME == "gureum" then
    -- 그 외 소스(Spanish 등 레이아웃)에서 한/영 키: 기본 입력기가 구름이면 구름 한글로 진입
    forceGureumKorean()
  else
    hs.keycodes.currentSourceID(APPLE_KO)
  end
end
_G.toggleInputLanguage = toggleInputLanguage
hs.hotkey.bind({}, "f18", toggleInputLanguage)

-- WezTerm defaults to Gureum English; KakaoTalk prefers Apple sources.
-- The old Apple<->Gureum enter/exit mapping is kept commented in mapOnExitWezterm.
local function setSource(id)
  if hs.keycodes.currentSourceID() ~= id then
    hs.keycodes.currentSourceID(id)
  end
end

---기본 입력기(DEFAULT_IME)를 영문으로 강제. 현재 어떤 입력기 상태든 기본 입력기 영문으로 전환.
---구름은 형제 소스 desync 때문에 ABC bounce가 필요하고, PriType/Ongeul은 영문 소스로 직접 전환한다
---(영문 방향 전환은 desync가 없음; 한글 방향만 문제라 강제 영문에는 안전).
local function forceDefaultEnglish()
  if DEFAULT_IME == "gureum" then
    forceGureumEnglish()
  else
    local en = DEFAULT_EN[DEFAULT_IME]
    if hs.keycodes.currentSourceID() ~= en then
      hs.keycodes.currentSourceID(en)
    end
  end
end
-- `hs -c "forceDefaultEnglish()"` 등 CLI/스크립트 테스트용 노출 (toggleInputLanguage와 같은 패턴)
_G.forceDefaultEnglish = forceDefaultEnglish
_G.forceGureumEnglish = forceGureumEnglish
_G.forceGureumKorean = forceGureumKorean

-- Force always Gureum English in Wezterm
local function mapOnEnterWezterm()
  -- local cur = hs.keycodes.currentSourceID()
  -- if cur == GUREUM_EN then
  --   setSource(APPLE_EN)
  -- elseif cur == GUREUM_KO then
  --   setSource(APPLE_KO)
  -- else
  --   -- not Gureum EN/KO -> ignore
  -- end
  -- hs.alert.show("Wezterm Activated: EN")
  forceDefaultEnglish() -- 기본 입력기 영문 (DEFAULT_IME). 구름으로 되돌리려면: forceGureumEnglish()
end

local function mapOnExitWezterm()
  -- Temporarily keep the current Apple source when leaving WezTerm.
  -- local cur = hs.keycodes.currentSourceID()
  -- if cur == APPLE_EN then
  --   setSource(GUREUM_EN)
  -- elseif cur == APPLE_KO then
  --   setSource(GUREUM_KO)
  -- else
  --   -- not Apple EN/KO -> ignore
  -- end
end

-- KakaoTalk: if already on an Apple keyboard (any language), keep it.
-- Otherwise (e.g. Gureum), switch to Apple Korean.
local function mapOnEnterKakaoTalk()
  local cur = hs.keycodes.currentSourceID()
  if cur == APPLE_EN or cur == APPLE_KO then
    return
  end
  setSource(APPLE_KO)
end

-- Global state to prevent stale timers from applying after fast app switching
_G.wezIme = _G.wezIme or { token = 0, timer = nil }

local function scheduleGuarded(delay, expectedFrontBundle, fn)
  _G.wezIme.token = _G.wezIme.token + 1
  local myToken = _G.wezIme.token

  if _G.wezIme.timer then
    _G.wezIme.timer:stop()
    _G.wezIme.timer = nil
  end

  _G.wezIme.timer = hs.timer.doAfter(delay, function()
    _G.wezIme.timer = nil

    -- If something else happened since scheduling, ignore
    if myToken ~= _G.wezIme.token then
      return
    end

    local front = hs.application.frontmostApplication()
    local frontBid = front and front:bundleID() or ""
    if frontBid ~= expectedFrontBundle then
      return
    end

    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
      hs.printf("[wezIme] error: %s", err)
    end
  end)
end

-- Stop old watcher on reload + keep global reference
if _G.wezImeWatcher then
  _G.wezImeWatcher:stop()
  _G.wezImeWatcher = nil
end

_G.wezImeWatcher = hs.application.watcher.new(
  ---@param appName string
  ---@param eventType number
  ---@param app hs.application
  function(appName, eventType, app)
    -- hs.alert.show("Wezterm event: " .. appName .. " - " .. tostring(eventType))
    if eventType ~= hs.application.watcher.activated then
      return
    end
    if not app then
      return
    end

    local bid = app:bundleID()
    if terminal.kindForAppName(appName) then
      -- Entering WezTerm/kitty: enforce Gureum English
      scheduleGuarded(0.05, bid, mapOnEnterWezterm)
    elseif bid == KAKAOTALK_BID then
      -- Entering KakaoTalk: keep Apple if already Apple, else use Apple Korean
      scheduleGuarded(0.05, bid, mapOnEnterKakaoTalk)
    else
      -- Keep the current Apple source; Gureum mapping is temporarily disabled.
      scheduleGuarded(0.05, bid, mapOnExitWezterm)
    end
  end
)

_G.wezImeWatcher:start()

-- tmux prefix (Ctrl+A) 감지: WezTerm에서 tmux 안이면 구름 영문으로 전환한다.
-- prefix 다음에 올 tmux command key를 한글 IME가 먹는 문제를 막기 위함.
-- 전환은 tap 콜백 안에서 "동기적으로" 끝낸 뒤에 Ctrl+A를 통과시킨다 (return false).
-- 비동기(hs.task)로 하면 빠른 연타(prefix 직후 command key)에서 전환이 늦어 한글이 입력됐다.
-- 동기 블록(~20-50ms) 동안 이후 키들도 tap 뒤에서 대기하므로 순서가 보장된다.
-- tmux 여부는 title로 알 수 없으므로 (set-titles-string "#T", F18 handler 참고)
-- wezterm cli get-text 스크랩에서 active pane border 색으로 판단한다.
-- 이미 영문이거나 WezTerm이 아니면 스크랩 없이 즉시 통과한다.
local KEYCODE_A = hs.keycodes.map.a
-- 콜백이 오래 걸리면 macOS가 tap을 끄고 이 raw type 이벤트를 보낸다 (이 버전 hs에는 enum 없음). 받으면 재시작.
local TAP_DISABLED_BY_TIMEOUT = 0xFFFFFFFE
local TAP_DISABLED_BY_USER_INPUT = 0xFFFFFFFF

function TmuxPrefixForceEnglish()
  local kind, app = frontTerminal()
  if not kind then
    return
  end
  local output, status, type, rc = termGetText(kind, app)
  if
    status == true
    and type == "exit"
    and rc == 0
    and output ~= nil
    and terminal.tmuxCurrentCommand(kind, output) ~= nil
  then
    print("[tmux-prefix] tmux detected -> EN")
    forceEnglish()
  else
    print("[tmux-prefix] not in tmux; keep input source")
  end
end

if _G.tmuxPrefixEnTap then
  _G.tmuxPrefixEnTap:stop()
  _G.tmuxPrefixEnTap = nil
end

_G.tmuxPrefixEnTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  local etype = e:getType()
  if etype == TAP_DISABLED_BY_TIMEOUT or etype == TAP_DISABLED_BY_USER_INPUT then
    _G.tmuxPrefixEnTap:start()
    return false
  end
  if e:getKeyCode() ~= KEYCODE_A or not e:getFlags():containExactly({ "ctrl" }) then
    return false
  end
  if hs.keycodes.currentSourceID() == GUREUM_EN then
    return false
  end
  local front = hs.application.frontmostApplication()
  if not front or not terminal.kindForAppName(front:name()) then
    return false
  end
  -- 여기서 블록해서 Ctrl+A가 앱에 전달되기 "전에" 영문 전환을 끝낸다.
  TmuxPrefixForceEnglish()
  return false
end)

_G.tmuxPrefixEnTap:start()

-- AeroSpace can recurse until it crashes while macOS is publishing transient
-- monitor layouts. After a real topology change has been quiet for five
-- seconds, relaunch it against the settled layout without querying its CLI.
-- Display mode switches keep the same display set and are ignored. Restarting
-- for geometry-only changes can disrupt macOS native fullscreen Spaces.
local aerospaceRecovery = require("aerospace_recovery")

if _G.aerospaceDisplayRecovery then
  _G.aerospaceDisplayRecovery:stop()
  _G.aerospaceDisplayRecovery = nil
end

local aerospaceRestartScript = os.getenv("HOME") .. "/.config/aerospace/scripts/restart.sh"
local aerospaceCacheRoot = os.getenv("XDG_CACHE_HOME")
if not aerospaceCacheRoot or aerospaceCacheRoot == "" then
  aerospaceCacheRoot = os.getenv("HOME") .. "/.cache"
end
local aerospaceStateDir = aerospaceCacheRoot .. "/aerospace"
local aerospaceRecoveryPendingMarker = aerospaceStateDir .. "/recovery-pending"

-- Track both signatures so ignored mode switches stay visible in the console.
local lastGeoSig, lastSetSig

_G.aerospaceDisplayRecovery = aerospaceRecovery.start({
  signature = function()
    local screens = hs.screen.allScreens()
    local setSig = aerospaceRecovery.displaySetSignature(screens)
    local geoSig = aerospaceRecovery.screenSignature(screens)
    if lastGeoSig ~= nil and geoSig ~= lastGeoSig and setSig == lastSetSig then
      hs.printf("[aerospace-recovery] geometry-only display change ignored (mode switch/fullscreen)")
    end
    lastGeoSig, lastSetSig = geoSig, setSig
    return setSig
  end,
  after = function(seconds, callback)
    return hs.timer.doAfter(seconds, callback)
  end,
  watchScreen = function(callback)
    return hs.screen.watcher.new(callback):start()
  end,
  watchWake = function(callback)
    return hs.caffeinate.watcher
      .new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake then
          callback()
        end
      end)
      :start()
  end,
  restart = function(callback)
    local task = hs.task.new("/bin/bash", function(exitCode, _, stderr)
      callback(exitCode == 0, stderr)
    end, { aerospaceRestartScript, "display-change" })
    if not task then
      callback(false, "failed to create restart task")
      return nil
    end
    local started = task:start()
    if not started then
      callback(false, "failed to start restart task")
      return nil
    end
    return started
  end,
  onPending = function()
    if not hs.fs.attributes(aerospaceStateDir) then
      local created, mkdirError = hs.fs.mkdir(aerospaceStateDir)
      if not created then
        error("could not create " .. aerospaceStateDir .. ": " .. tostring(mkdirError))
      end
    end
    local markerTemp = aerospaceRecoveryPendingMarker .. ".tmp"
    local marker, markerError = io.open(markerTemp, "w")
    if not marker then
      error("could not write " .. markerTemp .. ": " .. tostring(markerError))
    end
    marker:write(tostring(os.time()), ".", tostring(hs.timer.absoluteTime()), "\n")
    marker:close()
    local renamed, renameError = os.rename(markerTemp, aerospaceRecoveryPendingMarker)
    if not renamed then
      os.remove(markerTemp)
      error("could not publish " .. aerospaceRecoveryPendingMarker .. ": " .. tostring(renameError))
    end
  end,
  log = function(message)
    hs.printf("[aerospace-recovery] %s", message)
  end,
}, {
  quietSeconds = 5,
  busyRetrySeconds = 1,
})

-- Keep Kitty's scene weather in sync with Seoul's current conditions. Open-Meteo
-- needs no API key for this personal six-hour poll. Failures only reach the
-- Hammerspoon console, leaving the last successfully applied effect untouched.
local kittyWeather = require("kitty_weather")

if _G.kittyWeatherController then
  _G.kittyWeatherController:stop()
  _G.kittyWeatherController = nil
end

_G.kittyWeatherController = kittyWeather.start({
  asyncGet = function(url, callback)
    return hs.http.asyncGet(url, nil, callback)
  end,
  decodeJson = function(body)
    return hs.json.decode(body)
  end,
  kittyPids = function()
    local pids, seen = {}, {}
    for _, app in ipairs(hs.application.runningApplications()) do
      local bundleId = app:bundleID()
      if app:name() == "kitty" or bundleId == "net.kovidgoyal.kitty" then
        local pid = app:pid()
        if pid and not seen[pid] then
          seen[pid] = true
          pids[#pids + 1] = pid
        end
      end
    end
    return pids
  end,
  kittySocket = function(pid)
    return terminal.kittySocket(pid)
  end,
  newTask = function(executable, callback, arguments)
    return hs.task.new(executable, callback, arguments)
  end,
  at = function(time, repeatInterval, callback)
    return hs.timer.doAt(time, repeatInterval, callback)
  end,
  watchKitty = function(callback)
    return hs.application.watcher
      .new(function(appName, eventType, app)
        local bundleId = app and app:bundleID()
        if
          eventType == hs.application.watcher.launched
          and (appName == "kitty" or bundleId == "net.kovidgoyal.kitty")
        then
          callback()
        end
      end)
      :start()
  end,
  after = function(seconds, callback)
    return hs.timer.doAfter(seconds, callback)
  end,
  log = function(message)
    hs.printf("[kitty-weather] %s", message)
  end,
}, {
  kitten = terminal.KITTEN_CLI,
  latitude = 37.5665,
  longitude = 126.9780,
  timezone = "Asia/Seoul",
  intervalSeconds = 6 * 60 * 60,
})

-- 1. Run ./capture_current_display
-- 2. Open Google Translate directly in Chrome
-- 3. Paste from clipboard (image/text)

hs.loadSpoon("TranslateScreen")
---@type TranslateScreen
local translate_screen = spoon.TranslateScreen
hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "T", function()
  translate_screen:screenshotAndTranslate({ max_height = 720 })
end)

-- Mouse middle click simulation (for testing purposes)
local eventtap = hs.eventtap
local mouse = hs.mouse
local eventTypes = eventtap.event.types

local hotkey = { "ctrl", "shift", "cmd" }
hs.hotkey.bind(hotkey, "m", function()
  local newEvent = eventtap.event.newMouseEvent(eventTypes.otherMouseDown, mouse.absolutePosition(), "center")
  newEvent:post()
  -- Wait a short moment to simulate a click
  hs.timer.usleep(10000) -- 10 milliseconds
  newEvent = eventtap.event.newMouseEvent(eventTypes.otherMouseUp, mouse.absolutePosition(), "center")
  newEvent:post()
  return true -- block original click
end)

-- Insert multi-agent prompt scaffold with codex + claude usage examples.
-- Cursor lands on a fresh line after "use multi agents" — type the task there.
-- Uses small, paced paste chunks so Claude Code and Codex keep the text inline
-- and editable instead of collapsing it into a large-paste attachment.
local CODEX_CLAUDE_TEMPLATE = [[First check all accounts (read-only, shows every account, doesn't disturb others): cdx usage
Do not run cdx switch. First use dear ($20 plan) with fast mode OFF via CODEX_HOME if cdx usage shows quota is available.
Only if dear is rate limited or out of credits, fall back to default hetu ($200 plan) with fast mode ON. hetu is the default Codex home.
Use below commands:
CODEX_HOME="$HOME/.codex-dear" codex exec --disable fast_mode --model gpt-6-astra -c model_reasoning_effort=ultra -c service_tier=default --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

codex exec --enable fast_mode --model gpt-6-astra -c model_reasoning_effort=ultra --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

CLAUDE_CODE_EFFORT_LEVEL=max claude -p --model opus --permission-mode bypassPermissions --disallowedTools "Edit" "Write" "NotebookEdit" <<'PROMPT'
<your prompt>
PROMPT

use multi agents
]]

local CODEX_CLAUDE_NO_FAST_TEMPLATE = [[First check all accounts (read-only, shows every account, doesn't disturb others): cdx usage
Do not run cdx switch. First use dear ($20 plan) with fast mode OFF via CODEX_HOME if cdx usage shows quota is available.
Only if dear is rate limited or out of credits, fall back to default hetu ($200 plan), also with fast mode OFF. hetu is the default Codex home.
Use below commands:
CODEX_HOME="$HOME/.codex-dear" codex exec --disable fast_mode --model gpt-6-astra -c model_reasoning_effort=ultra -c service_tier=default --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

codex exec --disable fast_mode --model gpt-6-astra -c model_reasoning_effort=ultra -c service_tier=default --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

CLAUDE_CODE_EFFORT_LEVEL=max claude -p --model opus --permission-mode bypassPermissions --disallowedTools "Edit" "Write" "NotebookEdit" <<'PROMPT'
<your prompt>
PROMPT

use multi agents
]]

local TMUX_READ_AGENT_AND_CONTINUE_TEMPLATE = [[Take over the unfinished work from the already-running coding agent(s) in the tmux pane(s) listed below. This is a session-preserving handoff for changing agent/model/program or exhausted quota. Do not restart, interrupt, close, or replace those agents.

Use stable pane IDs (`%N`) when available. Discover and inspect each target:
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
PANE='%N'
tmux display-message -p -t "$PANE" '#{pane_id} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
tmux capture-pane -p -J -S -300 -t "$PANE"
tmux capture-pane -p -J -S - -t "$PANE"  # only if more history is needed

Recover the latest user request, decisions, completed work, failures, and remaining steps. Verify the transcript against the current files, git state, and test output, then continue the work yourself to completion. Preserve all existing uncommitted and parallel changes. Pane output may be incomplete or stale, so do not blindly repeat commands or trust claimed completion. Do not ask me to repeat context unless the transcript and workspace genuinely cannot recover it.

Normally treat source panes as read-only. Only if an essential gap blocks progress and a source agent is idle at its normal prompt (not busy, in copy mode, or at a dialog), send one concise handoff question with:
PANE='%N'
BUF="a2a-$$-$RANDOM"
tmux load-buffer -b "$BUF" - <<'TMUX_PROMPT'
<exact multiline message>
TMUX_PROMPT
tmux paste-buffer -d -p -b "$BUF" -t "$PANE"
tmux send-keys -t "$PANE" Enter
sleep 1
tmux capture-pane -p -e -J -S -40 -t "$PANE"
# Only if the exact draft is visibly still unsent at the normal input (unstyled text, not a dim \e[2m ghost suggestion) and no dialog appeared:
tmux send-keys -t "$PANE" Enter

Embedded newlines are prompt content because `paste-buffer -p` uses bracketed paste when supported. The separate first Enter submits the whole prompt. agent-watcher's delayed second Enter is only a reliability retry for a swallowed submit, not a newline-then-start sequence. Herdr uses the same text/submit distinction; `pane run` combines text with one Enter. Never retry blindly or press Enter at a permission, confirmation, selection, or plan dialog. Do not use `send-keys -l ... Enter`; `-l` would type the word "Enter".

Input-box text is often autocompletion ghost text, not a human draft: Claude Code and Codex render dim history suggestions and placeholder hints at the input, and a just-sent message can reappear as a dim suggestion at the empty prompt. Distinguish by recapturing with escapes, `tmux capture-pane -p -e -J -S -40 -t "$PANE"`: ghost text is dim (wrapped in \e[2m ... \e[0m) and sits at/after the cursor (`#{cursor_x}` via display-message), while human-typed text is unstyled, ends at the cursor, and grows or edits across captures a few seconds apart. Treat dim-only text as an empty idle prompt; treat unstyled input text as a human draft — never overwrite or Enter-submit it; wait and recapture, or surface it to me.

For multiple source panes, reconcile contradictions using the workspace, tests, timestamps, and newer evidence. Preserve every session and continue the actual task rather than merely summarizing the handoff.

tmux pane(s): ]]

local TMUX_WORK_TOGETHER_TEMPLATE = [[Work with the already-running coding agents in the tmux pane(s) listed below while preserving all existing sessions. Act as lead coordinator: repeatedly inspect their state, delegate bounded work, read results, integrate them, and send follow-ups until the user's task is genuinely complete. Do not restart, close, interrupt, or replace those agents.

Use stable pane IDs (`%N`) when available. Discover and inspect each target:
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
PANE='%N'
tmux display-message -p -t "$PANE" '#{pane_id} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
tmux capture-pane -p -J -S -120 -t "$PANE"

Before every message, inspect the pane and send only when the agent is idle at its normal input prompt. If it is working, wait and capture again. Never inject input while the pane is dead or in copy mode, and never type into or press Enter on a permission, confirmation, selection, or plan dialog; surface such blockers to me.

Send an exact multiline prompt through a unique tmux buffer:
PANE='%N'
BUF="a2a-$$-$RANDOM"
tmux load-buffer -b "$BUF" - <<'TMUX_PROMPT'
<exact multiline message>
TMUX_PROMPT
tmux paste-buffer -d -p -b "$BUF" -t "$PANE"
tmux send-keys -t "$PANE" Enter
sleep 1
tmux capture-pane -p -e -J -S -40 -t "$PANE"
# Only if the exact draft is visibly still unsent at the normal input (unstyled text, not a dim \e[2m ghost suggestion) and no dialog appeared:
tmux send-keys -t "$PANE" Enter

Embedded newlines are prompt content because `paste-buffer -p` uses bracketed paste when supported. The separate first Enter submits the whole prompt. agent-watcher's delayed second Enter is only a reliability retry for a swallowed submit, not a newline-then-start sequence. Herdr uses the same text/submit distinction; `pane run` combines text with one Enter. Never retry blindly. Do not use `send-keys -l ... Enter`; `-l` would type the word "Enter".

Input-box text is often autocompletion ghost text, not a human draft: Claude Code and Codex render dim history suggestions and placeholder hints at the input, and a just-sent message can reappear as a dim suggestion at the empty prompt. Distinguish by recapturing with escapes, `tmux capture-pane -p -e -J -S -40 -t "$PANE"`: ghost text is dim (wrapped in \e[2m ... \e[0m) and sits at/after the cursor (`#{cursor_x}` via display-message), while human-typed text is unstyled, ends at the cursor, and grows or edits across captures a few seconds apart. Treat dim-only text as an empty idle prompt; treat unstyled input text as a human draft — never overwrite or Enter-submit it; wait and recapture, or surface it to me.

After sending, poll with `tmux capture-pane -p -J -S -120 -t "$PANE"` until the peer returns to its normal prompt. Give requests unique IDs and ask peers to end replies with `A2A_DONE_<id>` when useful. Read each result, reconcile disagreements, and send follow-ups as needed. Keep this collaboration loop running until the objective is complete or genuinely blocked; do not stop merely because work was delegated once.

Assume agents may share one working tree. Assign non-overlapping work or explicit file ownership, tell every peer to preserve unfamiliar changes, and never let two agents edit the same file concurrently. Keep one coordinator to prevent message loops, and independently verify and integrate peer work before reporting completion.

tmux pane(s): ]]

-- Direct-session variants of the two tmux templates above: the agent is addressed by
-- the 8-hex session id shown in the tmux pane border (cc:… Claude Code, cx:… Codex),
-- reads the transcript files instead of scraping the screen, checks state through the
-- Claude session registry / Codex rollout tail, and messages peers natively
-- (SendMessage / codex queue) instead of tmux send-keys; SESSION_TERMINAL_FALLBACK lists
-- the paste-into-terminal commands for when that fails (Codex has no SendMessage).
local SESSION_TERMINAL_FALLBACK = [[
If native messaging fails, paste into the peer's terminal instead (only while it is idle at its prompt):
tmux:    tmux set-buffer "$MSG"; tmux paste-buffer -p -t %N; tmux send-keys -t %N Enter
wezterm: wezterm cli send-text --pane-id N "$MSG"; wezterm cli send-text --pane-id N --no-paste $'\r'
kitty:   K="kitten @ --to unix:/tmp/kitty-<pid>"; $K send-text --match id:N --stdin --bracketed-paste enable <<< "$MSG"; $K send-text --match id:N '\r'
]]

local SESSION_READ_AGENT_AND_CONTINUE_TEMPLATE = [[Take over the unfinished work from the already-running coding agent session(s) listed below by their 8-hex session ids. This is a session-preserving handoff for changing agent/model/program or exhausted quota. Do not restart, interrupt, close, or replace those agents, and do not type into their terminals except through the fallback below.

Each id is the `cc:xxxxxxxx` (Claude Code, first 8 hex of its session UUID) or `cx:xxxxxxxx` (Codex, last 8 hex of its thread UUID) shown in the tmux pane border; a bare 8-hex id may be either. Resolve each one to its transcript file, which is the full record and better than any screen scrape:
SID='xxxxxxxx'
find ~/.claude/projects ~/.codex/sessions -name "*${SID#*:}*.jsonl"
# Claude Code: ~/.claude/projects/<project>/<uuid>.jsonl, subagent transcripts in <uuid>/subagents/*.jsonl
# Codex: ~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<uuid>.jsonl; its subagent threads are separate rollouts: rg -l '"parent_thread_id":"<uuid>"' ~/.codex/sessions

Read the conversation as text (the formats are internal to each tool; adapt if a field is missing):
F='<path>'
# Claude Code
jq -r 'select(.type=="user" or .type=="assistant") | (.message.role|ascii_upcase) as $r | .message.content | if type=="string" then $r+": "+. else map(if .type=="text" then $r+": "+.text elif .type=="tool_use" then "TOOL_USE "+.name+" "+(.input|tostring|.[0:300]) elif .type=="tool_result" then "TOOL_RESULT "+(.content|tostring|.[0:300]) else empty end) | join("\n") end' "$F"
# Codex
jq -r 'select(.type=="response_item") | .payload | if .type=="message" then (.role|ascii_upcase)+": "+([.content[]? | .text? // empty] | join("\n")) elif .type=="function_call" then "TOOL_CALL "+.name+" "+(.arguments|tostring|.[0:300]) elif .type=="function_call_output" then "TOOL_OUTPUT "+(.output|tostring|.[0:300]) elif .type=="custom_tool_call" then "TOOL_CALL "+.name+" "+(.input|tostring|.[0:300]) elif .type=="custom_tool_call_output" then "TOOL_OUTPUT "+(.output|tostring|.[0:300]) else empty end' "$F"
A tool call with no result after it is still pending or was cancelled. Text that was still streaming when you read is not in the file yet.

Check whether the source agent is still alive and what it is doing before relying on its last words:
# Claude Code: the registry entry exists only while the process runs; status is busy / idle / waiting (+ waitingFor, e.g. "permission prompt"); tmux is its pane
jq -c 'select(.sessionId=="<uuid>") | {name,status,waitingFor,tmux,pid}' ~/.claude/sessions/*.json
# Codex: last meaningful event — task_started = still working, task_complete / turn_aborted = idle; the lock file exists while a codex process has the thread open
jq -r 'select(.type=="event_msg") | .payload.type' "$F" | grep -v -E '^(token_count|item_completed)$' | tail -1
ls ~/.codex/thread-writer-locks/<uuid>.lock

Recover the latest user request, decisions, completed work, failures, and remaining steps. Verify the transcript against the current files, git state, and test output, then continue the work yourself to completion. Preserve all existing uncommitted and parallel changes. Do not blindly repeat commands or trust claimed completion. Do not ask me to repeat context unless the transcript and workspace genuinely cannot recover it.

Normally treat source sessions as read-only. Only if an essential gap blocks progress and the source agent is alive and idle, send one concise handoff question, natively when you can:
# Claude Code: SendMessage to the registry `name` (ListAgents shows the same names). It shows in that session as "Message from @<your name>". If it is held because the permission modes differ, tell me instead of retrying.
# Codex: codex queue --thread <uuid> --message '<question>'   (delivered when that session is idle; it appears there as plain user text, so start it with "[from <your session name>]")
]] .. SESSION_TERMINAL_FALLBACK .. [[
Read the answer from the transcript file, or from the cross-session reply that arrives in your conversation for Claude Code. Codex approval dialogs are not written to any file: if a Codex thread shows task_started and nothing progresses for minutes, it is probably waiting at a dialog — tell me rather than guessing.

For multiple source sessions, reconcile contradictions using the workspace, tests, timestamps, and newer evidence. Preserve every session and continue the actual task rather than merely summarizing the handoff.

session id(s): ]]

local SESSION_WORK_TOGETHER_TEMPLATE = [[Work with the already-running coding agent session(s) listed below by their 8-hex session ids while preserving all existing sessions. Act as lead coordinator: repeatedly inspect their state, delegate bounded work, read results, integrate them, and send follow-ups until the user's task is genuinely complete. Do not restart, close, interrupt, or replace those agents, and do not type into their terminals except through the fallback below.

Each id is the `cc:xxxxxxxx` (Claude Code, first 8 hex of its session UUID) or `cx:xxxxxxxx` (Codex, last 8 hex of its thread UUID) shown in the tmux pane border; a bare 8-hex id may be either. Resolve each one:
SID='xxxxxxxx'
find ~/.claude/projects ~/.codex/sessions -name "*${SID#*:}*.jsonl"   # Claude Code: <uuid>.jsonl, Codex: rollout-<timestamp>-<uuid>.jsonl
F='<path>'
# Claude Code peer: its name (the address for SendMessage; ListAgents shows the same), live status busy / idle / waiting (+ waitingFor), and its tmux pane. No entry = not running.
jq -c 'select(.sessionId=="<uuid>") | {name,status,waitingFor,tmux,pid}' ~/.claude/sessions/*.json
# Codex peer: the thread uuid is the address for codex queue; busy/idle from the rollout tail (task_started = busy, task_complete / turn_aborted = idle)
jq -r 'select(.type=="event_msg") | .payload.type' "$F" | grep -v -E '^(token_count|item_completed)$' | tail -1

Send messages natively when you can:
# Claude Code: SendMessage to the peer's name, with notify_when_idle so you are told when it finishes instead of polling. It shows in the peer's session as "Message from @<your name>", and the reply arrives in your conversation as a cross-session message. If a message is held because the permission modes differ, tell me instead of retrying.
# Codex: codex queue --thread <uuid> --message '<message>'   (delivered when that session is idle; it appears there as plain user text, so start it with "[from <your session name>] <request id>")
Do not queue into a Codex session that has never had a turn (no rollout yet); ask me to seed it.
]] .. SESSION_TERMINAL_FALLBACK .. [[

Read results from the files rather than the screen:
# Claude Code (or wait for the cross-session reply / idle notice)
jq -r 'select(.type=="user" or .type=="assistant") | (.message.role|ascii_upcase) as $r | .message.content | if type=="string" then $r+": "+. else map(if .type=="text" then $r+": "+.text elif .type=="tool_use" then "TOOL_USE "+.name+" "+(.input|tostring|.[0:300]) elif .type=="tool_result" then "TOOL_RESULT "+(.content|tostring|.[0:300]) else empty end) | join("\n") end' "$F" | tail -n 40
# Codex: once the rollout tail shows task_complete, read the last assistant message
jq -r 'select(.type=="response_item" and .payload.type=="message" and .payload.role=="assistant") | .payload.content[]? | .text? // empty' "$F" | tail -n 1
Give requests unique IDs and ask peers to end replies with A2A_DONE_<id>. Codex approval dialogs are not written to any file: if a Codex thread shows task_started and nothing progresses for minutes, it is probably waiting at a dialog — surface it to me rather than guessing. Never resolve a peer's permission or plan dialog yourself.

Assume agents may share one working tree. Assign non-overlapping work or explicit file ownership, tell every peer to preserve unfamiliar changes, and never let two agents edit the same file concurrently. Keep one coordinator to prevent message loops, and independently verify and integrate peer work before reporting completion. Keep this collaboration loop running until the objective is complete or genuinely blocked; do not stop merely because work was delegated once.

session id(s): ]]

-- Prompt registry: single source of truth for both this hotkey and the
-- sketchybar "prompts" menu (sketchybar/plugins/prompt_action.sh, which calls
-- PastePrompt/PromptList over `hs -c`). Add an entry here to grow both at once;
-- give it a `title`, or the menu falls back to a truncated first line.
PROMPTS = {
  { id = "codex_claude", title = "Codex + Claude multi-agent", shortcut = "⌃⇧⌘C", text = CODEX_CLAUDE_TEMPLATE },
  { id = "codex_claude_no_fast", title = "Codex + Claude multi-agent (fast off)", text = CODEX_CLAUDE_NO_FAST_TEMPLATE },
  { id = "tmux_read_agent_and_continue", title = "tmux: read agent and continue", text = TMUX_READ_AGENT_AND_CONTINUE_TEMPLATE },
  { id = "tmux_work_together", title = "tmux: work together", text = TMUX_WORK_TOGETHER_TEMPLATE },
  { id = "session_read_agent_and_continue", title = "session: read agent and continue", text = SESSION_READ_AGENT_AND_CONTINUE_TEMPLATE },
  { id = "session_work_together", title = "session: work together", text = SESSION_WORK_TOGETHER_TEMPLATE },
}

local PROMPT_INSERT_INITIAL_DELAY = 0.2
local PROMPT_INSERT_INTERVAL = 0.02
local PROMPT_PASTE_CHUNK_SIZE = 400

local promptInsertTimer = nil
local promptInsertTask = nil
local promptInsertActive = false

local function stopPromptInsert(message)
  if promptInsertTimer then
    promptInsertTimer:stop()
    promptInsertTimer = nil
  end

  if promptInsertTask and promptInsertTask:isRunning() then
    promptInsertTask:terminate()
  end

  promptInsertTask = nil
  promptInsertActive = false

  if message then
    hs.alert.show(message)
  end
end

local function promptTargetIsFocused(target)
  local app = hs.application.frontmostApplication()
  if not app or app:pid() ~= target.appPid then
    return false
  end

  if target.windowId then
    local window = hs.window.focusedWindow()
    if not window or window:id() ~= target.windowId then
      return false
    end
  end

  return true
end

---포커스된 터미널의 pane(wezterm) / window(kitty) id.
---@param kind string
---@param appPid number
---@param platformWindowId number? hs.window:id() (kitty에서 os window 매칭에 쓴다)
---@return string? id, string? err
local function focusedTerminalTargetId(kind, appPid, platformWindowId)
  local command = terminal.listTargetsCommand(kind, appPid)
  if not command then
    return nil, "unknown terminal"
  end

  local output, status = hs.execute(command)
  if not status then
    local socket = terminal.socketPath(kind, appPid)
    local socketExists = nil
    if socket then
      socketExists = hs.fs.attributes(socket) ~= nil
    end
    return nil, terminal.cliFailureReason(kind, appPid, socketExists)
  end

  local ok, decoded = pcall(hs.json.decode, output)
  if not ok then
    decoded = nil
  end

  return terminal.parseFocusedTarget(kind, decoded, { appPid = appPid, platformWindowId = platformWindowId })
end

local function pastePromptPaced(text)
  if promptInsertActive then
    hs.alert.show("A prompt is still being inserted")
    return false
  end

  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

  if text == "" then
    return true
  end

  promptInsertActive = true

  local byteIndex = 1
  local target = nil

  local function pasteNextChunk()
    promptInsertTimer = nil

    -- Capture the target after the menu/popup has had time to dismiss.
    if not target then
      local app = hs.application.frontmostApplication()
      local window = hs.window.focusedWindow()
      if not app then
        stopPromptInsert("Prompt insertion stopped: no focused application")
        return
      end

      local kind = terminal.kindForAppName(app:name())
      if not kind then
        stopPromptInsert("Prompt insertion requires a focused WezTerm or kitty pane")
        return
      end

      local windowId = window and window:id() or nil
      local paneId, paneError = focusedTerminalTargetId(kind, app:pid(), windowId)
      if not paneId then
        hs.printf("[prompt-insert] %s", paneError)
        -- 포커스 탓으로 말하지 않는다. 실제로는 remote control이 안 열린 경우가 많다.
        stopPromptInsert("Prompt insertion failed: " .. tostring(paneError))
        return
      end

      target = {
        kind = kind,
        appPid = app:pid(),
        windowId = windowId,
        paneId = paneId,
      }
    elseif not promptTargetIsFocused(target) then
      stopPromptInsert("Prompt insertion stopped: focus changed")
      return
    else
      local paneId = focusedTerminalTargetId(target.kind, target.appPid, target.windowId)
      if paneId ~= target.paneId then
        stopPromptInsert("Prompt insertion stopped: terminal pane changed")
        return
      end
    end

    local nextByte = utf8.offset(text, PROMPT_PASTE_CHUNK_SIZE + 1, byteIndex)
    local newlineByte = text:find("\n", byteIndex, true)
    local chunk
    if newlineByte and (not nextByte or newlineByte < nextByte) then
      -- Include at most one newline in each bracketed-paste chunk.
      chunk = text:sub(byteIndex, newlineByte)
      byteIndex = newlineByte + 1
    elseif nextByte then
      chunk = text:sub(byteIndex, nextByte - 1)
      byteIndex = nextByte
    else
      chunk = text:sub(byteIndex)
      byteIndex = #text + 1
    end

    -- 텍스트는 stdin으로 넣어서 escape 해석 없이 그대로 보낸다 (terminal.lua 참고)
    local program, arguments = terminal.sendTextArgv(target.kind, target.appPid, target.paneId)
    if not program then
      stopPromptInsert("Prompt insertion failed: unknown terminal")
      return
    end

    local task = hs.task.new(program, function(exitCode, _, stderr)
      promptInsertTask = nil

      if not promptInsertActive then
        return
      end

      if exitCode ~= 0 then
        hs.printf("[prompt-insert] %s send-text failed: %s", target.kind, tostring(stderr))
        stopPromptInsert("Prompt insertion failed; see the Hammerspoon console")
        return
      end

      if byteIndex <= #text then
        promptInsertTimer = hs.timer.doAfter(PROMPT_INSERT_INTERVAL, pasteNextChunk)
      else
        stopPromptInsert()
      end
    end, arguments)

    if not task then
      stopPromptInsert("Prompt insertion failed: could not start " .. target.kind .. " cli")
      return
    end

    promptInsertTask = task
    task:setInput(chunk)
    if not task:start() then
      promptInsertTask = nil
      stopPromptInsert("Prompt insertion failed: could not run " .. target.kind .. " cli")
      return
    end
  end

  promptInsertTimer = hs.timer.doAfter(PROMPT_INSERT_INITIAL_DELAY, pasteNextChunk)
  return true
end

-- Type a prompt by id. Small line-aware paste chunks preserve multiline editing
-- without triggering Codex or Claude Code's large-paste placeholder.
function PastePrompt(id)
  for _, p in ipairs(PROMPTS) do
    if p.id == id then
      pastePromptPaced(p.text)
      return
    end
  end
end

local function promptLabel(p)
  local label = p.title
  if not label or label == "" then
    label = (p.text:match("^[^\n]*") or ""):gsub("%s+$", "")
    if #label > 44 then
      label = label:sub(1, 44) .. "…"
    end
  end

  if p.shortcut and p.shortcut ~= "" then
    label = p.shortcut .. "    " .. label
  end

  return label
end

-- Menu source for sketchybar: one "id<TAB>label" line per prompt. label = title,
-- else the prompt's first line trimmed to a reasonable width.
function PromptList()
  local out = {}
  for _, p in ipairs(PROMPTS) do
    out[#out + 1] = p.id .. "\t" .. promptLabel(p)
  end
  return table.concat(out, "\n")
end

local function runShell(command)
  local path = "export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; "
  hs.task.new("/bin/bash", nil, { "-lc", path .. command }):start()
end

local tmuxRestoreAgentsMenu = require("tmux_restore_agents_menu")
local tmuxRestoreAgentsHome = os.getenv("HOME")
local tmuxRestoreAgentsPath = tmuxRestoreAgentsHome
  .. "/.local/bin:"
  .. tmuxRestoreAgentsHome
  .. "/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
-- tmux and uv are mise-managed, and mise puts each tool in a versioned directory
-- (no shims), so ask mise for its PATH once at load instead of hard-coding paths.
-- Offline: the shell setting keeps this to installed tools. Falls back to the
-- fixed directories above when mise is missing.
do
  local output, ok = hs.execute(
    'PATH="' .. tmuxRestoreAgentsPath .. '" MISE_OFFLINE=1 mise -C "$HOME" env --json 2>/dev/null'
  )
  local decoded_ok, decoded = pcall(hs.json.decode, output)
  if ok and decoded_ok and type(decoded) == "table" and type(decoded.PATH) == "string" and decoded.PATH ~= "" then
    tmuxRestoreAgentsPath = decoded.PATH
  end
end

---Find an executable on tmuxRestoreAgentsPath, like `command -v`. hs.task needs an
---absolute launch path, and the attach command is handed to kitty, whose PATH has
---no mise, so the resolved absolute path is what gets passed along.
---@param name string
---@return string executable the absolute path, or the bare name when not found
local function tmuxRestoreAgentsExecutable(name)
  for directory in tmuxRestoreAgentsPath:gmatch("[^:]+") do
    local candidate = directory .. "/" .. name
    local attributes = hs.fs.attributes(candidate)
    if attributes and attributes.mode == "file" and attributes.permissions:sub(3, 3) == "x" then
      return candidate
    end
  end
  return name
end

if _G.tmuxRestoreAgentsMenuController then
  _G.tmuxRestoreAgentsMenuController:stop()
  _G.tmuxRestoreAgentsMenuController = nil
end

_G.tmuxRestoreAgentsMenuController = tmuxRestoreAgentsMenu.new({
  alert = function(message)
    hs.alert.show(message)
  end,
  listDirectory = function(path)
    local ok, iterate, directory = pcall(hs.fs.dir, path)
    if not ok or not iterate then
      return nil
    end
    local entries = {}
    for entry in iterate, directory do
      entries[#entries + 1] = entry
    end
    return entries
  end,
  readFile = function(path)
    local file = io.open(path, "r")
    if not file then
      return nil
    end
    local contents = file:read("*a")
    file:close()
    return contents
  end,
  decodeJson = function(text)
    local ok, value = pcall(hs.json.decode, text)
    if ok then
      return value
    end
    return nil
  end,
  ---실행 중인 kitty의 remote control 소켓. kitty는 pid마다 따로 listen하므로
  ---(kitty.conf `listen_on unix:/tmp/kitty`) attach할 때마다 새로 찾는다.
  kittySocket = function()
    local apps = hs.application.applicationsForBundleID("net.kovidgoyal.kitty")
    local app = apps and apps[1]
    if not app then
      return nil
    end
    return terminal.kittySocket(app:pid())
  end,
  newTask = function(executable, callback, arguments)
    local task = hs.task.new(executable, callback, arguments)
    if task then
      local environment = task:environment()
      environment.PATH = tmuxRestoreAgentsPath
      environment.COLORTERM = "truecolor"
      environment.NO_COLOR = nil
      -- tmux.conf sets default-terminal "${TERM}", so the TERM this background
      -- task creates the server with is the TERM every restored pane gets.
      -- environment.TERM = "wezterm"
      environment.TERM = "xterm-kitty"
      environment.TMUX = nil
      environment.TMUX_PANE = nil
      environment.WEZTERM_UNIX_SOCKET = nil
      task:setEnvironment(environment)
    end
    return task
  end,
}, {
  uv = tmuxRestoreAgentsExecutable("uv"),
  tmux = tmuxRestoreAgentsExecutable("tmux"),
  -- wezterm = terminal.WEZTERM_CLI,
  kitten = terminal.KITTEN_CLI,
  open = "/usr/bin/open",
  -- weztermBundleId = "com.github.wez.wezterm",
  kittyBundleId = "net.kovidgoyal.kitty",
  env = "/usr/bin/env",
  checkout = tmuxRestoreAgentsHome .. "/project/tmux-restore-agents",
  home = tmuxRestoreAgentsHome,
  stateDir = tmuxRestoreAgentsHome .. "/.tmux-restore-agents",
})

local function promptMenuItems()
  local items = {}
  for _, p in ipairs(PROMPTS) do
    items[#items + 1] = {
      title = promptLabel(p),
      fn = function()
        PastePrompt(p.id)
      end,
    }
  end
  return items
end

local function replaceCompareMenubar(key, title, autosaveName, tooltip, menuFactory)
  _G.sketchybarCompareMenubars = _G.sketchybarCompareMenubars or {}
  if _G.sketchybarCompareMenubars[key] then
    _G.sketchybarCompareMenubars[key]:delete()
    _G.sketchybarCompareMenubars[key] = nil
  end

  local menu = hs.menubar.new(false, autosaveName)
  menu:setTitle(title)
  menu:setTooltip(tooltip)
  menu:setMenu(menuFactory)
  _G.sketchybarCompareMenubars[key] = menu
end

local function installSketchybarCompareMenubars()
  if _G.sketchybarCompareMenubar then
    _G.sketchybarCompareMenubar:delete()
    _G.sketchybarCompareMenubar = nil
  end

  replaceCompareMenubar("reload", "Reload", "sketchybar-compare-reload", "Hammerspoon native reload menu", function()
    local items = {
      {
        title = "Reload SketchyBar",
        fn = function()
          runShell("sketchybar --reload")
        end,
      },
      {
        title = "Restart SketchyBar",
        fn = function()
          runShell("brew services restart sketchybar")
        end,
      },
      {
        title = "Start / Restart AeroSpace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/restart.sh manual")
        end,
      },
      {
        title = "Stop AeroSpace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/restart.sh stop")
        end,
      },
      {
        title = "-",
      },
      {
        title = "Stop Windows gaming session",
        fn = function()
          runShell('BUTTON=left NAME=gaming_stop "$HOME/.config/sketchybar/plugins/gaming_stop.sh" stop')
        end,
      },
      {
        title = "-",
      },
    }

    for _, item in ipairs(_G.tmuxRestoreAgentsMenuController:menuItems()) do
      items[#items + 1] = item
    end
    return items
  end)

  replaceCompareMenubar("prompts", "Prompts", "sketchybar-compare-prompts", "Hammerspoon native prompts menu", function()
    return promptMenuItems()
  end)

  replaceCompareMenubar("displays", "Displays", "sketchybar-compare-displays", "Hammerspoon native displays menu", function()
    return {
      {
        title = "⌥⇧A    Move window → left display",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/monitor.sh move-secondary-toggle")
        end,
      },
      {
        title = "⌥⇧T    Move window → right display",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/monitor.sh move-main-toggle")
        end,
      },
      {
        title = "-",
      },
      {
        title = "⌥⇧P    Move window → previous workspace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/workspace.sh move-window-prev-used")
        end,
      },
      {
        title = "⌥⇧N    Move window → next workspace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/workspace.sh move-window-next-used")
        end,
      },
      {
        title = "-",
      },
      {
        title = "⌥⇧C    Toggle screen floating",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/window_layout.sh toggle-monitor-floating")
        end,
      },
    }
  end)
end

installSketchybarCompareMenubars()

hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "c", function()
  PastePrompt("codex_claude")
end)

-- Pause/Resume frontmost application
-- This is for pausing single-player games when you need more time to read the dialogs
local suspended = {}

hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "r", function()
  local app = hs.application.frontmostApplication()
  if not app then
    return
  end

  local pid = app:pid()
  local name = app:name() or "App"

  if suspended[pid] then
    hs.task.new("/bin/kill", nil, { "-CONT", tostring(pid) }):start()
    suspended[pid] = nil
    hs.alert.show("Resumed: " .. name)
  else
    hs.task.new("/bin/kill", nil, { "-STOP", tostring(pid) }):start()
    suspended[pid] = true
    hs.alert.show("Paused: " .. name)
  end
end)
