#!/usr/bin/env python3
"""Extrae los fallos de `flutter test` y los publica como anotaciones de GitHub.

Uso en CI (solo cuando flutter test falla):
    flutter test --no-pub > test_report.txt 2>&1
    python3 tool/ci/test_annotations.py test_report.txt

Estrategia: cada excepción del framework viene precedida por la línea de
progreso del reporter compact (con el nombre del test) y seguida de un bloque
delimitado por ═══ que incluye el stack con rutas de archivo. Publica hasta
3 bloques de excepción completos como anotaciones.
"""
import re
import sys

BLOCK_MAX_LINES = 34
BLOCK_MAX_CHARS = 3800

HEADER = "EXCEPTION CAUGHT BY"
FAIL_NAME_RE = re.compile(r"^\d{2}:\d{2}\s+\+\d+\s+-\d+:\s+(.*?)(?:\s*\[E\])?$")


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


def _find_blocks(lines):
    """Bloques [nombre-test?] + excepción completa."""
    blocks = []
    i = 0
    while i < len(lines):
        if HEADER in lines[i]:
            start = max(0, i - 1)  # la línea previa suele traer el nombre del test
            body = lines[start:i]
            j = i
            while j < len(lines) and j - i < BLOCK_MAX_LINES:
                body.append(lines[j])
                if set(lines[j].strip()) == {"═"} and j > i:
                    break
                j += 1
            blocks.append(body)
            i = j + 1
        else:
            i += 1
    return blocks


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

    # Nombres de tests fallidos: razón del expect (contiene "desborda") y
    # líneas de progreso con contador negativo.
    fallidos = []
    for line in raw_lines:
        s = _flatten(line)
        if "desborda" in s:
            nombre = s[:160]
            if nombre not in fallidos:
                fallidos.append(nombre)
        if re.search(r"-\d+:", line):
            m = FAIL_NAME_RE.match(line.strip())
            nombre = _flatten(m.group(1))[:160] if m else _flatten(line)[:160]
            if nombre and nombre not in fallidos:
                fallidos.append(nombre)

    # "The test description was:" va seguido del nombre en la línea siguiente.
    for i, line in enumerate(raw_lines):
        if "The test description was:" in _flatten(line) and i + 1 < len(raw_lines):
            nombre = _flatten(raw_lines[i + 1])[:160]
            if nombre and nombre not in fallidos:
                fallidos.append(nombre)

    if fallidos:
        _emit("error", "tests-fallidos", "%0A".join(fallidos[:40]))

    # Bloques de excepción (máx 8 anotaciones).
    blocks = _find_blocks(raw_lines)
    for n, block in enumerate(blocks[:8], 1):
        _emit("error", f"fallo-{n}", "%0A".join(_chunk(block, BLOCK_MAX_LINES, BLOCK_MAX_CHARS)))

    # Expected/Actual de los expect() fallidos, por si los bloques no bastan.
    expect = [l for l in raw_lines
              if l.strip().startswith(("Expected:", "Actual:"))]
    if len(expect) <= 20 and expect:
        _emit("error", "expect-fallidos", "%0A".join(_chunk(expect, 30, 3500)))

    if not blocks and not fallidos and not expect:
        _emit("error", "flutter-test", "%0A".join(_chunk(raw_lines[-40:], 40, 3500)))

    print(
        f"test_annotations: {len(fallidos)} tests fallidos, {len(blocks)} bloques "
        f"de excepción ({len(raw_lines)} líneas totales)",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
