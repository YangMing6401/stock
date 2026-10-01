@echo off
chcp 65001 >nul
title 台股追蹤系統 - 網頁伺服器 (Port 3001)

echo ========================================================
echo        🚀 台股數據追蹤系統 - 啟動 Web 服務 (Port 3001)
echo ========================================================
echo.

cd /d "%~dp0"

echo 正在啟動 Flask Web 伺服器...
echo 網址: http://localhost:3001
echo.
echo 提示: 請勿關閉此視窗，按 Ctrl+C 可停止伺服器。
echo.

start "" "http://localhost:3001"

python main.py web --port 3001

pause
