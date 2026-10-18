# Auditoría de conexión APP (Flutter) ↔ servidor — Portal Pilot

**Task:** task-4 · **Autor:** app-flutter (equipo de verificación) · **Fecha:** 2026-10-07
**Alcance:** auditoría de SOLO LECTURA sobre `PP APP/` (192 archivos `.dart`) contra `PP Web/backend/`.
**Backend usado para las pruebas en vivo:** local `http://localhost:3000` (`node backend/server.js` desde `PP Web`), con Supabase productivo como DB.
**Producción:** `https://portal-pilot.vercel.app` responde `GET /api/health` → `{"status":"ok"}` (verificado con `node fetch`).

> Regla seguida: todo veredicto está respaldado por una salida real de comando o por `archivo:línea`.
> Lo que no se pudo probar se declara explícitamente como **NO VERIFICADO**.

---

## 0. Resumen ejecutivo

| Área | Veredicto |
|---|---|
| Login app → backend | ✅ Funciona. `POST /api/login` responde 200 para pulpería y club; `modulos_app` y `read_only`/`trial_expired` viajan dentro de `user`, que es donde el código de la app los lee. |
| `modulos_app` ⊆ catálogo de la app | ⚠️ Parcial. Pulpería y club: 100 % de los IDs son válidos. **Trial (starter): el backend devuelve `reportes` y `soporte`, que NO existen en `Modulo.modulosDisponibles` y la app descarta en silencio.** |
| Endpoints app → backend | ⚠️ 5 endpoints que la app llama **no existen** (404) y 3 llamadas usan el **paramétrico equivocado** (query en vez de path) → 404 siempre. |
| Trial / solo lectura | ✅ No hay hueco de seguridad: el backend bloquea escrituras con 403 `TRIAL_EXPIRED` (middleware global). ⚠️ La UI solo guarda 2 de N rutas de escritura; el resto depende del 403 del servidor. |
| Mocks en producción | ✅ No hay mocks de datos de negocio en `lib/` (solo `ReportDataProviderFake` en el archivo de proveedores de reportes, usado por tests). Sí hay **fallbacks hardcodeados** (módulos de ROOT, precios del cotizador) documentados abajo. |
| `flutter test` / `flutter analyze` | ❌ **NO EJECUTABLES en esta sesión**: el sandbox de la sesión no puede escribir en `bin/cache/lockfile` del SDK (fuera del workspace) ni crear procesos con stdio por pipe. Evidencia exacta en §6. **El Lead debe ejecutarlos fuera del sandbox.** |

**Bugs de mayor impacto encontrados (detalle en §7):**

1. `PATCH /api/facturas?id=<id>` — la app anula/actualiza facturas por *query string*, el backend expone `PATCH /api/facturas/:id` → **404 de router** (nunca funciona, ni online ni por la cola offline).
2. `DELETE /api/productos` (sin `:id`) — igual caso → **404 de router**; el borrado de productos desde la app nunca llega al servidor.
3. `GET /api/me` (404) — la app nunca refresca nombre/foto/plan tras reiniciar.
4. `GET /api/tenant/me` (404 vía `/api/tenant/:id`) — `modulos_avanzados_service` no puede leer plan/módulos.
5. `GET /api/configuracion-fiscal` (404) — la configuración fiscal solo vive en el dispositivo; nunca se lee de Supabase.
6. `POST /api/storage` (404) — subida/borrado de imágenes de perfil y productos falla siempre (el backend sí tiene `/api/upload` y `/api/upload-image`).
7. `GET /api/audit` (404) — la pantalla "Logs del sistema" nunca muestra logs remotos (el endpoint real es `/api/auditoria/tenant`).
8. Plan `starter` (trial) recibe `features` de la DB **sin** `cotizaciones`, `retail_pasillos` ni `gestion_membresias` → el trial se anuncia con "toda la plataforma abierta" pero la API responde 403 en `/api/cotizaciones`, `/api/pasillos`, `/api/mesas` y `/api/socios-accesos/actuales`.
9. `GET /api/promociones/activas` → **500** `column promociones.estado does not exist` (no lo llama la app; hallazgo colateral).

---

## 1. Metodología y comandos

```powershell
# 1) salud de los backends
node -e "fetch('http://localhost:3000/api/health').then(r=>r.text()).then(console.log)"
node -e "fetch('https://portal-pilot.vercel.app/api/health').then(r=>r.json()).then(j=>console.log('PROD:',JSON.stringify(j)))"

# 2) SDK Flutter
Get-Command flutter            # -> C:\Users\Sami\Documents\dart\flutter\bin\flutter.bat
Get-Command dart               # -> C:\Users\Sami\Documents\dart\flutter\bin\dart.bat

# 3) mapeo de endpoints app -> backend (herramientas grep/glob del arnés sobre lib/ y backend/)
#    y contraste contra las rutas reales de server.js (247 `app.<verbo>('/api/...')` + router admin + módulos avanzados)

# 4) pruebas en vivo (scripts temporales en %TEMP%, NO dentro del proyecto)
node "C:\Users\Sami\AppData\Local\Temp\pp_app_audit_login.cjs"      # registro+login pulperia/club + sonda de 44 endpoints
node "C:\Users\Sami\AppData\Local\Temp\pp_app_audit_starter.cjs"    # registro starter + simulacro de ModuleManager/Home
node "C:\Users\Sami\AppData\Local\Temp\pp_app_audit_features.cjs"   # features DB vs constantes locales
node "C:\Users\Sami\AppData\Local\Temp\pp_app_audit_starter_api.cjs"# gates de API del plan starter
node "C:\Users\Sami\AppData\Local\Temp\pp_app_audit_mismatch.cjs"   # mismatches query-vs-path y endpoints ausentes
```

