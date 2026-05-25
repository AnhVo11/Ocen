@echo off
setlocal enabledelayedexpansion
echo ================================================
echo   OCEN - Creating Android Emulator
echo ================================================
echo.

set ANDROID_SDK=C:\Users\anhvo\AppData\Local\Android\Sdk
set CMDLINE=%ANDROID_SDK%\cmdline-tools\latest\bin
set AVD_NAME=OCEN_Emulator

echo Checking installed system images...
dir "%ANDROID_SDK%\system-images" /b /ad 2>nul
echo.

echo Trying to create Pixel 6 emulator...
echo (Trying different Android versions and image types)
echo.

for %%v in (35 34 33 32) do (
    for %%t in (google_apis_playstore google_apis default) do (
        "%CMDLINE%\avdmanager.bat" create avd -n "%AVD_NAME%" -k "system-images;android-%%v;%%t;x86_64" --device "pixel_6" --force >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo SUCCESS! Created emulator with Android %%v ^(%%t^)
            goto :done
        )
    )
)

echo.
echo ERROR: Could not create emulator automatically.
echo Please open Android Studio - SDK Manager - SDK Images and download one.
pause
exit /b 1

:done
echo.
echo Starting emulator now...
start "" "%ANDROID_SDK%\emulator\emulator.exe" -avd %AVD_NAME% -no-snapshot-load
echo.
echo Emulator is booting in background.
echo Wait for the Android home screen to appear, then run the Flutter app.
echo.
pause
