# Portal Pilot v0.1.1

## Brand
- Robot logo de `img/Iconos/robot_logo.png` como icono oficial Android (mipmap 48/72/96/144/192), Windows `app_icon.ico` multi-size y Web (favicon + icons 192/512 maskable)

## Onboarding
- 6 pasos (3 intros + 3 preguntas separadas) con validacion por paso, cards full-width y radio
- Fondo `base-tecnologica.png` 0.14 opacity + gradient overlay
- Splash siempre antes de onboarding, fix `Crear mi espacio` -> `Login` via pushAndRemoveUntil
- `Crear mi espacio` en paso 6 con fallback `Ir directo a Acceder`

## Auth
- Onboarding guarda `business_type/customer_type/operation_type` en SharedPreferences
- Login register tab muestra `TUS SELECCIONES PRE-SELECCIONADO` y envia `?business_type=&customer_type=&operation_type=&onboarding=1` al portal, solo falta completar resto

## Builds
- Windows `PortalPilotWorkspace.exe 43.2MB` y APK `app-release.apk 89.7MB` firmados con `upload-keystore.jks`
- Commit: e2a28fa

Generated via --generate-notes
