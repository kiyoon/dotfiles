// Prints the current keyboard input source ID, e.g.
//   org.youknowone.inputmethod.Gureum.han2
//   com.apple.keylayout.Brazilian-Pro
// Used by plugins/input_source.sh: `defaults read com.apple.HIToolbox` returns
// stale values from sketchybar-spawned processes (per-process cfprefsd cache),
// so ask the Text Input Services API directly instead.
import Carbon
let s = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
if let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) {
    print(Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String)
}
