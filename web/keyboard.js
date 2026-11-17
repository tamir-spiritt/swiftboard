// iOS-style software keyboard drawn into the device canvas.
// The app sees it like a real one: the safe area shrinks by its height, so views move up.

export const KB_HEIGHT = 292; // keys area, above the home indicator inset

const ROWS = {
  abc: [['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'], ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'], ['z', 'x', 'c', 'v', 'b', 'n', 'm']],
  num: [['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'], ['-', '/', ':', ';', '(', ')', '$', '&', '@', '"'], ['.', ',', '?', '!', "'"]],
  sym: [['[', ']', '{', '}', '#', '%', '^', '*', '+', '='], ['_', '\\', '|', '~', '<', '>', '€', '£', '¥', '•'], ['.', ',', '?', '!', "'"]],
};

export function totalHeight(dev) {
  return KB_HEIGHT + Math.max(dev.bottom, 0) + 8;
}

// layout in device points; y0 = top of the keyboard
export function layout(dev, st, y0) {
  const W = dev.w;
  const gap = 6, side = 3, kh = 44, rowGap = 11.5, top = y0 + 9;
  const keys = [];
  const rows = ROWS[st.mode];
  const kw = (W - side * 2 - gap * 9) / 10;
  rows.forEach((row, ri) => {
    const y = top + ri * (kh + rowGap);
    if (ri < 2) {
      const n = row.length;
      const rowW = n * kw + (n - 1) * gap;
      let x = (W - rowW) / 2;
      for (const k of row) { keys.push({ x, y, w: kw, h: kh, label: k, kind: 'char' }); x += kw + gap; }
    } else {
      const wide = kw * 1.32;
      keys.push({ x: side, y, w: wide, h: kh, label: st.mode === 'abc' ? 'shift' : st.mode === 'num' ? '#+=' : '123', kind: st.mode === 'abc' ? 'shift' : 'page', to: st.mode === 'num' ? 'sym' : 'num' });
      const n = row.length;
      const inner = W - (side + wide + gap) * 2;
      const cw = st.mode === 'abc' ? kw : (inner - gap * (n - 1)) / n;
      const rowW = n * cw + (n - 1) * gap;
      let x = (W - rowW) / 2;
      for (const k of row) { keys.push({ x, y, w: cw, h: kh, label: k, kind: 'char' }); x += cw + gap; }
      keys.push({ x: W - side - wide, y, w: wide, h: kh, label: 'delete', kind: 'del' });
    }
  });
  const y = top + 3 * (kh + rowGap);
  const mw = kw * 1.32;
  keys.push({ x: side, y, w: mw, h: kh, label: st.mode === 'abc' ? '123' : 'ABC', kind: 'page', to: st.mode === 'abc' ? 'num' : 'abc' });
  keys.push({ x: side + mw + gap, y, w: mw * 0.78, h: kh, label: 'emoji', kind: 'emoji' });
  const rw = mw * 1.45;
  const sx = side + mw + gap + mw * 0.78 + gap;
  keys.push({ x: sx, y, w: W - side - rw - gap - sx, h: kh, label: 'space', kind: 'space' });
  keys.push({ x: W - side - rw, y, w: rw, h: kh, label: st.returnLabel || 'return', kind: 'return' });
  return keys;
}

function rr(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); }

function glyph(ctx, k, st, dark, fg) {
  const cx = k.x + k.w / 2, cy = k.y + k.h / 2;
  ctx.strokeStyle = fg; ctx.fillStyle = fg; ctx.lineWidth = 1.8; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  if (k.kind === 'shift') {
    ctx.beginPath();
    ctx.moveTo(cx, cy - 9); ctx.lineTo(cx + 9, cy + 1); ctx.lineTo(cx + 4.5, cy + 1); ctx.lineTo(cx + 4.5, cy + 8);
    ctx.lineTo(cx - 4.5, cy + 8); ctx.lineTo(cx - 4.5, cy + 1); ctx.lineTo(cx - 9, cy + 1); ctx.closePath();
    if (st.shift) ctx.fill(); else ctx.stroke();
    if (st.caps) { ctx.fillRect(cx - 4.5, cy + 10, 9, 1.8); }
  } else if (k.kind === 'del') {
    ctx.beginPath();
    ctx.moveTo(cx - 12, cy); ctx.lineTo(cx - 5, cy - 8); ctx.lineTo(cx + 11, cy - 8); ctx.lineTo(cx + 11, cy + 8); ctx.lineTo(cx - 5, cy + 8); ctx.closePath();
    ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx - 1, cy - 3.5); ctx.lineTo(cx + 6, cy + 3.5); ctx.moveTo(cx + 6, cy - 3.5); ctx.lineTo(cx - 1, cy + 3.5); ctx.stroke();
  } else if (k.kind === 'emoji') {
    ctx.beginPath(); ctx.arc(cx, cy, 10, 0, Math.PI * 2); ctx.stroke();
    ctx.beginPath(); ctx.arc(cx, cy + 1, 5.5, 0.15 * Math.PI, 0.85 * Math.PI); ctx.stroke();
    ctx.fillRect(cx - 4, cy - 4, 2, 2.6); ctx.fillRect(cx + 2, cy - 4, 2, 2.6);
  } else {
    let t = k.label;
    if (k.kind === 'char' && st.mode === 'abc' && (st.shift || st.caps)) t = t.toUpperCase();
    const big = k.kind === 'char';
    ctx.font = big ? `400 ${st.mode === 'abc' ? 25 : 23}px -apple-system, "SF Pro Text", Inter, system-ui, sans-serif` : '400 16px -apple-system, "SF Pro Text", Inter, system-ui, sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(t, cx, cy + (big && st.mode === 'abc' && !(st.shift || st.caps) ? -1.5 : 0));
    ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';
  }
}

