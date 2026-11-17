#!/usr/bin/env python3
# Swiftboard web port: removes whole declarations (from a matching signature line through its balanced braces) and
# matching import lines from an upstream Swift file. Only declarations whose enclosing scopes are all types /
# extensions (or top level) are removed, never statements inside function bodies. Used for storage/network code the
# web port does not build (FlatBuffers serialization, API (de)serializers).
#   drop-decls.py in.swift out.swift SIG_REGEX [IMPORT_REGEX]
import re, sys
src, out, sig = sys.argv[1], sys.argv[2], re.compile(sys.argv[3])
imp = re.compile(sys.argv[4]) if len(sys.argv) > 4 else None
lines = open(src, encoding='utf-8').read().split('\n')
DECL = re.compile(r'\s*(@[\w.]+(\([^)]*\))?\s+)*((public|private|fileprivate|internal|open|static|final|override|convenience|required|mutating|nonmutating|class|indirect|lazy|weak|dynamic)\s+)*(func|init|var|let|extension|case|struct|class|enum|protocol|typealias|subscript)\b')
TYPE = re.compile(r'^\s*(@[\w.]+(\([^)]*\))?\s+)*((public|private|fileprivate|internal|open|final|indirect)\s+)*(class|struct|enum|extension|protocol|actor)\b')
def clean(l):
    l = re.sub(r'"(?:[^"\\]|\\.)*"', '""', l); return re.sub(r'//.*', '', l)
res, stack, i, pending_type = [], [], 0, False
while i < len(lines):
    l = lines[i]
    if imp and re.match(r'\s*(internal |public |@_exported )?import\s+', l) and imp.search(l): i += 1; continue
    in_types = all(k == 'type' for k in stack)
    if in_types and sig.search(l) and DECL.match(l) and not re.match(r'\s*(if|guard|return|switch)\b', l):
        # drop from here through the end of the declaration
        depth, j, opened = 0, i, False
        while True:
            c = clean(lines[j]); depth += c.count('{') - c.count('}'); opened |= '{' in c
            nxt = lines[j + 1].strip() if j + 1 < len(lines) else ''
            if opened and depth <= 0: break
            if not opened and depth <= 0 and not nxt.startswith(('{', '|>', '.', '->', 'where', ',', ')')) and not c.rstrip().endswith((',', '(', '->', '=', '{')): break
            j += 1
            if j >= len(lines): break
        i = j + 1; continue
    c = clean(l)
    if TYPE.match(l): pending_type = True
    for ch in c:
        if ch == '{': stack.append('type' if pending_type else 'code'); pending_type = False
        elif ch == '}' and stack: stack.pop()
    res.append(l); i += 1
open(out, 'w', encoding='utf-8').write('\n'.join(res))
