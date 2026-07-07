// Event provider for the input_method item (spawned by sketchybarrc).
// Watches the current keyboard input source and triggers the sketchybar
// event `input_change` with INPUT_SOURCE_ID=<id> ONLY when it changes.
//
// Detection is belt-and-braces: the TIS distributed notifications no longer
// fire on this macOS (tested with real switches), so the primary mechanism is
// an in-process TIS poll every 150ms -- that's a couple of library calls, no
// process spawns, negligible CPU -- with the notification observers kept in
// case a future macOS revives them.
import Carbon
import Foundation

let sketchybar = "/opt/homebrew/bin/sketchybar"

func currentID() -> String {
    let s = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}

var last = ""
func push() {
    let id = currentID()
    guard !id.isEmpty, id != last else { return }
    last = id
    let t = Process()
    t.executableURL = URL(fileURLWithPath: sketchybar)
    t.arguments = ["--trigger", "input_change", "INPUT_SOURCE_ID=\(id)"]
    try? t.run()
}

let dnc = DistributedNotificationCenter.default()
for name in ["AppleSelectedInputSourcesChangedNotification",
             "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"] {
    dnc.addObserver(forName: Notification.Name(name), object: nil, queue: nil) { _ in push() }
}

Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in push() }

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
