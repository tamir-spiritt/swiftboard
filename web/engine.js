// Bridge to the Rust engine (Swift interpreter + SwiftUI layout, compiled to WebAssembly)
// and a Canvas2D painter for its display lists.
import { ICONS } from './icons.js';

const measureCtx = document.createElement('canvas').getContext('2d');
export const images = new Map();

export async function loadImage(name, url) {
  return new Promise((res) => {
    const img = new Image();
    img.onload = () => { images.set(name, img); res(img); };
    img.onerror = () => res(null);
    img.src = url;
  });
}

export async function loadEngine(url) {
  const dec = new TextDecoder();
  const enc = new TextEncoder();
  let ex;
  const str = (p, l) => dec.decode(new Uint8Array(ex.memory.buffer, p, l));
  const imports = {
    env: {
      host_measure(fp, fl, tp, tl) {
        measureCtx.font = str(fp, fl);
        return measureCtx.measureText(str(tp, tl)).width;
      },
      host_img_aspect(np, nl) {
        const img = images.get(str(np, nl));
        return img && img.naturalHeight ? img.naturalWidth / img.naturalHeight : 1;
      },
    },
  };
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`engine download failed (${resp.status})`);
  const { instance } = await WebAssembly.instantiate(await resp.arrayBuffer(), imports);
  ex = instance.exports;
  const out = (p) => JSON.parse(str(p, ex.sb_out_len()));
  const withStr = (s, fn) => {
    const b = enc.encode(s);
    const p = ex.sb_alloc(b.length);
    new Uint8Array(ex.memory.buffer, p, b.length).set(b);
    try { return fn(p, b.length); } finally { ex.sb_free(p, b.length); }
  };

  class Runtime {
    constructor() { this.id = ex.sb_create(); }
    setSource(src) { return out(withStr(src, (p, l) => ex.sb_set_source(this.id, p, l))); }
    config(w, h, top, bottom, dark, preview) {
      withStr(preview || '', (p, l) => ex.sb_config(this.id, w, h, top, bottom, dark ? 1 : 0, p, l));
    }
    render() { return out(ex.sb_render(this.id)); }
    tap(x, y) { return out(ex.sb_tap(this.id, x, y)); }
    scroll(x, y, dx, dy) { return ex.sb_scroll(this.id, x, y, dx, dy) === 1; }
    input(text) { withStr(text, (p, l) => ex.sb_input(this.id, p, l)); }
    submit() { return out(ex.sb_submit(this.id)); }
    blur() { ex.sb_blur(this.id); }
    reset() { ex.sb_reset(this.id); }
    cloneStateFrom(other) { ex.sb_clone_state(other.id, this.id); }
    destroy() { ex.sb_destroy(this.id); }
  }
  return { Runtime };
}

// ---------------- painter ----------------

function shapePath(ctx, k, x, y, w, h, r0, r1, r2, r3) {
  ctx.beginPath();
  if (k === 0) {
    if (r0 || r1 || r2 || r3) ctx.roundRect(x, y, w, h, [r0, r1, r2, r3]);
    else ctx.rect(x, y, w, h);
  } else {
    ctx.ellipse(x + w / 2, y + h / 2, Math.max(0, w / 2), Math.max(0, h / 2), 0, 0, Math.PI * 2);
  }
}

function withAlpha(rgba, a) {
  const m = /rgba\((\d+),(\d+),(\d+),([\d.]+)\)/.exec(rgba);
  if (!m) return rgba;
  return `rgba(${m[1]},${m[2]},${m[3]},${(+m[4] * a).toFixed(3)})`;
}

function style(ctx, p, y, h) {
  if (typeof p === 'string') return p;
  if (p.lin) {
    const g = ctx.createLinearGradient(p.lin[0], p.lin[1], p.lin[2], p.lin[3]);
    for (const [o, c] of p.stops) g.addColorStop(Math.min(1, Math.max(0, o)), c);
    return g;
  }
  if (p.rad) {
    const g = ctx.createRadialGradient(p.rad[0], p.rad[1], p.rad[2], p.rad[0], p.rad[1], Math.max(p.rad[3], 1));
    for (const [o, c] of p.stops) g.addColorStop(Math.min(1, Math.max(0, o)), c);
    return g;
  }
  if (p.mat) return p.mat;
  if (p.fade) {
    const g = ctx.createLinearGradient(0, y, 0, y + h);
    g.addColorStop(0, withAlpha(p.fade, 0.96));
    g.addColorStop(0.7, withAlpha(p.fade, 0.85));
    g.addColorStop(1, withAlpha(p.fade, 0));
    return g;
  }
  return '#000';
}

