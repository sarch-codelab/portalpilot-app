"""Restaura desde git los archivos dañados por fixup_const2.py v1.
Solo toca archivos que (a) tienen errores de análisis y (b) NO tenían
cambios previos del usuario (los cambios del usuario están en otras rutas).
"""
import subprocess, re, shutil

FLUTTER = shutil.which('flutter') or shutil.which('flutter.bat')
r = subprocess.run(
    [FLUTTER, 'analyze', '--no-pub'],
    capture_output=True, text=True, encoding='utf-8', errors='replace')
out = r.stdout + r.stderr

files = set()
for line in out.splitlines():
    m = re.search(r'- (lib[\\/][^ ]+\.dart):\d+:\d+ - ', line)
    if m:
        files.add(m.group(1).replace('\\', '/'))

files = sorted(files)
print(f'{len(files)} archivos con errores')
for f in files:
    subprocess.run(['git', 'checkout', '--', f], check=True)
    print('restaurado:', f)
