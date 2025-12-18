#Requires AutoHotkey v2.0
#SingleInstance Force

; Suspend a process
; This is to pause a single-player game to read dialogues
; Requirements: install PsSuspend: https://learn.microsoft.com/en-us/sysinternals/downloads/pssuspend
pssuspend := EnvGet("USERPROFILE") "\Downloads\PSTools\pssuspend64.exe"
if !FileExist(pssuspend) {
    MsgBox "PsSuspend not found:`n" pssuspend
    ExitApp
}

suspended := Map()

^!+r::
{
    pid := WinGetPID("A")
    if !pid
        return

    if suspended.Has(pid) {
        RunWait('"' pssuspend '" -r ' pid ' /accepteula', , "Hide")
        suspended.Delete(pid)
        ToolTip("Resumed PID " pid)
    } else {
        RunWait('"' pssuspend '" ' pid ' /accepteula', , "Hide")
        suspended[pid] := true
        ToolTip("Paused PID " pid)
    }
    SetTimer(() => ToolTip(), -800)
}

