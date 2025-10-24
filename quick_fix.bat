@echo off
echo ========================================
echo   Quick Fix: Redeploy to Firebase
echo ========================================
echo.

echo [1/2] Redeploying to Firebase...
call firebase deploy --only hosting --force

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Deployment failed!
    echo.
    echo Trying with login refresh...
    call firebase login --reauth
    call firebase deploy --only hosting
    
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo ❌ Still failed! Manual steps needed.
        pause
        exit /b %ERRORLEVEL%
    )
)

echo.
echo ========================================
echo   ✅ Deployment Complete!
echo ========================================
echo.
echo Your dashboard should now be live at:
echo https://fieldawy-admin-dashboard.web.app
echo.
echo Wait 30 seconds then open the URL
pause
