"""
Armonización de tema Portal Pilot.
1. Elimina IconButtons de toggle de tema duplicados (el shell ya pinta uno).
2. Convierte ternarios isDark ? <dark> : <light> a tokens de ThemePalette.
3. Clasifica literales planos (Colors.white, grises) a tokens según contexto.

Solo toca archivos "theme-aware" (referencian appThemeNotifier/ThemePalette).
Excluye: sistema de tema, login/onboarding (oscuro por diseño), main, home
(home se corrige a mano).
"""
import os, re, collections

ROOT = 'lib'
EXCLUDE = {
    os.path.join('lib', 'Shared', 'theme', 'app_theme.dart'),
    os.path.join('lib', 'main.dart'),
    os.path.join('lib', 'launch_screen.dart'),
    os.path.join('lib', 'Home', 'home_screen.dart'),
}
EXCLUDE_NAMES = {'login.dart', 'unico.dart'}

stats = collections.Counter()
changed_files = []

def is_excluded(p, fn):
    if p in EXCLUDE or fn in EXCLUDE_NAMES:
        return True
    return 'onboarding' in p.replace('\\', '/')

def is_theme_aware(src):
    return 'appThemeNotifier' in src or 'ThemePalette' in src

# ── utilidades de balance de paréntesis ──────────────────────────────────
def match_paren(src, open_idx):
    """src[open_idx] debe ser '('. Devuelve índice del ')' correspondiente."""
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

# ── 1. dedup de botones de tema ──────────────────────────────────────────
def remove_theme_toggles(src, path):
    """Elimina IconButtons cuyo onPressed llama a appThemeNotifier.toggle()."""
    has_shell = 'PPModuleScaffold' in src or 'PPAppShell' in src
    for _ in range(25):
        m = re.search(r'appThemeNotifier\s*\.\s*toggle', src)
        if not m:
            break
        start = src.rfind('IconButton(', 0, m.start())
        if start == -1:
            break
        end = match_paren(src, start + len('IconButton') - 1)
        if end == -1:
            break
        # expandir hacia atrás si está dentro de un Tooltip(...)
        pre = src[:start].rstrip()
        if pre.endswith('Tooltip('):
            tstart = len(pre) - len('Tooltip(')
            tend = match_paren(src, tstart + len('Tooltip') - 1)
            if tend != -1 and tend > end:
                start, end = tstart, tend
        # expandir hacia atrás si está dentro de un Container(...) decorativo
        pre = src[:start].rstrip()
        if pre.endswith('child:'):
            cstart = src.rfind('Container(', 0, start)
            if cstart != -1:
                cend = match_paren(src, cstart + len('Container') - 1)
                if cend != -1 and cend >= end:
                    start, end = cstart, cend
        # absorber ',' siguiente (era un argumento de lista)
        after = end + 1
        while after < len(src) and src[after] in ' \t\r\n':
            after += 1
        if after < len(src) and src[after] == ',':
            end = after
        if has_shell:
            src = src[:start] + '/*theme-toggle-removed*/' + src[end + 1:]
            stats['toggles_removed'] += 1
        else:
            # pantalla sin shell: conserva su único toggle, normaliza color
            src = src[:start] + '/*theme-toggle-kept*/' + src[end + 1:]
            stats['toggles_kept'] += 1
    return src