Los scripts de evidencia quedaron en `%TEMP%` (fuera del repo) para no ensuciar el workspace. Se pueden volver a ejecutar con el backend local arriba.

### Scripts temporales que creé (para reproducir)

`%TEMP%\pp_app_audit_login.cjs`, `%TEMP%\pp_app_audit_starter.cjs`, `%TEMP%\pp_app_audit_features.cjs`, `%TEMP%\pp_app_audit_starter_api.cjs`, `%TEMP%\pp_app_audit_mismatch.cjs`.

### Datos de prueba creados en Supabase productivo (para que el Lead los limpie)

| Código de empresa | Email | Plan |
|---|---|---|
| `PP-AUD-PUL-VFPT` | `aud.pulperia.vfpt@pp.test` | pulperia |
| `PP-AUD-CLUB-VFPT` | `aud.club.vfpt@pp.test` | club |
| `PP-AUD-STA-WOJZ` | `aud.starter.wojz@pp.test` | starter |

Contraseña de los tres: `PruebaPortal2026!`. No tienen datos operativos (solo el login creó eventos de auditoría).

---

## 2. Matriz endpoint-por-endpoint app → backend

**Leyenda:** `OK` = existe y responde; `403*` = existe y el gate de plan responde 403 (correcto, la ruta existe); `404-R` = 404 a nivel de router (la ruta no existe); `404-H` = 404 del handler (la ruta sí existe pero el recurso no); `MISMATCH` = la app usa otra forma (query vs path) → 404-R.

### 2.1 Autenticación

| App (archivo:línea) | Método y ruta | Backend | Veredicto |
|---|---|---|---|
| `db_service.dart:394` | `POST /api/login` | `server.js:2844` | **OK** (200 en vivo, 3 planes) |
| `db_service.dart:471` | `POST /api/login/2fa` | `server.js:3005` | OK (ruta existe) |
| `db_service.dart:444` | `POST /api/login/2fa/setup` | `server.js:3084` | OK (ruta existe) |
| `db_service.dart:459` | `POST /api/login/2fa/setup-confirm` | `server.js:3101` | OK (ruta existe) |
| `auth_controller.dart:130` | `GET /api/me` | — | **404-R — NO EXISTE** |

### 2.2 Sincronización y escritura (db_service.dart → cola SyncService)

| App | Método y ruta | Backend | Veredicto |
|---|---|---|---|
| `db_service.dart:164` | `POST /api/facturas` | `server.js:8519` | OK |
| `db_service.dart:176` | `PATCH /api/facturas?id=` | `server.js:8603` espera `:id` | **MISMATCH → 404-R** |
| `db_service.dart:204` | `PATCH /api/facturas?correlativo=` | ídem | **MISMATCH → 404-R** |
| `db_service.dart:223` | `POST /api/transacciones` | `server.js:10797` | OK |
| `db_service.dart:237` | `POST /api/clientes` | `server.js:8666` | OK |
| `db_service.dart:248` | `POST /api/productos` | `server.js:7888` | OK |
| `db_service.dart:262` | `DELETE /api/productos` (sin `:id`) | `server.js:8042` espera `:id` | **MISMATCH → 404-R** |
| `db_service.dart:281` | `POST /api/proveedores` | `server.js:7454` | OK |
| `db_service.dart:292` | `POST /api/cotizaciones` | `server.js:10838` | OK |
| `db_service.dart:303` | `POST /api/ordenes-compra` | `server.js:10897` | OK |
| `db_service.dart:314` | `POST /api/compras` | `server.js:7674` | OK |
| `db_service.dart:327` | `POST /api/pos/ventas` | `server.js:8108` | OK |
| `db_service.dart:345` | `POST /api/sync` | `server.js:11201` | OK |
| `db_service.dart:372` | `POST /api/notas` | `server.js:10939` | OK |

### 2.3 Catálogos / configuración / utilidades

| App | Ruta | Backend | Veredicto |
|---|---|---|---|
| `catalogos_service.dart:47,67` | `GET /api/categorias` | `server.js:11860` (registro en bucle) | **OK** (en vivo: `{"catalogo":[]}`) |
| `catalogos_service.dart:47,69` | `GET /api/marcas` | `server.js:11860` (bucle) | **OK** (`{"catalogo":[]}`) |
| `catalogos_service.dart:47,73` | `GET /api/pasillos` | `server.js:11929` | OK (403 en pulpería, 200 en starter) |
| `fiscal_compliance.dart:53` | `GET /api/configuracion-fiscal` | — | **404-R — NO EXISTE** |
| `app_update_service.dart:48` | `GET /api/app-version` | `server.js:2118` | **OK** (200, `versionCode 15`) |
| `system_logs.dart:67` | `GET /api/audit` | — | **404-R — NO EXISTE** (real: `/api/auditoria/tenant` `server.js:10512`) |
| `image_service.dart:74,102` | `POST /api/storage` | — | **404-R — NO EXISTE** (real: `/api/upload-image` `server.js:1882`, `/api/upload` `server.js:5176`) |
| `api_service.dart` (genérico) | base `https://portal-pilot.vercel.app` (`api_service.dart:10`, override `--dart-define=API_ROOT`) | producción OK | OK |
| `db_service.dart:8-11` | base `https://portal-pilot.vercel.app` | producción OK | OK |
| `ai_service.dart:12` | base IA `https://portal-pilot.vercel.app` | producción OK | OK |

