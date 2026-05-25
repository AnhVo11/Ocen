Set oShell = CreateObject("WScript.Shell")

Dim sdkPath
sdkPath = "C:\Users\anhvo\AppData\Local\Android\Sdk"
Dim avdMgr
avdMgr = sdkPath & "\cmdline-tools\latest\bin\avdmanager.bat"

Dim cmd, ret
Dim created
created = False

Dim versions(3)
versions(0) = "35"
versions(1) = "34"
versions(2) = "33"
versions(3) = "32"

Dim imgTypes(2)
imgTypes(0) = "google_apis_playstore"
imgTypes(1) = "google_apis"
imgTypes(2) = "default"

Dim i, j
For i = 0 To 3
    For j = 0 To 2
        cmd = "cmd /c """ & avdMgr & """ create avd -n ""OCEN_Emulator"" -k ""system-images;android-" & versions(i) & ";" & imgTypes(j) & ";x86_64"" --device ""pixel_6"" --force"
        ret = oShell.Run(cmd, 0, True)
        If ret = 0 Then
            created = True
            Exit For
        End If
    Next
    If created Then Exit For
Next

If created Then
    MsgBox "Emulator created! Starting now...", 64, "OCEN Setup"
    oShell.Run """" & sdkPath & "\emulator\emulator.exe"" -avd OCEN_Emulator -no-snapshot-load", 1, False
Else
    MsgBox "Could not create emulator. Please go to Android Studio > Tools > SDK Manager > SDK Images and download Android 34 (Google APIs).", 16, "OCEN Setup Error"
End If