# ── 2. ternarios → tokens ───────────────────────────────────────────────
LIGHT_MAP = {
    'Colors.white': 'appPalette.cardColor',
    'const Color(0xFFFFFFFF)': 'appPalette.cardColor',
    'Color(0xFFFFFFFF)': 'appPalette.cardColor',
    'const Color(0xFF1E1B2A)': 'appPalette.textPrimary',
    'Color(0xFF1E1B2A)': 'appPalette.textPrimary',
    'const Color(0xFF6B7280)': 'appPalette.textMuted',
    'Color(0xFF6B7280)': 'appPalette.textMuted',
    'const Color(0xFF675F7D)': 'appPalette.textMuted',
    'Color(0xFF675F7D)': 'appPalette.textMuted',
    'const Color(0xFF9289A8)': 'appPalette.textDim',
    'Color(0xFF9289A8)': 'appPalette.textDim',
    'const Color(0xFF9CA3AF)': 'appPalette.textMuted',
    'Color(0xFF9CA3AF)': 'appPalette.textMuted',
    'const Color(0xFFE5E7EB)': 'appPalette.borderLight',
    'Color(0xFFE5E7EB)': 'appPalette.borderLight',
    'const Color(0xFFECE8F7)': 'appPalette.bgSecondary',
    'Color(0xFFECE8F7)': 'appPalette.bgSecondary',
    'const Color(0xFFDDD6F0)': 'appPalette.bgTertiary',
    'Color(0xFFDDD6F0)': 'appPalette.bgTertiary',
    'const Color(0xFFF6F4FB)': 'appPalette.bgPrimary',
    'Color(0xFFF6F4FB)': 'appPalette.bgPrimary',
    'const Color(0xFFFDFCFF)': 'appPalette.sidebarColor',
    'Color(0xFFFDFCFF)': 'appPalette.sidebarColor',
    'const Color(0xFFF3E8FD)': 'appPalette.brandGradientSoft.first',
    'const Color(0xFFE0E7FB)': 'appPalette.brandGradientSoft.last',
    'const Color(0xFFF1E8FD)': 'appPalette.aurora[1]',
    'const Color(0xFFE3E9FB)': 'appPalette.aurora[2]',
    'const Color(0xFFE6E1F2)': 'appPalette.skeletonBase',
    'Color(0xFFE6E1F2)': 'appPalette.skeletonBase',
    'const Color(0xFFF2EEFB)': 'appPalette.skeletonHighlight',
    'const Color(0xFFF9FAFB)': 'appPalette.bgSecondary',
    'const Color(0xFFF3F4F6)': 'appPalette.bgSecondary',
    'const Color(0xFFF0F0F5)': 'appPalette.bgSecondary',
    'const Color(0x1A1A1633)': 'appPalette.borderLight',
    'Color(0x1A1A1633)': 'appPalette.borderLight',
    'const Color(0x33000000)': 'appPalette.overlayScrim',
    'Color(0x33000000)': 'appPalette.overlayScrim',
    'const Color(0xFF8B2FB0)': 'appPalette.brandDim',
    'Color(0xFF8B2FB0)': 'appPalette.brandDim',
    'const Color(0xFF4A4460)': 'appPalette.textDark',
    'Color(0xFF4A4460)': 'appPalette.textDark',
    'Colors.white70': 'appPalette.textMuted',
    'Colors.white54': 'appPalette.textMuted',
    'Colors.white38': 'appPalette.textDim',
    'Colors.white24': 'appPalette.textDim',
    'Colors.white12': 'appPalette.borderLight',
    'Colors.white10': 'appPalette.borderLight',
    'Colors.black': 'appPalette.textPrimary',
    'Colors.black87': 'appPalette.textPrimary',
    'Colors.black54': 'appPalette.textMuted',
    'Colors.black45': 'appPalette.textMuted',
    'Colors.black38': 'appPalette.textDim',
    'Colors.black26': 'appPalette.textDim',
    'Colors.black12': 'appPalette.borderLight',
}
DARK_MAP = {
    'const Color(0xFF070510)': 'appPalette.bgPrimary',
    'Color(0xFF070510)': 'appPalette.bgPrimary',
    'const Color(0xFF0E0B1A)': 'appPalette.bgSecondary',
    'Color(0xFF0E0B1A)': 'appPalette.bgSecondary',
    'const Color(0xFF17132A)': 'appPalette.bgTertiary',
    'Color(0xFF17132A)': 'appPalette.bgTertiary',
    'const Color(0xFF12101F)': 'appPalette.cardColor',
    'Color(0xFF12101F)': 'appPalette.cardColor',
    'const Color(0xFF1B1830)': 'appPalette.cardElevated',
    'Color(0xFF1B1830)': 'appPalette.cardElevated',
    'const Color(0xFF111111)': 'appPalette.cardColor',
    'const Color(0xFF1F1F1F)': 'appPalette.cardColor',
    'const Color(0xFF1A1A1A)': 'appPalette.cardColor',
    'const Color(0xFF000000)': 'appPalette.bgPrimary',
    'const Color(0xFF0A0814)': 'appPalette.appBarColor',
    'Color(0xFF0A0814)': 'appPalette.appBarColor',
    'const Color(0xFF0C0A18)': 'appPalette.sidebarColor',
    'Color(0xFF0C0A18)': 'appPalette.sidebarColor',
    'const Color(0x299B8FF2)': 'appPalette.borderLight',
    'Color(0x299B8FF2)': 'appPalette.borderLight',
    'const Color(0x2A9B8FF2)': 'appPalette.borderLight',
    'const Color(0xFF9C95B5)': 'appPalette.textMuted',
    'Color(0xFF9C95B5)': 'appPalette.textMuted',
    'const Color(0xFFF5F2FF)': 'appPalette.textPrimary',
    'Color(0xFFF5F2FF)': 'appPalette.textPrimary',
    'const Color(0xFF5D5672)': 'appPalette.textDim',
    'Color(0xFF5D5672)': 'appPalette.textDim',
    'const Color(0xFF2A1850)': 'appPalette.brandGradientSoft.first',
    'const Color(0xFF1A1E3C)': 'appPalette.brandGradientSoft.last',
    'const Color(0xFF1A0F2E)': 'appPalette.aurora[1]',
    'const Color(0xFF101426)': 'appPalette.aurora[2]',
    'const Color(0xFF1A1828)': 'appPalette.skeletonBase',
    'Color(0xFF1A1828)': 'appPalette.skeletonBase',
    'const Color(0xFF262238)': 'appPalette.skeletonHighlight',
    'const Color(0xFFD16BF0)': 'appPalette.brandBright',
    'const Color(0xCC000000)': 'appPalette.overlayScrim',
    'Color(0xCC000000)': 'appPalette.overlayScrim',
    'const Color(0xFF262626)': 'appPalette.borderLight',
    'const Color(0xFF292929)': 'appPalette.borderLight',
    'const Color(0xFFE5E7EB)': 'appPalette.borderLight',
}

