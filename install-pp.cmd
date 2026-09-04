@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "PP_INSTALL_DIR=%USERPROFILE%\bin"
set "PP_URL=https://raw.githubusercontent.com/sarch-codelab/portalpilot-app/main/pp.cmd"
set "PP_TARGET=%PP_INSTALL_DIR%\pp.cmd"

if not exist "%PP_INSTALL_DIR%" mkdir "%PP_INSTALL_DIR%"
where curl.exe >nul 2>&1
if errorlevel 1 (
  echo Portal Pilot necesita curl, incluido en Windows 10 y 11.
  exit /b 1
)

curl.exe -L --fail --silent --show-error -o "%PP_TARGET%" "%PP_URL%"
if errorlevel 1 (
  echo No se pudo instalar Portal Pilot. Revisa tu conexion.
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=[Environment]::GetEnvironmentVariable('Path','User'); $d='%PP_INSTALL_DIR%'; if (-not (($p -split ';') -contains $d)) {[Environment]::SetEnvironmentVariable('Path', (($p.TrimEnd(';') + ';' + $d).Trim(';')), 'User')}"
if errorlevel 1 (
  echo Portal Pilot se descargo, pero no se pudo actualizar el PATH.
  echo Ejecuta manualmente: setx PATH "%%PATH%%;%PP_INSTALL_DIR%"
  exit /b 1
)

set "PATH=%PATH%;%PP_INSTALL_DIR%"
echo.
echo Portal Pilot instalado correctamente.
echo Cierra y abre CMD para usar el comando global: pp
pp
endlocal
