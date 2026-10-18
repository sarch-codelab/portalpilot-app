param(
    [ValidateSet('windows', 'chrome', 'edge')]
    [string]$Device,
    [switch]$BuildWindows
)

$ErrorActionPreference = 'Stop'
$RuntimeRoot = Join-Path $PSScriptRoot '.dart_tool\portal-pilot-runtime'
$TempDirectory = Join-Path $RuntimeRoot 'temp'
$DataDirectory = Join-Path $RuntimeRoot 'data'

New-Item -ItemType Directory -Path $TempDirectory, $DataDirectory -Force | Out-Null

$RunningApp = Get-Process -Name 'PortalPilotWorkspace' -ErrorAction SilentlyContinue
if ($RunningApp) {
    Write-Host 'Cerrando la instancia anterior antes de compilar...'
    $RunningApp | Stop-Process -Force
}

$env:TEMP = $TempDirectory
$env:TMP = $TempDirectory
$env:PORTAL_PILOT_DATA_DIR = $DataDirectory

Push-Location $PSScriptRoot
try {
    if ($BuildWindows) {
        & flutter build windows --verbose
    } elseif ($Device) {
        & flutter run -d $Device
    } else {
        & flutter run
    }
    $ExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $ExitCode