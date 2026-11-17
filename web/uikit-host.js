// Swiftboard UIKit host (MIT): runs a Swift UIKit/AsyncDisplayKit app compiled to WebAssembly (WASI reactor) and
// paints its CALayer tree onto a canvas. The app exports `app_start`; the platform exports uikit_* (see
// platform/UIKit/WebHost.swift) and webRunLoopTick (platform/WebCompat/Dispatch.swift).

// ---- minimal WASI preview1 for the browser ----
function makeWasi(getMemory, log) {
  const enc = new TextEncoder(), dec = new TextDecoder();
  const lines = { 1: '', 2: '' };
  const view = () => new DataView(getMemory().buffer);
  const bytes = () => new Uint8Array(getMemory().buffer);
  class Exit extends Error { constructor(code) { super('exit ' + code); this.code = code; } }
  const t0 = performance.now();
  const impl = {
    args_sizes_get(argc, bufSize) { view().setUint32(argc, 0, true); view().setUint32(bufSize, 0, true); return 0; },
    args_get() { return 0; },
    environ_sizes_get(cnt, size) { view().setUint32(cnt, 0, true); view().setUint32(size, 0, true); return 0; },
    environ_get() { return 0; },
    clock_res_get(id, out) { view().setBigUint64(out, 1000n, true); return 0; },
    clock_time_get(id, prec, out) {
      const ns = id === 0 ? BigInt(Date.now()) * 1000000n : BigInt(Math.round((performance.now() - t0) * 1e6));
      view().setBigUint64(out, ns, true); return 0;
    },
    fd_write(fd, iovs, n, written) {
      let total = 0;
      for (let i = 0; i < n; i++) {
        const p = view().getUint32(iovs + i * 8, true), l = view().getUint32(iovs + i * 8 + 4, true);
        const s = dec.decode(bytes().slice(p, p + l));
        total += l;
        if (fd === 1 || fd === 2) {
          lines[fd] += s;
          let k;
          while ((k = lines[fd].indexOf('\n')) >= 0) { log(fd, lines[fd].slice(0, k)); lines[fd] = lines[fd].slice(k + 1); }
        }
      }
      view().setUint32(written, total, true); return 0;
    },
    fd_read(fd, iovs, n, read) { view().setUint32(read, 0, true); return 0; },
    fd_close() { return 0; },
    fd_seek(fd, off, whence, out) { view().setBigUint64(out, 0n, true); return 0; },
    fd_fdstat_get(fd, out) { const v = view(); v.setUint8(out, fd <= 2 ? 2 : 0); v.setUint16(out + 2, 0, true); v.setBigUint64(out + 8, 0n, true); v.setBigUint64(out + 16, 0n, true); return 0; },
    fd_fdstat_set_flags() { return 0; },
    fd_filestat_get() { return 8; },
    fd_prestat_get() { return 8; },
    fd_prestat_dir_name() { return 8; },
    path_open() { return 44; },
    path_filestat_get() { return 44; },
    random_get(p, l) { crypto.getRandomValues(bytes().subarray(p, p + l)); return 0; },
    sched_yield() { return 0; },
    poll_oneoff(inp, out, n, nevents) { view().setUint32(nevents, 0, true); return 0; },
    proc_exit(code) { throw new Exit(code); },
  };
  return new Proxy(impl, { get: (t, k) => t[k] || (() => 52) });
}

// ---- text measurement for CoreText (font strings are CSS shorthands) ----
const measureCtx = new OffscreenCanvas(1, 1).getContext('2d');
let lastFont = '';

// ---- painter ----
const rasterCache = new Map(); // CGImage serial -> canvas
const parsePath = new Map();
function path2d(svg) { let p = parsePath.get(svg); if (!p) { p = new Path2D(svg); parsePath.set(svg, p); } return p; }

