@echo off
echo ==========================================
echo    Notion+ Launcher
echo ==========================================
echo.

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not installed
    echo Please install from: https://nodejs.org/
    pause
    exit /b 1
)

REM Check Flutter
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter not installed
    pause
    exit /b 1
)

echo [OK] Node.js and Flutter found
echo.

REM Start proxy server
echo Starting proxy server...
cd server
if not exist node_modules (
    echo Installing server dependencies...
    npm install
)
start "Proxy Server" cmd /k "npm start"
cd ..

echo.
echo Waiting for proxy server (5 seconds)...
timeout /t 5 /nobreak >nul

REM Test proxy
curl -s http://localhost:3001/health >nul 2>&1
if errorlevel 1 (
    echo WARNING: Proxy server may not be running properly
    echo Check the proxy server window for errors
    echo.
)

REM Start Flutter
echo Starting Flutter Web app...
echo.
echo NOTE: Chrome will start with disabled web security
echo.

flutter run -d chrome --web-browser-flag "--disable-web-security" --web-hostname localhost --web-port 8080

echo.
echo ==========================================
echo App closed
echo ==========================================
pause