### 2.4 Módulos avanzados (router montado en la raíz, `server.js:1779-1801`)

Todos verificados en el router `modulosAvanzadosEndpoints.js` (12 rutas genéricas por `cfg.ruta` + handlers dedicados) y varios probados en vivo:

| App (`modulos_avanzados_service.dart`) | Ruta | Backend | Veredicto |
|---|---|---|---|
| :104,:109,:115,:121,:127 | `/api/contabilidad/cuentas`, `/plan-cuentas/sembrar` | `modulosAvanzadosEndpoints.js:253,286` | **OK** (en vivo 200) |
| :135,:144,:152,:158 | `/api/contabilidad/estado-resultados`, `/asientos` | `:312,407` | OK |
| :165,:172,:179 | `/api/contabilidad/cierres` | `:441` | OK |
| :190,:198,:207 | `/api/contabilidad/conciliaciones` | `:472` | OK |
| :216,:223 | `/api/contabilidad/config-impuestos` | `:509,519` | OK |
| :235,:240,:246,:252 | `/api/rrhh/empleados` | `:543` | **OK** (200 en starter, 403 en pulpería) |
| :259,:269,:277,:284 | `/api/rrhh/nomina*`, `/api/rrhh/recibo/:id` | `:597,689,711,730` | OK |
| :297,:307,:313,:319,:325 | `/api/fiscal/retenciones*` | `:753,805` | **OK** |
| :332,:340,:348,:357 | `/api/fiscal/libros`, `/documentos-sar` | `:832,877` | OK |
| :370,:377,:383,:389,:395 | `/api/crm-avanzado/leads`, `/pipeline` | `:918,954` | **OK** |
| :402–:451 | `/api/crm-avanzado/campanas`, `/segmentos`, `/calcular` | `:982,1014,1043` | OK |
| :457–:474 | `/api/crm-avanzado/fidelizacion` | `:1082` | OK |
| :484–:501 | `/api/multi-empresa/filiales` | `:1251` | **OK** |
| :508,:516,:524 | `/api/multi-empresa/tipos-cambio` | `:1301` | OK |
| :531,:540 | `/api/multi-empresa/consolidado[/calcular]` | `:1331,1425` | OK |
| `:551` | `GET /api/tenant/me` | `/api/tenant/:id` `server.js:3790` | **404-H — el literal `/api/tenant/me` no existe** |

### 2.5 Módulos operativos (llamadas directas desde pantallas)

| App | Ruta | Backend | Veredicto |
|---|---|---|---|
| `dashboard_gerencial.dart:56`, `forecasting_dashboard.dart:30`, `kpis_dashboard.dart:30`, `cierres_mensuales.dart:48` | `GET /api/dashboard/summary` | `server.js:6579` | **OK** (200) |
| `producto_list.dart:114`, `inventario_home.dart:172`, `kardex.dart:50`, `pos_home.dart:298`, `pos_terminal_v2.dart:245`, `operaciones_service.dart:156` | `GET /api/productos` | `server.js:7840` | **OK** (200) |
| `clientes/cliente_list.dart:27,70`, `crm_home.dart:57`, `credito_avanzado.dart:26` | `GET/DELETE /api/clientes[/:id]` | `server.js:8632,8736` | OK |
| `facturacion_home.dart:84`, `factura_list.dart:54` | `GET /api/facturas` | `server.js:8464` | **OK** (200) |
| `facturacion_home.dart:111` | `GET /api/facturas/resumen` | `server.js:8465` | OK |
| `bodegas.dart:46`, `producto_form.dart:246` | `GET /api/bodegas` | `server.js:7362` | OK (403 si el plan no tiene `sucursales`) |
| `inventario_tienda.dart:29` | `GET /api/sucursales` | `server.js:7267` | OK |
| `kardex.dart:49` | `GET /api/kardex` | `server.js:8754` | **OK** (200) |
| `pos_reportes.dart:30`, `pos_home.dart:286` | `GET /api/pos/ventas`, `/resumen` | `server.js:8064,8082` | OK |
| `promociones.dart:27` | `GET /api/promociones` | `server.js:8905` | OK |
| `cobros_efectivo.dart:26` | `GET /api/ventas-fiadas` | `server.js:9006` | **OK** |
| `ventas_home.dart:38,56,62` | `GET/POST/PATCH/DELETE /api/ventas-crm` | `server.js:9219,9259,9286,9309` | OK |
| `conciliacion_bancaria.dart:35` | `GET /api/transacciones` | `server.js:10779` | **OK** |
| `niveles_membresia.dart:29`, `operaciones_service.dart:363` | `GET /api/membresias/planes` | `server.js:9753` | OK |
| `puntos_recompensas.dart:28`, `renovaciones_automaticas.dart:30` | `GET /api/membresias/socios` | `server.js:9818` | **OK** |
| `operaciones_service.dart:373` | `GET /api/membresias/socios/:id/qr` | `server.js:12910` | OK |
| `operaciones_service.dart:383,397,415,426` | `/api/socios-accesos[/actuales|/validar-qr]` | `server.js:12747,12765,12894,12936` | OK |
| `operaciones_service.dart:107,:124,:141` | `/api/mermas`, `/mermas/resumen` | `server.js:12026,12046,12094` | **OK** (200) |
| `operaciones_service.dart:169–:198` | `/api/pasillos` (GET/POST/PUT/DELETE `/:id`) | `server.js:11929,11969,11984,12000` | OK |
| `operaciones_service.dart:203–:246` | `/api/mesas` | `server.js:12187,12219,12250,12293` | OK |
| `operaciones_service.dart:251–:308` | `/api/cuentas-abiertas` (+ `/consumos`, `/cerrar`) | `server.js:12334–12696` | OK |
| `comercial_service.dart:281,318,360,403` | `/api/proveedores`, `/cotizaciones`, `/ordenes-compra`, `/compras` | `server.js:7438,10823,10880,7658` | OK |
| `margenes_analisis.dart:31,32`, `devoluciones_proveedor.dart:28` | `/api/productos`, `/api/compras` | ver arriba | OK |
| `ai_service.dart` (chat/vision/barcode/dashboard/pos/crm/support) | `/api/ai/*` | `server.js:6032–6530` | OK (ruta; gate `requirePlanFeature('ia')`) |

