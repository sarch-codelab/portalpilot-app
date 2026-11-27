#!/usr/bin/env python3
"""Extrae los fallos de `flutter test` y los publica como anotaciones de GitHub.

Uso en CI (solo cuando flutter test falla):
    flutter test --no-pub > test_report.txt 2>&1
    python3 tool/ci/test_annotations.py test_report.txt

Publica hasta 3 anotaciones:
  1. Tests fallidos (nombres del reporter compact con contador negativo)
  2. Causa raíz: "error-causing widget was" + overflow + Expected/Actual
  3. Contexto crudo de [E] si lo anterior no bastó
"""
import re
import sys

MAX_RAW_LINES = 60
MAX_RAW_CHARS = 3500

FAIL_LINE_RE = re.compile(r"^\d{2}:\d{2}\s+\+\d+(?:\s+-\d+)?:\s+(.*)$")


def _flatten(text: str) -> str:
    return " ".join(str(text or "").split())


def _emit(level: str, title: str, message: str):
    print(f"::{level} title={title}::{message}", flush=True)


def _chunk(lines, max_lines, max_chars):
    out, size = [], 0
    for line in lines[:max_lines]:
        s = _flatten(line)
        out.append(s)
        size += len(s) + 3
        if size >= max_chars:
            break
    return out


def main(argv):
    if len(argv) != 2:
        print("uso: test_annotations.py <test_report.txt>", file=sys.stderr)
        return 2

    try:
        with open(argv[1], encoding="utf-8", errors="replace") as fh:
            raw_lines = fh.read().splitlines()
    except OSError:
        _emit("error", "flutter-test", "test_report.txt no existe")
        return 0

    # 1) Nombres de tests fallidos: líneas de progreso con contador negativo.
    fallidos = []
    for line in raw_lines:
        if re.search(r"\s+-\d+:", line):
            m = FAIL_LINE_RE.match(line)
            if m:
                nombre = _flatten(m.group(1))[:150]
                if nombre and nombre not in fallidos:
                    fallidos.append(nombre)

    if fallidos:
        msg = "%0A".join(fallidos[:40])
        _emit("error", "tests-fallidos", msg)

    # 2) Causa raíz: widget culpable, overflow, expectativas.
    causas = []
    for i, line in enumerate(raw_lines):
        s = _flatten(line)
        if "error-causing widget was" in s:
            causas.append(s[:200])
            if i + 1 < len(raw_lines):
                causas.append("→ " + _flatten(raw_lines[i + 1])[:250])
        elif "overflowed by" in s:
            causas.append(s[:250])
        elif s.startswith("Expected:") or s.startswith("Actual:"):
            causas.append(s[:200])

    if causas:
        _emit("error", "causa-raiz", "%0A".join(_chunk(causas, MAX_RAW_LINES, MAX_RAW_CHARS)))

    # 3) Contexto [E] crudo por si falta algo.
    e_lines = [l for l in raw_lines if "[E]" in l]
    if e_lines and len(causas) < 6:
        _emit("error", "flutter-test-contexto", "%0A".join(_chunk(e_lines, MAX_RAW_LINES, MAX_RAW_CHARS)))

    print(
        f"test_annotations: {len(fallidos)} tests fallidos, "
        f"{len(causas)} líneas de causa raíz ({len(raw_lines)} totales)",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
