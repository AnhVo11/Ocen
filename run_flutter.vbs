Set oShell = CreateObject("WScript.Shell")
' Run flutter in a visible cmd window that stays open (/k keeps the window after commands finish)
oShell.Run "cmd.exe /k ""cd /d C:\Users\anhvo\Desktop\Ocen\mobile && flutter pub get && flutter run""", 1, False