**No se encontró ningún endpoint que la app llame con otro MÉTODO sobre la misma ruta** salvo los 3 mismatches query-vs-path de §2.2.

---

## 3. Flujo de login y módulos (evidencia real)

### 3.1 Comando y salida (extracto literal)

```
--- registro pulperia -> 201 {"message":"Tenant creado con éxito","empresaCodigo":"PP-AUD-PUL-VFPT","plan":"pulperia"}
--- login pulperia -> 200
plan=pulperia trial_expired=false read_only=false features=15
  modulos_activos=["pos","canal_tradicional","inventario","facturacion","contabilidad"]
  modulos_app=["settings","pos","canal_tradicional","inventario","facturacion","fiscal_advanced","contabilidad"]
OK  [pulperia] modulos_app es subconjunto de Modulo.modulosDisponibles :: 7 ids válidos

--- registro club -> 201 {"message":"Tenant creado con éxito","empresaCodigo":"PP-AUD-CLUB-VFPT","plan":"club"}
--- login club -> 200
plan=club trial_expired=false read_only=false features=39
  modulos_activos=["pos","membresias","inventario","facturacion","crm","seguridad","chat_ia"]
  modulos_app=["settings","pos","membresias","inventario","facturacion","fiscal_advanced","crm","seguridad","chat_ia"]
OK  [club] modulos_app es subconjunto de Modulo.modulosDisponibles :: 9 ids válidos
```

El catálogo con el que se validó se extrajo por regex del propio `modulo.dart`:

```
Modulo.modulosDisponibles ids (21): analytics, canal_moderno, canal_tradicional, chat_ia, comercial,
compras_proveedores, contabilidad, cotizaciones, crm, crm_advanced, facturacion, fiscal_advanced,
inventario, membresias, multi_empresa, pos, rrhh, sector_retail, seguridad, settings, supply_chain
```

**Conclusión:** para pulpería y club, `modulos_app` ⊂ catálogo de la app (✅). Obsérvese que el backend añade `settings` (`MODULOS_APP_BASE`, `server.js:790`) y `fiscal_advanced` (efecto colateral de `MODULO_APP_MAP.facturacion = ['facturacion','fiscal_advanced']`, `server.js:742`) incluso en Pulpería; la app lo oculta por el gate de features (`home_screen.dart:281-284`) y la API también lo rechaza (403 `fiscal_avanzado`), así que **no es un hueco de seguridad**, pero sí un módulo "activo" que nunca se ve.

### 3.2 El caso que falla: trial (`starter`)

```
registro starter -> 201 {"empresaCodigo":"PP-AUD-STA-WOJZ","plan":"starter"}
login starter -> 200
plan=starter trial_expired=false read_only=false trial_ends_at=2026-10-22T15:11:31.621Z
modulos_activos (23): ["pos",...,"reportes",...,"soporte"]
modulos_app (23): ["settings","pos","facturacion","fiscal_advanced","inventario","contabilidad","rrhh",
  "crm","comercial","compras_proveedores","cotizaciones","membresias","canal_tradicional","canal_moderno",
  "analytics","reportes","supply_chain","multi_empresa","chat_ia","seguridad","crm_advanced",
  "sector_retail","soporte"]

>>> modulos_app SIN entrada en Modulo.modulosDisponibles: ["reportes","soporte"]
>>> activeAppModuleIds (ModuleManager) (21): [...sin reportes ni soporte...]
>>> módulos que ModuleManager DESCARTA: ["reportes","soporte"]
>>> módulos visibles en Home tras el gate de features (20): [...]
>>> módulos activos pero OCULTOS por el gate de features: ["cotizaciones"]
```

