' Launches Watch-Stock.ps1 with no console window flash (Task Scheduler runs this).
' Optional args: <checks per run> <seconds between checks>   defaults: 1 0
Dim sh, fso, dir, cmd, count, gapSec, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\Watch-Stock.ps1"""
count = 1
gapSec = 0
If WScript.Arguments.Count >= 1 Then count = CInt(WScript.Arguments(0))
If WScript.Arguments.Count >= 2 Then gapSec = CInt(WScript.Arguments(1))
If count < 1 Then count = 1
For i = 1 To count
    sh.Run cmd, 0, True
    If i < count And gapSec > 0 Then WScript.Sleep gapSec * 1000
Next
