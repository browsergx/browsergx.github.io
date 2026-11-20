@echo off
setlocal
set "BROWSERGX_SCRIPT=%~f0"
set "BROWSERGX_ARGS=%*"
#powershell.exe -NoProfile -Command "$lines = Get-Content -LiteralPath '%~f0'; $marker = [Array]::IndexOf($lines, '# POWERSHELL'); if ($marker -lt 0) { throw 'No se encontro el bloque PowerShell.' }; $code = $lines[($marker + 1)..($lines.Length - 1)] -join [Environment]::NewLine; & ([ScriptBlock]::Create($code))"
start "" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$lines = Get-Content -LiteralPath '%~f0'; $marker = [Array]::IndexOf($lines, '# POWERSHELL'); if ($marker -lt 0) { throw 'No se encontro el bloque PowerShell.' }; $code = $lines[($marker + 1)..($lines.Length - 1)] -join [Environment]::NewLine; & ([ScriptBlock]::Create($code))"
exit /b 0
set "exitCode=%ERRORLEVEL%"
if not "%exitCode%"=="0" (
  echo.
  pause
)
exit /b %exitCode%
# POWERSHELL
$ErrorActionPreference = 'Stop'
$mutexName = 'Local\BrowserGX-' + [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$singleInstanceMutex = [System.Threading.Mutex]::new($false, $mutexName)
try {
    $ownsMutex = $singleInstanceMutex.WaitOne(0)
}
catch [System.Threading.AbandonedMutexException] {
    $ownsMutex = $true
}

if (-not $ownsMutex) {
    Write-Host 'BrowserGX ya esta en ejecucion. Esta instancia se cerrara sin mostrar anuncios.'
    $singleInstanceMutex.Dispose()
    exit 0
}

$source = 'https://browsergx.github.io/ads/ads.txt'
$redirectBase = 'https://browsergx.github.io/ads/go.html?url='
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
$interval = [TimeSpan]::FromMinutes(30)
$installDirectory = Join-Path $env:LOCALAPPDATA 'BrowserGX'
$installPath = Join-Path $installDirectory 'BrowserGX.bat'
$legacyIconPath = Join-Path $installDirectory 'BrowserGX.ico'
$legacyAppShortcutPath = Join-Path $installDirectory 'BrowserGX.lnk'
$legacyStartupShortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'BrowserGX.lnk'
$currentScript = [System.IO.Path]::GetFullPath($env:BROWSERGX_SCRIPT)
$isInstalledCopy = [string]::Equals($currentScript, $installPath, [StringComparison]::OrdinalIgnoreCase)
$isStartup = $env:BROWSERGX_ARGS -match '(^|\s)/startup($|\s)'

# Paso 1: informar todas las acciones y solicitar una unica confirmacion antes de realizar cambios.
Write-Host ''
Write-Host 'INFORMACION Y CONFIRMACION DE BrowserGX' -ForegroundColor Cyan
Write-Host 'Al continuar, autorizas todas las acciones aplicables a esta ejecucion:'
if ($isStartup) {
    Write-Host '- Esta copia se inicio al iniciar sesion en Windows; la confirmacion se solicita de nuevo en cada inicio.'
}
else {
    Write-Host ("- Se creara/actualizara la copia en: {0}" -f $installPath)
    Write-Host '- El inicio de sesion ejecutara directamente el archivo BrowserGX.bat desde esa carpeta.'
    Write-Host '- El inicio automatico es para esta cuenta y no requiere permisos de administrador.'
}
Write-Host '- BrowserGX no descargara ni utilizara favicon, iconos personalizados o accesos directos .lnk.'
Write-Host '- Si existen archivos antiguos BrowserGX.ico o accesos directos propios de BrowserGX, se retiraran tras continuar.'
Write-Host '- Hasta que escribas CONTINUAR no se instalaran archivos, no se cambiara la configuracion, no se descargara la lista ni se abriran URLs.'
Write-Host ("- Se consultara la configuracion y la lista de URLs desde: {0}" -f $source)
Write-Host '- ads.txt se consulta al iniciar y luego en intervalos aleatorios de 5 a 10 minutos para distribuir las solicitudes entre usuarios.'
Write-Host '- activo=0 pausa la apertura; BrowserGX seguira abierto y volvera a consultar hasta detectar activo=1 (el cambio puede tardar hasta 10 minutos).'
Write-Host '- interval indica los minutos entre URLs (por ejemplo, interval=1 abre una cada minuto). Los cambios se aplican al volver a consultar el archivo.'
Write-Host '- Despues de abrir una URL, se mostrara una cuenta regresiva hasta la siguiente, basada en el intervalo vigente.'
Write-Host '- No se comprobaran las URLs mediante HEAD ni GET, porque algunos sitios bloquean esas solicitudes aunque funcionen en el navegador.'
Write-Host ("- Cada URL de la lista se abrira pasando primero por: {0}<URL-codificada>" -f $redirectBase)
Write-Host '- La disponibilidad final depende del sitio y del navegador; BrowserGX no filtrara destinos por sus respuestas HTTP.'
Write-Host '- Solo se aceptaran direcciones HTTPS; esto no comprueba si el contenido de cada sitio es seguro o apropiado.'
Write-Host '- Con activo=1 se abrira una direccion al azar y se recorrera la lista sin repetir hasta agotarla.'
Write-Host '- El limite de 24 horas se cuenta desde el inicio y no se extiende por una pausa.'
Write-Host '- El navegador puede comunicarse con cada sitio abierto como en una navegacion normal.'
Write-Host '- Solo se permite una instancia activa por usuario de Windows; una segunda apertura se cerrara sin mostrar anuncios.'
Write-Host '- En cada inicio de sesion futuro se solicitara esta misma confirmacion antes de abrir URLs.'
Write-Host '- CANCELAR no hace los cambios descritos para esta ejecucion; si el inicio automatico ya existia, se conserva y volvera a pedir confirmacion.'
Write-Host '- Ctrl+C detiene la ejecucion actual, pero no desactiva el inicio automatico.'
Write-Host ''
#$confirmation = (Read-Host 'Escribe CONTINUAR para aceptar todo o CANCELAR para salir').Trim()
#if ($confirmation -notmatch '^(continuar)$') {
#    Write-Host 'Operacion cancelada. No se realizaran las acciones descritas.'
#    exit 0
#}

try {
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
    if (-not $isInstalledCopy) {
        Copy-Item -LiteralPath $currentScript -Destination $installPath -Force
        Write-Host 'Copia instalada/actualizada. No se abrira ahora; esta ejecucion continuara desde el archivo que iniciaste.'
    }

    if (Test-Path -LiteralPath $legacyIconPath) {
        Remove-Item -LiteralPath $legacyIconPath -Force
        Write-Host 'Se elimino el icono antiguo de BrowserGX.'
    }
    if (Test-Path -LiteralPath $legacyAppShortcutPath) {
        $shell = New-Object -ComObject WScript.Shell
        $legacyAppShortcut = $shell.CreateShortcut($legacyAppShortcutPath)
        if ([string]::Equals($legacyAppShortcut.TargetPath, $installPath, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $legacyAppShortcutPath -Force
            Write-Host 'Se elimino el acceso directo antiguo de BrowserGX.'
        }
    }
    if (Test-Path -LiteralPath $legacyStartupShortcutPath) {
        $shell = New-Object -ComObject WScript.Shell
        $legacyStartupShortcut = $shell.CreateShortcut($legacyStartupShortcutPath)
        $isOwnedLegacyShortcut = [string]::Equals($legacyStartupShortcut.TargetPath, $env:ComSpec, [StringComparison]::OrdinalIgnoreCase) -and $legacyStartupShortcut.Arguments.IndexOf($installPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $legacyStartupShortcut.Arguments.IndexOf('/startup', [StringComparison]::OrdinalIgnoreCase) -ge 0
        if ($isOwnedLegacyShortcut) {
            Remove-Item -LiteralPath $legacyStartupShortcutPath -Force
            Write-Host 'Se elimino el acceso directo antiguo de inicio de BrowserGX.'
        }
    }

    if (-not $isStartup) {
        $startupCommand = '"' + $env:ComSpec + '" /d /c ""' + $installPath + '" /startup"'
        $runKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
        if ($null -eq $runKey) {
            throw 'No se pudo abrir la clave de inicio automatico.'
        }
        try {
            $runKey.SetValue('BrowserGX', $startupCommand, [Microsoft.Win32.RegistryValueKind]::String)
        }
        finally {
            $runKey.Dispose()
        }
        Write-Host 'El inicio de sesion ejecutara BrowserGX.bat directamente desde la carpeta instalada.'
    }
}
catch {
    Write-Host ("No se pudo preparar la instalacion: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

function Get-BrowserGXConfiguration {
    $response = Invoke-WebRequest -Uri $source -UseBasicParsing -UserAgent $userAgent -TimeoutSec 20
    $activeSetting = $null
    $intervalSetting = $null
    $urls = [System.Collections.Generic.List[string]]::new()

    foreach ($line in ($response.Content -split '\r?\n')) {
        $candidate = $line.Trim()
        if (-not $candidate -or $candidate.StartsWith('#')) {
            continue
        }

        if ($candidate -match '^(activo|active)\s*=\s*(.*?)\s*$') {
            if ($null -ne $activeSetting) {
                throw 'La configuracion debe contener una sola linea activo=0 o activo=1.'
            }
            $activeValue = $Matches[2]
            if ($activeValue -notmatch '^[01]$') {
                throw 'El valor de activo debe ser 0 o 1.'
            }
            $activeSetting = $activeValue -eq '1'
            continue
        }

        if ($candidate -match '^interval\s*=\s*(.*?)\s*$') {
            if ($null -ne $intervalSetting) {
                throw 'La configuracion debe contener una sola linea interval=N.'
            }
            $parsedInterval = 0
            if (-not [int]::TryParse($Matches[1], [ref]$parsedInterval) -or $parsedInterval -lt 1 -or $parsedInterval -gt 1440) {
                throw 'interval debe ser un numero entero entre 1 y 1440 minutos.'
            }
            $intervalSetting = $parsedInterval
            continue
        }

        $parsedUri = $null
        if ([Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$parsedUri) -and $parsedUri.Scheme -eq 'https') {
            $urls.Add($parsedUri.AbsoluteUri)
        }
    }

    if ($null -eq $activeSetting) {
        throw 'Falta la configuracion activo=0 o activo=1.'
    }
    if ($null -eq $intervalSetting) {
        throw 'Falta la configuracion interval=N.'
    }
    if ($activeSetting -and $urls.Count -eq 0) {
        throw 'activo=1 pero no se encontraron URLs HTTPS validas.'
    }

    [pscustomobject]@{
        Active = $activeSetting
        IntervalMinutes = $intervalSetting
        Urls = [string[]]$urls.ToArray()
    }
}

Write-Host 'Iniciando la consulta y apertura de URLs autorizada.'
$expiresAt = (Get-Date).AddHours(24)
$minimumPollMinutes = 5
$maximumPollMinutes = 10
$configuration = $null
$nextConfigurationCheck = Get-Date
$nextAdAt = Get-Date
$lastAdAt = $null
$lastIntervalMinutes = $null
$lastUrlSignature = $null
$remaining = [System.Collections.Generic.List[string]]::new()
$wasPaused = $false

while ((Get-Date) -lt $expiresAt) {
    $now = Get-Date
    if ($now -ge $nextConfigurationCheck) {
        try {
            $newConfiguration = Get-BrowserGXConfiguration
            $urlSignature = [string]::Join("`n", [string[]]$newConfiguration.Urls)
            if ($urlSignature -ne $lastUrlSignature) {
                $remaining.Clear()
                $remaining.AddRange([string[]]$newConfiguration.Urls)
                $lastUrlSignature = $urlSignature
            }
            if ($null -ne $lastIntervalMinutes -and $newConfiguration.IntervalMinutes -ne $lastIntervalMinutes -and $null -ne $lastAdAt) {
                $nextAdAt = $lastAdAt.AddMinutes($newConfiguration.IntervalMinutes)
            }
            $lastIntervalMinutes = $newConfiguration.IntervalMinutes
            $configuration = $newConfiguration
        }
        catch {
            Write-Warning ("No se pudo leer una configuracion valida desde {0}: {1}" -f $source, $_.Exception.Message)
            $configuration = $null
            $wasPaused = $true
        }
        $pollDelayMinutes = Get-Random -Minimum $minimumPollMinutes -Maximum ($maximumPollMinutes + 1)
        $nextConfigurationCheck = (Get-Date).AddMinutes($pollDelayMinutes)
        Write-Host ("Siguiente consulta de ads.txt en aproximadamente {0} minutos." -f $pollDelayMinutes)
        $now = Get-Date
    }

    if ($null -eq $configuration -or -not $configuration.Active) {
        Write-Progress -Activity 'BrowserGX' -Completed
        if (-not $wasPaused) {
            Write-Host 'Anuncios pausados. BrowserGX seguira comprobando ads.txt en intervalos aleatorios de 5 a 10 minutos; la pausa cuenta dentro del limite de 24 horas.'
        }
        $wasPaused = $true
    }
    else {
        if ($wasPaused) {
            Write-Host ("Anuncios reanudados. Intervalo configurado: {0} minuto(s)." -f $configuration.IntervalMinutes)
            $nextAdAt = $now
            $wasPaused = $false
        }
        if ($now -ge $nextAdAt) {
            if ($remaining.Count -eq 0) {
                $remaining.AddRange([string[]]$configuration.Urls)
            }

            $index = Get-Random -Minimum 0 -Maximum $remaining.Count
            $url = $remaining[$index]
            $remaining.RemoveAt($index)

            $redirectUrl = $redirectBase + [Uri]::EscapeDataString($url)
            Write-Host ("Abriendo URL mediante el redireccionador BrowserGX: {0}" -f $redirectUrl)
            Start-Process -FilePath $redirectUrl
            $lastAdAt = Get-Date
            $nextAdAt = $lastAdAt.AddMinutes($configuration.IntervalMinutes)
        }
    }

    $now = Get-Date
    $nextWakeAt = $nextConfigurationCheck
    if ($null -ne $configuration -and $configuration.Active) {
        if ($nextAdAt -lt $nextWakeAt) {
            $nextWakeAt = $nextAdAt
        }
        if ($nextAdAt -gt $now) {
            $secondsUntilNextUrl = [int][Math]::Ceiling(($nextAdAt - $now).TotalSeconds)
            $intervalSeconds = [Math]::Max(1, $configuration.IntervalMinutes * 60)
            $countdownProgress = [int](100 * (1 - ($secondsUntilNextUrl / $intervalSeconds)))
            $timeRemaining = [TimeSpan]::FromSeconds($secondsUntilNextUrl)
            $countdownText = '{0:00}:{1:00}:{2:00}' -f [int][Math]::Floor($timeRemaining.TotalHours), $timeRemaining.Minutes, $timeRemaining.Seconds
            Write-Progress -Activity 'BrowserGX' -Status ("Siguiente URL en: {0}" -f $countdownText) -SecondsRemaining $secondsUntilNextUrl -PercentComplete $countdownProgress
            $countdownTick = $now.AddSeconds(1)
            if ($countdownTick -lt $nextWakeAt) {
                $nextWakeAt = $countdownTick
            }
        }
        else {
            Write-Progress -Activity 'BrowserGX' -Completed
        }
    }
    if ($expiresAt -lt $nextWakeAt) {
        $nextWakeAt = $expiresAt
    }
    $sleepSeconds = [int][Math]::Ceiling(($nextWakeAt - $now).TotalSeconds)
    if ($sleepSeconds -gt 0) {
        Start-Sleep -Seconds $sleepSeconds
    }
}

Write-Host 'Se cumplio el limite de 24 horas. El programa ha finalizado.'
$singleInstanceMutex.ReleaseMutex()
$singleInstanceMutex.Dispose()
