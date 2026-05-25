Set oShell = CreateObject("WScript.Shell")
' Kill any existing flutter/dart processes
oShell.Run "cmd.exe /c taskkill /F /IM dart.exe /T 2>nul & taskkill /F /IM flutter.exe /T 2>nul", 0, True
' Wait a moment
WScript.Sleep 2000
' Now launch flutter run fresh
oShell.Run "cmd.exe /k ""cd /d C:\Users\anhvo\Desktop\Ocen\mobile && flutter run""", 1, False