// Core Graphics' copy blend mode replaces pixels inside the painted shape only; canvas 'copy' also clears everything
// outside it. Emulated as: punch the shape out (destination-out, opaque), then paint it source-over.
function copyAware(g, paint) {
  if (g.globalCompositeOperation !== 'copy') { g.save(); paint(g, false); g.restore(); return; }
  g.save(); g.globalCompositeOperation = 'destination-out'; g.globalAlpha = 1; g.fillStyle = '#000'; paint(g, true); g.restore();
  g.save(); g.globalCompositeOperation = 'source-over'; paint(g, false); g.restore();
}

// Bundle image assets: name -> { image (decoded HTMLImageElement), w, h, scale }, filled before the app starts.
const assets = new Map();

function rasterize(img) {
  let c = rasterCache.get(img.id);
  if (c) { c.used = true; return c; }
  c = document.createElement('canvas');
  c.width = Math.max(1, img.width); c.height = Math.max(1, img.height);
  c.used = true;
  if (img.kind === 'external' && img.source?.startsWith('asset:')) {
    const a = assets.get(img.source.slice(6));
    if (a) c.getContext('2d').drawImage(a.image, 0, 0, c.width, c.height);
  }
  if (img.kind === 'recording') {
    const g = c.getContext('2d');
    g.translate(0, c.height); g.scale(1, -1); // CoreGraphics bitmaps are y-up
    replay(g, img.ops || []);
  }
  rasterCache.set(img.id, c);
  return c;
}

function replay(g0, ops) {
  // clip(to:mask:) has no canvas equivalent: drawing after it goes to an offscreen layer that is masked by the image's
  // alpha (destination-in) and composited when the clip's graphics state is restored.
  let g = g0, depth = 0;
  const masks = [];
  for (const o of ops) {
    switch (o[0]) {
      case 'save': g.save(); depth++; break;
      case 'restore': {
        while (masks.length && masks[masks.length - 1].depth === depth) {
          const m = masks.pop(), layer = g;
          layer.setTransform(m.t); layer.globalCompositeOperation = 'destination-in'; layer.globalAlpha = 1;
          layer.translate(m.r[0], m.r[1] + m.r[3]); layer.scale(1, -1); layer.drawImage(m.bmp, 0, 0, m.r[2], m.r[3]);
          g = m.parent; g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over'; g.drawImage(layer.canvas, 0, 0); g.restore();
        }
        g.restore(); depth--; break;
      }
      case 'concat': g.transform(...o[1]); break;
      case 'fillColor': g.fillStyle = o[1]; break;
      case 'strokeColor': g.strokeStyle = o[1]; break;
      case 'lineWidth': g.lineWidth = o[1]; break;
      case 'lineCap': g.lineCap = o[1]; break;
      case 'lineJoin': g.lineJoin = o[1]; break;
      case 'miterLimit': g.miterLimit = o[1]; break;
      case 'lineDash': g.setLineDash(o[2]); g.lineDashOffset = o[1]; break;
      case 'alpha': g.globalAlpha = o[1]; break;
      case 'blend': g.globalCompositeOperation = o[1]; break;
      case 'shadow': g.shadowOffsetX = o[1][0]; g.shadowOffsetY = -o[1][1]; g.shadowBlur = o[2]; g.shadowColor = o[3]; break;
      case 'fill': copyAware(g, (h, punch) => { if (punch) h.fillStyle = '#000'; h.fill(path2d(o[1]), o[2]); }); break;
      case 'stroke': copyAware(g, (h, punch) => { if (punch) h.strokeStyle = '#000'; h.stroke(path2d(o[1])); }); break;
      case 'clip': g.clip(path2d(o[1]), o[2]); break;
      case 'clipMask': {
        const r = o[2], c = document.createElement('canvas');
        c.width = g.canvas.width; c.height = g.canvas.height;
        const layer = c.getContext('2d'), t = g.getTransform();
        layer.setTransform(t);
        for (const k of ['fillStyle', 'strokeStyle', 'lineWidth', 'lineCap', 'lineJoin', 'globalAlpha', 'font']) layer[k] = g[k];
        masks.push({ depth, parent: g, t, r, bmp: rasterize(o[1]) });
        g = layer; break;
      }
      case 'resetClip': break;
      case 'clear': { const r = o[1]; const op = g.globalCompositeOperation; g.globalCompositeOperation = 'destination-out'; g.fillStyle; g.save(); g.fillStyle = '#000'; g.fillRect(r[0], r[1], r[2], r[3]); g.restore(); g.globalCompositeOperation = op; break; }
      case 'image': {
        const r = o[2], bmp = rasterize(o[1]);
        copyAware(g, (h, punch) => { h.translate(r[0], r[1] + r[3]); h.scale(1, -1); punch ? h.fillRect(0, 0, r[2], r[3]) : h.drawImage(bmp, 0, 0, r[2], r[3]); }); break;
      }
      case 'linearGradient': case 'radialGradient': {
        const lin = o[0] === 'linearGradient';
        const grad = lin ? g.createLinearGradient(o[3][0], o[3][1], o[4][0], o[4][1]) : g.createRadialGradient(o[3][0], o[3][1], o[4], o[5][0], o[5][1], o[6]);
        o[1].forEach((col, i) => grad.addColorStop(Math.min(1, Math.max(0, o[2][i] ?? i / Math.max(1, o[1].length - 1))), col));
        g.save(); g.fillStyle = grad; g.resetTransform?.(); g.fillRect(0, 0, g.canvas.width, g.canvas.height); g.restore(); break;
      }
      case 'text': {
        const [, str, font, at, m, color] = o;
        g.save();
        g.translate(at[0], at[1]); g.transform(...m); g.scale(1, -1);
        g.font = font; if (color !== 'fill') g.fillStyle = color;
        g.textBaseline = 'alphabetic';
        g.fillText(str, 0, 0);
        g.restore(); break;
      }
      case 'beginLayer': g.save(); break;
      case 'endLayer': g.restore(); break;
    }
  }
}

