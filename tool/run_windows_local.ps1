# Lanza la app de Windows manteniendo TEMP/TMP y la base de datos dentro del
# repositorio. Necesario en entornos con escritura restringida (sandbox), donde
# solo el workspace es escribible: %LOCALAPPDATA%\Temp y Documents quedan en
# solo lectura y rompen DevFS (`_createDevFS`) y SQLite (readonly database).
#
# Uso:  pwsh -File tool\run_windows_local.ps1 [argumentos para `flutter run`]
$ErrorActionPreference = 'Stop'

$Project = Split-Path -Parent $PSScriptRoot
$TmpDir = Join-Path $Project '.tmp\TEMP'
$DataDir = Join-Path $Project '.localdata'

foreach ($Dir in @($TmpDir, $DataDir)) {
    if (-not (Test-Path -LiteralPath $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }
}

$env:TEMP = $TmpDir
$env:TMP = $TmpDir
$env:PORTAL_PILOT_DATA_DIR = $DataDir

Write-Host "TEMP=$env:TEMP"
Write-Host "PORTAL_PILOT_DATA_DIR=$env:PORTAL_PILOT_DATA_DIR"

Push-Location $Project
try {
    & flutter run -d windows @args
} finally {
    Pop-Location
}
