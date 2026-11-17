# Build web/icons.js: SF Symbol names -> Lucide (ISC) path data, all shapes converted to SVG path strings.
import re, json, sys, os
SRC = sys.argv[1]
M = {
 "square.and.pencil":"square-pen","pencil":"pencil","magnifyingglass":"search","speaker.slash":"volume-x","speaker.wave.2":"volume-2",
 "checkmark":"check","checkmark.circle":"circle-check","pin":"pin","paperclip":"paperclip","mic":"mic","face.smiling":"smile",
 "arrow.up":"arrow-up","arrow.down":"arrow-down","arrow.left":"arrow-left","arrow.right":"arrow-right","chevron.left":"chevron-left",
 "chevron.right":"chevron-right","chevron.up":"chevron-up","chevron.down":"chevron-down","person.crop.circle":"circle-user-round",
 "phone":"phone","bubble.left.and.bubble.right":"messages-square","bubble.left":"message-circle","message":"message-circle",
 "gearshape":"settings","gear":"settings","phone.arrow.up.right":"phone-outgoing","phone.arrow.down.left":"phone-incoming",
 "video":"video","info.circle":"info","plus":"plus","plus.circle":"circle-plus","minus":"minus","person.badge.plus":"user-plus",
 "location":"navigation","location.fill":"navigation","phone.badge.plus":"phone-call","bookmark":"bookmark","laptopcomputer":"laptop",
 "folder":"folder","bell":"bell","lock":"lock","cylinder.split.1x2":"database","paintbrush":"paintbrush","globe":"globe",
 "star":"star","xmark":"x","xmark.circle":"circle-x","ellipsis":"ellipsis","ellipsis.circle":"circle-ellipsis","heart":"heart",
 "house":"house","camera":"camera","trash":"trash-2","square.and.arrow.up":"share","person":"user-round","person.2":"users-round",
 "envelope":"mail","calendar":"calendar","clock":"clock","photo":"image","play":"play","pause":"pause","sparkles":"sparkles",
 "flame":"flame","bolt":"zap","cart":"shopping-cart","bag":"shopping-bag","map":"map","mappin":"map-pin","link":"link",
 "qrcode":"qr-code","wifi":"wifi","moon":"moon","sun.max":"sun","cloud":"cloud","music.note":"music","film":"film",
 "book":"book-open","doc":"file","doc.text":"file-text","tray":"inbox","archivebox":"archive","arrowshape.turn.up.left":"reply",
 "arrowshape.turn.up.right":"forward","hand.thumbsup":"thumbs-up","eye":"eye","eye.slash":"eye-off","slider.horizontal.3":"sliders-horizontal",
 "line.3.horizontal":"menu","list.bullet":"list","square.grid.2x2":"layout-grid","arrow.clockwise":"rotate-cw","gift":"gift",
 "creditcard":"credit-card","dollarsign.circle":"circle-dollar-sign","chart.bar":"chart-bar","flag":"flag","tag":"tag",
 "questionmark.circle":"circle-help","exclamationmark.triangle":"triangle-alert","shield":"shield","key":"key-round",
 "hand.raised":"hand","figure.walk":"footprints","airplane":"plane","car":"car","bicycle":"bike","cup.and.saucer":"coffee",
 "fork.knife":"utensils","leaf":"leaf","pawprint":"paw-print","brain":"brain","lightbulb":"lightbulb","wand.and.stars":"wand-sparkles",
 "paperplane":"send","arrow.up.circle":"circle-arrow-up","mic.slash":"mic-off","video.slash":"video-off","speaker":"volume",
 "person.circle":"circle-user","person.3":"users","checkmark.seal":"badge-check","crown":"crown","globe.americas":"earth",
 "battery.100":"battery-full","house.circle":"house","rectangle.portrait.and.arrow.right":"log-out","square.and.arrow.down":"download",
 "arrow.up.arrow.down":"arrow-up-down","line.3.horizontal.decrease":"list-filter","textformat":"type","at":"at-sign",
 "number":"hash","phone.down":"phone-off","waveform":"audio-lines","doc.on.doc":"copy","scissors":"scissors",
}
def num(s): return [float(x) for x in re.findall(r'-?[\d.]+(?:e-?\d+)?', s)]
def attrs(el):
    return dict(re.findall(r'([\w-]+)="([^"]*)"', el))
def topath(tag, a):
    g=lambda k,d=0: float(a.get(k,d))
    if tag=='path': return a['d']
    if tag=='circle':
        cx,cy,r=g('cx'),g('cy'),g('r'); return f"M{cx-r} {cy}a{r} {r} 0 1 0 {2*r} 0a{r} {r} 0 1 0 {-2*r} 0Z"
    if tag=='ellipse':
        cx,cy,rx,ry=g('cx'),g('cy'),g('rx'),g('ry'); return f"M{cx-rx} {cy}a{rx} {ry} 0 1 0 {2*rx} 0a{rx} {ry} 0 1 0 {-2*rx} 0Z"
    if tag=='line': return f"M{g('x1')} {g('y1')}L{g('x2')} {g('y2')}"
    if tag in ('polyline','polygon'):
        p=num(a['points']); s="M"+" L".join(f"{p[i]} {p[i+1]}" for i in range(0,len(p),2)); return s+("Z" if tag=='polygon' else "")
    if tag=='rect':
        x,y,w,h=g('x'),g('y'),g('width'),g('height'); r=g('rx',a.get('ry',0))
        if r<=0: return f"M{x} {y}h{w}v{h}h{-w}Z"
        return f"M{x+r} {y}h{w-2*r}a{r} {r} 0 0 1 {r} {r}v{h-2*r}a{r} {r} 0 0 1 {-r} {r}h{-(w-2*r)}a{r} {r} 0 0 1 {-r} {-r}v{-(h-2*r)}a{r} {r} 0 0 1 {r} {-r}Z"
    return None
out={}
for sf,lu in M.items():
    f=os.path.join(SRC,lu+'.svg')
    if not os.path.exists(f): print('missing',lu,file=sys.stderr); continue
    svg=open(f).read()
    els=re.findall(r'<(path|circle|ellipse|line|polyline|polygon|rect)\b([^>]*)/?>', svg)
    paths=[topath(t,attrs(a)) for t,a in els]
    # silhouette for filled variants: the biggest circle/rect, else the first path
    best,bi=0,0
    for i,(t,a) in enumerate(els):
        at=attrs(a)
        size = 3.14*float(at.get('r',0))**2 if t=='circle' else (float(at.get('width',0))*float(at.get('height',0)) if t=='rect' else 0)
        if size>best: best,bi=size,i
    if best < 150:
        bi=max(range(len(paths)), key=lambda i: len(paths[i]) if els[i][0]=='path' else 0)
    if bi: paths.insert(0, paths.pop(bi))
    out[sf]=paths
js="// SF Symbol name -> Lucide icon paths (Lucide is ISC licensed, https://lucide.dev)\nexport const ICONS = "+json.dumps(out,separators=(',',':'))+";\n"
open(sys.argv[2],'w').write(js)
print(len(out),'icons', len(js),'bytes')
