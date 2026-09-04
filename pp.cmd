@echo off
set "PP_SCRIPT=%~dp0pp.ps1"

if not exist "%PP_SCRIPT%" (
  echo Portal Pilot no encontro su nucleo Navi.
  exit /b 1
)

rem Actualiza el nucleo local en cada inicio; conserva la copia actual si no hay red.
set "PP_UPDATE_URL=https://github.com/sarch-codelab/portalpilot-app/releases/download/v0.1.5/pp.ps1"
set "PP_UPDATE_FILE=%PP_SCRIPT%.update"
curl.exe -L --fail --silent --show-error -o "%PP_UPDATE_FILE%" "%PP_UPDATE_URL%" >nul 2>&1
if not errorlevel 1 (
  move /Y "%PP_UPDATE_FILE%" "%PP_SCRIPT%" >nul
)
if exist "%PP_UPDATE_FILE%" del /Q "%PP_UPDATE_FILE%" >nul 2>&1

where wt.exe >nul 2>&1
if not errorlevel 1 (
  start "Portal Pilot" wt.exe -w 0 new-tab --title "Portal Pilot Command Deck" --tabColor #8B5CF6 powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%PP_SCRIPT%"
  exit /b 0
)

powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%PP_SCRIPT%"
exit /b 0

rem Legacy CMD deck kept below for offline fallback compatibility.
:legacy
setlocal EnableExtensions
chcp 65001 >nul
color 0B
set "PP_VERSION=v0.1.5"
set "PP_RELEASE=https://github.com/sarch-codelab/portalpilot-app/releases/tag/%PP_VERSION%"
set "PP_WEB=https://portalpilot-app.vercel.app"
set "PP_WIN=https://github.com/sarch-codelab/portalpilot-app/releases/download/%PP_VERSION%/Portal_Pilot_WDx64_v0.1.5.exe"
set "PP_APK=https://github.com/sarch-codelab/portalpilot-app/releases/download/%PP_VERSION%/PortalPilot_Android_v0.1.5.apk"
set "PP_DIR=%USERPROFILE%\Downloads\PortalPilot"

:menu
cls
call :brand
echo.
echo       COMMAND DECK  /  NUCLEO NAVI  /  HONDURAS
echo       Estado del enlace: ACTIVO       Version: %PP_VERSION%
echo.
echo       [1] Abrir el Portal Pilot
echo       [2] Abrir la compuerta de versiones
echo       [3] Desplegar Portal Pilot en Windows ARM / x64
echo       [4] Enviar Portal Pilot a Android ARM
echo       [5] Abrir el hangar de descargas
echo       [6] Ejecutar escaneo Navi del equipo
echo       [0] Cerrar el Command Deck
 echo.
choice /C 1234560 /N /M "       Portal Pilot ^> Selecciona una opcion: "
if errorlevel 7 goto :exit
if errorlevel 6 goto :diagnostic
if errorlevel 5 goto :downloads
if errorlevel 4 goto :apk
if errorlevel 3 goto :windows
if errorlevel 2 goto :release
if errorlevel 1 goto :web
goto :menu

:web
start "Portal Pilot" "%PP_WEB%"
echo.
echo       Portal Pilot se abrio en tu navegador.
timeout /t 2 /nobreak >nul
goto :menu

:release
start "Portal Pilot Releases" "%PP_RELEASE%"
echo.
echo       Abriendo el centro de versiones...
timeout /t 2 /nobreak >nul
goto :menu

:windows
if not exist "%PP_DIR%" mkdir "%PP_DIR%"
echo.
echo       Descargando instalador Windows...
curl.exe -L --fail --progress-bar -o "%PP_DIR%\Portal_Pilot_WDx64_v0.1.5.exe" "%PP_WIN%"
if errorlevel 1 (
  echo       No se pudo descargar. Revisa tu conexion a internet.
) else (
  echo       Descarga completa: %PP_DIR%\Portal_Pilot_WDx64_v0.1.5.exe
  choice /C SN /N /M "       Deseas iniciar el instalador ahora? [S/N]: "
  if errorlevel 2 goto :menu
  start "Portal Pilot Installer" "%PP_DIR%\Portal_Pilot_WDx64_v0.1.5.exe"
)
timeout /t 3 /nobreak >nul
goto :menu

:apk
if not exist "%PP_DIR%" mkdir "%PP_DIR%"
echo.
echo       Descargando APK Android ARM...
curl.exe -L --fail --progress-bar -o "%PP_DIR%\PortalPilot_Android_v0.1.5.apk" "%PP_APK%"
if errorlevel 1 (
  echo       No se pudo descargar. Revisa tu conexion a internet.
) else (
  echo       APK listo en: %PP_DIR%\PortalPilot_Android_v0.1.5.apk
  echo       Transfiere el archivo al telefono para instalarlo.
)
timeout /t 3 /nobreak >nul
goto :menu

:downloads
if not exist "%PP_DIR%" mkdir "%PP_DIR%"
start "Portal Pilot Downloads" "%PP_DIR%"
goto :menu

:diagnostic
cls
call :brand
echo       ESCANEO NAVI  /  PERFIL DEL EQUIPO
echo.
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type"
echo.
where curl.exe >nul 2>&1 && echo       OK  curl disponible || echo       AVISO  curl no encontrado
where winget.exe >nul 2>&1 && echo       OK  winget disponible || echo       AVISO  winget no encontrado
where flutter.bat >nul 2>&1 && echo       OK  Flutter disponible || echo       INFO  Flutter no instalado (no necesario para usar la app)
echo.
pause
goto :menu

:exit
color 07
cls
echo.
echo       Portal Pilot: hasta pronto.
echo.
endlocal
exit /b 0

:brand
echo.
echo        +------------------------------------------------+
echo        +       PORTAL PILOT  /  COMMAND DECK            +
echo        +       N A V I   C O R E   O N L I N E          +
echo        +------------------------------------------------+
echo.
echo                 P O R T A L   P I L O T
exit /b 0
