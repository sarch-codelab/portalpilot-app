@echo off
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
echo.
echo  ================================================================
echo       PORTAL PILOT HONDURAS  ^|  CENTRO DE CONTROL
 echo  ================================================================
echo.
echo       Tu portal. Tu operacion. Un solo comando.
echo       Version estable: %PP_VERSION%
echo.
echo       [1] Visitar Portal Pilot en la web
echo       [2] Ver la ultima version publicada
echo       [3] Descargar instalador Windows ARM / x64
echo       [4] Descargar app Android ARM
echo       [5] Abrir carpeta de descargas
echo       [6] Diagnostico de este equipo
echo       [0] Salir
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
echo.
echo  ================================================================
echo       PORTAL PILOT  ^|  DIAGNOSTICO DEL EQUIPO
echo  ================================================================
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
