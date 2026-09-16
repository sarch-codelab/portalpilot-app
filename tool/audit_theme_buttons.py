import os, re, collections

root = os.path.join('lib')
shapes = collections.Counter()
examples = {}

for dirpath, _, files in os.walk(root):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(dirpath, fn)
        with open(p, 'r', encoding='utf-8', errors='replace') as f:
            src = f.read()
        for m in re.finditer(r'appThemeNotifier\.toggle', src):
            start = src.rfind('IconButton(', 0, m.start())
            if start == -1:
                continue
            # find matching close paren of IconButton(
            depth = 0
            i = start
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
                            break
                i += 1
            block = src[start:i+1]
            # normalize: collapse whitespace, replace color literals and sizes
            norm = re.sub(r'color:\s*[^,]+,', 'color: X,', block)
            norm = re.sub(r'size:\s*[\d.]+', 'size: N', norm)
            norm = re.sub(r'isDark\s*\?', 'D?', norm)
            norm = re.sub(r'Icons\.\w+', 'ICON', norm)
            norm = re.sub(r'\s+', ' ', norm).strip()
            # key signature: has Tooltip wrapper? just normalize the IconButton itself
            sig = norm[:160]
            shapes[sig] += 1
            if sig not in examples:
                examples[sig] = (p, block[:400])

print(f'TOTAL toggle buttons: {sum(shapes.values())}')
print(f'UNIQUE shapes: {len(shapes)}\n')
for sig, count in shapes.most_common():
    print(f'--- x{count}: {sig}')
    p, block = examples[sig]
    print(f'    file: {p}')
    print(f'    block: {block}\n')
