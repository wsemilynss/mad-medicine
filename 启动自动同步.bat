@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Mad Medicine 自动同步到 GitHub Pages ===
node auto-sync.js
pause
