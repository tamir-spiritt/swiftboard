import { loadEngine, loadImage, paint, paintChrome } from './engine.js';
import * as KB from './keyboard.js';
import { startUIKitApp } from './uikit-host.js';

const FILES = ['Theme.swift', 'Models.swift', 'ChatList.swift', 'ChatView.swift', 'Tabs.swift'];
const DEVICES = {
  iphone17pro: { name: 'iPhone 17 Pro', w: 402, h: 874, top: 62, bottom: 34, radius: 62, island: true, home: true },
  iphone17promax: { name: 'iPhone 17 Pro Max', w: 440, h: 956, top: 62, bottom: 34, radius: 66, island: true, home: true },
  iphone16e: { name: 'iPhone 16e', w: 390, h: 844, top: 50, bottom: 34, radius: 50, island: false, home: true },
  iphoneSE: { name: 'iPhone SE', w: 375, h: 667, top: 20, bottom: 0, radius: 0, island: false, home: false },
};
const STORE = 'swiftboard:v2';
// files live next to this script (the host may serve them from a different path than the page)
const asset = (p) => new URL(p, import.meta.url).href;
const enc = new TextEncoder();
const $ = (s, r = document) => r.querySelector(s);
const h = (tag, attrs = {}, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'class') e.className = v;
    else if (k === 'html') e.innerHTML = v;
    else if (v !== undefined && v !== null && v !== false) e.setAttribute(k, v);
  }
  for (const c of kids.flat()) if (c != null) e.append(c.nodeType ? c : document.createTextNode(c));
  return e;
};
const uid = () => Math.random().toString(36).slice(2, 9);
const ago = (t) => {
  const s = (Date.now() - t) / 1000;
  if (s < 45) return 'Now';
  if (s < 3600) return `${Math.round(s / 60)}m ago`;
  if (s < 86400) return `${Math.round(s / 3600)}h ago`;
  return `${Math.round(s / 86400)}d ago`;
};

let E;
let S; // persistent board state
const live = new Map(); // frameId -> { rt, el, canvas, last, err }
const srcCache = new Map(); // branchId -> { src, offs, b2c }
const ui = { mode: 'interact', tab: 'design', file: 'ChatList.swift', elem: null, hover: null, focus: null, lastMs: 0, codeErr: null };

// ---------------- persistence ----------------

async function defaultState() {
  const files = {};
  for (const f of FILES) files[f] = await (await fetch(asset(`examples/01-Messenger/${f}`))).text();
  const main = { id: 'main', name: 'main', files, order: FILES.slice(), versions: [{ t: Date.now(), label: 'Messenger example', files: { ...files } }] };
  const names = ['Chat List', 'Chat', 'Contacts', 'Calls', 'Settings'];
  const frames = names.map((n, i) => ({ id: uid(), name: n, preview: n, branch: 'main', x: i * 482, y: 0, device: 'iphone17pro', dark: false }));
  return { branches: { main }, frames, cam: null, sel: frames[0].id };
}

let saveT;
function save() {
  clearTimeout(saveT);
  saveT = setTimeout(() => {
    try { localStorage.setItem(STORE, JSON.stringify(S)); } catch (e) { console.warn('save failed', e); }
  }, 400);
}

// ---------------- source mapping ----------------

function branchSrc(bid) {
  let c = srcCache.get(bid);
  if (c) return c;
  const b = S.branches[bid];
  let src = '';
  const offs = [];
  for (const f of b.order) { offs.push([src.length, f]); src += b.files[f] + '\n'; }
  const bytes = enc.encode(src);
  let b2c = null;
  if (bytes.length !== src.length) {
    b2c = new Int32Array(bytes.length + 1);
    let bi = 0;
    for (let ci = 0; ci < src.length; ci++) {
      const cp = src.codePointAt(ci);
      const n = cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
      for (let k = 0; k < n; k++) b2c[bi + k] = ci;
      bi += n;
      if (cp > 0xffff) ci++;
    }
    b2c[bytes.length] = src.length;
  }
  c = { src, offs, b2c };
  srcCache.set(bid, c);
  return c;
}
const toChar = (c, byte) => (c.b2c ? c.b2c[Math.min(byte, c.b2c.length - 1)] : byte);
function locate(bid, byte) {
  const c = branchSrc(bid);
  const ci = toChar(c, byte);
  let fo = c.offs[0];
  for (const o of c.offs) if (o[0] <= ci) fo = o;
  const local = ci - fo[0];
  const text = S.branches[bid].files[fo[1]];
  const before = text.slice(0, local);
  const line = before.split('\n').length;
  const col = local - before.lastIndexOf('\n');
  return { file: fo[1], idx: local, line, col, ci };
}

function editBranch(bid, edits, label) {
  // edits: [{a, b, text}] in global char indices of current branch source; apply back-to-front
  const b = S.branches[bid];
  const c = branchSrc(bid);
  edits.sort((x, y) => y.a - x.a);
  for (const e of edits) {
    let fo = c.offs[0];
    for (const o of c.offs) if (o[0] <= e.a) fo = o;
    const f = fo[1];
    const la = e.a - fo[0], lb = e.b - fo[0];
    b.files[f] = b.files[f].slice(0, la) + e.text + b.files[f].slice(lb);
  }
  branchChanged(bid, label);
}

// ---------------- runtime ----------------

function compileFrame(f) {
  const L = live.get(f.id);
  const c = branchSrc(f.branch);
  const t0 = performance.now();
  const r = L.rt.setSource(c.src);
  L.compileMs = performance.now() - t0;
  L.compileErr = r.ok ? null : r.error;
  L.previews = r.previews || L.previews || [];
}

function branchChanged(bid, label) {
  srcCache.delete(bid);
  for (const f of S.frames) if (f.branch === bid) { compileFrame(f); renderFrame(f); }
  recordVersion(bid, label);
  save();
  if (ui.tab === 'code') refreshCodeStatus();
  renderLeft();
}

let verT;
function recordVersion(bid, label) {
  clearTimeout(verT);
  verT = setTimeout(() => {
    const b = S.branches[bid];
    const last = b.versions[b.versions.length - 1];
    if (last && b.order.every((f) => last.files[f] === b.files[f])) return;
    b.versions.push({ t: Date.now(), label: label || 'Edited code', files: { ...b.files } });
    if (b.versions.length > 15) b.versions.splice(1, 1);
    save();
    if (ui.tab === 'design' && !ui.elem) renderPanel();
  }, 900);
}

function pxScale() {
  return Math.min(3, Math.max(0.75, (window.devicePixelRatio || 1) * S.cam.z));
}

function renderFrame(f) {
  const L = live.get(f.id);
  if (!L) return;
  const dev = DEVICES[f.device];
  const px = pxScale();
  const cv = L.canvas;
  const W = Math.round(dev.w * px), H = Math.round(dev.h * px);
  if (cv.width !== W || cv.height !== H) { cv.width = W; cv.height = H; }
  const ctx = cv.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, W, H);
  ctx.setTransform(px, 0, 0, px, 0, 0);
  ctx.fillStyle = f.dark ? '#000' : '#fff';
  ctx.fillRect(0, 0, dev.w, dev.h);
  let r;
  const t0 = performance.now();
  if (L.compileErr) {
    r = { error: { ...L.compileErr, kind: 'compile' } };
  } else {
    const kbH = L.kbH || 0;
    L.rt.config(dev.w, dev.h, dev.top, kbH > 0 ? Math.max(dev.bottom, kbH) : dev.bottom, f.dark, f.preview);
    r = L.rt.render();
  }
  const t1 = performance.now();
  L.last = r;
  L.err = r.error || (r.errors && r.errors[0]) || null;
  if (r.error) {
    paint.statusDark = undefined;
    paintError(ctx, dev, f, r.error);
  } else {
    paint(ctx, r.ops, px);
  }
  if (L.kbH > 0) L.kbKeys = KB.draw(ctx, dev, kbState(L), dev.h - L.kbH, f.dark);
  paintChrome(ctx, dev, f.dark);
  const t2 = performance.now();
  ui.lastMs = { layout: t1 - t0, paint: t2 - t1 };
  $('#stats').textContent = `layout ${(t1 - t0).toFixed(1)}ms · paint ${(t2 - t1).toFixed(1)}ms`;
  syncInput(f);
  if (ui.elem && ui.elem.frame === f.id) drawOverlay();
}

