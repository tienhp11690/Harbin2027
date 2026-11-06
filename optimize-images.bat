@echo off
chcp 65001 > nul
echo Dang khoi chay cong cu toi uu hoa hinh anh...
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\optimize-images.ps1"
echo.
pause
