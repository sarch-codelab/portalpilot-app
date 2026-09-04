<div align="center">

# Portal Pilot

**ERP multi-área y multi-tenant para Honduras** — App móvil, web y escritorio con facturación electrónica SAR, POS con escáner de códigos de barras, inventario multi-bodega, **asistente IA "Navi"** y sincronización offline-first.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white)
![Groq](https://img.shields.io/badge/Groq%20IA-F55036?logo=groq&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-000000?logo=vercel&logoColor=white)
![Version](https://img.shields.io/badge/Version-0.1.5-8B5CF6)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20Web-6B7280)

</div>

---

## Tabla de contenidos

- [Descripción](#descripción)
- [Planes de suscripción](#planes-de-suscripción)
- [Características](#características)
- [Asistente IA "Navi"](#asistente-ia-navi)
- [Áreas de negocio](#áreas-de-negocio)
- [Módulos del sistema](#módulos-del-sistema)
- [Arquitectura](#arquitectura)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Requisitos](#requisitos)
- [Configuración](#configuración)
- [Cómo ejecutar](#cómo-ejecutar)
- [Base de datos](#base-de-datos)
- [API Serverless](#api-serverless)
- [Sincronización offline](#sincronización-offline)
- [Pruebas](#pruebas)
- [Builds y despliegue](#builds-y-despliegue)
- [Instalador Windows](#instalador-windows)
- [Licencia](#licencia)

---

## Descripción

**Portal Pilot** es un ERP diseñado para negocios hondureños (pulperías, abarroterías, distribuidoras, supermercados, cadenas multi-sucursal, clubes de membresía e instituciones educativas). Funciona **offline-first**: los datos se guardan localmente (SQLite/Drift) y se sincronizan con la nube (Supabase) cuando hay conexión, con cola de sincronización y resolución de conflictos por `(empresa, código)`.

Está construido con un único código Flutter que compila para **Windows, Android, iOS y Web**, respaldado por una API serverless en Vercel y una base de datos PostgreSQL multi-tenant.

El sistema incluye módulos por área de negocio y un **asistente de IA "Navi"** que se adapta al plan de suscripción de la empresa (Prueba / Business / Enterprise).

---

## Planes de suscripción

La IA **Navi** y las capacidades del ERP se adaptan según el plan contratado por la empresa (leído del backend en el inicio de sesión y persistido en `empresa_plan`):

| Plan | Precio | Usuarios | Empresas | IA Navi | Soporte |
|---|---|---|---|---|---|
| **Prueba** | Gratis (15 días) | 5 | 1 | Uso básico | Email |
| **Business** | L 1,499 / mes | 15 | 3 | Uso generoso | Email prioritario |
| **Enterprise** | L 4,999 / mes | Ilimitados | Ilimitadas | Avanzada / personalizada | Prioritario 24/7 |

Todos los planes incluyen **Facturación electrónica SAR**.

---

## Características

### Finanzas y fiscalidad
- **Facturación electrónica SAR** — CAI, RTN, correlativos, generación de PDF y tickets.
- **Número a letras** y validación de CAI/RTN conforme a normativa hondureña.
- Retenciones, libros contables, cierres mensuales y conciliación bancaria.

### Punto de Venta (POS)
- **Escáner de códigos de barras** con cámara (EAN-13/8, UPC-A/E, Code 39/93/128, ITF, DataMatrix, QR).
- Carrito con cantidades, descuentos, promociones e **ISV 15%/18%** automático.
- Impresión de tickets (PDF/impresora) y registro de ventas con decremento de stock atómico.
- Ingreso manual de código como respaldo e **IA que analiza y recomienda productos** en el carrito.

### Inventario
- Productos con imagen, categorías, unidades de medida, **precio compra/venta**, stock mínimo y bodega.
- **Kardex**, múltiples bodegas, lotes, fechas de caducidad, trazabilidad y recepción.
- **Dedupe garantizado por `(empresa_codigo, codigo)`** — en la API, en la BD local y en SharedPreferences.
- **Lectura de códigos de barras con IA de visión** para el alta rápida de productos.

### Educación
- **Notas**, **matrícula** y **asistencia** para instituciones educativas.
- Integración del asistente **Navi** con contexto académico.

### Gestión comercial y clientes
- CRM con clientes, ventas y seguimiento; CRM Avanzado con leads, campañas y segmentación.
- Compras, proveedores, cotizaciones, órdenes de compra y recepción.
- Canal Tradicional (fiado, cobros, rutas) y Canal Moderno (multi-sucursal, transferencias, consolidado).
- Membresías (socios, precios preferenciales, vigencias).

### Multi-área y multi-tenant
- **Empresas como tenants** con módulos habilitados según el área de negocio y el plan.
- Configuración **multi-área**: retail, canal tradicional/moderno, membresías, comercial y educación.
- Módulos activables por empresa con flags persistentes y restablecimiento por área.

### Otros módulos
- Contabilidad, RRHH/nómina, Analytics/BI, cadena de suministro, fiscal avanzado, multi-empresa (holding), seguridad/auditoría y configuración.

---

## Asistente IA "Navi"

**Navi** es el asistente inteligente integrado del ERP (antes "Edu IA"). Se conecta a la API en Vercel con **Groq** (modelos `openai/gpt-oss-20b` y `openai/gpt-oss-120b`, con auto-descubrimiento de modelos) y se **adapta al plan de la empresa**:

- **Prueba** → respuestas concisas, funcionalidades esenciales (máx. ~300 palabras).
- **Business** → uso generoso, análisis de ventas/inventario y reportes estándar (máx. ~500 palabras).
- **Enterprise** → análisis predictivo, reportes profundos y personalización avanzada (máx. ~800 palabras).

**Capacidades de la IA (endpoints serverless `api/ai/…`):**
- `ai/chat` — Chat conversacional de Navi con contexto del ERP y RPA local (crear documentos/HTML).
- `ai/vision` — Análisis de productos por cámara.
- `ai/barcode` — Reconocimiento de códigos de barras asistido.
- `ai/dashboard` — Resumen/estado del sistema.
- `ai/pos/analyze` y `ai/pos/upsell` — Análisis del carrito y recomendaciones de venta cruzada.
- `ai/crm/customer` — Apertura/contexto de clientes.
- `ai/support` — Asistente de soporte técnica (módulo Soporte).

El plan se extrae del backend en el login (`_planDesdeRespuesta`), se persiste en `empresa_plan` (SharedPreferences) y se inyecta en el prompt maestro de `EduIARules.generarPromptMaestro()`.

---

## Áreas de negocio

El catálogo de áreas (en `multi_area_config.dart`) determina los módulos por defecto de una empresa:

| Área | Módulos por defecto |
|---|---|
| **Comercial Genérico** | comercial, facturación, inventario, contabilidad, crm, cotizaciones |
| **Retail** | pos, facturación, inventario, crm, contabilidad |
| **Membresías** | membresías, pos, facturación, inventario, crm |
| **Canal Tradicional** | pos, facturación, crm, inventario |
| **Canal Moderno** | pos, facturación, inventario, contabilidad, crm |
| **General** | todos los módulos habilitados |
| **Educación** | educacion, facturación, inventario, rrhh, crm |

---

## Módulos del sistema

| Módulo | Descripción | Ruta |
|---|---|---|
| `chat_ia` | Asistente Navi, análisis y creación | `/modules/chat_ia` |
| `educacion` | Notas, matrícula, asistencia | `/modules/educacion` |
| `facturacion` | Facturación SAR electrónica | `/modules/facturacion` |
| `inventario` | Productos, kardex, bodegas | `/modules/inventario` |
| `contabilidad` | Estados financieros, transacciones | `/modules/contabilidad` |
| `rrhh` | Empleados, planilla, beneficios | `/modules/rrhh` |
| `crm` | Clientes, ventas, seguimiento | `/modules/crm` |
| `pos` | Punto de venta, cobros, código de barras | `/modules/pos` |
| `comercial` | Compras, proveedores, cotizaciones, OC | `/modules/comercial` |
| `membresias` | Socios, precios preferenciales, vigencias | `/modules/membresias` |
| `canal_moderno` | Multi-sucursal, transferencias, consolidado | `/modules/canal_moderno` |
| `canal_tradicional` | Fiado, rutas de reparto | `/modules/canal_tradicional` |
| `cotizaciones` | Cotizaciones a clientes, conversión a ventas | `/modules/cotizaciones` |
| `compras_proveedores` | Órdenes de compra, recepción, costeo | `/modules/compras_proveedores` |
| `sector_retail` | Precios por canal, promociones, inventario por tienda | `/modules/sector_retail` |
| `settings` | Configuración fiscal, backups, logs | `/modules/settings` |
| `analytics` | Dashboards gerenciales, KPIs, forecasting | `/modules/analytics` |
| `supply_chain` | Recepción, trazabilidad, multi-bodega | `/modules/supply_chain` |
| `crm_advanced` | Leads, oportunidades, campañas, segmentación | `/modules/crm_advanced` |
| `fiscal_advanced` | Retenciones, libros contables, facturación electrónica | `/modules/fiscal_advanced` |
| `seguridad` | Roles granulares, auditoría, 2FA | `/modules/seguridad` |
| `multi_empresa` | Holding, filiales, consolidado, tipo de cambio | `/modules/multi_empresa` |
| `soporte` | Soporte técnico con asistente IA | — |

---

## Arquitectura

```
┌───────────────────────────────┐
│        Portal Pilot App       │  Flutter (Windows / Android / iOS / Web)
│  ┌─────────────────────────┐  │
│  │      UI (Módulos)       │  │
│  ├─────────────────────────┤  │
│  │   Navi (IA, plan-aware) │  │
│  ├─────────────────────────┤  │
│  │   SyncService (cola)    │  │
│  │  LocalDatabaseService   │  │
│  │     (SQLite / Drift)    │  │
│  └──────────┬──────────────┘  │
└─────────────┼─────────────────┘
              │ HTTPS + JWT
┌─────────────▼─────────────────┐
│  Vercel Serverless API        │  Node.js — despachador único [...slug].js
│  login · productos · ventas · │  facturas · clientes · compras · transacciones
│  ┌──────────────────────────┐ │  ai/chat · ai/vision · ai/barcode · …
│  │ Supabase (PostgreSQL)    │ │
│  │ multi-tenant + RLS       │ │
│  └──────────────────────────┘ │
└───────────────────────────────┘
        ┌──────────────┐
        │ Groq (IA)    │  ✓ model picker automático
        └──────────────┘
```

**Principios clave:**
- **Offline-first**: la app funciona sin red; los cambios se encolan y sincronizan en segundo plano.
- **Upsert idempotente**: los endpoints usan `(empresa_codigo, codigo)` como clave natural para evitar duplicados.
- **Multi-tenant**: aislamiento por `empresa_codigo` con Row Level Security en Supabase.
- **IA plan-aware**: el prompt maestro de Navi cambia según el plan de la empresa.

---

## Estructura del repositorio

```
pp-w/
├── api/
│   ├── [...slug].js           # Despachador único de la API serverless
│   ├── _modelPicker.js        # Auto-descubrimiento de modelos Groq
│   └── ai/                    # Sub-rutas de IA (chat, vision, barcode, pos, …)
├── lib/
│   ├── main.dart              # Punto de entrada
│   ├── Auth/                  # Login, registro, sesión
│   ├── Home/                  # Home y configuración multi-área
│   ├── onboarding/            # Onboarding de empresa (área negocio)
│   ├── Modules/               # Módulos funcionales (ver tabla)
│   │   ├── ChatIA/            # Asistente Navi
│   │   └── Educacion/         # Módulo educativo + ia/ (reglas + chat Navi)
│   └── Shared/
│       ├── database/          # Esquema Drift (app_database.dart + .g.dart)
│       ├── services/          # Sync, POS, SAR, IA, local DB, backup, …
│       ├── models/            # Modelos de dominio
│       ├── widgets/           # Widgets compartidos
│       ├── theme/             # Tema de la app
│       ├── mixins/            # Mixins compartidos
│       └── utils/             # Utilidades (logger, …)
├── img/fondos-img/            # Fondos e imágenes de login/onboarding
├── assets/
│   ├── img/                   # robot_logo.png y otros recursos
│   └── installer/             # Imágenes del instalador (Inno Setup)
├── supabase/
│   ├── schema.sql             # Esquema multi-tenant
│   ├── migracion_sync.sql     # Migración de sincronización (idempotente)
│   ├── migracion_matriculas.sql
│   └── crear_tabla_productos.sql
├── test/                      # Tests unitarios (flutter test)
├── docs/                      # Documentación (instalación, storage Supabase)
├── setup.iss                  # Script Inno Setup para instalador Windows
├── pubspec.yaml
├── codemagic.yaml             # CI: builds web e iOS
└── vercel.json
```

---

## Requisitos

- **Flutter** 3.24+ (Dart 3.x)
- **Node.js** 18+ (solo para la API)
- Cuenta en **Supabase** (base de datos), **Vercel** (API) y **Groq** (IA)
- Android SDK (para builds Android) o Xcode (para iOS)
- Visual Studio con C++ y **Inno Setup 6** (solo para empaquetar el instalador Windows)

---

## Configuración

### 1. Variables de entorno

La app lee la configuración desde `--dart-define` o variables de entorno. Las variables de la API se configuran en el panel de Vercel:

| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave de rol de servicio (solo servidor) |
| `WEB_DOMAIN` | Dominio del portal web |
| `GROQ_API_KEY` | Clave de la API de Groq (asistente Navi) |

> ⚠️ `.env*` está en `.gitignore`. No se suben secretos al repositorio. Respaldar `android/app/upload-keystore.jks` (llave de firma Android) en un lugar seguro.

### 2. Base de datos (Supabase)

Ejecutar en el SQL Editor de Supabase, en orden:

1. `supabase/schema.sql` — esquema multi-tenant (empresas, usuarios, módulos).
2. `supabase/migracion_sync.sql` — tablas de sincronización + índices UNIQUE.
3. `supabase/migracion_matriculas.sql` — tablas de matrícula del módulo educativo.

Para imágenes de productos, seguir `docs/supabase_storage_setup.md` (bucket público `productos`).

### 3. API (Vercel)

Desplegar la carpeta raíz con `vercel` (el despachador vive en `api/[...slug].js`). Configurar las variables de entorno de la API en el dashboard, incluyendo `GROQ_API_KEY`.

---

## Cómo ejecutar

```bash
# Dependencias
flutter pub get

# Web (hot reload)
flutter run -d chrome

# Android (dispositivo/emulador)
flutter run -d <device-id>

# Windows / macOS / iOS
flutter run -d windows
flutter run -d macos
flutter run -d iphone
```

---

## Base de datos

Esquema **multi-tenant** en PostgreSQL (Supabase):

- **`empresas`** — tenant principal; plan, módulos habilitados, configuración.
- **`usuarios`** — extiende `auth.users`; rol global (`owner`/`admin`/`user`).
- **`empresa_modulos` / `usuario_modulos`** — módulos por empresa y por usuario.
- **Tablas de negocio** — `productos`, `facturas`, `clientes`, `ventas`, `transacciones`, `compras`, `proveedores`, `cotizaciones`, `ordenes-compra`, `matriculas`, `notas`, `empleados`, `nomina`, … con columna de tenant `empresa_codigo`.

**Garantía anti-duplicados** en `productos`:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_productos_empresa_codigo_codigo
  ON productos(empresa_codigo, codigo);
```

Las políticas RLS filtran por `empresa_codigo` comparando el claim del JWT.

---

## API Serverless

Un único handler (`api/[...slug].js`) despacha por ruta (optimizado para el plan Hobby de Vercel, máx. 12 funciones):

| Endpoint | Métodos | Descripción |
|---|---|---|
| `/api/login` | `POST` | Autenticación |
| `/api/productos` | `GET, POST, PATCH, DELETE` | Catálogo (upsert idempotente) |
| `/api/ventas` | `POST` | Registra venta, decrementa stock y crea factura |
| `/api/facturas` | `GET, POST, PATCH` | Facturación |
| `/api/clientes` | `GET, POST, DELETE` | CRM |
| `/api/transacciones` | — | Contabilidad |
| `/api/compras` · `/api/proveedores` | — | Comercial |
| `/api/cotizaciones` · `/api/ordenes-compra` | — | Cotizaciones |
| `/api/matriculas` · `/api/notas` | — | Módulo educativo |
| `/api/sync` | — | Sincronización |
| `/api/storage` | — | Almacenamiento de imágenes |
| `/api/ai/chat` · `/api/ai/groq` | `POST` | Asistente Navi |
| `/api/ai/vision` · `/api/ai/barcode` | — | IA de visión y códigos |
| `/api/ai/dashboard` · `/api/ai/pos/analyze` · `/api/ai/pos/upsell` | — | IA de análisis |
| `/api/ai/crm/customer` · `/api/ai/support` | — | IA de CRM y soporte |

---

## Sincronización offline

1. Los cambios se escriben primero en la **BD local (SQLite/Drift)**.
2. `SyncService` encola las operaciones (`insert`/`delete`) en la tabla `sync_queue`.
3. En segundo plano se reenvían al servidor; al recibir confirmación, se eliminan de la cola.
4. Los productos descargados de Supabase se hacen **upsert por `(empresa_codigo, codigo)`**, reutilizando el id local existente.
5. `SharedPreferences` se reconstruyen desde la BD local (sin acumular duplicados).

---

## Pruebas

```bash
# Suite completa
flutter test

# Un archivo específico
flutter test test/multi_area_config_test.dart

# Análisis estático (sin errores)
flutter analyze
```

Los tests cubren config multi-área, servicios SAR (CAI, RTN, número a letras) y generación de PDF de facturas.

---

## Builds y despliegue

```bash
# Windows (principal, instala en escritorio)
flutter build windows --release

# Android release
flutter build apk --release

# Web
flutter build web --release

# iOS (con firma)
flutter build ipa --release
```

CI con **Codemagic** (`codemagic.yaml`): workflows para web e iOS (IPA ad-hoc con `com.sarchcodelab.portalpilot`). La API se despliega a Vercel.

---

## Instalador Windows

El instalador se genera con **Inno Setup** a partir de `setup.iss`, con imágenes personalizadas, mensajes en español, compresión LZMA2 y actualización de versión.

```bash
# 1. Compilar la app
flutter build windows --release

# 2. Compilar el instalador (Inno Setup 6)
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss

# 3. El instalador se genera en dist\Portal_Pilot_WDx64_v0.1.5.exe
```

> Los instaladores publicados se suben como assets a los releases de GitHub con `gh release upload v0.1.5 dist/Portal_Pilot_WDx64_v0.1.5.exe --clobber`.

La última versión publicada: **Portal_Pilot_WDx64_v0.1.5.exe** (~20 MB, Windows 10/11 x64 y Windows ARM con emulación x64).

---

## Licencia

Proyecto privado — **Portal Pilot**. No distribuir sin autorización. Copyright (c) 2026.

---

*Hecho con Flutter · Supabase · Vercel · Groq*