const pathCache = new Map();
function iconPaths(name) {
  if (pathCache.has(name)) return pathCache.get(name);
  let key = name;
  let filled = false;
  if (!ICONS[key] && key.endsWith('.fill')) { key = key.slice(0, -5); filled = true; }
  if (!ICONS[key]) {
    const alt = key.replace(/\.(circle|square|fill|badge)$/g, '');
    if (ICONS[alt]) key = alt;
  }
  if (!ICONS[key] && key.endsWith('.circle')) key = key.slice(0, -7);
  const d = ICONS[key];
  const r = d ? { paths: d.map((s) => new Path2D(s)), filled } : null;
  pathCache.set(name, r);
  return r;
}

const iconBitmapCache = new Map();
function iconBitmap(name, color, px, weight) {
  const key = `${name}|${color}|${px}|${weight}`;
  let c = iconBitmapCache.get(key);
  if (c) return c;
  const info = iconPaths(name);
  c = document.createElement('canvas');
  c.width = c.height = px;
  const g = c.getContext('2d');
  const s = px / 24;
  // SF Symbols fill a little more of their box than Lucide
  g.translate(px / 2, px / 2);
  g.scale(s * 1.08, s * 1.08);
  g.translate(-12, -12);
  g.lineCap = 'round';
  g.lineJoin = 'round';
  g.strokeStyle = color;
  g.fillStyle = color;
  g.lineWidth = 1.55 + Math.max(0, (weight - 300)) / 400 * 1.1;
  if (!info) {
    g.beginPath(); g.roundRect(4, 4, 16, 16, 4); g.stroke();
  } else if (info.filled) {
    g.fill(info.paths[0]);
    g.stroke(info.paths[0]);
    g.globalCompositeOperation = 'xor';
    for (const p of info.paths.slice(1)) { g.stroke(p); }
    g.globalCompositeOperation = 'source-over';
  } else {
    for (const p of info.paths) g.stroke(p);
  }
  if (iconBitmapCache.size > 3000) iconBitmapCache.clear();
  iconBitmapCache.set(key, c);
  return c;
}

function lumOf(p) {
  const c = typeof p === 'string' ? p : p && p.stops ? p.stops[0][1] : p && (p.mat || p.fade);
  const m = /rgba\((\d+),(\d+),(\d+),([\d.]+)\)/.exec(c || '');
  if (!m || +m[4] < 0.5) return null;
  return 0.299 * m[1] + 0.587 * m[2] + 0.114 * m[3];
}

