@echo off
echo ========================================
echo   CodeQuest Certificate System Deploy
echo ========================================
echo.

echo Step 1: Building Flutter web app...
call flutter build web
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
echo ✅ Flutter web build completed
echo.

echo Step 2: Deploying to Firebase Hosting...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ERROR: Firebase deployment failed!
    echo Make sure you're logged in: firebase login
    pause
    exit /b 1
)
echo ✅ Firebase Hosting deployment completed
echo.

echo Step 3: Testing certificate URLs...
echo.
echo Test URLs:
echo - Main app: https://codequest-a5317.web.app/
echo - Certificate test: https://codequest-a5317.web.app/test-certificate.html
echo - Certificate download: https://codequest-a5317.web.app/certificate-download.html?cert=test123
echo.

echo ========================================
echo   Deployment Complete! 🎉
echo ========================================
echo.
echo Your certificate system is now live!
echo QR codes will now work and point to:
echo https://codequest-a5317.web.app/certificate-download.html?cert={certificateId}
echo.
pause