- **Hueco 1 — IDs sin `Modulo`:** `reportes` y `soporte` existen en `MODULOS_COTIZADOR` (`server.js:689-691`) y en `MODULO_APP_MAP` (`server.js:754,763`), pero **no** en `Modulo.modulosDisponibles` (`modulo.dart:203-372`). `module_manager.dart:159-161` solo conserva IDs que estén en `Modulo.modulosDisponibles`, así que **se descartan en silencio**: el backend los cuenta como "módulos activos del plan" y la app nunca los muestra. No rompe la UI, pero la promesa del trial ("23 módulos") es falsa en la app (se ven 20-21).
- **Hueco 2 — `cotizaciones` oculto en el trial:** `u.features` para `starter` viene de `plan_features` en Supabase (39 features, idénticas a *club*) y **le faltan** `cotizaciones`, `retail_pasillos` y `gestion_membresias` respecto de `ALL_PLAN_FEATURES` (`server.js:653-677`). Consecuencias (probadas en vivo con el token del propio trial):

```
403  GET /api/cotizaciones             {"code":"PLAN_LIMIT"}    <- el catálogo dice que el trial la incluye
403  GET /api/pasillos                 {"code":"PLAN_LIMIT"}
403  GET /api/mesas                    {"code":"PLAN_LIMIT"}
403  GET /api/socios-accesos/actuales  {"code":"PLAN_LIMIT"}
200  GET /api/rrhh/empleados, /api/fiscal/retenciones, /api/crm-avanzado/leads, /api/multi-empresa/filiales
```

  Es decir: en el trial, la API y la app **coinciden** en ocultar/bloquear esos 3 módulos, pero contradicen `PLAN_CATALOGO_MODULOS.starter = [...MODULOS_COTIZADOR]` (`server.js:851`) y el comentario "trial de 15 días con TODA la plataforma abierta" (`server.js:695`). Es un problema de datos (`plan_features`), no de código de la app → lo reporto a quien posea task-3/task-1.

### 3.3 Simulación exacta de la cadena de filtrado de la app

Réplica en Node de `module_manager.dart:126-167` + `home_screen.dart:281-284` sobre el `modulos_app` real de starter:

| Etapa | Resultado |
|---|---|
| `modulos_app` del backend (23) | incluye `reportes`, `soporte` |
| `ModuleManager._applyCurrentSubscription` | descarta `reportes`, `soporte` → 21 |
| `home_screen._applySession` gate por `moduloFeatureRequerida` | quita `cotizaciones` → 20 visibles |
| `MultiAreaConfig` (subset de `AreasNegocio.todosModulos`) | no quita nada más |
| Fallback final | no se activa (lista no vacía) |

Módulos visibles en Home para un trial: `analytics, canal_moderno, canal_tradicional, chat_ia, comercial, compras_proveedores, contabilidad, crm, crm_advanced, facturacion, fiscal_advanced, inventario, membresias, multi_empresa, pos, rrhh, sector_retail, seguridad, settings, supply_chain` (20).

---

## 4. Trial / solo lectura en la app

### 4.1 Cómo llega y cómo se lee ✅

- El backend pone `trial_expired` y `read_only` **dentro de `user`** (`server.js:2990-2991` login normal; `server.js:3074` tras 2FA).
- La app los lee exactamente de ahí: `login.dart:342-343`
  ```dart
  final bool trialVencido = userJson['trial_expired'] == true || userJson['read_only'] == true;
  ```
  y lo persiste como `soloLectura` (`login.dart:391` → `AuthController.setSession`, `auth_controller.dart:187,205`).
- `session_guard.dart:31-34` excluye explícitamente `TRIAL_EXPIRED`, `PLAN_LIMIT`, `AI_TOKEN_LIMIT_REACHED` para que un 403 de plan **no** provoque logout. Correcto.
- `api_service.dart:166-179`: cualquier respuesta con `code == 'TRIAL_EXPIRED'` llama a `AuthController.instance.marcarSoloLectura(activo: true)` y devuelve `readOnly: true`. Es el único mecanismo que **aprende** que el trial venció con la app abierta.

### 4.2 ¿Bloquea escrituras o solo oculta UI?

**Solo parcialmente en la UI; el bloqueo real es el 403 del servidor.**

- El servidor SÍ bloquea: middleware global (`server.js:428-449`) → toda petición no-GET que no esté en la whitelist (`server.js:380-403`) responde `403 {code:'TRIAL_EXPIRED', readOnly:true}`. **No hay hueco de seguridad por este lado.**
- Guard de UI: `ReadOnlyGuard.bloqueado(context)` (`read_only_guard.dart:16-25`) se usa en **2 sitios**:
  - `pp_module_scaffold.dart:121-126` (solo el botón "+" de nuevo registro del scaffold)
  - `ventas_home.dart:83`
- Banner: `home_screen.dart:680-683`.
- **No** hay guard en las rutas de escritura más usadas: `factura_form.dart:613` (`insertFacturaLocal`), `pos_terminal_v2.dart` (venta POS), `producto_form.dart:1231`, `cliente_form.dart:114`, `comercial_service`, `canal_tradicional_service`, `sar_service`, `operaciones_service`, etc.
- **Riesgo real (UX, no seguridad):** con el trial vencido, esas pantallas guardan **local** y encolan el envío; el backend devuelve 403 `TRIAL_EXPIRED`, la cola reintenta 5 veces (`sync_service.dart:102,512`) y el registro queda atascado sin un aviso claro. `db_service.dart:144-147` solo hace `debugPrint` del 403 (no marca solo-lectura ni notifica al usuario).
- **No hay verificación periódica:** la app no consulta `/api/tenant/subscription` ni `/api/empresa/entitlements`; si el trial vence con la app abierta, `soloLectura` solo cambia al primer fallo de escritura o al reiniciar sesión.