function roundRect(g, w, h, r) { g.beginPath(); if (r > 0) g.roundRect(0, 0, w, h, Math.min(r, w / 2, h / 2)); else g.rect(0, 0, w, h); }

function drawContents(g, L, w, h) {
  const img = L.contents;
  if (!img || typeof img !== 'object') return;
  if (img.kind === 'external' && !img.source?.startsWith('asset:')) { return; }
  let bmp = rasterize(img);
  if (L.tintColor) {
    const t = document.createElement('canvas'); t.width = bmp.width; t.height = bmp.height;
    const tg = t.getContext('2d'); tg.drawImage(bmp, 0, 0); tg.globalCompositeOperation = 'source-in'; tg.fillStyle = L.tintColor; tg.fillRect(0, 0, t.width, t.height);
    bmp = t;
  }
  const s = L.contentsScale || 1, iw = img.width / s, ih = img.height / s;
  const grav = L.contentsGravity || 'resize';
  const cc = L.contentsCenter;
  if (cc && grav === 'resize') { // nine-slice
    const x0 = cc[0] * bmp.width, y0 = cc[1] * bmp.height, x1 = (cc[0] + cc[2]) * bmp.width, y1 = (cc[1] + cc[3]) * bmp.height;
    const sx = [0, x0, x1, bmp.width], sy = [0, y0, y1, bmp.height];
    const dx = [0, x0 / s, w - (bmp.width - x1) / s, w], dy = [0, y0 / s, h - (bmp.height - y1) / s, h];
    for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) {
      const sw = sx[i + 1] - sx[i], sh = sy[j + 1] - sy[j], dw = dx[i + 1] - dx[i], dh = dy[j + 1] - dy[j];
      if (sw > 0 && sh > 0 && dw > 0 && dh > 0) g.drawImage(bmp, sx[i], sy[j], sw, sh, dx[i], dy[j], dw, dh);
    }
    return;
  }
  let dx = 0, dy = 0, dw = w, dh = h;
  if (grav === 'resizeAspect' || grav === 'resizeAspectFill') {
    const k = grav === 'resizeAspect' ? Math.min(w / iw, h / ih) : Math.max(w / iw, h / ih);
    dw = iw * k; dh = ih * k; dx = (w - dw) / 2; dy = (h - dh) / 2;
  } else if (grav !== 'resize') {
    dw = iw; dh = ih;
    dx = grav.includes('eft') ? 0 : grav.includes('ight') ? w - iw : (w - iw) / 2;
    dy = grav === 'top' || grav.startsWith('top') ? 0 : grav === 'bottom' || grav.startsWith('bottom') ? h - ih : (h - ih) / 2;
  }
  g.drawImage(bmp, dx, dy, dw, dh);
}

