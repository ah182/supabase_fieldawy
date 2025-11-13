@echo off
echo ==========================================
echo   Deploying Cloudflare Worker
echo ==========================================
echo.

cd /d "%~dp0"

echo Deploying to Cloudflare...
wrangler publish

echo.
echo ==========================================
echo   Deployment Complete!
echo ==========================================
echo.
echo Worker URL:
echo https://notification-webhook.ah3181997-1e7.workers.dev
echo.
echo Endpoints:
echo   - POST / (Supabase webhook)
echo   - POST /send-custom-notification (Dashboard)
echo   - GET /health (Health check)
echo.
pause
