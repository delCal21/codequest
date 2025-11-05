@echo off
echo ========================================
echo CodeQuest GitHub Setup Script
echo ========================================
echo.

echo [1/4] Checking Git installation...
git --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git is not installed. Please install Git from https://git-scm.com/
    pause
    exit /b 1
)
echo ✓ Git is installed
echo.

echo [2/4] Initializing Git repository...
if exist .git (
    echo Git repository already initialized
) else (
    git init
    echo ✓ Git repository initialized
)
echo.

echo [3/4] Staging files...
git add .
echo ✓ Files staged
echo.

echo [4/4] Creating initial commit...
git commit -m "Initial commit: CodeQuest learning platform"
echo ✓ Initial commit created
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Create a new repository on GitHub:
echo    https://github.com/new
echo.
echo 2. Connect your local repository:
echo    git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
echo.
echo 3. Push your code:
echo    git branch -M main
echo    git push -u origin main
echo.
echo 4. Deploy to Vercel:
echo    See DEPLOYMENT.md for detailed instructions
echo.
pause