export function draw(ctx, dev, st, y0, dark) {
  const H = dev.h - y0;
  // glass panel
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.12)'; ctx.shadowBlur = 20; ctx.shadowOffsetY = -2;
  rr(ctx, 0, y0, dev.w, H + 40, [26, 26, 0, 0]);
  ctx.fillStyle = dark ? 'rgba(44,44,46,0.97)' : 'rgba(214,216,222,0.97)';
  ctx.fill();
  ctx.restore();
  const keys = layout(dev, st, y0);
  for (const k of keys) {
    const special = !['char', 'space'].includes(k.kind) || (k.kind === 'return' && false);
    const pressed = st.pressed === k;
    const isReturnBlue = k.kind === 'return' && st.returnBlue;
    let bg = dark ? (special ? '#4a4a4d' : '#6b6b6e') : (special ? '#acb0b9' : '#ffffff');
    if (k.kind === 'shift' && (st.shift || st.caps)) bg = dark ? '#ffffff' : '#ffffff';
    if (isReturnBlue) bg = '#0a84ff';
    if (pressed) bg = dark ? '#8e8e93' : (special ? '#ffffff' : '#c8cad0');
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.3)'; ctx.shadowOffsetY = 1; ctx.shadowBlur = 0;
    rr(ctx, k.x, k.y, k.w, k.h, 8.5);
    ctx.fillStyle = bg; ctx.fill();
    ctx.restore();
    const fg = isReturnBlue ? '#fff' : (k.kind === 'shift' && (st.shift || st.caps) && dark) ? '#000' : (dark ? '#fff' : '#000');
    glyph(ctx, k, st, dark, fg);
  }
  // key preview bubble
  if (st.pressed && st.pressed.kind === 'char') {
    const k = st.pressed;
    const bw = k.w + 22, bh = 58;
    const bx = Math.min(dev.w - bw - 2, Math.max(2, k.x - 11)), by = k.y - bh + 6;
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.25)'; ctx.shadowBlur = 8; ctx.shadowOffsetY = 2;
    rr(ctx, bx, by, bw, bh, 10); ctx.fillStyle = dark ? '#6b6b6e' : '#fff'; ctx.fill();
    ctx.restore();
    let t = k.label;
    if (st.mode === 'abc' && (st.shift || st.caps)) t = t.toUpperCase();
    ctx.fillStyle = dark ? '#fff' : '#000';
    ctx.font = '400 36px -apple-system, "SF Pro Text", Inter, system-ui, sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(t, bx + bw / 2, by + bh / 2 - 2);
    ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';
  }
  // bottom row: globe + mic
  const gy = dev.h - Math.max(dev.bottom, 0) + 2;
  ctx.strokeStyle = dark ? '#c7c7cc' : '#3a3a3c'; ctx.lineWidth = 1.6;
  ctx.beginPath(); ctx.arc(30, gy, 11, 0, Math.PI * 2); ctx.stroke();
  ctx.beginPath(); ctx.ellipse(30, gy, 5, 11, 0, 0, Math.PI * 2); ctx.moveTo(19, gy); ctx.lineTo(41, gy); ctx.stroke();
  const mx = dev.w - 30;
  ctx.beginPath(); ctx.roundRect(mx - 4, gy - 11, 8, 14, 4); ctx.stroke();
  ctx.beginPath(); ctx.arc(mx, gy - 2, 8, 0.1 * Math.PI, 0.9 * Math.PI); ctx.moveTo(mx, gy + 6); ctx.lineTo(mx, gy + 10); ctx.stroke();
  return keys;
}

export function keyAt(keys, x, y) {
  // generous hit areas: nearest key in the tapped row
  let best = null, bd = Infinity;
  for (const k of keys) {
    const dx = x < k.x ? k.x - x : x > k.x + k.w ? x - k.x - k.w : 0;
    const dy = y < k.y - 6 ? k.y - 6 - y : y > k.y + k.h + 6 ? y - k.y - k.h - 6 : 0;
    const d = dx + dy * 4;
    if (d < bd) { bd = d; best = k; }
  }
  return bd < 12 ? best : null;
}
