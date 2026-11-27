#!/usr/bin/env python3
"""Extrae los fallos de `flutter test` y los publica como anotaciones de GitHub.

Uso en CI (solo cuando flutter test falla):
    flutter test --no-pub > test_report.txt 2>&1
    python3 tool/ci/test_annotations.py test_report.txt

Prioriza las líneas marcadas con [E] (test fallido en reporter compact),
los "Expected/Actual" y los encabezados de carga; el resto se recorta.
"""
import sys

MAX_RAW_LINES = 40
MAX_RAW_CHARS = 1500

MARKERS = (
    "[E]",
    "Expected:",
    "Actual:",
    "EXCEPTION",
    "Failed to load",
    "test failed",
    "Some tests failed",
    "Unhandled exception",
)


def _flatten(text: str) -> str:
    return " ".join(str(text or "").split())


def _emit(level: str, title: str, message: str):
    print(f"::{level} title={title}::{message}", flush=True)


def main(argv):
    if len(argv) != 2:
        print("uso: test_annotations.py <test_report.txt>", file=sys.stderr)
        return 2

    try:
        with open(argv[1], encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError:
        _emit("error", "flutter-test", "test_report.txt no existe")
        return 0

    total_lines = len(lines)
    importants = [l for l in lines if any(m in l for m in MARKERS)]

    out = []
    size = 0
    for line in importants[:MAX_RAW_LINES]:
        s = _flatten(line)
        out.append(s)
        size += len(s) + 3
        if size >= MAX_RAW_CHARS:
            break

    if not out:
        # Sin marcadores: volcar el final del reporte, donde está el resumen.
        for line in lines[-MAX_RAW_LINES:]:
            s = _flatten(line)
            if s:
                out.append(s)
            if sum(len(x) for x in out) >= MAX_RAW_CHARS:
                break

    _emit("error", "flutter-test", "%0A".join(out) if out else "(reporte vacío)")
    print(
        f"test_annotations: {len(importants)} líneas relevantes de {total_lines} totales",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
