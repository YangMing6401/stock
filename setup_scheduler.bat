@echo off
chcp 65001 >nul
title 台股追蹤系統 - 設定每日自動排程

echo ========================================================
echo        ⏰ 台股數據追蹤系統 - 設定 Windows 自動排程
echo ========================================================
echo.
echo 將於每週一至週五 下午 16:30（盤後資料發布後）自動執行更新。
echo.

cd /d "%~dp0"
set SCRIPT_PATH=%~dp0daily_updater.py
set PYTHON_PATH=python

schtasks /create /tn "TaiwanStockDailyUpdate" /tr "\"%PYTHON_PATH%\" \"%SCRIPT_PATH%\"" /sc weekly /d MON,TUE,WED,THU,FRI /st 16:30 /f

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo ✅ 自動排程建立成功！
    echo    工作名稱: TaiwanStockDailyUpdate
    echo    執行時間: 每週一至五 下午 16:30
    echo ========================================================
) else (
    echo.
    echo ⚠️ 建立排程時發生錯誤，請嘗試「以系統管理員身分執行」此批次檔。
)

echo.
pause
