@echo off
echo ========================================
echo   Quick Deploy - Build and Deploy
echo ========================================
echo.

echo [1/2] Building Flutter Web...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/2] Deploying to Firebase...
call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Deployment failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================
echo   ✅ SUCCESS!
echo ========================================
echo.
echo Your Admin Dashboard:
echo https://fieldawy-store-app.web.app
echo.
echo Changes deployed:
echo - Fixed duplicate AppBars
echo - Added user counts in tabs
echo - Added Companies count card
echo - Fixed all warnings
echo.
pause
