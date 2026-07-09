' Launches Watch-Stock.ps1 with no console window flash (Task Scheduler runs this).
' Args: <checks per run> <seconds between checks> <max jitter seconds>   defaults: 1 0 0
' Jitter keeps the cadence from being a perfect metronome (a bot signature).
Dim sh, fso, dir, cmd, count, gapSec, jitterSec, i, thisGap
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\Watch-Stock.ps1"""
count = 1
gapSec = 0
jitterSec = 0
If WScript.Arguments.Count >= 1 Then count = CInt(WScript.Arguments(0))
If WScript.Arguments.Count >= 2 Then gapSec = CInt(WScript.Arguments(1))
If WScript.Arguments.Count >= 3 Then jitterSec = CInt(WScript.Arguments(2))
If count < 1 Then count = 1
Randomize

' one check per run (>= 1 minute intervals): jitter WHEN in the minute it fires
If count = 1 And jitterSec > 0 Then WScript.Sleep Int(Rnd * (jitterSec + 1)) * 1000

For i = 1 To count
    sh.Run cmd, 0, True
    If i < count Then
        thisGap = gapSec
        If jitterSec > 0 Then thisGap = gapSec - jitterSec + Int(Rnd * (2 * jitterSec + 1))
        If thisGap < 3 Then thisGap = 3
        WScript.Sleep thisGap * 1000
    End If
Next
