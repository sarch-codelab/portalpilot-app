"""Elimina la palabra clave `const` (no el constructor) cuando el constructor
const contiene appPalette dentro. También convierte `static const X = ...;`
a `static final X = ...;` cuando la inicialización usa appPalette.

v2 — seguro: solo elimina la palabra clave `const ` (con espacio),
nunca el nombre del constructor. Itera hasta estado estable.
"""
import os, re

ROOT = 'lib'

def match_paren(src, open_idx):
    depth = 0
    i = open_idx
    in_str = False
    quote = ''
    while i < len(src):
        c = src[i]
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == quote:
                in_str = False
        else:
            if c in ("'", '"'):
                in_str = True
                quote = c
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return -1

def clean_once(src):
    changed = False
    # 1. static const X = <expr con appPalette> ;
    for m in re.finditer(r'\bstatic\s+const\s+', src):
        eq = src.find('=', m.end())
        semi = src.find(';', m.end())
        if eq == -1 or semi == -1 or eq > semi:
            continue
        if 'appPalette' in src[eq:semi]:
            kw_start = m.start() + len('static ')
            src = src[:kw_start] + src[kw_start + len('const '):]
            changed = True
            break
    # 2. final local/global: const _x = <expr con appPalette>; o const x = ...
    for m in re.finditer(r'(?m)^\s*const\s+(_?[a-z]\w*)\s*=\s*', src):
        semi = src.find(';', m.end())
        if semi == -1:
            continue
        if 'appPalette' in src[m.end():semi]:
            src = src[:m.start()] + m.group(0).replace('const ', 'final ', 1) + src[m.end():]
            changed = True
            break
    # 3. const CTOR( ... appPalette ... ) → quitar solo 'const '
    for m in re.finditer(r'\bconst\s+([A-Z][A-Za-z0-9_]*)\s*\(', src):
        open_idx = m.end() - 1
        close = match_paren(src, open_idx)
        if close == -1:
            continue
        if 'appPalette' in src[open_idx:close]:
            # borrar únicamente 'const ' conservando posición del constructor
            src = src[:m.start()] + src[m.start() + len('const '):]
            changed = True
            break
    return src, changed

for dirpath, _, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(dirpath, fn)
        with open(p, 'r', encoding='utf-8', errors='replace', newline='') as f:
            src = f.read()
        orig = src
        for _ in range(200):
            new, changed = clean_once(src)
            if not changed:
                break
            src = new
        if src != orig:
            with open(p, 'w', encoding='utf-8', newline='') as f:
                f.write(src)
            print('limpiado:', p)

print('limpieza const v2 completada')
