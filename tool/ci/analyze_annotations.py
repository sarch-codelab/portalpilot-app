#!/usr/bin/env python3
"""Convierte la salida --machine de `flutter analyze` en anotaciones de GitHub.

Uso en CI:
    flutter analyze --no-pub --no-fatal-infos --machine > analyze_report.json 2> analyze_err.txt
    python3 tool/ci/analyze_annotations.py analyze_report.json analyze_err.txt

Las anotaciones (::error / ::warning) quedan visibles en la UI de GitHub
Actions y consultables por API (check-runs/annotations), aunque el log
completo del job no se pueda descargar.

Si flutter analyze falla sin producir diagnósticos (p. ej. error de entorno
o de SDK), publica el stderr capturado como anotación para poder diagnosticar
sin acceso al log.
"""
import json
import sys

MAX_DIAGNOSTICS = 40
MAX_RAW_LINES = 40
MAX_RAW_CHARS = 1500

# Prefijos de carpetas del proyecto, para recortar rutas absolutas del runner.
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
    """Publica líneas de texto crudo (stderr) como una sola anotación."""
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


def main(argv):
    if len(argv) < 2:
        print("uso: analyze_annotations.py <analyze_report.json> [analyze_err.txt]", file=sys.stderr)
        return 2

    report_path = argv[1]
    err_path = argv[2] if len(argv) >= 3 else None

    emitted = 0
    saw_json = False
    try:
        report = open(report_path, encoding="utf-8", errors="replace")
    except OSError:
        _emit("error", "ci-analyze",
              "analyze_report.json no existe: flutter analyze no llegó a escribir nada")
        report = None

    if report is not None:
        with report:
            for raw in report:
                raw = raw.strip()
                if not raw.startswith("{"):
                    continue
                try:
                    diag = json.loads(raw)
                except ValueError:
                    continue
                saw_json = True
                if diag.get("type") != "Diagnostic":
                    continue
                severity = diag.get("severity")
                if severity not in ("error", "warning"):
                    continue

                loc = diag.get("location") or {}
                file_path = _shorten(loc.get("file") or "")
                line_no = loc.get("startLine") or 1
                col = loc.get("startColumn")
                code = diag.get("code") or "analyzer"
                message = _flatten(diag.get("message"))

                props_file = file_path if file_path else None
                _emit("error" if severity == "error" else "warning", code, message,
                      props_file, line_no, col)

                emitted += 1
                if emitted >= MAX_DIAGNOSTICS:
                    _emit("error", "ci-analyze",
                          f"Se truncaron los diagnósticos (límite {MAX_DIAGNOSTICS})")
                    break

    if emitted == 0:
        _emit("error", "ci-analyze",
              f"flutter analyze no produjo errores/warnings parseables "
              f"(saw_json={saw_json}). El fallo real está en la anotación "
              f"'flutter-analyze-stderr'.")

        stderr_text = ""
        if err_path:
            try:
                with open(err_path, encoding="utf-8", errors="replace") as fh:
                    stderr_text = fh.read()
            except OSError:
                stderr_text = ""
        if stderr_text.strip():
            _dump_raw("error", "flutter-analyze-stderr", stderr_text)
        else:
            _emit("error", "flutter-analyze-stderr", "(stderr vacío o no capturado)")

    print(f"analyze_annotations: {emitted} diagnósticos emitidos (saw_json={saw_json})",
          flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
