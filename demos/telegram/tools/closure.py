#!/usr/bin/env python3
# Swiftboard web port: grows a module's set of real upstream code. Type-checks the module (shim + real files +
# extracted declarations), maps each missing name to the upstream file declaring it (decl index), then either adds the
# whole file (path matches ALLOW) or extracts just that top-level declaration and its extensions (verbatim upstream
# code). Names in SHIM_NAMES are left for the hand-written shim. Repeats until nothing new is found.
#   closure.py Module index.json state.json allow_regex [rounds]
# DROP_SIG / DROP_IMPORT (drop-decls.py) remove serialization and network-bound members everywhere.
import json, re, subprocess, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assemble import assemble, extract
SHIM_NAMES = set('ChatListNodeInteraction ChatListNode AccountContext SharedAccountContext AnimationCache MultiAnimationRenderer MediaResourceData ResourceDataRequestOption AccumulatedPeers Account AccountStateManager Network Postbox Api TelegramEngine MTRpcError Transaction AccountManager MediaBox EngineData '.split())
mod, index, state_path, allow = sys.argv[1:5]
rounds = int(sys.argv[5]) if len(sys.argv) > 5 else 12
# names declared in dependency modules go to that module's closure (never duplicated here)
DEPS = {'Postbox': 'Postbox/', 'TelegramCore': 'TelegramCore/', 'TelegramUIPreferences': 'TelegramUIPreferences/', 'TelegramPresentationData': 'TelegramPresentationData/', 'TextFormat': 'TextFormat/', 'AccountContext': 'AccountContext/', 'TelegramStringFormatting': 'TelegramStringFormatting/'}
DEP_ALLOW = {'ChatListUI': '^ChatListUI/Sources/(Node/)?(ChatList(BadgeNode|StatusNode|TypingNode|ItemStrings|PresentationData|Item|RichTextPreview|NeighborFacets))\\.swift$', 'Postbox': '^$', 'TelegramCore': '^TelegramCore/Sources/SyncCore/', 'TelegramUIPreferences': '^TelegramUIPreferences/Sources/', 'TelegramPresentationData': '^TelegramPresentationData/Sources/', 'TextFormat': '^TextFormat/Sources/', 'AccountContext': '^$', 'TelegramStringFormatting': '^TelegramStringFormatting/Sources/'}
dirty = set()
def route(f, name):
    for dm, pre in DEPS.items():
        if dm != mod and f.startswith(pre):
            jp = f'{HERE}/shims/chatlist/{dm}.closure.json'
            st = json.load(open(jp)) if os.path.exists(jp) else {'files': [], 'extract': {}}
            if re.search(DEP_ALLOW[dm], f):
                if f not in st['files']: st['files'].append(f)
            else:
                ex = st['extract'].setdefault(f, [])
                if name not in ex: ex.append(name)
            json.dump(st, open(jp, 'w'), indent=1); dirty.add(dm); return True
    return False
idx = json.load(open(index))
TG = os.environ.get('TG', os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../build/telegram-ios')) + '/submodules/'
HERE = os.path.dirname(os.path.abspath(__file__)) + '/..'
OUT = os.environ.get('TG_BUILD', os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../build/telegram')) + '/disp'
state = json.load(open(state_path)) if os.path.exists(state_path) else {'files': [], 'extract': {}}
allow_re = re.compile(allow)
for r in range(rounds):
    src = assemble(mod, state, OUT)
    cmd = f'. "{os.path.dirname(os.path.abspath(__file__))}/../env.sh"; swiftc -target wasm32-unknown-wasip1 -sdk "$WASM_SDK/WASI.sdk" -resource-dir "$WASM_SDK/swift.xctoolchain/usr/lib/swift_static" -module-name {mod} -parse-as-library -wmo -I {OUT} -typecheck -swift-version 5 -suppress-warnings {src}/*.swift'
    log = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True).stderr
    open(f'{OUT}/{mod}.log', 'w').write(log)
    missing = set(re.findall(r"cannot find (?:type )?'([A-Za-z_][A-Za-z0-9_]*)' in scope", log))
    added, left = 0, set()
    for name in sorted(missing):
        if name in SHIM_NAMES or name not in idx: left.add(name); continue
        cands = [f for f in idx[name] if f.startswith(mod + '/')] or [f for f in idx[name] if f.startswith('TelegramCore/')] or idx[name]
        f = cands[0]
        if mod == 'Postbox' and not f.startswith('Postbox/'): left.add(name); continue
        if route(f, name): left.add(name + '(dep)'); continue
        own = {'ChatListUI': 'ChatListUI/'}.get(mod, mod + '/')
        if not f.startswith(own): left.add(name + '(' + f.split('/')[0] + ')'); continue
        if allow_re.search(f) and mod != 'Postbox':
            if f not in state['files']: state['files'].append(f); added += 1
        else:
            ex = state['extract'].setdefault(f, [])
            if name not in ex: ex.append(name); added += 1
            else: left.add(name + '(extracted, still missing)')
    # members from upstream extensions: "value of type 'T' has no member 'm'"
    for T, m in set(re.findall(r"value of (?:optional )?type '(?:any )?([A-Za-z_][A-Za-z0-9_.]*)\??' has no member '([A-Za-z_][A-Za-z0-9_]*)'", log)):
        T = T.split('.')[0]
        hit = None
        for root in ([mod] + (['TelegramCore', 'Postbox'] if mod != 'Postbox' else [])):
            for dp, _, fs in os.walk(TG + root + '/Sources'):
                for fn in fs:
                    if not fn.endswith('.swift'): continue
                    path = os.path.join(dp, fn); text = open(path, encoding='utf-8', errors='ignore').read()
                    if re.search(r'extension\s+' + re.escape(T) + r'\b', text) and re.search(r'(var|func|let)\s+' + re.escape(m) + r'\b', text):
                        hit = os.path.relpath(path, TG); break
                if hit: break
            if hit: break
        if not hit: left.add(f'{T}.{m}'); continue
        if route(hit, T): left.add(f'{T}.{m}(dep)'); continue
        if not hit.startswith({'ChatListUI': 'ChatListUI/'}.get(mod, mod + '/')): left.add(f'{T}.{m}(' + hit.split('/')[0] + ')'); continue
        if allow_re.search(hit) and mod != 'Postbox':
            if hit not in state['files']: state['files'].append(hit); added += 1
        else:
            ex = state['extract'].setdefault(hit, [])
            if T not in ex: ex.append(T); added += 1
    errs = len(re.findall(r': error:', log))
    print(f"round {r}: {len(state['files'])} files + {sum(len(v) for v in state['extract'].values())} extracted decls, {errs} errors, +{added}", flush=True)
    json.dump(state, open(state_path, 'w'), indent=1)
    if not added: break
print('LEFT FOR SHIM:', ' '.join(sorted(left)))
print('DIRTY:', ' '.join(sorted(dirty)))
