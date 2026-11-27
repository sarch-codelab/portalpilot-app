#!/usr/bin/env python3
"""Parsea la salida de `flutter analyze` y la convierte en anotaciones de GitHub.

Soporta dos formatos (según versión de Flutter):
  1. Machine (JSON por línea, flag --machine en versiones que lo emiten)
  2. Humano:  "  error • mensaje • lib/x.dart:10:5 • codigo_analizador"

Además publica un resumen agrupado por código (anotaciones ::notice) para
cubrir los casos donde el límite de anotaciones por paso recorta la lista.

Uso en CI:
    flutter analyze --no-pub --no-fatal-infos --machine > analyze_report.txt 2>&1
    python3 tool/ci/analyze_annotations.py analyze_report.txt

Las anotaciones quedan visibles en la UI de GitHub Actions y consultables
por API (check-runs/annotations), aunque el log del job no se pueda descargar.
"""
import json
import re
import sys

MAX_ANNOTATIONS = 40          # por-diagnóstico (errores primero)
MAX_DIGEST_CHARS = 1400       # por chunk del resumen
MAX_RAW_LINES = 40
MAX_RAW_CHARS = 1500

# "  error • mensaje • lib/x.dart:10:5 • codigo"
HUMAN_RE = re.compile(
    r"^\s*(info|warning|error)\s*•\s*(.*?)\s*•\s*(.+?):(\d+):(\d+)\s*•\s*([A-Za-z0-9_]+)\s*$"
)

_PREFIXES = ("/lib/", "/test/", "/tool/", "/bin/", "/web/", "/integration_test/")


def _shorten(path: str) -> str:
    p = (path or "").replace("\\", "/")
    for prefix in _PREFIXES:
        idx = p.find(prefix)
        if idx != -1:
            return p[idx + 1:]
    return p


def _flatten(text: str) -> str:
    return " ".join(str(text or "").split())


def _emit(level: str, title: str, message: str, file_path=None, line=None, col=None):
    props = ""
    if file_path:
        props = f"file={file_path},line={line or 1}"
        if col:
            props += f",col={col}"
        props += ","
    print(f"::{level} {props}title={title}::{message}", flush=True)


def _dump_raw(level: str, title: str, text: str):
    lines = [l for l in (text or "").splitlines() if l.strip()]
    if not lines:
        return
    out = []
    size = 0
    for line in lines[:MAX_RAW_LINES]:
        s = _flatten(line)
        out.append(s)
        size += len(s) + 3
        if size >= MAX_RAW_CHARS:
            break
    _emit(level, title, "%0A".join(out))


def _parse(fh):
    """Devuelve [(severidad, código, mensaje, archivo, línea, col)]."""
    diags = []
    for raw in fh:
        s = raw.strip()
        if s.startswith("{"):
            try:
                d = json.loads(s)
            except ValueError:
                continue
            if d.get("type") != "Diagnostic":
                continue
            loc = d.get("location") or {}
            diags.append((
                d.get("severity") or "info",
                d.get("code") or "analyzer",
                d.get("message") or "",
                loc.get("file") or "",
                loc.get("startLine") or 1,
                loc.get("startColumn") or 0,
            ))
        else:
            m = HUMAN_RE.match(raw)
            if m:
                sev, msg, f, ln, col, code = m.groups()
                diags.append((sev, code, msg, f, int(ln), int(col)))
    return diags


def _digest(diags):
    """Agrupa por código: 'codigo (n): archivo:lin, archivo:lin, ...'."""
    by_code = {}
    for sev, code, _msg, f, ln, _col in diags:
        by_code.setdefault(code, []).append(f"{_shorten(f)}:{ln}")
    lines = []
    for code in sorted(by_code, key=lambda c: -len(by_code[c])):
        locs = by_code[code]
        lines.append(f"{code} ({len(locs)}): " + ", ".join(locs))
    return lines


def _emit_digest(digest_lines):
    chunk, size = [], 0
    part = 0
    total = 0
    for line in digest_lines:
        if size + len(line) + 3 > MAX_DIGEST_CHARS and chunk:
            part += 1
            _emit("notice", f"resumen-de-issues ({part})", "%0A".join(chunk))
            total += len(chunk)
            chunk, size = [], 0
        chunk.append(line)
        size += len(line) + 3
    if chunk:
        part += 1
        _emit("notice", f"resumen-de-issues ({part})", "%0A".join(chunk))
        total += len(chunk)
    return total


def main(argv):
    if len(argv) < 2:
        print("uso: analyze_annotations.py <analyze_report.txt>", file=sys.stderr)
        return 2

    try:
        report = open(argv[1], encoding="utf-8", errors="replace")
    except OSError:
        _emit("error", "ci-analyze",
              "analyze_report.txt no existe: flutter analyze no llegó a ejecutarse")
        return 0

    with report:
        diags = _parse(report)

    if not diags:
        # Falló antes de analizar (pub, SDK, etc.): volcar la salida cruda.
        try:
            with open(argv[1], encoding="utf-8", errors="replace") as fh:
                _dump_raw("error", "flutter-analyze-salida-cruda", fh.read())
        except OSError:
            pass
        print("analyze_annotations: 0 diagnósticos", flush=True)
        return 0

    severidades = {}
    for sev, *_ in diags:
        severidades[sev] = severidades.get(sev, 0) + 1

    # Errores primero, luego warnings (son los que bloquean el paso).
    orden = {"error": 0, "warning": 1, "info": 2}
    diags_ordenados = sorted(diags, key=lambda d: orden.get(d[0], 3))

    emitidos = 0
    for sev, code, msg, f, ln, col in diags_ordenados:
        if sev not in ("error", "warning"):
            continue
        if emitidos >= MAX_ANNOTATIONS:
            break
        _emit("error" if sev == "error" else "warning", code, _flatten(msg),
              _shorten(f), ln, col)
        emitidos += 1

    if emitidos >= MAX_ANNOTATIONS:
        _emit("error", "ci-analyze",
              f"Se truncaron los diagnósticos por anotación (límite {MAX_ANNOTATIONS})"
              " — el detalle completo está en las anotaciones 'resumen-de-issues'.")

    digest_total = _emit_digest(_digest(diags))
    print(
        f"analyze_annotations: {len(diags)} diagnósticos "
        f"(por severidad: {severidades}); {emitidos} anotaciones de error/warning, "
        f"{digest_total} líneas de resumen",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
