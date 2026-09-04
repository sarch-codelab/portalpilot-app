$ErrorActionPreference = 'Stop'
$Version = 'v0.1.5'
$Web = 'https://portal-pilot.vercel.app'
$Release = "https://github.com/sarch-codelab/portalpilot-app/releases/tag/$Version"
$WindowsUrl = "https://github.com/sarch-codelab/portalpilot-app/releases/download/$Version/Portal_Pilot_WDx64_v0.1.5.exe"
$ApkUrl = "https://github.com/sarch-codelab/portalpilot-app/releases/download/$Version/PortalPilot_Android_v0.1.5.apk"
$DownloadPath = Join-Path $env:USERPROFILE 'Downloads\PortalPilot'
$Esc = [char]27
$Purple = "$Esc[38;5;141m"
$Lavender = "$Esc[38;5;183m"
$Cyan = "$Esc[38;5;81m"
$Green = "$Esc[38;5;78m"
$Muted = "$Esc[38;5;245m"
$White = "$Esc[97m"
$Reset = "$Esc[0m"
$Clear = "$Esc[2J$Esc[H"

function Show-Brand([int]$Frame = 0, [bool]$ClearScreen = $true) {
    if ($ClearScreen) {
        Write-Host "$Clear$Purple"
    } else {
        Write-Host "$Esc[H$Purple"
    }
    $Logo = @(
        '██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗         ██████╗ ██╗██╗      ██████╗ ████████╗'
        '██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║         ██╔══██╗██║██║     ██╔═══██╗╚══██╔══╝'
        '██████╔╝██║   ██║██████╔╝   ██║   ███████║██║         ██████╔╝██║██║     ██║   ██║   ██║   '
        '██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║         ██╔═══╝ ██║██║     ██║   ██║   ██║   '
        '██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗    ██║     ██║███████╗╚██████╔╝   ██║   '
        '╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝╚══════╝ ╚═════╝    ╚═╝   '
    )
    $BorderCharacters = '═║╔╗╚╝╠╣╦╩'
    foreach ($LogoLine in $Logo) {
        [Console]::Write('   ')
        for ($column = 0; $column -lt $LogoLine.Length; $column++) {
            $Character = [string]$LogoLine[$column]
            if ($BorderCharacters.Contains($Character)) {
                $distance = [Math]::Abs($column - (($Frame % 120) - 10))
                $glow = [Math]::Max(0, 1 - ($distance / 14))
                $red = [int](100 + (155 * $glow))
                $green = [int](25 + (55 * $glow))
                $blue = [int](185 + (70 * $glow))
                [Console]::Write("$Esc[38;2;${red};${green};${blue}m$Character")
            } else {
                [Console]::Write("$Purple$Character")
            }
        }
        [Console]::Write("$Reset`n")
    }
    Write-Host "$Reset"
    Write-Host "   $White PORTAL PILOT $Purple// COMMAND DECK $Reset"
    Write-Host "   $Muted NUCLEO NAVI $Green● EN LINEA $Muted // $Version$Reset"
}

function Pause-Deck {
    Write-Host ""
    Read-Host "$Muted Presiona ENTER para volver al Command Deck$Reset" | Out-Null
}

function Download-Asset([string]$Url, [string]$FileName) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
    $Target = Join-Path $DownloadPath $FileName
    Write-Host ""
    Write-Host "   $Lavender>NAVI esta transfiriendo $FileName...$Reset"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Target -UseBasicParsing
        Write-Host "   $Green● Transferencia completa$Reset"
        Write-Host "   $Muted$Target$Reset"
        return $Target
    } catch {
        Write-Host "   $Esc[38;5;203m● No se pudo completar la transferencia$Reset"
        return $null
    }
}

function Show-Deck {
    if ([Console]::IsInputRedirected) {
        Show-Brand
        return ([Console]::ReadLine()).Trim()
    }

    $Frame = 0
    while ($true) {
        Show-Brand $Frame ($Frame -eq 0)
        Write-Host ""
        Write-Host "   $White 01 $Lavender ABRIR PORTAL PILOT$Reset       $Muted Acceso web$Reset"
        Write-Host "   $White 02 $Lavender VER VERSIONES$Reset             $Muted Releases y novedades$Reset"
        Write-Host "   $White 03 $Lavender DESPLEGAR EN WINDOWS$Reset      $Muted Instalador ARM / x64$Reset"
        Write-Host "   $White 04 $Lavender ENVIAR A ANDROID$Reset          $Muted APK ARM para pruebas$Reset"
        Write-Host "   $White 05 $Lavender ABRIR HANGAR$Reset               $Muted Carpeta de descargas$Reset"
        Write-Host "   $White 06 $Lavender ESCANEO NAVI$Reset               $Muted Diagnostico del equipo$Reset"
        Write-Host "   $Purple----------------------------------------------------------------$Reset"
        Write-Host "   $Muted 00 CERRAR COMMAND DECK$Reset"
        Write-Host ""
        Write-Host "   $Purple> Escribe una tecla para elegir una ruta$Reset"

        for ($wait = 0; $wait -lt 8; $wait++) {
            if ([Console]::KeyAvailable) {
                return ([Console]::ReadKey($true).KeyChar.ToString())
            }
            Start-Sleep -Milliseconds 45
        }
        $Frame++
    }
}

while ($true) {
    $Choice = Show-Deck
    switch ($Choice) {
        '1' { Start-Process $Web; Pause-Deck }
        '2' { Start-Process $Release; Pause-Deck }
        '3' {
            $File = Download-Asset $WindowsUrl 'Portal_Pilot_WDx64_v0.1.5.exe'
            if ($File -and (Read-Host "   ${Muted}Abrir instalador ahora? (S/N)$Reset") -match '^[sS]$') { Start-Process $File }
            Pause-Deck
        }
        '4' { Download-Asset $ApkUrl 'PortalPilot_Android_v0.1.5.apk' | Out-Null; Pause-Deck }
        '5' { New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null; Start-Process $DownloadPath }
        '6' {
            Show-Brand
            Write-Host "   $White ESCANEO NAVI / PERFIL DE ENLACE$Reset"
            Write-Host ""
            Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | Format-List
            Write-Host "   $Green● PowerShell disponible$Reset"
            if (Get-Command wt.exe -ErrorAction SilentlyContinue) { Write-Host "   $Green● Windows Terminal disponible$Reset" } else { Write-Host "   $Muted○ Windows Terminal no detectado$Reset" }
            Pause-Deck
        }
        '0' { Clear-Host; Write-Host "$Purple`n   PORTAL PILOT // ENLACE CERRADO$Reset`n"; return }
        '00' { Clear-Host; Write-Host "$Purple`n   PORTAL PILOT // ENLACE CERRADO$Reset`n"; return }
    }
}
