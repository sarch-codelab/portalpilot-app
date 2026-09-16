# Portal Pilot v0.1.5

## Correcciones y mejoras
- Registro externo funcional con estado de carga, manejo de errores y datos preseleccionados.
- Nueva barra móvil con el Núcleo Portal Pilot para acceso rápido al menú, configuración, soporte y salida.
- Instalador Windows compatible con equipos ARM que soportan emulación x64.
- Build Android actualizado a `0.1.5+2`.

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

# Portal Pilot v1.0.9+7

## Fondos claro/oscuro (fix raíz)
- Los fondos claros y oscuros estaban INTERCAMBIADOS en `assets/img/fondos/` (el archivo `claro` estaba en `*_dark` y el `oscuro` en `*_light`). Verificado por checksum y luminancia (pc_dark ahora 27 lum, pc_light 198 lum) e intercambiados.
- Renombrados los orígenes en `img/fondos-img/fondos dispositivos/` (claro/oscuro) para que no vuelva a pasar.

## Notificaciones estilo Sileo
- Nuevo sistema de toasts estilo Sileo (sileo.aaryan.design): tarjetas apiladas arriba, blur, barra de progreso, swipe/tap para cerrar, temporizador que se pausa con la app en segundo plano.
- `PPNotifications.success/error/info/warning` con títulos automáticos; ReadOnlyGuard y todos los avisos nuevos lo usan.
- SnackBarTheme de respaldo legible en ambos temas.

## Tema claro arreglado
- Panel de módulos (Home) rediseñado por completo con la paleta: encabezado, búsqueda, tarjetas de módulo, acciones rápidas, drawer, bottom nav y footer ya no usan negros fijados.
- Toggle de tema Claro/Oscuro/Sistema visible en el Home (móvil y PC) y en la barra superior de TODOS los módulos, con menú de selección y persistencia.
- Chat IA: texto negro puro en claro corregido, burbujas, chips, historial e input adaptados; el borde del input ahora se ve en claro.
- ProductoForm (Nuevo Producto) con fondo, campos, dropdowns, diálogos y estados vacíos con paleta.
- Scaffold de módulos: el fondo claro ya no se oscurece (antes se aplicaba un filtro negro en claro); ahora se aclara con tinte lavanda para legibilidad.

## Submódulos (Nuevo Producto y más)
- FIX raíz: el guard de solo lectura bloqueaba las acciones "Nuevo" en silencio si la ventana no tenía un Scaffold arriba; ahora el aviso se muestra siempre y el flujo continúa cuando corresponde.
- Los handlers de "Nuevo" se pasan correctamente al shell; el aviso de solo lectura usa el estilo Sileo.

## Navegación
- Chat IA: nuevo botón "Panel de módulos" en la barra superior (móvil y PC) que lleva al Home limpiando la pila.
- Móvil dentro de módulos: breadcrumb compacto (icono + título) y botón FAB "Nuevo" flotante además del de la topbar.

## Versiones
- version: 1.0.9+7, instalador Inno Setup a 1.0.9
