@echo off
setlocal
set "BROWSERGX_SCRIPT=%~f0"
set "BROWSERGX_ARGS=%*"
start "" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$lines = Get-Content -LiteralPath '%~f0'; $marker = [Array]::IndexOf($lines, '# POWERSHELL'); if ($marker -lt 0) { throw 'No se encontro el bloque PowerShell.' }; $code = $lines[($marker + 1)..($lines.Length - 1)] -join [Environment]::NewLine; & ([ScriptBlock]::Create($code))"
set "exitCode=%ERRORLEVEL%"
if not "%exitCode%"=="0" (
  echo.
  pause
)
exit /b %exitCode%
# POWERSHELL
# BROWSERGX_VERSION=1.0.0
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
$updaterPath = Join-Path $installDirectory 'AutoUpdate.bat'
$currentScript = [System.IO.Path]::GetFullPath($env:BROWSERGX_SCRIPT)
$isInstalledCopy = [string]::Equals($currentScript, $installPath, [StringComparison]::OrdinalIgnoreCase)
$isStartup = $env:BROWSERGX_ARGS -match '(^|\s)/startup($|\s)'
$isManagedLaunch = $env:BROWSERGX_ARGS -match '(^|\s)/managed($|\s)'

if ($isInstalledCopy -and -not $isManagedLaunch -and (Test-Path -LiteralPath $updaterPath)) {
    $singleInstanceMutex.ReleaseMutex()
    $singleInstanceMutex.Dispose()
    $launcherArguments = '/d /c ""' + $updaterPath + '" /launch ' + $env:BROWSERGX_ARGS + '"'
    Start-Process -FilePath $env:ComSpec -ArgumentList $launcherArguments -WorkingDirectory $installDirectory
    exit 0
}

# Paso 1: informar todas las acciones y solicitar una unica confirmacion antes de realizar cambios.
Write-Host ''
Write-Host 'INFORMACION Y CONFIRMACION DE BrowserGX' -ForegroundColor Cyan
Write-Host 'Al continuar, autorizas todas las acciones aplicables a esta ejecucion:'
if ($isStartup) {
    Write-Host '- Esta copia se inicio al iniciar sesion en Windows; la confirmacion se solicita de nuevo en cada inicio.'
}
else {
    Write-Host ("- Se creara/actualizara la copia en: {0}" -f $installPath)
    Write-Host '- Se creara AutoUpdate.bat; el inicio de sesion lo usara para aplicar actualizaciones verificadas.'
    Write-Host '- El inicio automatico es para esta cuenta y no requiere permisos de administrador.'
}
Write-Host '- Se consultara https://browsergx.github.io/update.txt; las versiones nuevas se descargan en segundo plano y se aplican al siguiente inicio.'
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

    $autoUpdaterContent = @'
@echo off

# POWERSHELL
$ErrorActionPreference = 'Stop'
$installDirectory = Split-Path -Parent $env:BROWSERGX_UPDATER
$installPath = Join-Path $installDirectory 'BrowserGX.bat'
$updateDirectory = Join-Path $installDirectory 'Update'
$pendingPath = Join-Path $updateDirectory 'BrowserGX.pending.bat'
$metadataPath = Join-Path $updateDirectory 'pending.txt'
$manifestUrl = 'https://browsergx.github.io/update.txt'
$logPath = Join-Path $updateDirectory 'AutoUpdate.log'

function Write-UpdateLog {
    param([string]$Message)
    Add-Content -LiteralPath $logPath -Value ('{0:u} {1}' -f (Get-Date), $Message) -Encoding UTF8
}

