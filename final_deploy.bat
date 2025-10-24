@echo off
echo ========================================
echo   FINAL Deploy - Hardcoded Keys Fix
echo ========================================
echo.

echo [1/3] Cleaning...
call flutter clean

echo.
echo [2/3] Building with hardcoded Supabase keys...
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
echo   ✅ SUCCESS! Dashboard is LIVE!
echo ========================================
echo.
echo Your Admin Dashboard:
echo https://fieldawy-store-app.web.app
echo.
echo ⚠️  Don't forget to update Supabase URLs:
echo.
echo 1. Go to: https://supabase.com/dashboard
echo 2. Authentication → URL Configuration
echo 3. Site URL: https://fieldawy-store-app.web.app
echo 4. Redirect URLs: https://fieldawy-store-app.web.app/**
echo.
pause
