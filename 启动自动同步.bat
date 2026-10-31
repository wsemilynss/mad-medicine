@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Mad Medicine 自动同步到 GitHub Pages ===
echo.
where node >nul 2>nul
if %errorlevel%==0 (
  echo [模式] Node.js 监听
  echo.
  node auto-sync.js
) else (
  echo [模式] PowerShell 监听（未检测到 Node.js，已自动切换）
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0auto-sync.ps1"
)
echo.
echo 同步已停止。如果窗口一打开就退出，请把上方提示截图反馈。
pause