function Get-ScriptVersion {
    param([string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($content, '(?m)^# BROWSERGX_VERSION=(\d+\.\d+\.\d+)\s*$')
    $parsedVersion = $null
    if (-not $match.Success -or -not [Version]::TryParse($match.Groups[1].Value, [ref]$parsedVersion)) {
        throw ('No se encontro una version valida en {0}.' -f $Path)
    }
    return $parsedVersion
}

try {
    New-Item -ItemType Directory -Path $updateDirectory -Force | Out-Null

    if ($env:BROWSERGX_MODE -notmatch '^/?check$' -and (Test-Path -LiteralPath $pendingPath) -and (Test-Path -LiteralPath $metadataPath)) {
        $metadata = @{}
        foreach ($line in (Get-Content -LiteralPath $metadataPath)) {
            if ($line -match '^(version|sha256)=(.+)$') {
                $metadata[$Matches[1]] = $Matches[2]
            }
        }
        if (-not $metadata.ContainsKey('version') -or -not $metadata.ContainsKey('sha256') -or $metadata['sha256'] -notmatch '^[a-fA-F0-9]{64}$') {
            throw 'Los metadatos de la actualizacion pendiente no son validos.'
        }
        $pendingVersion = $null
        if (-not [Version]::TryParse($metadata['version'], [ref]$pendingVersion)) {
            throw 'La version de la actualizacion pendiente no es valida.'
        }
        $pendingHash = (Get-FileHash -LiteralPath $pendingPath -Algorithm SHA256).Hash
        if ($pendingHash -ne $metadata['sha256']) {
            throw 'La suma SHA-256 de la actualizacion pendiente no coincide.'
        }
        $candidateVersion = Get-ScriptVersion -Path $pendingPath
        $installedVersion = Get-ScriptVersion -Path $installPath
        if ($candidateVersion -ne $pendingVersion) {
            throw 'La version del archivo no coincide con los metadatos de la actualizacion.'
        }
        if ($pendingVersion -gt $installedVersion) {
            $installingPath = Join-Path $installDirectory 'BrowserGX.installing.bat'
            $backupPath = Join-Path $updateDirectory 'BrowserGX.previous.bat'
            Copy-Item -LiteralPath $pendingPath -Destination $installingPath -Force
            if (Test-Path -LiteralPath $backupPath) {
                Remove-Item -LiteralPath $backupPath -Force
            }
            try {
                [System.IO.File]::Replace($installingPath, $installPath, $backupPath)
                Remove-Item -LiteralPath $backupPath -Force
            }
            catch {
                if (-not (Test-Path -LiteralPath $installPath) -and (Test-Path -LiteralPath $backupPath)) {
                    Move-Item -LiteralPath $backupPath -Destination $installPath
                }
                throw
            }
            Remove-Item -LiteralPath $pendingPath, $metadataPath -Force
            Write-UpdateLog ('Actualizada la version {0}.' -f $pendingVersion)
        }
        else {
            Remove-Item -LiteralPath $pendingPath, $metadataPath -Force
        }
    }

    if ($env:BROWSERGX_MODE -match '^/?check$') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -TimeoutSec 30
        $manifest = @{}
        foreach ($line in ($response.Content -split '\r?\n')) {
            $candidate = $line.Trim()
            if (-not $candidate -or $candidate.StartsWith('#')) {
                continue
            }
            if ($candidate -notmatch '^(version|url|sha256)=(.+)$' -or $manifest.ContainsKey($Matches[1])) {
                throw 'El manifiesto tiene un campo desconocido o duplicado.'
            }
            $manifest[$Matches[1]] = $Matches[2].Trim()
        }
        if ($manifest.Count -ne 3 -or -not $manifest.ContainsKey('version') -or -not $manifest.ContainsKey('url') -or -not $manifest.ContainsKey('sha256')) {
            throw 'El manifiesto debe incluir version, url y sha256.'
        }
        $releaseVersion = $null
        if (-not [Version]::TryParse($manifest['version'], [ref]$releaseVersion) -or $manifest['version'] -notmatch '^\d+\.\d+\.\d+$') {
            throw 'La version del manifiesto no es valida; use el formato N.N.N.'
        }
        if ($manifest['sha256'] -notmatch '^[a-fA-F0-9]{64}$') {
            throw 'El SHA-256 del manifiesto no es valido.'
        }
        $releaseUri = $null
        if (-not [Uri]::TryCreate($manifest['url'], [UriKind]::Absolute, [ref]$releaseUri) -or $releaseUri.Scheme -ne 'https' -or $releaseUri.Host -ne 'browsergx.github.io') {
            throw 'La URL del release debe ser HTTPS y pertenecer a browsergx.github.io.'
        }
        $installedVersion = Get-ScriptVersion -Path $installPath
        if ($releaseVersion -gt $installedVersion) {
            $downloadPath = Join-Path $updateDirectory 'BrowserGX.download.tmp'
            Invoke-WebRequest -Uri $releaseUri.AbsoluteUri -UseBasicParsing -OutFile $downloadPath -TimeoutSec 60
            $downloadHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash
            if ($downloadHash -ne $manifest['sha256']) {
                throw 'El SHA-256 del archivo descargado no coincide con el manifiesto.'
            }
            $downloadVersion = Get-ScriptVersion -Path $downloadPath
            if ($downloadVersion -ne $releaseVersion) {
                throw 'La version del archivo descargado no coincide con la del manifiesto.'
            }
            Move-Item -LiteralPath $downloadPath -Destination $pendingPath -Force
            $metadataContent = 'version=' + $releaseVersion.ToString(3) + [Environment]::NewLine + 'sha256=' + $manifest['sha256'].ToLowerInvariant()
            Set-Content -LiteralPath $metadataPath -Value $metadataContent -Encoding ASCII
            Write-UpdateLog ('Descargada la version {0}; se aplicara en el siguiente inicio.' -f $releaseVersion)
        }
    }
}
catch {
    try {
        Write-UpdateLog ('Error: ' + $_.Exception.Message)
    }
    catch {
        Write-Warning ('No se pudo registrar el error del actualizador: ' + $_.Exception.Message)
    }
}

if ($env:BROWSERGX_MODE -notmatch '^/?check$') {
    try {
        $appArguments = $env:BROWSERGX_ARGS -replace '^\s*/(?:check|launch)\b\s*', ''
        $appArguments = ($appArguments + ' /managed').Trim()
        $launchCommand = '/d /c ""' + $installPath + '" ' + $appArguments + '"'
        Start-Process -FilePath $env:ComSpec -ArgumentList $launchCommand -WorkingDirectory $installDirectory
    }
    catch {
        try {
            Write-UpdateLog ('No se pudo iniciar BrowserGX: ' + $_.Exception.Message)
        }
        catch {
            Write-Warning ('No se pudo registrar el error de inicio: ' + $_.Exception.Message)
        }
    }
}
'@
    Set-Content -LiteralPath $updaterPath -Value $autoUpdaterContent -Encoding ASCII

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
        $startupCommand = '"' + $env:ComSpec + '" /d /c ""' + $updaterPath + '" /startup"'
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
        Write-Host 'El inicio de sesion usara AutoUpdate.bat y ejecutara BrowserGX.bat desde la carpeta instalada.'
    }
}
catch {
    Write-Host ("No se pudo preparar la instalacion: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

try {
    Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c ""' + $updaterPath + '" /check"') -WorkingDirectory $installDirectory -WindowStyle Hidden
}
catch {
    Write-Warning ('No se pudo iniciar la comprobacion de actualizaciones: ' + $_.Exception.Message)
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
