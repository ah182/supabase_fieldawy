@echo off
echo ========================================
echo   Rebuild and Deploy with ENV fix
echo ========================================
echo.

echo [1/3] Cleaning old build...
call flutter clean

echo.
echo [2/3] Building Flutter Web with ENV...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Deploying to Firebase...
call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Deployment failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================
echo   ✅ Deployment Complete!
echo ========================================
echo.
echo Your dashboard is now live at:
echo https://fieldawy-admin-dashboard.web.app
echo.
echo Wait 30 seconds then test login
echo.
pause
