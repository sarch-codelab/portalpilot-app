#!/usr/bin/env python3
"""Convierte la salida --machine de `flutter analyze` en anotaciones de GitHub.

Uso en CI:
    flutter analyze --no-pub --no-fatal-infos --machine > analyze_report.json
    python3 tool/ci/analyze_annotations.py analyze_report.json

Las anotaciones (::error / ::warning) quedan visibles en la UI de GitHub
Actions y consultables por API (check-runs/annotations), aunque el log
completo no se pueda descargar.
"""
import json
import sys

MAX_ANNOTATIONS = 40

# Prefijos de carpetas del proyecto, para recortar rutas absolutas del runner.
_PREFIXES = ("/lib/", "/test/", "/tool/", "/bin/", "/web/", "/integration_test/")


def _shorten(path: str) -> str:
    p = (path or "").replace("\\", "/")
    # Recorta prefijos tipo /home/runner/work/repo/repo/lib/x.dart -> lib/x.dart
    for prefix in _PREFIXES:
        idx = p.find(prefix)
        if idx != -1:
            return p[idx + 1:]
    return p


def _flatten(text: str) -> str:
    return " ".join(str(text or "").split())


def main(argv):
    if len(argv) != 2:
        print("uso: analyze_annotations.py <analyze_report.json>", file=sys.stderr)
        return 2

    emitted = 0
    with open(argv[1], encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw.startswith("{"):
                continue
            try:
                diag = json.loads(raw)
            except ValueError:
                continue
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

            cmd = "::error" if severity == "error" else "::warning"
            props = f"file={file_path},line={line_no}"
            if col:
                props += f",col={col}"
            props += f",title={code}"
            print(f"{cmd} {props}::{message}", flush=True)

            emitted += 1
            if emitted >= MAX_ANNOTATIONS:
                print(
                    "::error::Se truncaron los diagnósticos (límite "
                    f"{MAX_ANNOTATIONS}) — revisa el paso completo del job",
                    flush=True,
                )
                break

    print(f"analyze_annotations: {emitted} anotaciones emitidas", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
