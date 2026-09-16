"""Fixups posteriores a harmonize_theme.py:
1. appThemeNotifier.appPalette → appPalette
2. Color(appPalette.x) / const Color(appPalette.x) → appPalette.x
3. Limpia llaves/residuos conocidos.
"""
import os, re

ROOT = 'lib'
changed = 0
files_changed = []

for dirpath, _, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(dirpath, fn)
        with open(p, 'r', encoding='utf-8', errors='replace', newline='') as f:
            src = f.read()
        orig = src
        # 1. prefijo residual del ternario dentro de appThemeNotifier.isDark
        src = src.replace('appThemeNotifier.appPalette', 'appPalette')
        # 2. desenvolver Color( appPalette.x )
        src = re.sub(r'(?:const\s+)?Color\(\s*(appPalette\.[\w.]+)\s*\)', r'\1', src)
        if src != orig:
            with open(p, 'w', encoding='utf-8', newline='') as f:
                f.write(src)
            changed += 1
            files_changed.append(p)

print(f'fixups aplicados en {changed} archivos')
