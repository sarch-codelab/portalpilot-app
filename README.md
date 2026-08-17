<div align="center">

# Portal Pilot

**ERP Financiero y Comercial multi-tenant para Honduras** — App móvil, web y escritorio con facturación electrónica SAR, POS con escáner de códigos de barras, inventario multi-bodega y sincronización offline.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-000000?logo=vercel&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-6B7280)

</div>

---

## Tabla de contenidos

- [Descripción](#descripción)
- [Características](#características)
- [Arquitectura](#arquitectura)
- [Módulos del sistema](#módulos-del-sistema)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Requisitos](#requisitos)
- [Configuración](#configuración)
- [Cómo ejecutar](#cómo-ejecutar)
- [Base de datos](#base-de-datos)
- [API Serverless](#api-serverless)
- [Sincronización offline](#sincronización-offline)
- [Pruebas](#pruebas)
- [Builds y despliegue](#builds-y-despliegue)
- [Licencia](#licencia)

---

## Descripción

**Portal Pilot** es un ERP diseñado para negocios comerciales hondureños (pulperías, abarroterías, distribuidoras, supermercados, cadenas multi-sucursal y modelos de membresía). Funciona **offline-first**: los datos se guardan localmente (SQLite/Drift) y se sincronizan con la nube (Supabase) cuando hay conexión, con cola de sincronización y resolución de conflictos por `(empresa, código)`.

Está construido con un único código Flutter que compila para **Android, iOS, Web y Windows**, respaldado por una API serverless en Vercel y una base de datos PostgreSQL multi-tenant.

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
- Ingreso manual de código como respaldo.

### Inventario
- Productos con imagen, categorías, unidades de medida, **precio compra/venta**, stock mínimo y bodega.
- **Kardex**, múltiples bodegas, lotes y fechas de caducidad, trazabilidad y recepción.
- **Dedupe garantizado por `(empresa_codigo, codigo)`** — en la API, en la BD local y en SharedPreferences.

### Gestión comercial y clientes
- CRM con clientes, ventas, seguimiento; CRM avanzado con leads, campañas y segmentación.
- Compras, proveedores, cotizaciones, órdenes de compra y recepción.
- Canal Tradicional (fiado, cobros, rutas) y Canal Moderno (multi-sucursal, transferencias, consolidado).

### Multi-tenant y multi-área
- **Empresas como tenants** con módulos habilitados por plan.
- Configuración **multi-área**: retail, canal tradicional/moderno, membresías, comercial general.
- Módulos activables por empresa con flags persistentes y restablecimiento por área.

### Otros módulos
- Compras y proveedores, cotizaciones, analytics/BI, RRHH/nómina, seguridad (roles/auditoría), supply chain, y más.

---

## Arquitectura

```
┌───────────────────────────────┐
│        Portal Pilot App       │  Flutter (Android / iOS / Web / Windows)
│  ┌─────────────────────────┐  │
│  │      UI (Módulos)       │  │
│  ├─────────────────────────┤  │
│  │   SyncService (cola)    │  │
│  │  LocalDatabaseService   │  │
│  │     (SQLite / Drift)    │  │
│  └──────────┬──────────────┘  │
└─────────────┼─────────────────┘
              │ HTTPS + JWT
┌─────────────▼─────────────────┐
│  Vercel Serverless API        │  Node.js — despachador único /api/* 
│  login · clientes · facturas  │  productos · ventas · compras · …
│  ┌──────────────────────────┐ │
│  │ Supabase (PostgreSQL)    │ │
│  │ multi-tenant + RLS       │ │
│  └──────────────────────────┘ │
└───────────────────────────────┘
```

**Principios clave:**
- **Offline-first**: la app funciona sin red; los cambios se encolan y sincronizan en segundo plano.
- **Upsert idempotente**: los endpoints usan `(empresa_codigo, codigo)` como clave natural para evitar duplicados.
- **Multi-tenant**: aislamiento por `empresa_codigo` con Row Level Security en Supabase.

---

## Módulos del sistema

| Módulo | Descripción |
|---|---|
| `Inventario` | Productos, kardex, bodegas, stock |
| `POS` | Terminal con escáner, carrito, ventas, historial |
| `Facturacion` | Facturación SAR, detalle, reportes |
| `Comercial` | Compras, proveedores, cotizaciones, OC |
| `ComprasProveedores` | Órdenes de compra, recepción, costeo |
| `Cotizaciones` | Cotizaciones y conversión a ventas |
| `CRM` | Clientes y ventas |
| `CRMAdvanced` | Leads, campañas, segmentación |
| `CanalTradicional` | Fiado, cobros, rutas de reparto |
| `CanalModerno` | Multi-sucursal, transferencias, consolidado |
| `Contabilidad` | Cierres, conciliación, impuestos |
| `FiscalAdvanced` | Retenciones, libros, facturación electrónica |
| `SectorRetail` | Precios por canal, promociones, inventario por tienda |
| `SupplyChain` | Recepción, trazabilidad, multi-bodega |
| `Membresias` | Socios, precios, puntos, renovaciones |
| `RRHH` | Empleados y nómina |
| `MultiEmpresa` | Holding, filiales, consolidado, tipo de cambio |
| `Analytics` | Dashboard gerencial, KPIs, forecasting |
| `Seguridad` | Roles, auditoría, configuración |
| `Settings` | Backups, configuración fiscal, logs |

---

## Estructura del repositorio

```
pp-w/
├── api/
│   └── [...slug].js          # Despachador único de la API serverless
├── lib/
│   ├── main.dart             # Punto de entrada
│   ├── Auth/                 # Login, registro, sesión
│   ├── Home/                 # Home y configuración multi-área
│   ├── Modules/              # Módulos funcionales (ver tabla)
│   ├── Shared/
│   │   ├── database/         # Esquema Drift (app_database.dart + .g.dart)
│   │   ├── services/         # Sync, POS, SAR, local DB, backup, …
│   │   ├── models/           # Modelos de dominio
│   │   ├── widgets/          # Widgets compartidos
│   │   └── theme/            # Tema de la app
│   └── dns_global.dart       # Fallback DNS para redes corporativas
├── supabase/
│   ├── schema.sql            # Esquema multi-tenant
│   ├── migracion_sync.sql    # Migración de sincronización (idempotente)
│   ├── crear_tabla_productos.sql
│   └── migracion_matriculas.sql
├── test/                     # Tests unitarios (flutter test)
├── web/                      # Build web + PWA
├── docs/                     # Documentación (setup, instalación)
├── pubspec.yaml
├── codemagic.yaml            # CI: builds web e iOS
└── vercel.json
```

---

## Requisitos

- **Flutter** 3.24+ (Dart 3.x)
- **Node.js** 18+ (solo para la API)
- Cuenta en **Supabase** (base de datos) y **Vercel** (API)
- Android SDK (para builds Android) o Xcode (para iOS)

---

## Configuración

### 1. Variables de entorno

La app lee la configuración desde `--dart-define` o variables de entorno. Las variables de la API se configuran en el panel de Vercel:

| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave de rol de servicio (solo servidor) |
| `WEB_DOMAIN` | Dominio del portal web |

> ⚠️ `.env*` está en `.gitignore`. No se suben secretos al repositorio. Respaldar `android/app/upload-keystore.jks` (llave de firma Android) en un lugar seguro.

### 2. Base de datos (Supabase)

Ejecutar en el SQL Editor de Supabase, en orden:

1. `supabase/schema.sql` — esquema multi-tenant (empresas, usuarios, módulos).
2. `supabase/migracion_sync.sql` — tablas de sincronización + índices UNIQUE.

Para imágenes de productos, seguir `docs/supabase_storage_setup.md` (bucket público `productos`).

### 3. API (Vercel)

Desplegar la carpeta raíz con `vercel` (el despachador vive en `api/[...slug].js`). Configurar las variables de entorno de la API en el dashboard.

---

## Cómo ejecutar

```bash
# Dependencias
flutter pub get

# Web (hot reload)
flutter run -d chrome

# Android (dispositivo/emulador)
flutter run -d <device-id>

# Windows / iOS / macOS
flutter run -d windows
flutter run -d macos
flutter run -d iphone

# API en local
node api/[...slug].js
```

---

## Base de datos

Esquema **multi-tenant** en PostgreSQL (Supabase):

- **`empresas`** — tenant principal; plan, módulos habilitados, configuración.
- **`usuarios`** — extiende `auth.users`; rol global (`owner`/`admin`/`user`).
- **`empresa_modulos` / `usuario_modulos`** — módulos por empresa y por usuario.
- **Tablas de negocio** (`productos`, `facturas`, `clientes`, `ventas`, `transacciones`, `matriculas`, `notas`, …) con columna de tenant `empresa_codigo`.

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
| `/api/matriculas` · `/api/matriculas/stats` · `/api/notas` | — | Educación |
| `/api/ai/groq` | — | Asistente IA |

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
# Android release
flutter build apk --release

# Web
flutter build web --release

# iOS (con firma)
flutter build ipa --release
```

CI con **Codemagic** (`codemagic.yaml`): workflows para web e iOS (IPA ad-hoc con `com.sarchcodelab.portalpilot`). La API se despliega a Vercel.

---

## Licencia

Proyecto privado — **Portal Pilot**. No distribuir sin autorización.

---

*Hecho con Flutter · Supabase · Vercel*
