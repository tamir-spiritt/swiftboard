#!/usr/bin/env python3
# Swiftboard (MIT): source preprocessor that lets iOS Swift code compile where Objective-C interop is off (WASI).
#
#   objc-strip.py IN OUT [--import Mod ...]
#
# - drops @objc / @objc(name) / @nonobjc / @objcMembers / @IBAction / @IBOutlet / @IBInspectable
# - #selector(Type.method(_:)) / #selector(self.method) -> Selector("method(_:)", Type.method(_:)) / Self.method
#   (WebCompat's Selector keeps a type-checked invoker, so target/action works without the ObjC runtime)
# - `x.method?(...)` -> `x.method(...)` for ObjC optional protocol requirements (objc-optional-methods.txt): the
#   platform protocols declare them as requirements with default implementations
# - `NotificationCenter`/`RunLoop` -> WebCompat's WebNotificationCenter/WebRunLoop (Foundation's are unavailable on WASI)
# - `x as NSNumber` -> `x as Any as! NSNumber` (numeric bridging coercion needs ObjC interop)
# - `NSMutableString()`/`NSAttributedString()` -> `(string: "")` (missing in corelibs Foundation)
# - `import UIKit.Submodule` -> `import UIKit`
# - appends `import WebCompat` (end of file keeps line numbers) (Dispatch, Selector, runtime shims), plus any extra --import modules
import re
import sys

ATTRS = re.compile(r'@(?:objcMembers|nonobjc|IBAction|IBOutlet|IBInspectable|GKInspectable)\b\s*|@objc(?:\([^)]*\))?(?![A-Za-z0-9_])\s*')
SUBMODULE_IMPORT = re.compile(r'^(\s*import\s+(?:UIKit|QuartzCore|CoreGraphics|Foundation))\.[A-Za-z_.]+', re.M)


def selector(expr):
    e = expr.strip()
    if e.startswith('getter:') or e.startswith('setter:'):
        e = e.split(':', 1)[1].strip()
    if e.startswith('self.'):
        ref = 'Self.' + e[5:]
    elif re.match(r'^[a-z_]', e):
        ref = 'Self.' + e
    else:
        ref = e
    # member part = after the last '.' that is outside parentheses
    depth = 0
    cut = 0
    for i, c in enumerate(e):
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        elif c == '.' and depth == 0:
            cut = i + 1
    name = e[cut:]
    return 'Selector("%s", %s)' % (name, ref)


def replace_selectors(src):
    out = []
    i = 0
    key = '#selector('
    while True:
        j = src.find(key, i)
        if j < 0:
            out.append(src[i:])
            break
        out.append(src[i:j])
        k = j + len(key)
        depth = 1
        while depth:
            if src[k] == '(':
                depth += 1
            elif src[k] == ')':
                depth -= 1
            k += 1
        out.append(selector(src[j + len(key):k - 1]))
        i = k
    return ''.join(out)


import os
OPTIONAL_METHODS = [l.strip() for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'objc-optional-methods.txt'))
                    if l.strip() and not l.startswith('#')]
OPTIONAL_CALL = re.compile(r'\.(' + '|'.join(map(re.escape, OPTIONAL_METHODS)) + r')\?\(')


def main():
    args = sys.argv[1:]
    src_path, out_path = args[0], args[1]
    extra = []
    while '--import' in args:
        k = args.index('--import')
        extra.append(args[k + 1])
        del args[k:k + 2]
    src = open(src_path, encoding='utf-8').read()
    src = ATTRS.sub('', src)
    src = replace_selectors(src)
    src = SUBMODULE_IMPORT.sub(r'\1', src)
    src = OPTIONAL_CALL.sub(r'.\1(', src)
    # Foundation's NotificationCenter (block API) and RunLoop are unavailable on WASI: use WebCompat's
    src = re.sub(r'\bNotificationCenter\b', 'WebNotificationCenter', src)
    src = re.sub(r'\bRunLoop\b', 'WebRunLoop', src)
    # numeric bridging coercions (`x as NSNumber`) need ObjC interop; a dynamic cast bridges on corelibs
    src = '\n'.join(l if re.search(r'\bcase\b|\bcatch\b', l) else re.sub(r'(?<=\w|\)|\]) as (NSNumber|CFNumber)\b(?![?!.(])', r' as Any as! \1', l)
                     for l in src.split('\n'))
    # corelibs Foundation has no NSMutableString() (only init(capacity:) / init(string:))
    src = re.sub(r'\b(NSMutableString|NSAttributedString)\(\)', r'\1(string: "")', src)
    header = ''.join('import %s\n' % m for m in ['WebCompat'] + extra)
    open(out_path, 'w', encoding='utf-8').write(src + '\n' + header)


if __name__ == '__main__':
    main()
