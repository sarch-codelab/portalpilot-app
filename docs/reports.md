# Sistema universal de reportes — Portal Pilot

## Modelo

- **`lib/Shared/reportes/report_models.dart`** — esquema `ReportData` (espejo del
  contrato que lee `reporte.html`). Bloques opcionales; `noData: true` marca el
  caso "no se encontraron datos". Nunca se inventan registros ni totales.
- **`reporte.html`** — plantilla universal. La app inyecta el JSON como
  `window.PORTAL_PILOT_REPORT` (o `?data=` en URL). Rendering idéntico al PDF.

## Construcción y formato

- **`lib/Shared/reportes/report_builder.dart`** — capa autorizada para convertir
  datos reales a `ReportData`: `money()` (L 25,500.00), `cantidad()`, fechas
  `dd/MM/yyyy`, `periodoLargo()` (es-HN), `assemble()` y `fila()`.

## Acceso a datos

- **`lib/Shared/reportes/report_data_provider.dart`** — interfaz `ReportDataProvider`
  (filtra SIEMPRE por `empresaId`), impl `ReportDataProviderDrift` (drift local)
  y `ReportDataProviderFake` (tests en memoria). Métodos por dominio:
  `facturas`, `transacciones`, `posVentas`, `posVentaItems`, `compras`,
  `compraItems`, `productos`, `clientes`, `empleados`, `nomina`, `fiadoAbonos`,
  `posClienteCredito`, `arqueosCaja`.

## Herramientas controladas

- **`lib/Shared/reportes/report_tools.dart`** — catálogo cerrado `ReportToolType`
  con **11 tools** (gastos, ventas, inventarioMovimientos, stock, compras,
  clientes, facturacion, cuentasPorCobrar, caja, resumenFinanciero, empleados),
  parámetros acotados (`ReportToolParams`), `ReportToolDispatcher` que:
  1. Valida permisos RBAC (`NaviRules.puedeAccederA(rol,'reportes')`).
  2. Toma el tenant de la sesión (AuthController/AIManager), nunca de la IA.
  3. Genera correlativo `REP-000001…` (inyectable en tests).
  4. Devuelve `ReportToolResult` (con `mensaje` y `noData`).

### Herramientas y sus datos (todo filtrado por `empresaId`)

| Tool | Origen | Reglas de agregación |
|---|---|---|
| gastos | `transacciones` | solo tipo gasto (`_esGasto`), rango |
| ventas | `facturas` + `posVentas` | excluye anuladas/canceladas, rango |
| inventarioMovimientos | `posVentaItems` + `compraItems` | rango |
| stock | `productos` | solo activos, detecta bajo mínimo |
| compras | `compras` | excluye `estado` iniciado en "anul"; KPIs: total, ISV (15+18), proveedor principal, documentos |
| clientes | `clientes` + `posClienteCredito` | directorio + saldo de fiado por cliente; solo tenant |
| facturacion | `facturas` | excluye `estado == 'anulada'`; KPIs: total facturado, ISV, condición principal |
| cuentasPorCobrar | `posClienteCredito` + `fiadoAbonos` | solo cuentas con `saldoActual > 0`; abonos del periodo |
| caja | `posArqueoCaja` | solo `fechaCierre != null` en rango; suma efectivo/tarjeta/transferencia/mixto/gastos/diferencia |
| resumenFinanciero | `facturas` + `posVentas` + `transacciones` | ventas facturadas + ventas POS + otros ingresos − gastos; utilidad y margen |
| empleados | `empleados` + `nomina` | activos (`estado == 'activo'`); costo salarial; planilla pagada del mes (`anio`/`mes`/`pagado`) |

## Interprete de intents

- **`lib/Shared/reportes/report_tool_parser.dart`** — `ReportToolParser.interpretar(reply,
  {mensajeUsuario})`: bloque JSON `{"tool":...,"periodo":...,...}` (vía preferida)
  con fallback conservador por palabras (requiere verbo de reporte + categoría).

## Visor, PDF, guardado, historial

- **`lib/Modules/Reportes/report_viewer.dart`** — `ReportViewer` (preview nativo,
  Guardar/Abrir/Compartir/Imprimir).
- **`lib/Modules/Reportes/historial_reportes_screen.dart`** — historial local
  (solo meta-datos, máx 50).
- **`lib/Shared/services/report_service.dart`** — `generarPdf` (A4 replicando la
  plantilla), `reporteHtmlDesdeTemplate` (pura), `guardarLocal` (PDF+HTML en
  `Documentos\PortalPilot\Reportes`, con sufijos `_01`, `_02` en conflictos),
  `abrir`, `compartir`, `imprimir`, `obtenerHistorial`, `guardarHistorial`.

## Integración con el Chat IA

- **`lib/Modules/ChatIA/chat_ia_home.dart`** — tras una respuesta de la IA se
  ejecuta `ReportToolParser.interpretar`; si hay intent y permisos, se despacha
  la herramienta y se adjunta `ReportData` al mensaje para el botón **"Ver reporte"**
  (abre `ReportViewer`). Errores de permisos/herramienta se muestran como
  mensajes amigables (nunca "Exception"). El AppBar incluye un atajo a
  **`HistorialReportesScreen`** (reportes guardados).
- **`lib/Shared/services/navi_rules.dart`** — el prompt maestro documenta las
  11 herramientas de reporte y el formato JSON esperado.

## Seguridad

- La IA no genera SQL, HTML ni elige el tenant.
- RBAC en el despachador; aislamiento por tenant verificado por tests.
- UX obligatoria: "Generando reporte...", "Preparando PDF...", "Guardando
  archivo...", "Reporte guardado correctamente."

## Tests

- `test/reportes/` — builder (format/assemble), parser (JSON + fallback),
  dispatcher (tenant, rango, noData, permisos, correlativo) cubriendo las 11
  tools y service (template puro, `guardarLocal` con `outputDirectory`, historial).
- Suite completa (`flutter test`, incl. `test/qa_attacks/`) debe pasar sin
  regresiones.

## Archivos creados/modificados en esta iteración

- Creados: `report_models.dart`, `report_builder.dart`, `report_data_provider.dart`,
  `report_tools.dart`, `report_tool_parser.dart`, `report_viewer.dart`,
  `historial_reportes_screen.dart`, `test/reportes/*`.
- Modificados: `report_service.dart`, `chat_ia_home.dart`, `navi_rules.dart`
  (schema de tools), `pubspec.yaml` (assets), `reporte.html` (comentario de
  contrato).