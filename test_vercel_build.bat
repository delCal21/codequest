@echo off
REM Test script for Windows to verify Vercel build setup
REM This checks the configuration files

echo ==========================================
echo Testing Vercel Build Setup (Windows)
echo ==========================================
echo.

REM Check if we're in the project root
if not exist "pubspec.yaml" (
    echo Error: pubspec.yaml not found. Please run this script from the project root.
    exit /b 1
)

echo Step 1: Testing install.sh
echo ----------------------------------------
if exist "install.sh" (
    echo [OK] install.sh exists
) else (
    echo [ERROR] install.sh not found
    exit /b 1
)

echo.
echo Step 2: Testing build.sh
echo ----------------------------------------
if exist "build.sh" (
    echo [OK] build.sh exists
) else (
    echo [ERROR] build.sh not found
    exit /b 1
)

echo.
echo Step 3: Testing vercel.json
echo ----------------------------------------
if exist "vercel.json" (
    echo [OK] vercel.json exists
    findstr /C:"install.sh" vercel.json >nul 2>&1
    if %errorlevel% equ 0 (
        findstr /C:"build.sh" vercel.json >nul 2>&1
        if %errorlevel% equ 0 (
            echo [OK] vercel.json references install.sh and build.sh
        ) else (
            echo [WARNING] vercel.json might not reference build.sh
        )
    ) else (
        echo [WARNING] vercel.json might not reference install.sh
    )
) else (
    echo [ERROR] vercel.json not found
    exit /b 1
)

echo.
echo Step 4: Checking required files
echo ----------------------------------------
if exist "lib\main.dart" (
    echo [OK] lib\main.dart exists
) else (
    echo [ERROR] lib\main.dart not found
    exit /b 1
)

echo.
echo Step 5: Checking .gitignore
echo ----------------------------------------
if exist ".gitignore" (
    echo [OK] .gitignore exists
    findstr /C:"flutter" .gitignore >nul 2>&1
    if %errorlevel% equ 0 (
        echo [OK] flutter directory is in .gitignore
    ) else (
        echo [WARNING] flutter directory might not be in .gitignore
    )
) else (
    echo [WARNING] .gitignore not found
)

echo.
echo ==========================================
echo All checks passed!
echo ==========================================
echo.
echo Next steps:
echo 1. Commit and push your changes to GitHub
echo 2. Vercel will automatically detect and deploy
echo 3. Monitor the build in Vercel dashboard
echo.
echo Note: To fully test the build, you need a Linux/Mac environment
echo or use WSL (Windows Subsystem for Linux)
echo.

pause

