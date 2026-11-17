# Writes the examples gallery manifest from examples/<NN-Name>/*.swift
import json, os, re, sys
META = {
    'Messenger': ('Chat app, 5 screens', 'Telegram-style messenger: chat list, chat, contacts, calls, settings'),
    'Weather': ('Gradient + toggle', 'Weather screen with a °C/°F toggle'),
    'TodoPlayground': ('State, forms, lists', 'Counter, toggle, filters and a todo list'),
    'Calculator': ('Working calculator', 'iOS-style calculator, try 7 × 6 ='),
    'MusicPlayer': ('List + mini player', 'Music library with a floating mini player'),
    'Notes': ('Search + navigation', 'Searchable notes with push navigation'),
    'Shop': ('Grid, cart, tabs', 'Product grid, cart, tab badge and totals'),
}
root = sys.argv[1]
out = []
for d in sorted(os.listdir(root)):
    p = os.path.join(root, d)
    if not os.path.isdir(p): continue
    key = re.sub(r'^\d+-', '', d)
    tag, desc = META.get(key, ('SwiftUI app', ''))
    name = re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', key).replace('Todo Playground', 'Todo')
    out.append({'dir': d, 'name': name, 'tag': tag, 'desc': desc, 'files': sorted(f for f in os.listdir(p) if f.endswith('.swift'))})
print(json.dumps(out, indent=1))