### 4.3 Líneas exactas

| Qué | Archivo:línea |
|---|---|
| Lee `trial_expired`/`read_only` del login | `PP APP/lib/Auth/login.dart:342-343` |
| Persiste solo-lectura | `PP APP/lib/Auth/login.dart:391`, `PP APP/lib/Shared/services/auth_controller.dart:187,205,270-276` |
| No hace logout con TRIAL_EXPIRED | `PP APP/lib/Shared/services/session_guard.dart:31-36` |
| 403 → activa solo-lectura | `PP APP/lib/Shared/services/api_service.dart:166-179` |
| Guard UI | `PP APP/lib/Shared/widgets/read_only_guard.dart:16-25`; usos en `pp_module_scaffold.dart:121-126` y `ventas_home.dart:83` |
| Banner | `PP APP/lib/Home/home_screen.dart:680-683` |
| Escribe local sin guard | `PP APP/lib/Modules/Facturacion/factura_form.dart:613`, `PP APP/lib/Modules/POS/pos_terminal_v2.dart` (venta), `PP APP/lib/Modules/Inventario/producto_form.dart:1231` |

---

## 5. Datos locales como fuente de verdad y sincronización

**Sí: la app es offline-first con Drift como fuente de verdad de lectura.** `db_service.dart:26-28` lo dice explícitamente ("READ METHODS (offline-first - read from local DB)").

- Lecturas locales: `PortalPilotDB.getFacturas/getClientes/getProductos/getTransacciones` (`db_service.dart:30-120`) leen **solo** de Drift (`local_db_service.dart`). Consumidores: `contabilidad_home.dart:60`, `clientes/cliente_form.dart:45`, `pp_ai_assistant.dart:179,200,234`.
- Muchas pantallas **también** leen del API en paralelo y pintan lo remoto (`producto_list.dart:111-127` guarda el resultado en `SharedPreferences('productos_api_cache')`, **no** en Drift).
- **Único camino servidor → Drift:** `pos_terminal_v2.dart:239-258` (`_cargarProductosFromSupabase` → `upsertProductosLocal(..., enqueueSync:false)`).
- Escritura: las operaciones se guardan en Drift y se encolan en la tabla `syncQueue` (`sync_service.dart:158-190`); el envío ocurre al encolar si hay red, cada 5 min, cada 1 min para reintentos, y al recuperar conectividad (`sync_service.dart:122-156,193-195`). El destino es `/api/sync` (genérico) o endpoints directos por tabla (`sync_service.dart:281-310`).
- **Punto de sincronización exacto:** `main.dart:67-75` inicializa `OfflineSyncService` y `SyncService`; `SyncService.initialize()` (`sync_service.dart:122-142`) purga la tabla `empresas` (códigos de onboarding inválidos), libera locks `procesando=true` y arranca el primer `_processPendingSync()`.
- **Huecos concretos:**
  1. `configuracion_fiscal` se **sube** por `/api/sync` (tabla soportada, `server.js:11008`) pero **no se puede bajar**: `fiscal_compliance.dart:53` llama a un `GET /api/configuracion-fiscal` que no existe (404). La config fiscal compartida entre dispositivos nunca llega a la app.
  2. `anularFacturaLocal` (`local_db_service.dart:236-265`) encola `operacion: update` → `_syncFactura` → `updateFactura` → **404 siempre** (§7). Y `eliminarProductoGlobal` (`local_db_service.dart:584-617`) encola `delete` → `deleteProducto` → **404 siempre**. Ambos quedan como "pendientes con error terminal" tras 5 intentos.
  3. No hay descarga genérica servidor → Drift: un dispositivo nuevo ve vacío el inventario local hasta que abra el POS o el listado que hace fetch del API.

---

## 6. `flutter test` y `flutter analyze` — resultado REAL

### 6.1 ¿Dónde está el SDK?

```powershell
Get-Command flutter  ->  C:\Users\Sami\Documents\dart\flutter\bin\flutter.bat
Get-Command dart     ->  C:\Users\Sami\Documents\dart\flutter\bin\dart.bat
dart --version       ->  Dart SDK version: 3.12.1 (stable) ... on "windows_x64"
```

El SDK **existe y funciona** (el `dart --version` directo responde). No se instaló nada.

### 6.2 Ejecuciones intentadas y error literal

**Intento 1 — `flutter --no-version-check test`** (vía `flutter.bat`, en background, sin `Out-String`): no produjo ninguna salida en >10 min y el proceso `cmd.exe` quedó al ~94-100 % de CPU. Ningún artefacto nuevo en `PP APP/build` (los más recientes eran de un run previo a las 01:51). Se mató el job.

**Intento 2 — snapshot de `flutter_tools` directamente** (evita el wrapper `.bat`):

```powershell
& dart.exe --disable-dart-dev "$FLUTTER_ROOT\bin\cache\flutter_tools.snapshot" test
```
```
Flutter failed to open a file at "C:\Users\Sami\Documents\dart\flutter\bin\cache\lockfile".
The flutter tool cannot access the file or directory.
Please ensure that the SDK and/or project is installed in a location that has read/write permissions for the current user.
EXIT_TEST=1
```

**Intento 3 — mismo comando con `FLUTTER_ALREADY_LOCKED=true`** (saltarse el lock del cache):

