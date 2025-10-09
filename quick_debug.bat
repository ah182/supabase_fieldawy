@echo off
echo ========================================
echo    Quick Notification System Check
echo ========================================
echo.

echo [1/4] Testing local server...
curl -s http://localhost:3000/api/notify/product-change -X POST -H "Content-Type: application/json" -d "{\"operation\":\"INSERT\",\"table\":\"test\",\"product_name\":\"Test\",\"tab_name\":\"home\"}"
echo.
echo.

echo [2/4] Testing localtunnel...
curl -s https://little-mice-ask.loca.lt/api/notify/product-change -X POST -H "Content-Type: application/json" -d "{\"operation\":\"INSERT\",\"table\":\"test\",\"product_name\":\"Test\",\"tab_name\":\"home\"}"
echo.
echo.

echo [3/4] Checking if server is running...
netstat -ano | findstr :3000
echo.

echo [4/4] Testing FCM...
node test_notification_direct.js
echo.

echo ========================================
echo Check complete! 
echo If you saw errors above, that's the issue.
echo ========================================
pause