function paintLayer(g, L, alpha) {
  if (L.hidden) return;
  const a = alpha * (L.opacity ?? 1);
  if (a <= 0.002) return;
  const [w, h] = L.size;
  const ap = L.anchorPoint || [0.5, 0.5];
  g.save();
  g.translate(L.position[0], L.position[1]);
  if (L.transform) { const m = L.transform; g.transform(m[0], m[1], m[4], m[5], m[12], m[13]); }
  g.translate(-ap[0] * w, -ap[1] * h);
  g.globalAlpha = a;
  const r = L.cornerRadius || 0;
  if (L.shadow && L.shadow.opacity > 0 && L.backgroundColor) {
    g.save(); g.shadowColor = L.shadow.color; g.shadowBlur = L.shadow.radius * 2; g.shadowOffsetX = L.shadow.offset[0]; g.shadowOffsetY = L.shadow.offset[1];
    g.globalAlpha = a * L.shadow.opacity; roundRect(g, w, h, r); g.fillStyle = L.backgroundColor; g.fill(); g.restore();
  }
  if (L.backgroundColor) { roundRect(g, w, h, r); g.fillStyle = L.backgroundColor; g.fill(); }
  const clipContents = L.masksToBounds || r > 0;
  if (L.contents) {
    g.save(); if (clipContents && L.masksToBounds) { roundRect(g, w, h, r); g.clip(); }
    drawContents(g, L, w, h); g.restore();
  }
  if (L.gradient) {
    const gr = g.createLinearGradient(L.gradient.start[0] * w, L.gradient.start[1] * h, L.gradient.end[0] * w, L.gradient.end[1] * h);
    L.gradient.colors.forEach((c, i) => gr.addColorStop(i / Math.max(1, L.gradient.colors.length - 1), c));
    g.fillStyle = gr; roundRect(g, w, h, r); g.fill();
  }
  if (L.shape) {
    const p = path2d(L.shape.path);
    if (L.shape.fill) { g.fillStyle = L.shape.fill; g.fill(p); }
    if (L.shape.stroke) { g.strokeStyle = L.shape.stroke; g.lineWidth = L.shape.lineWidth; g.stroke(p); }
  }
  if (L.sublayers) {
    g.save();
    if (L.masksToBounds) { roundRect(g, w, h, r); g.clip(); }
    if (L.boundsOrigin) g.translate(-L.boundsOrigin[0], -L.boundsOrigin[1]);
    for (const s of L.sublayers) paintLayer(g, s, a);
    g.restore();
  }
  if (L.border && L.border.width > 0) {
    g.lineWidth = L.border.width; g.strokeStyle = L.border.color;
    g.beginPath(); g.roundRect(L.border.width / 2, L.border.width / 2, w - L.border.width, h - L.border.width, Math.max(0, r - L.border.width / 2)); g.stroke();
  }
  g.restore();
}

/**
 * Starts a UIKit wasm app in `canvas`.
 * options: { wasm: URL, assets: manifest URL (optional), width, height (points), chrome: (ctx, w, h) => void,
 *            onLog: (line) => void }
 */
