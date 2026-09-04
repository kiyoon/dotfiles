// Event provider for the input_method item (spawned by sketchybarrc).
// Watches the current keyboard input source and triggers the sketchybar
// event `input_change` with INPUT_SOURCE_ID=<id> ONLY when it changes.
//
// Detection is EVENT-DRIVEN: the TIS distributed notifications
// (AppleSelectedInputSourcesChanged / TISNotifySelectedKeyboardInputSourceChanged)
// DO fire on this macOS (re-verified 2026-09-03), and the Ongeul fork posts
// io.github.hiking90.inputmethod.Ongeul.modeChanged on every 한/영 flip. Those
// drive the update. A slow 2s TIS poll remains only as a belt-and-braces safety
// net for any switch path that somehow emits no event (e.g. an IME internal
// mode flip that doesn't re-select the source).
import Carbon
import Foundation

let sketchybar = "/opt/homebrew/bin/sketchybar"

func currentID() -> String {
    let s = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}

// Ongeul(포크)이 한/영 모드를 UserDefaults + distributed notification으로 공표한다.
// 입력 소스는 늦게 갱신되므로, 여기서 modeChanged를 받아 즉시 반영하고 mode를
// 플러그인에 ONGEUL_MODE로 넘긴다. 초기값은 defaults에서 1회 읽는다.
let ongeulDomain = "io.github.hiking90.inputmethod.Ongeul"
var ongeulMode: String = {
    CFPreferencesAppSynchronize(ongeulDomain as CFString)
    return (CFPreferencesCopyAppValue("currentInputMode" as CFString, ongeulDomain as CFString) as? String) ?? ""
}()

var last = ""
func push(force: Bool = false) {
    let id = currentID()
    guard !id.isEmpty, force || id != last else { return }
    last = id
    let t = Process()
    t.executableURL = URL(fileURLWithPath: sketchybar)
    t.arguments = ["--trigger", "input_change", "INPUT_SOURCE_ID=\(id)", "ONGEUL_MODE=\(ongeulMode)"]
    try? t.run()
}

let dnc = DistributedNotificationCenter.default()
for name in ["AppleSelectedInputSourcesChangedNotification",
             "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"] {
    dnc.addObserver(forName: Notification.Name(name), object: nil, queue: nil) { _ in push() }
}
// Ongeul 포크의 즉시 모드 공표를 구독 → 소스 지연 없이 바 갱신.
dnc.addObserver(forName: Notification.Name(ongeulDomain + ".modeChanged"), object: nil, queue: nil) { note in
    if let m = (note.userInfo?["mode"] as? String) ?? (note.object as? String), !m.isEmpty {
        ongeulMode = m
    }
    push(force: true)
}

Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in push() }

// Exit when sketchybar is gone so reload-spawned copies don't accumulate
// (sketchybarrc also killalls before spawning).
Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    t.arguments = ["-x", "sketchybar"]
    t.standardOutput = Pipe()
    try? t.run()
    t.waitUntilExit()
    if t.terminationStatus != 0 { exit(0) }
}

RunLoop.main.run()
