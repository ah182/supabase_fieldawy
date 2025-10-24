@echo off
echo ========================================
echo   Admin Dashboard Deployment
echo ========================================
echo.

echo [1/3] Building Web App with Admin as default...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Deploying to Firebase...
call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Deployment failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================
echo   ✅ ADMIN DASHBOARD IS LIVE!
echo ========================================
echo.
echo Admin Login:
echo https://fieldawy-store-app.web.app
echo.
echo The web app will now open directly to Admin Login!
echo.
echo ⚠️  IMPORTANT: Update Supabase URLs
echo 1. https://supabase.com/dashboard
echo 2. Authentication → URL Configuration
echo 3. Site URL: https://fieldawy-store-app.web.app
echo 4. Redirect URLs: https://fieldawy-store-app.web.app/**
echo.
pause
