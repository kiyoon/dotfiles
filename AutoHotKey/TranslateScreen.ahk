#Requires AutoHotkey v2.0
#SingleInstance Force

; Hotkey: Ctrl + Shift + Alt + T
^+!t::ScreenshotAndTranslate(720)  ; pass 720, or "" to disable resize


ScreenshotAndTranslate(maxHeight := "") {
    ; 1) Screenshot -> clipboard (image)
    if !CaptureScreenToClipboard(maxHeight) {
        MsgBox "Screenshot failed."
        return
    }

    ; Save the image clipboard so we can temporarily copy the URL without losing the image
    clipImage := ClipboardAll()

    ; 2) Open Chrome to Google Translate (opens new tab if Chrome already running)
    url := "https://translate.google.com/?sl=auto&tl=en&op=images"
    Run 'chrome.exe "' url '"'

    ; 3) Wait for Chrome to be active
    if !WinWaitActive("ahk_exe chrome.exe", , 2) {
        MsgBox "Chrome did not activate."
        return
    }

    ; 4) Wait until the address bar URL matches (navigation barrier)
    if !WaitChromeUrlContains("translate.google.com", 5, clipImage) {
        ; Fallback: small delay
        Sleep 300
    }

    A_Clipboard := clipImage
    Send "{Esc}"
    Sleep 120
    ClickChromePage()
    Sleep 150
    Send "^v"
}


WaitChromeUrlContains(needle, timeoutSec := 5, clipToRestore := "") {
    deadline := A_TickCount + (timeoutSec * 1000)

    while (A_TickCount < deadline) {
        old := ClipboardAll()
        A_Clipboard := ""

        Send "^l"
        Sleep 30
        Send "^c"

        cur := ClipWait(0.2) ? A_Clipboard : ""

        ; IMPORTANT: get out of the address bar
        Send "{Esc}"

        ; Restore clipboard (image)
        A_Clipboard := (IsSet(clipToRestore) && clipToRestore != "") ? clipToRestore : old

        if InStr(cur, needle)
            return true

        Sleep 50
    }
    return false
}


ClickChromePage() {
    WinGetPos &x, &y, &w, &h, "ahk_exe chrome.exe"
    CoordMode "Mouse", "Screen"
    Click x + (w//2), y + 240
}


CaptureScreenToClipboard(maxHeight := "") {
    ; Uses PowerShell to capture Primary Screen and optionally downscale by height, then SetImage() into clipboard.
    ; This is fast and avoids temp files.

    ps :=
    (
    '$ErrorActionPreference="Stop";' .
    'Add-Type -AssemblyName System.Windows.Forms;' .
    'Add-Type -AssemblyName System.Drawing;' .
    '$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;' .
    '$bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height;' .
    '$g=[System.Drawing.Graphics]::FromImage($bmp);' .
    '$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);' .
    '$g.Dispose();' .
    (maxHeight != "" ?
        ('$mh=' maxHeight ';' .
         'if($bmp.Height -gt $mh){' .
         '$scale=$mh/$bmp.Height;' .
         '$nw=[int]($bmp.Width*$scale);' .
         '$nh=[int]$mh;' .
         '$bmp2=New-Object System.Drawing.Bitmap $nw,$nh;' .
         '$g2=[System.Drawing.Graphics]::FromImage($bmp2);' .
         '$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor;' .
         '$g2.DrawImage($bmp,0,0,$nw,$nh);' .
         '$g2.Dispose();' .
         '$bmp.Dispose();' .
         '$bmp=$bmp2;' .
         '}')
        : '') .
    '[System.Windows.Forms.Clipboard]::SetImage($bmp);' .
    '$bmp.Dispose();'
    )

    ; Run PowerShell hidden, wait until done (this is your "clipboard is ready" barrier)
    try {
        RunWait 'powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -Command "' ps '"', "", "Hide"
        return true
    } catch {
        return false
    }
}