function paintError(ctx, dev, f, e) {
  const loc = e.pos != null ? locate(f.branch, e.pos) : null;
  ctx.fillStyle = f.dark ? '#1c1c1e' : '#f2f2f7';
  ctx.fillRect(0, 0, dev.w, dev.h);
  ctx.fillStyle = '#ff3b30';
  ctx.font = '600 15px Inter, system-ui';
  ctx.fillText(e.kind === 'compile' ? 'Swift compile error' : 'Swift runtime error', 24, 130);
  ctx.fillStyle = f.dark ? '#fff' : '#1d1d1f';
  ctx.font = '13px "JetBrains Mono", monospace';
  const words = String(e.msg).split(' ');
  let line = '', y = 160;
  for (const w of words) {
    if (ctx.measureText(line + w).width > dev.w - 48) { ctx.fillText(line, 24, y); y += 20; line = ''; }
    line += w + ' ';
  }
  ctx.fillText(line, 24, y);
  if (loc) { ctx.fillStyle = '#8a8a8e'; ctx.fillText(`${loc.file}:${loc.line}:${loc.col}`, 24, y + 28); }
}

// ---------------- board / camera ----------------

const board = $('#board'), world = $('#world'), overlay = $('#overlay');

function applyCam() {
  world.style.transform = `translate(${S.cam.x}px, ${S.cam.y}px) scale(${S.cam.z})`;
  $('#zoom').textContent = `${Math.round(S.cam.z * 100)}%`;
  for (const f of S.frames) {
    const L = live.get(f.id);
    if (L) L.el.querySelector('.label').style.transform = `scale(${1 / S.cam.z})`;
  }
  drawOverlay();
  clearTimeout(applyCam.t);
  applyCam.t = setTimeout(() => S.frames.forEach(renderFrame), 120);
  save();
}

function fit(frames = S.frames) {
  if (!frames.length) return;
  const r = board.getBoundingClientRect();
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const f of frames) {
    const d = DEVICES[f.device];
    x0 = Math.min(x0, f.x); y0 = Math.min(y0, f.y); x1 = Math.max(x1, f.x + d.w); y1 = Math.max(y1, f.y + d.h);
  }
  const pad = 70;
  const z = Math.min(1.4, (r.width - pad * 2) / (x1 - x0), (r.height - pad * 2 - 40) / (y1 - y0));
  S.cam = { z, x: (r.width - (x1 - x0) * z) / 2 - x0 * z, y: (r.height - 40 - (y1 - y0) * z) / 2 - y0 * z + 6 };
  applyCam();
}

function zoomAt(cx, cy, factor) {
  const z = Math.min(4, Math.max(0.1, S.cam.z * factor));
  const k = z / S.cam.z;
  S.cam.x = cx - (cx - S.cam.x) * k;
  S.cam.y = cy - (cy - S.cam.y) * k;
  S.cam.z = z;
  applyCam();
}

function frameAt(clientX, clientY) {
  for (const f of [...S.frames].reverse()) {
    const L = live.get(f.id);
    const r = L.canvas.getBoundingClientRect();
    if (clientX >= r.left && clientX <= r.right && clientY >= r.top && clientY <= r.bottom) {
      const d = DEVICES[f.device];
      return { f, L, x: ((clientX - r.left) / r.width) * d.w, y: ((clientY - r.top) / r.height) * d.h };
    }
  }
  return null;
}

board.addEventListener('wheel', (e) => {
  if (e.target.closest('.native .screen')) return;
  e.preventDefault();
  const br = board.getBoundingClientRect();
  if (e.ctrlKey || e.metaKey) {
    zoomAt(e.clientX - br.left, e.clientY - br.top, Math.exp(-e.deltaY * 0.01));
    return;
  }
  const hit = frameAt(e.clientX, e.clientY);
  if (hit && ui.mode === 'interact') {
    const dy = e.deltaMode === 1 ? e.deltaY * 18 : e.deltaY;
    const dx = e.deltaMode === 1 ? e.deltaX * 18 : e.deltaX;
    if (hit.L.rt.scroll(hit.x, hit.y, dx, dy)) { renderFrame(hit.f); return; }
  }
  S.cam.x -= e.deltaX;
  S.cam.y -= e.deltaY;
  applyCam();
}, { passive: false });

let drag = null;
board.addEventListener('pointerdown', (e) => {
  if (e.target.closest('#toolbar') || e.target.closest('.ctl') || e.target.classList.contains('fld') || e.target.closest('.native')) return;
  const lab = e.target.closest('.label');
  if (lab) {
    const f = S.frames.find((x) => x.id === lab.dataset.id);
    selectFrame(f.id);
    drag = { kind: 'frame', f, sx: e.clientX, sy: e.clientY, ox: f.x, oy: f.y };
    board.setPointerCapture(e.pointerId);
    return;
  }
  const hit = frameAt(e.clientX, e.clientY);
  if (hit) {
    if (S.sel !== hit.f.id) selectFrame(hit.f.id, true);
    if (ui.mode === 'select' || e.altKey) {
      pickElem(hit, true);
      return;
    }
    drag = { kind: 'app', hit, sx: e.clientX, sy: e.clientY, lx: e.clientY, lxx: e.clientX, moved: false };
    board.setPointerCapture(e.pointerId);
    return;
  }
  if (ui.focus) blurInput();
  drag = { kind: 'pan', sx: e.clientX, sy: e.clientY, ox: S.cam.x, oy: S.cam.y, moved: false };
  board.classList.add('panning');
  board.setPointerCapture(e.pointerId);
});

board.addEventListener('pointermove', (e) => {
  if (!drag) {
    if (ui.mode === 'select' || e.altKey) {
      const hit = frameAt(e.clientX, e.clientY);
      const prev = ui.hover;
      ui.hover = hit ? findElem(hit) : null;
      if (prev !== ui.hover) drawOverlay();
    } else if (ui.hover) { ui.hover = null; drawOverlay(); }
    return;
  }
  if (drag.kind === 'pan') {
    S.cam.x = drag.ox + (e.clientX - drag.sx);
    S.cam.y = drag.oy + (e.clientY - drag.sy);
    if (Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy) > 3) drag.moved = true;
    applyCam();
  } else if (drag.kind === 'frame') {
    drag.f.x = Math.round(drag.ox + (e.clientX - drag.sx) / S.cam.z);
    drag.f.y = Math.round(drag.oy + (e.clientY - drag.sy) / S.cam.z);
    positionFrame(drag.f);
    drawOverlay();
    save();
  } else if (drag.kind === 'app') {
    const dist = Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy);
    if (dist > 5) drag.moved = true;
    if (drag.moved) {
      const k = 1 / S.cam.z;
      const dy = (drag.lx - e.clientY) * k, dx = (drag.lxx - e.clientX) * k;
      drag.lx = e.clientY; drag.lxx = e.clientX;
      if (drag.hit.L.rt.scroll(drag.hit.x, drag.hit.y, dx, dy)) renderFrame(drag.hit.f);
    }
  }
});

board.addEventListener('pointerup', (e) => {
  board.classList.remove('panning');
  const d = drag;
  drag = null;
  if (!d) return;
  if (d.kind === 'pan' && !d.moved) { clearElem(); }
  if (d.kind === 'app' && !d.moved) {
    const hit = frameAt(e.clientX, e.clientY);
    if (hit && hit.f.id === d.hit.f.id) tapApp(hit);
  }
});

// ---------------- software keyboard ----------------

function kbState(L) {
  if (!L.kb) L.kb = { mode: 'abc', shift: true, caps: false, pressed: null, lastShift: 0 };
  return L.kb;
}

