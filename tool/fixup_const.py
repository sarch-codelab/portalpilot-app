"""Limpia 'const' previo a expresiones no-const con appPalette/GoogleFonts."""
import os, re

ROOT = 'lib'
changed = 0

for dirpath, _, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(dirpath, fn)
        with open(p, 'r', encoding='utf-8', errors='replace', newline='') as f:
            src = f.read()
        orig = src
        # const appPalette.x / const appPalette.x[1] / const appPalette.x.first
        src = re.sub(r'\bconst\s+(appPalette\.[\w.\[\]0-9]+)', r'\1', src)
        # const <const>[appPalette...] → lista con contenido no const
        src = re.sub(r'\bconst\s+\[', '[', src) if 'appPalette' in src else src
        if src != orig:
            with open(p, 'w', encoding='utf-8', newline='') as f:
                f.write(src)
            changed += 1

print(f'const limpiado en {changed} archivos')