P_RE = re.compile(
    r'isDark(?:\.value)?\s*\?\s*(?:const\s+)?Color\(\s*(0x[0-9A-Fa-f]+|Colors\.\w+)\s*\)\s*:\s*((?:const\s+)?Color\()')
R_RE = re.compile(
    r'isDark(?:\.value)?\s*\?'
    r'\s*((?:const\s+)?Color\(\s*(?:0x[0-9A-Fa-f]+|Colors\.\w+)\s*\)|Colors\.\w+)'
    r'\s*:\s*((?:const\s+)?Color\(\s*(?:0x[0-9A-Fa-f]+|Colors\.\w+)\s*\)|Colors\.\w+)')

def convert_ternaries(src):
    """isDark ? oscuro : claro → token de paleta."""
    spans = []  # (start, end, replacement)
    consumed = []
    for m in P_RE.finditer(src):
        q2 = m.end(2) - 1  # índice del '(' de la 2ª Color(
        close = match_paren(src, q2)
        if close == -1:
            continue
        light = m.group(1)
        tok = LIGHT_MAP.get(light) or LIGHT_MAP.get(f'const Color({light})') or LIGHT_MAP.get(f'Color({light})')
        if not tok:
            continue
        spans.append((m.start(), close + 1, tok))
        consumed.append((m.start(), close + 1))
    for m in R_RE.finditer(src):
        if any(s <= m.start() < e for s, e in consumed):
            continue
        dark, light = m.group(1), m.group(2)
        dtok = DARK_MAP.get(dark.strip()) or DARK_MAP.get(dark.strip().replace('const ', 'const ', 1))
        if not dtok:
            continue
        ltok = LIGHT_MAP.get(light.strip())
        if not ltok:
            ltok = DARK_MAP.get(light.strip())  # par oscuro→oscuro mal emparejado
        if not ltok:
            continue
        spans.append((m.start(), m.end(), ltok))
    spans.sort(key=lambda x: x[0], reverse=True)
    for s, e, rep in spans:
        # quitar const heredado inmediatamente anterior
        pre = src[:s]
        stripped = pre.rstrip()
        if stripped.endswith('const'):
            s = len(stripped) - len('const')
            pre = src[:s]
        src = pre + rep + src[e:]
        stats['ternaries_converted'] += 1
    return src

