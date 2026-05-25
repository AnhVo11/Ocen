@echo off
:: OCEN Backend Startup Script
:: Starts the FastAPI server on http://localhost:8000
:: Android emulator reaches this as http://10.0.2.2:8000

cd /d "%~dp0"

:: Check for .env file
if not exist .env (
    echo [WARN] No .env file found. Copying .env.example to .env ...
    copy .env.example .env
    echo [INFO] Edit .env to add your Twilio / Google Maps keys if needed.
)

:: Install dependencies (first run)
echo [INFO] Installing Python dependencies...
pip install -r requirements.txt --quiet

:: Start the FastAPI server
echo.
echo ============================================
echo  OCEN Backend starting on http://localhost:8000
echo  Android emulator URL: http://10.0.2.2:8000
echo  Press Ctrl+C to stop
echo ============================================
echo.

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