```
CreateFile failed 5 (Acceso denegado.)
Flutter failed to run "ver". The flutter tool cannot access the file or directory.
EXIT_TEST=1
```

**Intento 4 — `dart analyze`** (sin flutter_tools):

```
Analyzing PP APP...
ProcessException: Acceso denegado (at ../../runtime/bin/process_win.cc:742)
  Command: C:\...\dart-sdk\bin\dartaotruntime.exe ...\snapshots\analysis_server_aot.dart.snapshot
  --client-id=dart-analyze ...
EXIT_ANALYZE=1
```

### 6.3 Diagnóstico

- El SDK Flutter vive **fuera del workspace** (`C:\Users\Sami\Documents\dart\flutter`) y la sesión corre con política de archivos `workspace-write` con raíz `C:\Users\Sami\Downloads\Portal Pilot`. El tool intenta crear/bloquear `bin/cache/lockfile` y **no tiene permiso de escritura**.
- El análisis/test además necesita lanzar procesos hijos con **stdio por pipe** (`dartaotruntime.exe`/analysis server y `cmd /c ver`): el sandbox deniega la creación del pipe (`CreateFile failed 5`). Esta es la frontera documentada del sandbox de Windows; no se puede rodear desde dentro de la sesión y las aprobaciones están deshabilitadas.
- **Conclusión honesta: no pude obtener conteos de `flutter test` ni de `flutter analyze` en esta sesión.** No es un fallo del proyecto ni del SDK. Se necesitan **una** de estas dos cosas desde fuera:
  ```powershell
  # opción A (recomendada): ejecutar en una terminal normal, sin el sandbox de DSH
  cd "C:\Users\Sami\Downloads\Portal Pilot\PP APP"
  flutter test
  flutter analyze --no-fatal-infos

  # opción B: mover/copiar el SDK dentro del workspace y usar el wrapper
  #   $env:FLUTTER_ROOT="<ruta dentro del workspace>"; ...
  #   (requiere ~3 GB y una copia nueva; no lo hice por la regla de "no instalar")
  ```
- Lo que **sí** puedo aportar como verificación estática provisoria: la suite existente es de 18 archivos (`PP APP/test/**`),entre ellos `module_manager_plan_test.dart`, `multi_area_config_test.dart` y 7 pruebas de `qa_attacks/`. Ninguna cubre los hallazgos de §3.2 (`reportes`/`soporte`) ni los mismatches de §7.

---

## 7. Huecos encontrados (archivo:línea) y acción propuesta

### 7.1 Críticos — llamadas que NUNCA funcionan

| # | Hueco | Evidencia app | Evidencia backend/en vivo | Propuesta (no aplicada: no poseo estos archivos) |
|---|---|---|---|---|
| 1 | `PATCH /api/facturas?id=` (anular factura) | `PP APP/lib/Shared/services/db_service.dart:176` | `PATCH /api/facturas?id=…` → `404 text/html Cannot PATCH /api/facturas`; `PATCH /api/facturas/:id` → `404 {"error":"Factura no encontrada"}` (ruta real `server.js:8603`) | Cambiar a `PATCH /api/facturas/<id>`; o añadir en el backend `app.patch('/api/facturas')` que lea `req.query.id/correlativo`. Afecta a `local_db_service.dart:236-265`. |
| 2 | `PATCH /api/facturas?correlativo=` (update) | `db_service.dart:204` | ídem anterior (404 de router) | ídem |
| 3 | `DELETE /api/productos` sin `:id` | `db_service.dart:262` (llamado desde `local_db_service.dart:584-617`) | `DELETE /api/productos` → `404 Cannot DELETE /api/productos`; `DELETE /api/productos/:id` → `200 {"success":true}` (`server.js:8042`) | Usar `/api/sync` con `operacion:'delete'` (ya está soportado) o `DELETE /api/productos/<id>`. |
| 4 | `GET /api/me` no existe | `PP APP/lib/Shared/services/auth_controller.dart:130` | `404 Cannot GET /api/me` | O crear el endpoint (devolver `user` con `foto_perfil_url`, plan, etc.) o cambiarlo por `/api/auth/status` (`server.js:11306`). Efecto actual: nombre/foto/plan no se refrescan tras reiniciar (falla en silencio, `auth_controller.dart:131`). |
| 5 | `GET /api/configuracion-fiscal` no existe | `PP APP/lib/Shared/utils/fiscal_compliance.dart:53` | `404 Cannot GET /api/configuracion-fiscal` | Exponer `GET /api/configuracion-fiscal` o leer de `/api/sync`-equivalente. Efecto: config fiscal nunca baja de la nube. |
| 6 | `POST /api/storage` no existe | `PP APP/lib/Shared/services/image_service.dart:74,102` | `404 Cannot POST /api/storage` | Apuntar a `/api/upload-image` (`server.js:1882`) — o implementar `/api/storage`. Efecto: fotos de perfil/productos no se suben ni se borran. |
| 7 | `GET /api/audit` no existe | `PP APP/lib/Modules/Settings/system_logs.dart:67` | `404 Cannot GET /api/audit` | Usar `/api/auditoria/tenant` (`server.js:10512`, requiere admin del tenant), y ajustar el parseo (`eventos` en vez de `logs`). Efecto: la pantalla de logs remotos siempre sale vacía. |
| 8 | `GET /api/tenant/me` no existe | `PP APP/lib/Shared/services/modulos_avanzados_service.dart:551` | `404 {"error":"Tenant no encontrado"}` (lo captura `/api/tenant/:id`, `server.js:3790`) | Usar `/api/tenant/subscription` o `/api/tenant/modules` (ambos verificados 200). |

