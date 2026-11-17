#!/usr/bin/env python3
# Swiftboard web port: exports the Telegram bundle images an app references to PNGs plus a manifest for the browser
# host (web/uikit-host.js: { name: [file, pixelWidth, pixelHeight, scale] }). Names are every
# `bundleImageName: "..."` / `UIImage(named: "...")` string in the given Swift sources that has an imageset in
# TelegramUI/Images.xcassets. PDF vectors are rendered at 3x (PyMuPDF); PNG sets use their largest scale.
#   gen-assets.py OUT_DIR swift-file...
import json, os, re, sys, subprocess, warnings
warnings.filterwarnings('ignore')
import fitz
TG = os.environ.get('TG', os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../build/telegram-ios'))
CAT = 'submodules/TelegramUI/Images.xcassets'
out_dir, sources = sys.argv[1], sys.argv[2:]
names = set()
for f in sources:
    t = open(f, encoding='utf-8', errors='ignore').read()
    names |= set(re.findall(r'(?:bundleImageName|UIImage\(named): "([^"]+)"', t))
os.makedirs(out_dir, exist_ok=True)
def git_show(path): return subprocess.run(['git', '-C', TG, 'show', f'HEAD:{path}'], capture_output=True).stdout
def git_ls(path): return subprocess.run(['git', '-C', TG, 'ls-tree', '--name-only', 'HEAD', path + '/'], capture_output=True, text=True).stdout.splitlines()
manifest = {}
for name in sorted(names):
    base = f'{CAT}/{name}.imageset'
    files = [os.path.basename(p) for p in git_ls(base)]
    if not files: continue
    file = re.sub(r'[^A-Za-z0-9]+', '_', name) + '.png'
    pdfs = [x for x in files if x.endswith('.pdf')]
    pngs = sorted((x for x in files if x.endswith('.png')), key=lambda x: (int(m.group(1)) if (m := re.search(r'@(\d)x', x)) else 1))
    if pdfs:
        doc = fitz.open(stream=git_show(f'{base}/{pdfs[0]}'), filetype='pdf')
        pm = doc[0].get_pixmap(matrix=fitz.Matrix(3, 3), alpha=True)
        pm.save(f'{out_dir}/{file}'); w, h, scale = pm.width, pm.height, 3
    elif pngs:
        data = git_show(f'{base}/{pngs[-1]}'); open(f'{out_dir}/{file}', 'wb').write(data)
        m = re.search(r'@(\d)x', pngs[-1]); scale = int(m.group(1)) if m else 1
        w, h = int.from_bytes(data[16:20], 'big'), int.from_bytes(data[20:24], 'big')
    else: continue
    manifest[name] = [file, w, h, scale]
json.dump(manifest, open(f'{out_dir}/manifest.json', 'w'), indent=0, sort_keys=True)
print(f'{len(manifest)} of {len(names)} referenced images exported')
