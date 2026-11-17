#!/usr/bin/env python3
# Swiftboard web port: writes a module's sources into OUT/src/<Module>: real upstream files and extracted upstream
# declarations listed in shims/chatlist/<Module>.closure.json (made by closure.py), each through objc-strip.py and
# drop-decls.py (DROP_SIG/DROP_IMPORT), plus the shim shims/chatlist/<Module>.swift.
#   assemble.py Module state.json OUT
import json, re, subprocess, sys, os
TG = os.environ.get('TG', os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../build/telegram-ios')) + '/submodules/'
HERE = os.path.dirname(os.path.abspath(__file__)) + '/..'
os.environ.setdefault('DROP_SIG', r'\bApi\.|account: Account|accountManager: AccountManager|network: Network|Reachability|postbox: Postbox|transaction: Transaction|engine: TelegramEngine|stateManager: AccountStateManager|accountPeerId: PeerId, postbox|: Signal<\w*,\s*MTRpcError>|MTRpcError|ChatListView\b|ChatListEntry\b|ChatListGroupReferenceEntry|ChatListAdditionalItemEntry|ChatListViewReadState|getAppBundle\(\)\.path\(forResource: "Localizable"')
os.environ.setdefault('DROP_IMPORT', 'MtProtoKit|TelegramApi|CryptoUtils|EncryptionProvider|NetworkLogging|Reachability|zlib')
DECL = r'^(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:(?:public|open|internal|private|fileprivate|final|indirect)\s+)*(?:class|struct|enum|protocol|typealias|func|let|var|extension)\s+'
def clean(l): l = re.sub(r'"(?:[^"\\]|\\.)*"', '""', l); return re.sub(r'//.*', '', l)
def extract(path, names):
    lines = open(TG + path, encoding='utf-8', errors='ignore').read().split('\n')
    # imports of the source file, limited to modules the port builds (others belong to declarations not extracted)
    OUT = os.environ.get('TG_BUILD', os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../build/telegram')) + '/disp'
    def built(l):
        m = re.match(r'\s*(?:internal |public )?import\s+(\w+)', l)
        return m and (m.group(1) in ('Foundation', 'Dispatch', 'Swift') or os.path.exists(f'{OUT}/{m.group(1)}.swiftmodule'))
    out = [l for l in lines if built(l)]
    i = 0
    while i < len(lines):
        m = re.match(DECL + r'([A-Za-z_][A-Za-z0-9_]*)', lines[i])
        if m and m.group(1) in names and not lines[i].startswith(' '):
            depth, j, opened = 0, i, False
            while True:
                c = clean(lines[j]); depth += c.count('{') - c.count('}'); opened |= '{' in c
                if (opened and depth <= 0) or (not opened and j > i + 40): break
                if not opened and re.match(r'.*(typealias|let|var)\b', lines[i]) and '{' not in c and not c.rstrip().endswith(('(', ',', '=')): break
                j += 1
            out += lines[i:j + 1]; i = j + 1; continue
        i += 1
    return '\n'.join(out)

SDK = set('Swift Foundation FoundationEssentials FoundationInternationalization Dispatch WASILibc _Concurrency CoreFoundation Synchronization'.split())
def known_modules():
    mods = set(SDK)
    for line in open(f'{HERE}/shims/chatlist/MODULES'):
        if ':' in line and not line.startswith('#'): mods.add(line.split(':')[0].strip())
    disp = open(f'{HERE}/build-display.sh').read()
    mods |= set(re.findall(r'\b([A-Z][A-Za-z]+)\b', disp))
    return mods
def drop_unknown_imports(path, known):
    lines = open(path, encoding='utf-8').read().split('\n')
    out = [l for l in lines if not ((m := re.match(r'\s*(?:@_exported |internal |public )?import\s+(?:class |struct |enum |func )?([A-Za-z_][A-Za-z0-9_]*)', l)) and m.group(1) not in known)]
    open(path, 'w', encoding='utf-8').write('\n'.join(out))

def assemble(mod, state, OUT):
    src = f'{OUT}/src/{mod}'
    subprocess.run(['rm', '-rf', src]); os.makedirs(src)
    def emit(dst, text=None, path=None):
        if text is not None: open(dst, 'w').write(text); path = dst
        subprocess.run(['python3', f'{HERE}/../../platform/tools/objc-strip.py', path, dst])
        subprocess.run(['python3', f'{HERE}/tools/drop-decls.py', dst, dst, os.environ['DROP_SIG'], os.environ['DROP_IMPORT']])
    for f in state['files']: emit(f'{src}/{os.path.basename(f)}', path=TG + f)
    for f, names in state['extract'].items():
        emit(f'{src}/Extracted_{os.path.basename(f)}', text=extract(f, set(names)))
    known = known_modules()
    for fn in os.listdir(src): drop_unknown_imports(f'{src}/{fn}', known)
    shim = f'{HERE}/shims/chatlist/{mod}.swift'
    if os.path.exists(shim): subprocess.run(['cp', shim, f'{src}/WebStub_{mod}.swift'])
    return src

if __name__ == '__main__':
    assemble(sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3])
