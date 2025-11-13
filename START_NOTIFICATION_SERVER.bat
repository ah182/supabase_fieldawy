@echo off
echo ==========================================
echo   Starting Custom Notification Server
echo ==========================================
echo.

REM Install dependencies if needed
if not exist "node_modules\cors" (
    echo Installing dependencies...
    call npm install
    echo.
)

REM Start server
echo Starting server on http://localhost:3000
echo.
node notification_server.js

pause