### 7.2 De plan / datos

| # | Hueco | Evidencia | Propuesta |
|---|---|---|---|
| 9 | `modulos_app` devuelve `reportes` y `soporte`, que no existen en `Modulo.modulosDisponibles` | login starter: `modulos_app` 23 IDs, `reportes`/`soporte` sin entrada; `module_manager.dart:159-161` los descarta | O añadir los `Modulo` correspondientes en `modulo.dart`, o excluirlos de `MODULO_APP_MAP` (`server.js:754,763`) para el contrato con la app. Decidir cuál es la fuente de verdad (task-1). |
| 10 | Trial `starter`: `plan_features` en DB sin `cotizaciones`, `retail_pasillos`, `gestion_membresias` | live: `403 PLAN_LIMIT` en `/api/cotizaciones`, `/api/pasillos`, `/api/mesas`, `/api/socios-accesos/actuales` con token del trial; `server.js:653-677,695,851` dicen que el trial trae todo | Alinear `plan_features` de `starter` con `ALL_PLAN_FEATURES` (o cambiar el copy del trial). Zona de task-1/task-3. |
| 11 | Pulpería recibe `fiscal_advanced` "activo" | `modulos_app` de pulpería incluye `fiscal_advanced` por `server.js:742` | Cosmético (app y API lo bloquean), pero ensucia el contrato. |

### 7.3 Colateral (no de la app)

| # | Hueco | Evidencia |
|---|---|---|
| 12 | `GET /api/promociones/activas` → 500 | `{"error":"column promociones.estado does not exist"}` con el token del trial. La app no lo llama; es un bug de esquema (task-2). |

---

## 8. Verificación de "mocks" en la app (objetivo 5 del contexto)

Barrido con grep del arnés sobre `PP APP/lib` con `Fake|mock|Mock|demo|Demo|ejemplo|hardcod|sample|dummy`:

```
PP APP/lib/Shared/reportes/report_data_provider.dart:10,166-167  ReportDataProviderFake (implementación para tests)
PP APP/lib/Modules/SupplyChain/trazabilidad.dart:43             "No se muestran datos de ejemplo en producción"
PP APP/lib/Modules/POS/pos_terminal_v2.dart:1764                instrucción al prompt de IA, no datos
PP APP/lib/Modules/module_manager.dart:146                      comentario sobre el fallback
PP APP/lib/Shared/services/modulos_avanzados_service.dart:7     comentario histórico
```

**Veredicto:** ✅ no hay datos de negocio mock servidos al usuario en `lib/`. `ReportDataProviderFake` (`report_data_provider.dart:166`) es una implementación de test, no se instancia en el árbol de producción.

**Fallbacks hardcodeados que sí existen** (aceptables como respaldo, peligrosos como fuente):

| Ubicación | Qué hardcodea | Riesgo |
|---|---|---|
| `PP APP/lib/Auth/login.dart:370-373` | Si `loggedUser.isRoot` → `modulos = 'facturacion,inventario,contabilidad,rrhh,crm,pos,comercial,membresias'`, **ignorando** `modulos_app` del servidor | Un ROOT solo ve 8 módulos hasta que `home_screen.dart:255-256` vuelve a mostrar todo el catálogo. Inconsistente. |
| `PP APP/lib/Modules/module_manager.dart:137-139` | Si `auth.modulos` está vacío → `['pos_caja','cuentas_por_cobrar','control_caja','facturacion_sar','inventario_basico']` (pack legacy de Pulpería) | Solo se activa con backend antiguo; puede mostrar un plan que el tenant no contrató. |
| `PP APP/lib/Modules/module_manager.dart:305,331-356` | `basePrice = 150` y tabla de precios por módulo (ids WEB) para `getQuotationSummary()` | Duplica (`module_manager.dart` vs `planes.html` vs `server.js`) la fuente de precios. Verificado: hoy **no se usa en ninguna pantalla** (`getQuotationSummary` solo lo consume `exportForWeb()`, sin llamadas en `lib/`). |
| `PP APP/lib/Shared/services/auth_controller.dart:102` (`restore()`) y `PP APP/lib/Auth/login.dart:357-362` | Default de 8 módulos si el servidor no manda `modulos_app` y módulos por área de negocio | Respaldo offline. |

---

## 9. Limitaciones de esta auditoría

1. **`flutter test` / `flutter analyze`: NO ejecutados** (§6.3). Requiere salir del sandbox.
2. No verifiqué la UI de la app en ejecución (no hay build de escritorio disponible dentro del sandbox ni se pidió compilarla): el análisis de módulos/trial es **estático + simulación fiel en Node**, no observación visual.
3. El gate de `read_only` en el backend lo verifiqué por lectura de código (`server.js:428-449`) y por los 403 observados; **no** probé un tenant realmente vencido (eso es el alcance de task-3).
4. Los tenants de prueba `PP-AUD-*` (§1) quedan en Supabase productivo y deben limpiarse.
5. Los 3 primeros veredictos de §2.5 sobre rutas no probadas en vivo son **existe/no existe por lectura de las rutas**, no por respuesta HTTP (marcados como "OK (ruta existe)" sin salida en vivo).