export async function startUIKitApp(canvas, options) {
  const width = options.width ?? 390, height = options.height ?? 844;
  const dpr = Math.min(3, window.devicePixelRatio || 1);
  canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr);
  canvas.style.width = width + 'px'; canvas.style.height = height + 'px';
  const g = canvas.getContext('2d');
  let memory;
  const log = (fd, line) => (options.onLog || console.log)(line, fd);
  const wasi = makeWasi(() => memory, log);
  const dec = new TextDecoder();
  const imports = {
    wasi_snapshot_preview1: wasi,
    swiftboard: {
      measure_text(fp, fl, tp, tl) {
        const font = dec.decode(new Uint8Array(memory.buffer, fp, fl));
        const text = dec.decode(new Uint8Array(memory.buffer, tp, tl));
        if (font !== lastFont) { measureCtx.font = font; lastFont = font; }
        return measureCtx.measureText(text).width;
      },
      asset_info(np, nl, out) {
        const a = assets.get(dec.decode(new Uint8Array(memory.buffer, np, nl)));
        if (!a) return 0;
        new Float64Array(memory.buffer, out, 3).set([a.w, a.h, a.scale]);
        return 1;
      },
    },
    env: new Proxy({}, { get: (t, k) => () => { console.warn('unresolved import env.' + String(k)); return 0; } }),
  };
  const t0 = performance.now();
  // options.assets: URL of a manifest { name: [file, pixelWidth, pixelHeight, scale] }; files relative to it
  const assetsReady = options.assets ? fetch(options.assets).then((r) => r.ok ? r.json() : {}).then((manifest) =>
    Promise.all(Object.entries(manifest).map(async ([name, [file, w, h, scale]]) => {
      const image = new Image(); image.src = new URL(file, new URL(options.assets, location.href)).href;
      try { await image.decode(); assets.set(name, { image, w, h, scale }); } catch {}
    }))).catch(() => {}) : Promise.resolve();
  const resp = await fetch(options.wasm);
  const { instance } = await WebAssembly.instantiateStreaming(resp, imports);
  const ex = instance.exports;
  memory = ex.memory;
  const loadMs = performance.now() - t0;
  await assetsReady;
  ex._initialize?.();
  ex.uikit_set_screen(width, height, dpr);
  ex.app_start();

  let lastGen = -1, dirtyFrames = 2, frames = 0;
  const stats = { loadMs, frames: 0, lastFrameMs: 0, layers: 0 };
  function frame() {
    const tStart = performance.now();
    let r = -1;
    for (let i = 0; i < 50; i++) { r = Number(ex.webRunLoopTick()); if (r !== 0 || performance.now() - tStart > 8) break; }
    const gen = ex.uikit_generation();
    if (r >= 0) dirtyFrames = Math.max(dirtyFrames, 1);
    if (gen !== lastGen || dirtyFrames > 0) {
      lastGen = gen; dirtyFrames = Math.max(0, dirtyFrames - 1);
      const p = ex.uikit_frame(), n = ex.uikit_frame_len();
      const windows = JSON.parse(dec.decode(new Uint8Array(memory.buffer, p, n)));
      for (const c of rasterCache.values()) c.used = false;
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, width, height);
      for (const w of windows) paintLayer(g, w, 1);
      for (const [k, c] of rasterCache) if (!c.used) rasterCache.delete(k);
      options.chrome?.(g, width, height);
      stats.frames = ++frames; stats.lastFrameMs = performance.now() - tStart; stats.lastJSON = n;
      canvas.dataset.frames = String(frames);
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  // input: pointer -> UITouch, wheel -> scroll views
  const pt = (e) => { const b = canvas.getBoundingClientRect(); return [(e.clientX - b.left) * width / b.width, (e.clientY - b.top) * height / b.height]; };
  canvas.addEventListener('pointerdown', (e) => { canvas.setPointerCapture(e.pointerId); const [x, y] = pt(e); ex.uikit_pointer(e.pointerId, 0, x, y); });
  canvas.addEventListener('pointermove', (e) => { if (e.buttons || e.pointerType === 'touch') { const [x, y] = pt(e); ex.uikit_pointer(e.pointerId, 1, x, y); } });
  canvas.addEventListener('pointerup', (e) => { const [x, y] = pt(e); ex.uikit_pointer(e.pointerId, 2, x, y); });
  canvas.addEventListener('pointercancel', (e) => { const [x, y] = pt(e); ex.uikit_pointer(e.pointerId, 3, x, y); });
  canvas.addEventListener('wheel', (e) => { e.preventDefault(); const [x, y] = pt(e); ex.uikit_wheel(x, y, e.deltaX, e.deltaY); }, { passive: false });
  canvas.style.touchAction = 'none';
  return { exports: ex, stats };
}