function animateKb(f, to) {
  const L = live.get(f.id);
  if (!L) return;
  const from = L.kbH || 0;
  if (Math.abs(from - to) < 0.5) return;
  const t0 = performance.now(), dur = 300;
  L.kbAnim = t0;
  const step = (now) => {
    if (L.kbAnim !== t0) return;
    const k = Math.min(1, (now - t0) / dur);
    const e = 1 - Math.pow(1 - k, 3);
    L.kbH = from + (to - from) * e;
    renderFrame(f);
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function openKb(f) {
  const st = kbState(live.get(f.id));
  st.mode = 'abc';
  st.shift = !ui.inputEl || ui.inputEl.value === '' || /[.!?]\s$/.test(ui.inputEl.value);
  animateKb(f, KB.totalHeight(DEVICES[f.device]));
}
function closeKb(f) { animateKb(f, 0); }

function kbTap(hit) {
  const { f, L } = hit;
  const k = KB.keyAt(L.kbKeys || [], hit.x, hit.y);
  if (!k || !ui.inputEl) return;
  const st = kbState(L);
  const el = ui.inputEl;
  let v = el.value;
  const a = el.selectionStart ?? v.length, b = el.selectionEnd ?? v.length;
  const insert = (t) => { v = v.slice(0, a) + t + v.slice(b); el.value = v; el.setSelectionRange(a + t.length, a + t.length); };
  switch (k.kind) {
    case 'char': {
      const c = st.mode === 'abc' && (st.shift || st.caps) ? k.label.toUpperCase() : k.label;
      insert(c);
      if (!st.caps) st.shift = false;
      if (st.mode !== 'abc' && k.label === "'") st.mode = 'abc';
      break;
    }
    case 'space':
      insert(' ');
      if (st.mode !== 'abc') st.mode = 'abc';
      st.shift = /[.!?]\s$/.test(el.value);
      break;
    case 'del':
      if (a !== b) insert('');
      else if (a > 0) { const p = [...v.slice(0, a)]; p.pop(); const head = p.join(''); el.value = head + v.slice(a); el.setSelectionRange(head.length, head.length); }
      st.shift = el.value === '';
      break;
    case 'shift': {
      const now = performance.now();
      if (st.caps) { st.caps = false; st.shift = false; }
      else if (now - st.lastShift < 320) { st.caps = true; st.shift = true; }
      else st.shift = !st.shift;
      st.lastShift = now;
      break;
    }
    case 'page': st.mode = k.to; break;
    case 'emoji': insert('🙂'); break;
    case 'return': {
      const r = L.rt.submit();
      if (r.error) toast(r.error.msg);
      el.value = '';
      st.shift = true;
      renderFrame(f);
      L.rt.input(el.value);
      break;
    }
  }
  if (k.kind !== 'return') L.rt.input(el.value);
  st.pressed = k;
  renderFrame(f);
  clearTimeout(L.kbPressT);
  L.kbPressT = setTimeout(() => { st.pressed = null; renderFrame(f); }, 110);
  el.focus();
}

function tapApp(hit) {
  const devK = DEVICES[hit.f.device];
  if (hit.L.kbH > 0 && hit.y >= devK.h - hit.L.kbH) { kbTap(hit); return; }
  const r = hit.L.rt.tap(hit.x, hit.y);
  if (r.error) toast(`Runtime error: ${r.error.msg}`);
  const hadFocus = ui.focus && ui.focus.frame === hit.f.id;
  if (r.focus) { ui.focus = { frame: hit.f.id, ...r.focus }; }
  else if (hadFocus) { removeInput(); ui.focus = null; closeKb(hit.f); }
  if (r.changed) renderFrame(hit.f);
  if (r.focus) { mountInput(hit.f); openKb(hit.f); }
}

// ---------------- text input bridge ----------------

function mountInput(f) {
  removeInput();
  const L = live.get(f.id);
  const fo = ui.focus;
  const el = fo.multiline ? h('textarea', { class: 'fld', rows: 1 }) : h('input', { class: 'fld', type: fo.secure ? 'password' : 'text' });
  el.value = fo.value;
  el.style.font = fo.font;
  el.style.color = fo.color;
  placeInput(el, fo);
  el.addEventListener('input', () => { L.rt.input(el.value); const st = kbState(L); st.shift = el.value === '' || /[.!?]\s$/.test(el.value); renderFrame(f); });
  el.addEventListener('keydown', (e) => {
    e.stopPropagation();
    if (e.key === 'Enter' && (!fo.multiline || !e.shiftKey)) {
      e.preventDefault();
      const r = L.rt.submit();
      if (r.error) toast(r.error.msg);
      renderFrame(f);
    }
    if (e.key === 'Escape') blurInput();
  });
  L.el.querySelector('.screen').append(el);
  ui.inputEl = el;
  setTimeout(() => el.focus(), 0);
}

function placeInput(el, r) {
  el.style.left = `${r.x}px`;
  el.style.top = `${r.y}px`;
  el.style.width = `${r.w}px`;
  el.style.height = `${r.h}px`;
}

function syncInput(f) {
  if (!ui.focus || ui.focus.frame !== f.id || !ui.inputEl) return;
  const L = live.get(f.id);
  const inp = (L.last.inputs || []).find((i) => i[4] === ui.focusId) || (L.last.inputs || []).find((i) => Math.abs(i[0] - ui.focus.x) < 2 && Math.abs(i[1] - ui.focus.y) < 80);
  if (!inp) { removeInput(); ui.focus = null; closeKb(f); return; }
  ui.focusId = inp[4];
  ui.focus.x = inp[0]; ui.focus.y = inp[1];
  placeInput(ui.inputEl, { x: inp[0], y: inp[1], w: inp[2], h: inp[3] });
  if (ui.inputEl.value !== inp[8] && document.activeElement === ui.inputEl && inp[8] === '') ui.inputEl.value = '';
}

function removeInput() {
  if (ui.inputEl) { ui.inputEl.remove(); ui.inputEl = null; }
  ui.focusId = null;
}

function blurInput() {
  if (!ui.focus) return;
  const f = S.frames.find((x) => x.id === ui.focus.frame);
  removeInput();
  ui.focus = null;
  if (f) { live.get(f.id).rt.blur(); renderFrame(f); closeKb(f); }
}

// ---------------- frames ----------------

function mountFrame(f) {
  const rt = new E.Runtime();
  const canvas = h('canvas');
  const dev = DEVICES[f.device];
  const el = h('div', { class: 'frame' },
    h('div', { class: 'label', 'data-id': f.id }),
    h('div', { class: 'ctl' },
      h('button', { title: 'Full screen', onclick: () => fullscreen(f) }, '⤢'),
      h('button', { class: 'x', title: 'Delete frame', onclick: () => deleteFrame(f.id) }, '×')),
    h('div', { class: 'screen' }, canvas));
  world.append(el);
  live.set(f.id, { rt, el, canvas, last: null, err: null });
  positionFrame(f);
  compileFrame(f);
  void dev;
}

function positionFrame(f) {
  const L = live.get(f.id);
  const dev = DEVICES[f.device];
  L.el.style.left = `${f.x}px`;
  L.el.style.top = `${f.y}px`;
  const sc = L.el.querySelector('.screen');
  sc.style.width = `${dev.w}px`;
  sc.style.height = `${dev.h}px`;
  sc.style.borderRadius = `${dev.radius}px`;
  L.el.style.width = `${dev.w}px`;
  const lab = L.el.querySelector('.label');
  const br = f.branch !== 'main' ? `<span class="badge br">${esc(S.branches[f.branch].name)}</span>` : '';
  lab.innerHTML = `${esc(f.name)} ${br}`;
  lab.style.transform = `scale(${1 / S.cam.z})`;
  L.el.classList.toggle('sel', S.sel === f.id);
}

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function selectFrame(id, keepElem) {
  S.sel = id;
  if (!keepElem && ui.elem && ui.elem.frame !== id) ui.elem = null;
  for (const f of S.frames) live.get(f.id).el.classList.toggle('sel', f.id === id);
  renderLeft();
  renderPanel();
  save();
}

function deleteFrame(id) {
  if (S.frames.length <= 1) return toast('Keep at least one frame');
  const i = S.frames.findIndex((f) => f.id === id);
  const [f] = S.frames.splice(i, 1);
  const L = live.get(id);
  L.rt.destroy();
  L.el.remove();
  live.delete(id);
  if (!S.frames.some((x) => x.branch === f.branch) && f.branch !== 'main') delete S.branches[f.branch];
  if (ui.elem && ui.elem.frame === id) ui.elem = null;
  S.sel = S.frames[Math.max(0, i - 1)].id;
  selectFrame(S.sel);
  drawOverlay();
  save();
}

let clipboard = null;
function duplicateFrame(id) {
  const src = S.frames.find((f) => f.id === id);
  const parent = S.branches[src.branch];
  const n = Object.keys(S.branches).length;
  const bid = uid();
  const bname = `${src.name.toLowerCase().replace(/\s+/g, '-')}-v${n + 1}`;
  S.branches[bid] = {
    id: bid, name: bname, files: { ...parent.files }, order: parent.order.slice(), parent: parent.id,
    versions: [{ t: Date.now(), label: `Copied from "${src.name}"`, files: { ...parent.files } }],
  };
  const dev = DEVICES[src.device];
  let x = src.x + dev.w + 80, y = src.y;
  while (S.frames.some((f) => Math.abs(f.x - x) < 200 && Math.abs(f.y - y) < 200)) y += dev.h + 90;
  const f = { ...src, id: uid(), name: `${src.name} variant`, branch: bid, x, y };
  S.frames.push(f);
  mountFrame(f);
  live.get(f.id).rt.cloneStateFrom(live.get(src.id).rt);
  renderFrame(f);
  selectFrame(f.id);
  toast(`Branched the whole codebase → ${bname}`);
  save();
  return f;
}

// ---------------- element selection ----------------

function findElem(hit) {
  const r = hit.L.last;
  if (!r || !r.elems) return null;
  let best = null, ba = Infinity;
  for (const e of r.elems) {
    if (hit.x >= e[0] && hit.x <= e[0] + e[2] && hit.y >= e[1] && hit.y <= e[1] + e[3]) {
      const a = e[2] * e[3];
      if (e[4] === 'Spacer' || e[4] === 'Empty' || a < 1) continue;
      if (a < ba - 0.5 || (Math.abs(a - ba) <= 0.5 && e[13] > best.e[13])) { best = { frame: hit.f.id, e }; ba = a; }
    }
  }
  return best;
}

function pickElem(hit) {
  const el = findElem(hit);
  ui.elem = el;
  ui.hover = null;
  drawOverlay();
  renderPanel();
  if (ui.tab === 'code' && el) jumpToSource(el);
}

function clearElem() {
  if (!ui.elem) return;
  ui.elem = null;
  drawOverlay();
  renderPanel();
}

function elemScreen(frameId, e) {
  const L = live.get(frameId);
  const f = S.frames.find((x) => x.id === frameId);
  const d = DEVICES[f.device];
  const r = L.canvas.getBoundingClientRect();
  const br = board.getBoundingClientRect();
  const k = r.width / d.w;
  return { x: r.left - br.left + e[0] * k, y: r.top - br.top + e[1] * k, w: e[2] * k, h: e[3] * k };
}

function drawOverlay() {
  overlay.innerHTML = '';
  const box = (sel, cls, label, size) => {
    const s = elemScreen(sel.frame, sel.e);
    const d = h('div', { class: `hl ${cls}` });
    Object.assign(d.style, { left: `${s.x}px`, top: `${s.y}px`, width: `${s.w}px`, height: `${s.h}px` });
    if (label) d.append(h('div', { class: 'kn' }, label));
    if (size) d.append(h('div', { class: 'sz' }, `${+sel.e[2].toFixed(2)} × ${+sel.e[3].toFixed(2)}`));
    overlay.append(d);
  };
  if (ui.elem && live.has(ui.elem.frame)) {
    const L = live.get(ui.elem.frame);
    const same = (L.last.elems || []).filter((x) => x[5] === ui.elem.e[5] && x[6] === ui.elem.e[6] && x !== ui.elem.e);
    for (const x of same.slice(0, 40)) box({ frame: ui.elem.frame, e: x }, 'inst');
    box(ui.elem, '', elemName(ui.elem), true);
  }
  if (ui.hover && (!ui.elem || ui.hover.e !== ui.elem.e)) box(ui.hover, 'hover', null, true);
}

function elemName(sel) {
  const e = sel.e;
  if (e[4] === 'Text' && e[12]) return `Text “${e[12].length > 18 ? e[12].slice(0, 18) + '…' : e[12]}”`;
  return e[4];
}

function reselect(frameId, old) {
  const L = live.get(frameId);
  const els = (L.last && L.last.elems) || [];
  let best = null, bd = Infinity;
  const cx = old[0] + old[2] / 2, cy = old[1] + old[3] / 2;
  for (const e of els) {
    if (e[4] !== old[4]) continue;
    const d = Math.hypot(e[0] + e[2] / 2 - cx, e[1] + e[3] / 2 - cy) + Math.abs(e[2] - old[2]) * 0.3;
    if (d < bd) { bd = d; best = e; }
  }
  ui.elem = best ? { frame: frameId, e: best } : null;
  drawOverlay();
}

// ---------------- swift source edits for the inspector ----------------

function chain(sel) {
  const f = S.frames.find((x) => x.id === sel.frame);
  const c = branchSrc(f.branch);
  const s = toChar(c, sel.e[5]), e = toChar(c, sel.e[6]);
  const mods = sel.e[9].map(([ms, me]) => {
    const a = toChar(c, ms), b = toChar(c, me);
    const text = c.src.slice(a, b);
    const m = /^\.\s*(\w+)/.exec(text);
    return { a, b, text, name: m ? m[1] : '?' };
  });
  // contiguous chain directly after the view expression
  let end = e;
  const own = [];
  let progressed = true;
  while (progressed) {
    progressed = false;
    for (const m of mods) {
      if (own.includes(m)) continue;
      if (m.a >= end && /^\s*$/.test(c.src.slice(end, m.a))) { own.push(m); end = m.b; progressed = true; }
    }
  }
  const lineStart = c.src.lastIndexOf('\n', s - 1) + 1;
  const indent = /^\s*/.exec(c.src.slice(lineStart, s))[0];
  return { branch: f.branch, c, s, e, end, own, indent, text: c.src.slice(s, end) };
}

function setModifier(sel, name, code, label) {
  const ch = chain(sel);
  const ex = ch.own.find((m) => m.name === name);
  if (code == null) {
    if (ex) editBranch(ch.branch, [{ a: ex.a - (/\n\s*$/.exec(ch.c.src.slice(0, ex.a)) || [''])[0].length, b: ex.b, text: '' }], label);
    return;
  }
  if (ex) editBranch(ch.branch, [{ a: ex.a, b: ex.b, text: code }], label);
  else {
    const multi = ch.c.src.slice(ch.s, ch.end).includes('\n') || ch.end - ch.s > 30;
    editBranch(ch.branch, [{ a: ch.end, b: ch.end, text: multi ? `\n${ch.indent}    ${code}` : code }], label);
  }
}

function modArgs(sel, name) {
  const ch = chain(sel);
  const m = ch.own.find((x) => x.name === name);
  return m ? m.text : null;
}

const WEIGHTS = { 100: 'ultraLight', 200: 'thin', 300: 'light', 400: 'regular', 500: 'medium', 600: 'semibold', 700: 'bold', 800: 'heavy', 900: 'black' };
const hex6 = (c) => '#' + c.slice(0, 3).map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
const swiftColor = (hex, a = 1) => `Color(hex: 0x${hex.slice(1).toUpperCase()}${a < 1 ? `, opacity: ${+a.toFixed(2)}` : ''})`;

function afterEdit(sel) {
  const old = sel.e;
  reselect(sel.frame, old);
  renderPanel();
}

// ---------------- right panel ----------------

const panel = $('#panel');

function renderPanel() {
  panel.innerHTML = '';
  if (ui.tab === 'code') return renderCode();
  const f = S.frames.find((x) => x.id === S.sel);
  if (!f) { panel.append(h('div', { class: 'empty' }, 'Select a frame')); return; }
  if (ui.elem && ui.elem.frame === f.id) return renderElemPanel(f, ui.elem);
  renderFramePanel(f);
}

function renderFramePanel(f) {
  const L = live.get(f.id);
  const b = S.branches[f.branch];
  const head = h('div', { class: 'sec' },
    h('h4', {}, h('span', {}, 'Frame'), h('small', {}, b.id === 'main' ? 'main' : `branch · ${b.name}`)),
    h('div', { class: 'row' }, h('label', {}, 'Name'), h('div', { class: 'v' }, h('input', { class: 'inp', value: f.name, onchange: (e) => { f.name = e.target.value; positionFrame(f); renderLeft(); save(); } }))),
    h('div', { class: 'row' }, h('label', {}, 'Preview'), h('div', { class: 'v' }, sel((L.previews || []).map((p) => [p, `#Preview("${p}")`]), f.preview, (v) => { f.preview = v; renderFrame(f); save(); }))));
  const dev = DEVICES[f.device];
  const device = h('div', { class: 'sec' },
    h('h4', {}, 'Device'),
    h('div', { class: 'row' }, h('label', {}, 'Phone'), h('div', { class: 'v' }, sel(Object.entries(DEVICES).map(([k, d]) => [k, `${d.name}  ${d.w}×${d.h}`]), f.device, (v) => { f.device = v; positionFrame(f); renderFrame(f); save(); }))),
    h('div', { class: 'row' }, h('label', {}, 'Appearance'), h('div', { class: 'v' }, sel([['light', 'Light'], ['dark', 'Dark']], f.dark ? 'dark' : 'light', (v) => { f.dark = v === 'dark'; renderFrame(f); save(); }))),
    h('div', { class: 'row' }, h('label', {}, 'Frame'), h('div', { class: 'v pair' }, h('div', { class: 'cell' }, h('span', {}, 'W'), h('input', { class: 'inp', value: dev.w, disabled: true })), h('div', { class: 'cell' }, h('span', {}, 'H'), h('input', { class: 'inp', value: dev.h, disabled: true })))),
    h('div', { class: 'row' },
      h('button', { class: 'btn blue', onclick: () => duplicateFrame(f.id) }, '⧉ Duplicate as variant'),
      h('button', { class: 'btn', onclick: () => { L.rt.reset(); renderFrame(f); } }, '↺ Reset app')));
  const vers = h('div', { class: 'sec' }, h('h4', {}, h('span', {}, 'Code'), h('small', {}, `${b.order.length} Swift files`)), h('div', { class: 'muted', style: 'margin-bottom:6px' }, 'Versions'));
  const vs = b.versions.slice().reverse();
  vs.forEach((v, i) => {
    vers.append(h('div', { class: `ver ${i === 0 ? 'cur' : ''}`, title: i ? 'Restore this version' : 'Current', onclick: () => { if (i) restore(b, v); } },
      h('div', { class: 'dot' }, i === 0 ? 'N' : ''),
      h('div', {}, h('div', { class: 't' }, v.label), h('div', { class: 's' }, ago(v.t)))));
  });
  if (b.parent) vers.append(h('div', { class: 'muted', style: 'margin-top:6px' }, `Forked from ${S.branches[b.parent] ? S.branches[b.parent].name : 'a deleted branch'}`));
  panel.append(head, device, vers);
  if (L.err) panel.append(errBox(f, L.err));
}

function errBox(f, err) {
  const loc = err.pos != null ? locate(f.branch, err.pos) : null;
  return h('div', { class: 'err', onclick: () => { if (loc) { ui.tab = 'code'; ui.file = loc.file; setTab('code'); gotoLine(loc.line); } } },
    `${loc ? `${loc.file}:${loc.line}:${loc.col}\n` : ''}${err.msg}`);
}

function restore(b, v) {
  b.files = { ...v.files };
  branchChanged(b.id, `Restored version from ${ago(v.t)}`);
  renderPanel();
  toast('Version restored');
}

function sel(opts, val, on) {
  const s = h('select', { class: 'inp', onchange: (e) => on(e.target.value) });
  for (const [v, t] of opts) s.append(h('option', { value: v, selected: v === val }, t));
  return s;
}

function num(v, on, step = 1) {
  return h('input', { class: 'inp', type: 'number', step, value: v, onchange: (e) => on(parseFloat(e.target.value)) });
}

function renderElemPanel(f, selE) {
  const e = selE.e;
  const ch = chain(selE);
  const loc = locate(f.branch, e[5]);
  const L = live.get(f.id);
  const count = (L.last.elems || []).filter((x) => x[5] === e[5] && x[6] === e[6]).length;
  const head = h('div', { class: 'sec' },
    h('h4', {}, h('span', { class: 'kind' }, elemName(selE), ' ', h('i', {}, e[4])), h('small', {}, count > 1 ? `${count} instances` : '')),
    h('div', { class: 'code-ref', title: 'Open in code', onclick: () => { setTab('code'); jumpToSource(selE); } }, `${loc.file}:${loc.line}\n${ch.text.length > 220 ? ch.text.slice(0, 220) + '…' : ch.text}`));
  panel.append(head);
  if (count > 1) panel.append(h('div', { class: 'sec muted' }, 'This view comes from one line of Swift rendered in a loop: style edits apply to every instance.'));

  if (e[4] === 'Text') {
    const lit = e[7] >= 0;
    const s = h('div', { class: 'sec' }, h('h4', {}, 'Content'));
    if (lit) {
      const c = branchSrc(f.branch);
      const a = toChar(c, e[7]), b = toChar(c, e[8]);
      const ta = h('textarea', { class: 'inp' });
      ta.value = c.src.slice(a, b).replace(/\\n/g, '\n').replace(/\\"/g, '"');
      ta.addEventListener('input', () => {
        const c2 = branchSrc(f.branch);
        const cur = ui.elem.e;
        const a2 = toChar(c2, cur[7]), b2 = toChar(c2, cur[8]);
        editBranch(f.branch, [{ a: a2, b: b2, text: ta.value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') }], 'Edited text');
        reselect(f.id, cur);
      });
      s.append(ta);
    } else {
      s.append(h('div', { class: 'muted' }, 'Bound to data in code: ', h('code', {}, ch.text.slice(0, ch.e - ch.s).replace(/^Text\(|\)$/g, ''))));
    }
    panel.append(s);
  }
  if (e[10]) {
    const [size, weight] = e[10];
    const setFont = (sz, w) => { setModifier(ui.elem, 'font', `.font(.system(size: ${+sz.toFixed(1)}, weight: .${WEIGHTS[w] || 'regular'}))`, 'Changed font'); afterEdit(ui.elem); };
    panel.append(h('div', { class: 'sec' }, h('h4', {}, 'Typography'),
      h('div', { class: 'row' }, h('label', {}, 'Font'), h('div', { class: 'v' }, h('input', { class: 'inp', value: e[10][2] === 1 ? 'SF Pro Rounded' : e[10][2] === 2 ? 'SF Mono' : 'SF Pro', disabled: true }))),
      h('div', { class: 'row' }, h('label', {}, 'Weight'), h('div', { class: 'v' }, sel(Object.entries(WEIGHTS).map(([k, v]) => [k, v[0].toUpperCase() + v.slice(1)]), String(weight), (v) => setFont(size, +v)))),
      h('div', { class: 'row' }, h('label', {}, 'Size'), h('div', { class: 'v' }, num(size, (v) => setFont(v, weight))))));
  }
  if (e[11] && e[4] !== 'Shape') {
    const c = e[11];
    panel.append(h('div', { class: 'sec' }, h('h4', {}, 'Colour'), colorRow(hex6(c), c[3], (hx, a) => { setModifier(ui.elem, 'foregroundStyle', `.foregroundStyle(${swiftColor(hx, a)})`, 'Changed colour'); afterEdit(ui.elem); })));
  }
  if (e[4] === 'Shape' && e[11]) {
    const c = e[11];
    panel.append(h('div', { class: 'sec' }, h('h4', {}, 'Fill'), colorRow(hex6(c), c[3], (hx, a) => {
      const ch2 = chain(ui.elem);
      const fillM = ch2.own.find((m) => m.name === 'fill');
      if (fillM) editBranch(ch2.branch, [{ a: fillM.a, b: fillM.b, text: `.fill(${swiftColor(hx, a)})` }], 'Changed fill');
      else setModifier(ui.elem, 'fill', `.fill(${swiftColor(hx, a)})`, 'Changed fill');
      afterEdit(ui.elem);
    })));
  }
  // background
  const bgText = modArgs(selE, 'background');
  const bgHex = bgText && /0x([0-9A-Fa-f]{6})/.exec(bgText);
  const radius = (/cornerRadius:\s*([\d.]+)/.exec(ch.text) || [])[1];
  panel.append(h('div', { class: 'sec' }, h('h4', {}, h('span', {}, 'Fill'), h('small', {}, bgText ? '' : 'none')),
    colorRow(bgHex ? `#${bgHex[1]}` : '#ffffff', 1, (hx, a) => {
      const r = (/cornerRadius:\s*([\d.]+)/.exec(chain(ui.elem).text) || [])[1];
      const shape = r ? `, in: RoundedRectangle(cornerRadius: ${r})` : (bgText && /Capsule|Circle/.exec(bgText) ? `, in: ${/Capsule/.test(bgText) ? 'Capsule()' : 'Circle()'}` : '');
      setModifier(ui.elem, 'background', `.background(${swiftColor(hx, a)}${shape})`, 'Changed background');
      afterEdit(ui.elem);
    }, !bgText)));
  // padding + radius + opacity
  const padText = modArgs(selE, 'padding');
  const padV = padText ? (/(\d+(?:\.\d+)?)\s*\)\s*$/.exec(padText) || [, padText === '.padding()' ? 16 : 0])[1] : 0;
  const opText = modArgs(selE, 'opacity');
  panel.append(h('div', { class: 'sec' }, h('h4', {}, 'Layout'),
    h('div', { class: 'row' }, h('label', {}, 'Padding'), h('div', { class: 'v' }, num(+padV, (v) => { setModifier(ui.elem, 'padding', v ? `.padding(${v})` : null, 'Changed padding'); afterEdit(ui.elem); }))),
    h('div', { class: 'row' }, h('label', {}, 'Radius'), h('div', { class: 'v' }, num(+(radius || 0), (v) => {
      const ch2 = chain(ui.elem);
      const m = /cornerRadius:\s*([\d.]+)/.exec(ch2.text);
      if (m) {
        const at = ch2.s + ch2.text.indexOf(m[0]);
        editBranch(ch2.branch, [{ a: at, b: at + m[0].length, text: `cornerRadius: ${v}` }], 'Changed radius');
      } else setModifier(ui.elem, 'clipShape', `.clipShape(RoundedRectangle(cornerRadius: ${v}))`, 'Changed radius');
      afterEdit(ui.elem);
    }))),
    h('div', { class: 'row' }, h('label', {}, 'Opacity'), h('div', { class: 'v' }, num(opText ? +(/([\d.]+)\)/.exec(opText) || [, 1])[1] : 1, (v) => { setModifier(ui.elem, 'opacity', v >= 1 ? null : `.opacity(${v})`, 'Changed opacity'); afterEdit(ui.elem); }, 0.05))),
    h('div', { class: 'row' }, h('label', {}, 'Size'), h('div', { class: 'v pair' },
      h('div', { class: 'cell' }, h('span', {}, 'W'), h('input', { class: 'inp', value: +e[2].toFixed(2), onchange: (ev) => setFrame(ev.target.value, null) })),
      h('div', { class: 'cell' }, h('span', {}, 'H'), h('input', { class: 'inp', value: +e[3].toFixed(2), onchange: (ev) => setFrame(null, ev.target.value) }))))));
  if (L.err) panel.append(errBox(f, L.err));
}

function setFrame(w, hh) {
  const sel = ui.elem;
  const cur = modArgs(sel, 'frame') || '';
  const gw = w != null ? w : (/width:\s*([\d.]+)/.exec(cur) || [])[1];
  const gh = hh != null ? hh : (/height:\s*([\d.]+)/.exec(cur) || [])[1];
  const parts = [];
  if (gw) parts.push(`width: ${+gw}`);
  if (gh) parts.push(`height: ${+gh}`);
  setModifier(sel, 'frame', parts.length ? `.frame(${parts.join(', ')})` : null, 'Changed size');
  afterEdit(sel);
}

function colorRow(hex, alpha, on, none) {
  const ci = h('input', { type: 'color', value: hex });
  const ti = h('input', { class: 'inp', value: none ? '' : hex.toUpperCase().slice(1), placeholder: 'none' });
  const ai = h('input', { class: 'inp', style: 'width:64px', value: `${Math.round(alpha * 100)}%` });
  const fire = () => on(ci.value, Math.min(1, Math.max(0, parseFloat(ai.value) / 100 || 1)));
  ci.addEventListener('input', () => { ti.value = ci.value.slice(1).toUpperCase(); });
  ci.addEventListener('change', fire);
  ti.addEventListener('change', () => { if (/^[0-9a-f]{6}$/i.test(ti.value)) { ci.value = `#${ti.value}`; fire(); } });
  ai.addEventListener('change', fire);
  return h('div', { class: 'colorrow' }, ci, ti, ai);
}

// ---------------- code tab ----------------

const KW = new Set('struct class enum extension protocol func var let if else guard return for in while switch case default import some private fileprivate public static self Self init true false nil where break continue mutating any inout throws async await try do catch defer typealias'.split(' '));

function highlight(src) {
  const re = /(\/\/[^\n]*)|("(?:[^"\\\n]|\\.)*")|(@\w+)|(\b\d+(?:\.\d+)?\b|\b0x[0-9A-Fa-f]+\b)|(\.[a-z]\w*)|(\b[A-Z]\w*)|(\b\w+\b)/g;
  let out = '', last = 0, m;
  while ((m = re.exec(src))) {
    out += esc(src.slice(last, m.index));
    const t = esc(m[0]);
    if (m[1]) out += `<span class="c">${t}</span>`;
    else if (m[2]) out += `<span class="s">${t}</span>`;
    else if (m[3]) out += `<span class="a">${t}</span>`;
    else if (m[4]) out += `<span class="n">${t}</span>`;
    else if (m[5]) out += `<span class="m">${t}</span>`;
    else if (m[6]) out += `<span class="t">${t}</span>`;
    else if (m[7] && KW.has(m[0])) out += `<span class="k">${t}</span>`;
    else out += t;
    last = m.index + m[0].length;
  }
  return out + esc(src.slice(last)) + '\n';
}

let codeEls = null;
function renderCode() {
  const f = S.frames.find((x) => x.id === S.sel);
  const b = S.branches[f.branch];
  if (!b.files[ui.file]) ui.file = b.order[0];
  const files = h('div', { class: 'files' }, ...b.order.map((fn) => h('button', { class: fn === ui.file ? 'on' : '', onclick: () => { ui.file = fn; renderPanel(); } }, fn)));
  const pre = h('pre');
  const ta = h('textarea', { spellcheck: 'false', autocapitalize: 'off', autocomplete: 'off' });
  const gut = h('div', { class: 'gut' });
  const ed = h('div', { class: 'editor' }, gut, pre, ta);
  const bar = h('div', { class: 'codebar' });
  ta.value = b.files[ui.file];
  const paintCode = () => {
    pre.innerHTML = highlight(ta.value);
    const n = ta.value.split('\n').length;
    let g = '';
    for (let i = 1; i <= n; i++) g += `<div data-l="${i}">${i}</div>`;
    gut.innerHTML = g;
    syncScroll();
  };
  const syncScroll = () => { pre.scrollTop = ta.scrollTop; pre.scrollLeft = ta.scrollLeft; gut.style.transform = `translateY(${-ta.scrollTop}px)`; };
  ta.addEventListener('scroll', syncScroll);
  ta.addEventListener('keydown', (e) => {
    e.stopPropagation();
    if (e.key === 'Tab') { e.preventDefault(); const s = ta.selectionStart; ta.setRangeText('    ', s, ta.selectionEnd, 'end'); ta.dispatchEvent(new Event('input')); }
  });
  let t;
  ta.addEventListener('input', () => {
    paintCode();
    clearTimeout(t);
    t = setTimeout(() => {
      b.files[ui.file] = ta.value;
      const t0 = performance.now();
      branchChanged(b.id, `Edited ${ui.file}`);
      bar.dataset.ms = (performance.now() - t0).toFixed(1);
      refreshCodeStatus();
    }, 90);
  });
  paintCode();
  codeEls = { ta, pre, gut, bar, branch: b.id };
  const dl = h('button', { class: 'ghost', onclick: () => downloadSwift(b) }, 'Download .swift');
  panel.append(files, ed, bar, h('div', { class: 'codebar' }, h('span', { class: 'muted' }, `Branch: ${b.name}`), h('span', { style: 'flex:1' }), dl));
  refreshCodeStatus();
}

function refreshCodeStatus() {
  if (!codeEls) return;
  const f = S.frames.find((x) => x.id === S.sel);
  const L = live.get(f.id);
  const err = L.err;
  codeEls.bar.innerHTML = '';
  codeEls.gut.querySelectorAll('.bad').forEach((x) => x.classList.remove('bad'));
  if (err) {
    const loc = err.pos != null ? locate(f.branch, err.pos) : null;
    codeEls.bar.append(h('span', { class: 'bad' }, '●'), h('span', { style: 'cursor:pointer', onclick: () => { if (loc) { ui.file = loc.file; renderPanel(); gotoLine(loc.line); } } }, `${loc ? `${loc.file}:${loc.line}  ` : ''}${err.msg}`));
    if (loc && loc.file === ui.file) { const g = codeEls.gut.querySelector(`[data-l="${loc.line}"]`); if (g) g.classList.add('bad'); }
  } else {
    const ms = codeEls.bar.dataset.ms;
    codeEls.bar.append(h('span', { class: 'ok' }, '●'), h('span', {}, `Compiled & rendered ${ms ? `in ${ms} ms` : ''} · ${S.frames.filter((x) => x.branch === f.branch).length} frame(s) on this branch`));
  }
}

function gotoLine(line) {
  if (!codeEls) return;
  const lines = codeEls.ta.value.split('\n');
  let idx = 0;
  for (let i = 0; i < line - 1 && i < lines.length; i++) idx += lines[i].length + 1;
  codeEls.ta.focus();
  codeEls.ta.setSelectionRange(idx, idx + (lines[line - 1] || '').length);
  codeEls.ta.scrollTop = Math.max(0, (line - 6) * 18);
}

function jumpToSource(sel) {
  const f = S.frames.find((x) => x.id === sel.frame);
  const loc = locate(f.branch, sel.e[5]);
  ui.file = loc.file;
  renderPanel();
  gotoLine(loc.line);
}

function downloadSwift(b) {
  const blob = new Blob(b.order.map((f) => `// ===== ${f} =====\n${b.files[f]}\n`), { type: 'text/plain' });
  const a = h('a', { href: URL.createObjectURL(blob), download: `${b.name}-swiftui.swift` });
  a.click();
}

function setTab(t) {
  ui.tab = t;
  $('#app').classList.toggle('code', t === 'code');
  setTimeout(drawOverlay, 50);
  document.querySelectorAll('.rtabs [data-tab]').forEach((b) => b.classList.toggle('on', b.dataset.tab === t));
  codeEls = null;
  renderPanel();
}
document.querySelectorAll('.rtabs [data-tab]').forEach((b) => b.addEventListener('click', () => setTab(b.dataset.tab)));

// ---------------- left panel ----------------

function renderLeft() {
  const fl = $('#frameList');
  fl.innerHTML = '';
  for (const f of S.frames) {
    const b = S.branches[f.branch];
    fl.append(h('div', { class: `fl-item ${f.id === S.sel ? 'on' : ''}`, onclick: () => { selectFrame(f.id); fit([f]); } },
      h('div', { class: 'ph' }), h('div', { class: 'nm' }, f.name), h('span', { class: `badge ${b.id === 'main' ? '' : 'br'}` }, b.name)));
  }
  const main = S.branches.main;
  const loc = main ? main.order.reduce((n, f) => n + main.files[f].split('\n').length, 0) : 0;
  $('#projSub').textContent = `SwiftUI · ${loc.toLocaleString()} lines · ${Object.keys(S.branches).length} branch${Object.keys(S.branches).length > 1 ? 'es' : ''}`;
}

// ---------------- import any SwiftUI project ----------------

async function importProject(files, label) {
  // files: { 'Name.swift': text }
  const names = Object.keys(files).filter((n) => n.endsWith('.swift')).sort();
  if (!names.length) return toast('No .swift files found');
  const bid = uid();
  const slug = (label || names[0].replace(/\.swift$/, '')).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'project';
  S.branches[bid] = { id: bid, name: slug, files: {}, order: names, versions: [] };
  for (const n of names) S.branches[bid].files[n] = files[n];
  S.branches[bid].versions.push({ t: Date.now(), label: `Imported ${names.length} Swift file${names.length > 1 ? 's' : ''}`, files: { ...S.branches[bid].files } });
  const rt = new E.Runtime();
  const r = rt.setSource(branchSrc(bid).src);
  rt.destroy();
  const previews = r.ok && r.previews.length ? r.previews : [''];
  const y0 = Math.max(...S.frames.map((f) => f.y + DEVICES[f.device].h)) + 160;
  const made = previews.map((p, i) => ({ id: uid(), name: p && p !== 'Preview' ? p : (label || 'App'), preview: p, branch: bid, x: i * 482, y: y0, device: 'iphone17pro', dark: false }));
  for (const f of made) { S.frames.push(f); mountFrame(f); renderFrame(f); }
  selectFrame(made[0].id);
  fit(made);
  ui.file = names[0];
  save();
  toast(r.ok ? `Imported ${names.length} file(s) · ${made.length} frame(s)` : `Imported, but it doesn't compile yet: ${r.error.msg}`);
}

async function readEntries(entry, out, path = '', wasm = []) {
  if (entry.isFile) {
    if (entry.name.endsWith('.wasm')) wasm.push(await new Promise((res) => entry.file(res)));
    else if (entry.name.endsWith('.swift')) { const f = await new Promise((res) => entry.file(res)); out[f.name in out ? `${path}${f.name}` : f.name] = await f.text(); }
  } else if (entry.isDirectory && !/^(\.|Pods$|build$|DerivedData$)/.test(entry.name)) {
    const rd = entry.createReader();
    let batch;
    do { batch = await new Promise((res) => rd.readEntries(res)); for (const e of batch) await readEntries(e, out, `${path}${entry.name}/`, wasm); } while (batch.length);
  }
}

async function filesFromInput(list) {
  const out = {};
  for (const f of list) if (f.name.endsWith('.wasm')) importNative(f);
  for (const f of list) if (f.name.endsWith('.swift')) out[f.name in out ? f.webkitRelativePath || f.name : f.name] = await f.text();
  const root = (list[0] && list[0].webkitRelativePath || '').split('/')[0];
  return [out, root || null];
}

const pickFiles = h('input', { type: 'file', multiple: true, accept: '.swift,.wasm', hidden: true, onchange: async (e) => { const [fs, root] = await filesFromInput(e.target.files); if (Object.keys(fs).length) importProject(fs, root); e.target.value = ''; } });
const pickDir = h('input', { type: 'file', webkitdirectory: true, hidden: true, onchange: async (e) => { const [fs, root] = await filesFromInput(e.target.files); if (Object.keys(fs).length) importProject(fs, root); e.target.value = ''; } });
document.body.append(pickFiles, pickDir);
$('#impFiles').onclick = () => pickFiles.click();
$('#impDir').onclick = () => pickDir.click();
$('#newApp').onclick = async () => importProject({ 'ContentView.swift': await (await fetch(asset('starter.swift'))).text() }, 'Playground');
board.addEventListener('dragover', (e) => { e.preventDefault(); board.classList.add('drop'); });
board.addEventListener('dragleave', () => board.classList.remove('drop'));
board.addEventListener('drop', async (e) => {
  e.preventDefault();
  board.classList.remove('drop');
  const out = {}, wasm = [];
  for (const it of e.dataTransfer.items) { const en = it.webkitGetAsEntry && it.webkitGetAsEntry(); if (en) await readEntries(en, out, '', wasm); }
  for (const f of wasm) importNative(f);
  if (Object.keys(out).length || !wasm.length) importProject(out, null);
});

// ---------------- compiled UIKit apps (.wasm) ----------------
// A UIKit app compiled by the Swift compiler against platform/ runs in its own frame. These frames are live but not
// editable or saved (the binary is too big for local storage), so they stay outside S.frames.

const natives = [];

async function importNative(file, label) {
  const dev = DEVICES.iphone17pro;
  const bottom = Math.max(...S.frames.map((f) => f.y + DEVICES[f.device].h), ...natives.map((n) => n.y + dev.h));
  const n = { x: 0, y: bottom + 160, device: 'iphone17pro' };
  natives.push(n);
  const name = label || file.name.replace(/\.wasm$/, '');
  const canvas = h('canvas');
  const status = h('div', { class: 'nload' }, `Loading ${name}… (${(file.size / 1e6).toFixed(0)} MB)`);
  const el = h('div', { class: 'frame native' },
    h('div', { class: 'nlabel' }, `${name} `, h('span', { class: 'badge' }, 'compiled UIKit')),
    h('div', { class: 'ctl' }, h('button', { class: 'x', title: 'Remove frame', onclick: () => { el.remove(); natives.splice(natives.indexOf(n), 1); } }, '×')),
    h('div', { class: 'screen' }, canvas, status));
  el.style.left = `${n.x}px`; el.style.top = `${n.y}px`; el.style.width = `${dev.w}px`;
  const sc = el.querySelector('.screen');
  sc.style.width = `${dev.w}px`; sc.style.height = `${dev.h}px`; sc.style.borderRadius = `${dev.radius}px`;
  world.append(el);
  fit([n]);
  try {
    const url = URL.createObjectURL(new Blob([file], { type: 'application/wasm' }));
    await startUIKitApp(canvas, {
      wasm: url, width: dev.w, height: dev.h,
      chrome: (g) => paintChrome(g, dev, false),
      onLog: (line) => console.log(`[${name}]`, line),
    });
    status.remove();
    toast(`${name} is running`);
  } catch (e) {
    status.textContent = `Could not start ${name}: ${e.message || e}`;
  }
}

// ---------------- preloaded examples ----------------

async function renderExamples() {
  let list = [];
  try { list = await (await fetch(asset('examples/examples.json'))).json(); } catch { return; }
  const box = $('#examples');
  for (const ex of list) {
    box.append(h('button', { title: ex.desc, onclick: async () => {
      const files = {};
      await Promise.all(ex.files.map(async (f) => { files[f] = await (await fetch(asset(`examples/${ex.dir}/${f}`))).text(); }));
      importProject(files, ex.name);
    } }, h('b', {}, ex.name), h('span', {}, ex.tag)));
  }
}

// ---------------- misc ----------------

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toast.t);
  toast.t = setTimeout(() => t.classList.remove('show'), 2200);
}

function setMode(m) {
  ui.mode = m;
  $('#tSelect').classList.toggle('on', m === 'select');
  document.body.classList.toggle('mode-select', m === 'select');
  if (m !== 'select') { ui.hover = null; drawOverlay(); }
}

$('#tSelect').onclick = () => setMode(ui.mode === 'select' ? 'interact' : 'select');
$('#tFit').onclick = () => fit();
$('#tIn').onclick = () => { const r = board.getBoundingClientRect(); zoomAt(r.width / 2, r.height / 2, 1.25); };
$('#tOut').onclick = () => { const r = board.getBoundingClientRect(); zoomAt(r.width / 2, r.height / 2, 0.8); };
$('#tFull').onclick = () => { const f = S.frames.find((x) => x.id === S.sel); if (f) fullscreen(f); };
$('#resetAll').onclick = async () => { if (confirm('Reset the board to the original sample? Your branches will be removed.')) { localStorage.removeItem(STORE); location.reload(); } };
$('#share').onclick = async () => {
  try { await navigator.clipboard.writeText(location.href); toast('Link copied'); } catch { toast(location.href); }
};

let fsState = null;
function fullscreen(f) {
  const L = live.get(f.id);
  const sc = L.el.querySelector('.screen');
  const d = DEVICES[f.device];
  const k = Math.min((innerHeight - 60) / d.h, (innerWidth - 60) / d.w);
  $('#fs').hidden = false;
  const inner = $('#fsInner');
  inner.style.width = `${d.w * k}px`;
  inner.style.height = `${d.h * k}px`;
  sc.style.transform = `scale(${k})`;
  sc.style.transformOrigin = '0 0';
  inner.append(sc);
  fsState = { f, sc, L };
  const onDown = (e) => {
    const r = L.canvas.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width) * d.w, y = ((e.clientY - r.top) / r.height) * d.h;
    fsState.down = { x, y, cy: e.clientY, cx: e.clientX, moved: false, ly: e.clientY, lx: e.clientX };
  };
  const onMove = (e) => {
    const dn = fsState && fsState.down;
    if (!dn) return;
    if (Math.abs(e.clientY - dn.cy) + Math.abs(e.clientX - dn.cx) > 5) dn.moved = true;
    if (dn.moved) { if (L.rt.scroll(dn.x, dn.y, (dn.lx - e.clientX) / k, (dn.ly - e.clientY) / k)) renderFrame(f); dn.ly = e.clientY; dn.lx = e.clientX; }
  };
  const onUp = () => {
    const dn = fsState && fsState.down;
    if (dn && !dn.moved) tapApp({ f, L, x: dn.x, y: dn.y });
    if (fsState) fsState.down = null;
  };
  const onWheel = (e) => { e.preventDefault(); const r = L.canvas.getBoundingClientRect(); if (L.rt.scroll(((e.clientX - r.left) / r.width) * d.w, ((e.clientY - r.top) / r.height) * d.h, e.deltaX / k, e.deltaY / k)) renderFrame(f); };
  sc.addEventListener('pointerdown', onDown);
  addEventListener('pointermove', onMove);
  addEventListener('pointerup', onUp);
  sc.addEventListener('wheel', onWheel, { passive: false });
  fsState.cleanup = () => { sc.removeEventListener('pointerdown', onDown); removeEventListener('pointermove', onMove); removeEventListener('pointerup', onUp); sc.removeEventListener('wheel', onWheel); };
  renderFrame(f);
}
$('#fsClose').onclick = () => {
  if (!fsState) return;
  fsState.cleanup();
  fsState.sc.style.transform = '';
  fsState.L.el.append(fsState.sc);
  $('#fs').hidden = true;
  const f = fsState.f;
  fsState = null;
  renderFrame(f);
};