export function paint(ctx, ops, scale) {
  // track the colour drawn behind the status bar so the bar picks light or dark text automatically
  paint.statusDark = undefined;
  for (const o of ops) {
    switch (o[0]) {
      case 'F': {
        if (o[2] <= 40 && o[3] <= 20 && o[2] + o[4] >= 60 && o[3] + o[5] >= 24) {
          const l = lumOf(o[10]);
          if (l != null) paint.statusDark = l < 110;
        }
        shapePath(ctx, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9]);
        ctx.fillStyle = style(ctx, o[10], o[3], o[5]);
        ctx.fill();
        break;
      }
      case 'S': {
        shapePath(ctx, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9]);
        ctx.strokeStyle = style(ctx, o[10], o[3], o[5]);
        ctx.lineWidth = o[11];
        ctx.stroke();
        break;
      }
      case 'T':
        ctx.font = o[3];
        ctx.fillStyle = o[4];
        ctx.fillText(o[5], o[1], o[2]);
        break;
      case 'I': {
        const px = Math.max(8, Math.round(o[4] * scale));
        const bmp = iconBitmap(o[1], o[6], px, o[7]);
        ctx.drawImage(bmp, o[2], o[3], o[4], o[5]);
        break;
      }
      case 'M': {
        const img = images.get(o[1]);
        const [x, y, w, h, mode] = [o[2], o[3], o[4], o[5], o[6]];
        if (!img) { ctx.fillStyle = 'rgba(120,120,128,0.16)'; ctx.fillRect(x, y, w, h); break; }
        if (mode === 3) {
          const pat = ctx.createPattern(img, 'repeat');
          pat.setTransform(new DOMMatrix().translate(x, y).scale(0.6));
          ctx.fillStyle = pat;
          ctx.fillRect(x, y, w, h);
        } else if (mode === 1 || mode === 2) {
          const ar = img.naturalWidth / img.naturalHeight;
          let dw = w, dh = w / ar;
          if ((mode === 1 && dh > h) || (mode === 2 && dh < h)) { dh = h; dw = h * ar; }
          ctx.save();
          ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip();
          ctx.drawImage(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
          ctx.restore();
        } else {
          ctx.drawImage(img, x, y, w, h);
        }
        break;
      }
      case 'C':
        ctx.save();
        shapePath(ctx, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9]);
        ctx.clip();
        break;
      case 'P':
        ctx.restore();
        break;
      case 'A':
        ctx.save();
        ctx.globalAlpha *= o[1];
        break;
      case 'B':
        ctx.save();
        ctx.filter = `blur(${o[1] * scale}px)`;
        break;
      case 'SH':
        ctx.save();
        ctx.shadowColor = o[1];
        ctx.shadowBlur = o[2] * scale;
        ctx.shadowOffsetX = o[3] * scale;
        ctx.shadowOffsetY = o[4] * scale;
        break;
      case 'X':
        ctx.save();
        ctx.translate(o[1], o[2]);
        ctx.rotate((o[3] * Math.PI) / 180);
        ctx.scale(o[4], o[4]);
        ctx.translate(-o[1], -o[2]);
        break;
    }
  }
}

// iOS chrome: status bar, dynamic island, home indicator
export function paintChrome(ctx, dev, dark) {
  if (typeof paint.statusDark === 'boolean') dark = paint.statusDark;
  const fg = dark ? '#fff' : '#000';
  if (dev.island) {
    ctx.fillStyle = '#000';
    ctx.beginPath();
    ctx.roundRect(dev.w / 2 - 63, 11, 126, 37, 18.5);
    ctx.fill();
  }
  ctx.fillStyle = fg;
  ctx.font = '600 17px -apple-system, "SF Pro Text", Inter, system-ui, sans-serif';
  const tw = ctx.measureText('9:41').width;
  const ty = dev.island ? 37 : 15;
  ctx.fillText('9:41', dev.island ? 82 - tw / 2 : 12, ty);
  // signal
  const rx = dev.w - (dev.island ? 46 : 12);
  ctx.beginPath(); ctx.roundRect(rx - 4, ty - 11.5, 25, 12, 3.5); ctx.strokeStyle = dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.4)'; ctx.lineWidth = 1; ctx.stroke();
  ctx.beginPath(); ctx.roundRect(rx - 2, ty - 9.5, 21, 8, 2); ctx.fill();
  ctx.beginPath(); ctx.roundRect(rx + 22, ty - 7, 1.5, 4, 1); ctx.fill();
  // wifi
  const wx = rx - 16, wy = ty - 2;
  ctx.save();
  ctx.lineWidth = 2; ctx.strokeStyle = fg; ctx.lineCap = 'round';
  for (const r of [3, 6.5, 10]) { ctx.beginPath(); ctx.arc(wx, wy, r, Math.PI * 1.25, Math.PI * 1.75); ctx.stroke(); }
  ctx.restore();
  const sx = wx - 34;
  for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.roundRect(sx + i * 5, ty - 3 - i * 2.6, 3.2, 3.5 + i * 2.6, 1); ctx.fill(); }
  if (dev.home) {
    ctx.fillStyle = dark ? 'rgba(255,255,255,0.85)' : 'rgba(0,0,0,0.85)';
    ctx.beginPath(); ctx.roundRect(dev.w / 2 - 70, dev.h - 9, 140, 5, 2.5); ctx.fill();
  }
}
