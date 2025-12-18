#Requires AutoHotkey v2.0
#SingleInstance Force

; Hotkey: Ctrl + Shift + Alt + T
^+!t::ScreenshotAndTranslate(720)  ; pass 720, or "" to disable resize

ScreenshotAndTranslate(maxHeight := "") {
    ; 1) Screenshot -> clipboard (image)
    if !CaptureCurrentMonitorToClipboard("active", maxHeight) {
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
    ; when it's fully loaded, the URL changes from op=images to op=translate
    if !WaitChromeUrlContains("op=translate", 5, clipImage) {
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


CaptureCurrentMonitorToClipboard(mode := "mouse", maxHeight := "") {
    rect := GetMonitorRect(mode)
    if !rect {
        MsgBox "Couldn't determine monitor rect."
        return false
    }
    return CaptureRectToClipboard(rect.L, rect.T, rect.W, rect.H, maxHeight)
}

GetMonitorRect(mode := "mouse") {
    if (mode = "mouse") {
        MouseGetPos &x, &y
        return MonitorRectFromPoint(x, y)
    } else if (mode = "active") {
        WinGetPos &wx, &wy, &ww, &wh, "A"
        cx := wx + ww//2
        cy := wy + wh//2
        return MonitorRectFromPoint(cx, cy)
    }
    return false
}

MonitorRectFromPoint(x, y) {
    count := MonitorGetCount()
    Loop count {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (x >= L && x < R && y >= T && y < B) {
            return { L:L, T:T, W:(R-L), H:(B-T) }
        }
    }
    return false
}

CaptureRectToClipboard(L, T, W, H, maxHeight := "") {
    if (W <= 0 || H <= 0)
        return false

    newW := W, newH := H
    if (maxHeight != "" && H > maxHeight) {
        newH := maxHeight
        newW := Round(W * (maxHeight / H))
    }

    ; Screen DC
    hdcScreen := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !hdcScreen
        return false

    ; Source DC/bitmap
    hdcSrc := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbmSrc := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", W, "Int", H, "Ptr")
    obmSrc := DllCall("gdi32\SelectObject", "Ptr", hdcSrc, "Ptr", hbmSrc, "Ptr")

    ; Copy from screen into source bitmap
    SRCCOPY := 0x00CC0020
    ok := DllCall("gdi32\BitBlt"
        , "Ptr", hdcSrc, "Int", 0, "Int", 0, "Int", W, "Int", H
        , "Ptr", hdcScreen, "Int", L, "Int", T
        , "UInt", SRCCOPY)

    if !ok {
        ; cleanup
        DllCall("gdi32\SelectObject", "Ptr", hdcSrc, "Ptr", obmSrc)
        DllCall("gdi32\DeleteObject", "Ptr", hbmSrc)
        DllCall("gdi32\DeleteDC", "Ptr", hdcSrc)
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
        return false
    }

    ; If no resize needed, use hbmSrc. Else StretchBlt into a new bitmap.
    hbmFinal := hbmSrc
    if (newW != W || newH != H) {
        hdcDst := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hbmDst := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", newW, "Int", newH, "Ptr")
        obmDst := DllCall("gdi32\SelectObject", "Ptr", hdcDst, "Ptr", hbmDst, "Ptr")

        ; better downscale quality
        DllCall("gdi32\SetStretchBltMode", "Ptr", hdcDst, "Int", 4) ; HALFTONE

        DllCall("gdi32\StretchBlt"
            , "Ptr", hdcDst, "Int", 0, "Int", 0, "Int", newW, "Int", newH
            , "Ptr", hdcSrc, "Int", 0, "Int", 0, "Int", W, "Int", H
            , "UInt", SRCCOPY)

        ; restore/destroy dst dc selection
        DllCall("gdi32\SelectObject", "Ptr", hdcDst, "Ptr", obmDst)
        DllCall("gdi32\DeleteDC", "Ptr", hdcDst)

        ; We'll put hbmDst on clipboard, and we can delete hbmSrc after
        hbmFinal := hbmDst
    }

    ; restore src dc selection
    DllCall("gdi32\SelectObject", "Ptr", hdcSrc, "Ptr", obmSrc)
    DllCall("gdi32\DeleteDC", "Ptr", hdcSrc)
    DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    ; If we created a resized bitmap, delete the original
    if (hbmFinal != hbmSrc)
        DllCall("gdi32\DeleteObject", "Ptr", hbmSrc)

    ; Put bitmap on clipboard
    if !DllCall("user32\OpenClipboard", "Ptr", 0) {
        DllCall("gdi32\DeleteObject", "Ptr", hbmFinal)
        return false
    }
    DllCall("user32\EmptyClipboard")

    CF_BITMAP := 2
    ; After SetClipboardData succeeds, the system owns the handle -> do NOT delete it.
    if !DllCall("user32\SetClipboardData", "UInt", CF_BITMAP, "Ptr", hbmFinal, "Ptr") {
        DllCall("user32\CloseClipboard")
        DllCall("gdi32\DeleteObject", "Ptr", hbmFinal)
        return false
    }
    DllCall("user32\CloseClipboard")
    return true
}