addEventListener('keydown', (e) => {
  if (e.target.matches('input, textarea, select')) return;
  const mod = e.metaKey || e.ctrlKey;
  if (mod && e.key === 'c' && S.sel) { clipboard = S.sel; toast('Frame copied · paste to branch the codebase'); e.preventDefault(); }
  else if (mod && e.key === 'v' && clipboard) { duplicateFrame(clipboard); e.preventDefault(); }
  else if (mod && e.key === 'd' && S.sel) { duplicateFrame(S.sel); e.preventDefault(); }
  else if ((e.key === 'Backspace' || e.key === 'Delete') && S.sel && !ui.elem) deleteFrame(S.sel);
  else if (e.key === 'v' && !mod) setMode(ui.mode === 'select' ? 'interact' : 'select');
  else if (e.key === 'Escape') { if (!$('#fs').hidden) $('#fsClose').click(); else if (ui.elem) clearElem(); else setMode('interact'); }
  else if (e.key === '1' && e.shiftKey) fit();
});
addEventListener('resize', () => drawOverlay());

// ---------------- boot ----------------

async function boot() {
  const fontsReady = Promise.all(['400', '500', '600', '700'].map((w) => document.fonts.load(`${w} 17px Inter`))).catch(() => {});
  const [eng] = await Promise.all([loadEngine(asset('swiftboard.wasm?v=__V__')), loadImage('chat-pattern', asset('assets/chat-pattern.png')), fontsReady]);
  E = eng;
  let saved = null;
  try { saved = JSON.parse(localStorage.getItem(STORE)); } catch {}
  S = saved && saved.frames && saved.frames.length ? saved : await defaultState();
  const needFit = !S.cam;
  if (!S.cam) S.cam = { x: 0, y: 0, z: 0.5 };
  for (const f of S.frames) mountFrame(f);
  renderLeft();
  if (needFit) fit(); else applyCam();
  S.frames.forEach(renderFrame);
  selectFrame(S.sel || S.frames[0].id);
  renderExamples();
  const logo = document.querySelector('.built img'); if (logo) logo.src = asset('assets/spiritt-logo.svg');
  window.__sb = { importProject, S, live, renderFrame, duplicateFrame, editBranch, branchSrc, ui, fit, setMode, pickElem, findElem, frameAt, tapApp, setTab };
}
boot().catch((e) => {
  console.error(e);
  $('#projSub').textContent = 'failed to start';
  board.append(h('div', { class: 'bootErr' }, h('b', {}, 'Swiftboard could not start'), h('div', {}, String(e && e.message || e)), h('button', { class: 'btn', onclick: () => location.reload() }, 'Reload')));
});