# ── 3. literales planos → tokens con contexto ────────────────────────────
def context_kind(src, idx):
    back = src[max(0, idx - 300):idx]
    tail = back[-80:]
    fwd = src[idx:idx + 80]
    if re.search(r'Icon\s*\(\s*$', tail) or 'IconData' in tail:
        return 'icon'
    if 'TextStyle(' in back or 'GoogleFonts.' in back or 'TextSpan(' in back or 'style:' in tail:
        return 'text'
    if 'BoxShadow' in tail:
        return 'shadow'
    if 'Border.all' in tail or 'side:' in tail:
        return 'border'
    if 'gradient' in back[-160:]:
        return 'gradient'
    if 'withValues' in fwd or 'withOpacity' in fwd:
        return 'alpha'
    if 'color:' in tail or 'fillColor' in tail or 'backgroundColor' in tail:
        return 'fill'
    return 'other'

LITERAL_RULES = {
    'Colors.white':      {'icon': 'appPalette.textPrimary', 'text': 'appPalette.textPrimary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textPrimary', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    'Colors.white70':    {'icon': 'appPalette.textMuted', 'text': 'appPalette.textMuted', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textMuted', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textMuted'},
    'Colors.white54':    {'icon': 'appPalette.textMuted', 'text': 'appPalette.textMuted', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textMuted', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textMuted'},
    'Colors.white38':    {'icon': 'appPalette.textDim', 'text': 'appPalette.textDim', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textDim', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textDim'},
    'Colors.white24':    {'icon': 'appPalette.textDim', 'text': 'appPalette.textDim', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textDim', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    'Colors.white12':    {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    'Colors.white10':    {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    '0xFFFFFFFF':        {'icon': 'appPalette.textPrimary', 'text': 'appPalette.textPrimary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textPrimary', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFFA3A3A3':        {'icon': 'appPalette.textMuted', 'text': 'appPalette.textMuted', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textMuted', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textMuted'},
    '0xFF525252':        {'icon': 'appPalette.textDim', 'text': 'appPalette.textDim', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textDim', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textDim'},
    '0xFF737373':        {'icon': 'appPalette.textMuted', 'text': 'appPalette.textMuted', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textMuted', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textMuted'},
    '0xFF6B7280':        {'icon': 'appPalette.textMuted', 'text': 'appPalette.textMuted', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textMuted', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textMuted'},
    '0xFF9CA3AF':        {'icon': 'appPalette.textMuted', 'text': 'appPalette.textMuted', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textMuted', 'fill': 'appPalette.bgTertiary', 'other': 'appPalette.textMuted'},
    '0xFF262626':        {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    '0xFF292929':        {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    '0xFF2A2A2A':        {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardElevated', 'other': 'appPalette.cardElevated'},
    '0xFF333333':        {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardElevated', 'other': 'appPalette.cardElevated'},
    '0xFF1F1F1F':        {'icon': 'appPalette.cardColor', 'text': 'appPalette.cardColor', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFF1A1A1A':        {'icon': 'appPalette.cardColor', 'text': 'appPalette.cardColor', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFF1E1E1E':        {'icon': 'appPalette.cardColor', 'text': 'appPalette.cardColor', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFF141414':        {'icon': 'appPalette.cardColor', 'text': 'appPalette.cardColor', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFF18181B':        {'icon': 'appPalette.cardColor', 'text': 'appPalette.cardColor', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFF0F0F0F':        {'icon': 'appPalette.bgSecondary', 'text': 'appPalette.bgSecondary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.bgSecondary', 'other': 'appPalette.bgSecondary'},
    '0xFF080808':        {'icon': 'appPalette.bgSecondary', 'text': 'appPalette.bgSecondary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.bgSecondary', 'other': 'appPalette.bgSecondary'},
    '0xFF0A0A0D':        {'icon': 'appPalette.bgSecondary', 'text': 'appPalette.bgSecondary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.bgSecondary', 'other': 'appPalette.bgSecondary'},
    '0xFF111111':        {'icon': 'appPalette.cardColor', 'text': 'appPalette.cardColor', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.cardColor', 'other': 'appPalette.cardColor'},
    '0xFF000000':        {'icon': 'appPalette.textPrimary', 'text': None, 'shadow': None, 'border': None, 'gradient': None, 'alpha': 'appPalette.bgPrimary', 'fill': 'appPalette.bgPrimary', 'other': None},
    '0xFFE5E7EB':        {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    '0xFFD1D5DB':        {'icon': 'appPalette.borderLight', 'text': 'appPalette.borderLight', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.borderLight', 'fill': 'appPalette.borderLight', 'other': 'appPalette.borderLight'},
    '0xFFF5F2FF':        {'icon': 'appPalette.textPrimary', 'text': 'appPalette.textPrimary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textPrimary', 'fill': 'appPalette.cardColor', 'other': 'appPalette.textPrimary'},
    '0xFF1E1B2A':        {'icon': 'appPalette.textPrimary', 'text': 'appPalette.textPrimary', 'shadow': None, 'border': 'appPalette.borderLight', 'gradient': None, 'alpha': 'appPalette.textPrimary', 'fill': 'appPalette.bgSecondary', 'other': 'appPalette.textPrimary'},
}

LIT_RE = re.compile(
    r'(Colors\.white(?:70|54|38|24|12|10)?|0xFF(?:FFFFFF|A3A3A3|525252|737373|6B7280|9CA3AF|262626|292929|2A2A2A|333333|1F1F1F|1A1A1A|1E1E1E|141414|18181B|0F0F0F|080808|0A0A0D|111111|000000|E5E7EB|D1D5DB|F5F2FF|1E1B2A))\b')

def convert_literals(src):
    spans = []
    for m in LIT_RE.finditer(src):
        lit = m.group(1)
        rules = LITERAL_RULES.get(lit)
        if not rules:
            continue
        kind = context_kind(src, m.start())
        tok = rules.get(kind)
        if not tok:
            continue
        # expandir const heredado
        s = m.start()
        e = m.end()
        pre = src[:s].rstrip()
        if pre.endswith('const'):
            s = len(pre) - len('const')
        spans.append((s, e, tok))
    spans.sort(key=lambda x: x[0], reverse=True)
    applied = []
    last_s = None
    for s, e, rep in spans:
        if last_s is not None and e > last_s:
            continue  # solapamiento
        src = src[:s] + rep + src[e:]
        applied.append(s)
        last_s = s
        stats['literals_converted'] += 1
    return src

# ── limpieza final ───────────────────────────────────────────────────────
def cleanup(src):
    src = re.sub(r'/\*theme-toggle-removed\*/\s*', '', src)
    src = re.sub(r'/\*theme-toggle-kept\*/\s*', '', src)
    # actions: [ ], → eliminar el parámetro completo
    src = re.sub(r'actions\s*:\s*\[\s*\]\s*,\s*\r?\n\s*', '', src)
    src = re.sub(r'actions\s*:\s*\[\s*\]\s*,\s*', '', src)
    # const antes de tokens de paleta (invalidez de const)
    src = re.sub(r'const\s+(appPalette\.\w+)', r'\1', src)
    return src

for dirpath, _, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(dirpath, fn)
        if is_excluded(p, fn):
            continue
        with open(p, 'r', encoding='utf-8', errors='replace') as f:
            src = f.read()
        orig = src
        if not is_theme_aware(src):
            continue
        before_toggles = stats['toggles_removed'] + stats['toggles_kept']
        src = remove_theme_toggles(src, p)
        src = convert_ternaries(src)
        src = convert_literals(src)
        src = cleanup(src)
        if src != orig:
            with open(p, 'w', encoding='utf-8', newline='') as f:
                f.write(src)
            changed_files.append(p)

print(f'archivos modificados: {len(changed_files)}')
for f in changed_files:
    print('  ', f)
print(f"toggles eliminados: {stats['toggles_removed']}")
print(f"toggles conservados (sin shell): {stats['toggles_kept']}")
print(f"ternarios convertidos: {stats['ternaries_converted']}")
print(f"literales convertidos: {stats['literals_converted']}")
