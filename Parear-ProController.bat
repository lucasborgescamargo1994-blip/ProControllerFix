@echo off
setlocal
title Correcao Bluetooth - Pro Controller generico
cd /d "%~dp0"

rem Precisa de administrador (grava no registro do Bluetooth). Se nao for, reabre pedindo permissao.
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Pedindo permissao de administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Parear-ProController.ps1" %*
echo.
echo Log salvo em: %~dp0Parear-ProController.log
echo.
pause
