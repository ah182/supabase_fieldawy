@echo off
REM Script سريع للـ Build و Deploy على Firebase

echo ========================================
echo   Fieldawy Admin Dashboard Deployment
echo ========================================
echo.

echo [1/3] Building Flutter Web...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Build failed! Check errors above.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ✅ Build successful!
echo.

echo [2/3] Deploying to Firebase Hosting...
call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Deployment failed! Check errors above.
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
pause
