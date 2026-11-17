// Node driver for a reactor-model UIKit app wasm: start, frame, tap at (x,y) -> checks input handling headlessly.
import { WASI } from 'node:wasi'; import fs from 'node:fs';
const wasi = new WASI({ version: 'preview1', args: ['app'], env: {}, stdout: 1, stderr: 2, returnOnExit: true });
let memory; const dec = new TextDecoder();
const narrow = new Set([...'iljtfrI!.,:;|\'"()[] ']), wide = new Set([...'mwMW@']);
function measure(fp, fl, tp, tl) {
  const font = dec.decode(new Uint8Array(memory.buffer, fp, fl)), text = dec.decode(new Uint8Array(memory.buffer, tp, tl));
  const m = /([\d.]+)px/.exec(font); const size = m ? parseFloat(m[1]) : 17;
  let w = 0; for (const ch of text) w += ch === ' ' ? 0.26 : narrow.has(ch) ? 0.3 : wide.has(ch) ? 0.85 : /[A-Z]/.test(ch) ? 0.66 : 0.53;
  return w * size;
}
const { instance } = await WebAssembly.instantiate(fs.readFileSync(process.argv[2]), { wasi_snapshot_preview1: wasi.wasiImport, swiftboard: { measure_text: measure }, env: new Proxy({}, { get: (t, k) => () => { console.log('env.' + String(k)); return 0; } }) });
const ex = instance.exports; memory = ex.memory;
wasi.initialize(instance);
ex.uikit_set_screen(390, 844, 2);
if (process.env.UIKIT_DEBUG) ex.uikit_debug?.(1);
ex.app_start();
const tick = (ms) => { const t = Date.now(); let n = 0; while (Date.now() - t < ms) { const r = Number(ex.webRunLoopTick()); n++; if (r < 0) break; } return n; };
const frame = () => { const p = ex.uikit_frame(), n = ex.uikit_frame_len(); return dec.decode(new Uint8Array(memory.buffer, p, n)); };
console.log('ticks', tick(300), 'frame bytes', frame().length);
const taps = JSON.parse(process.argv[3] || '[[44,103]]');
for (const [x, y] of taps) {
  console.log('tap', x, y);
  ex.uikit_pointer(1, 0, x, y); tick(50);
  ex.uikit_pointer(1, 2, x, y); console.log('ticks', tick(300));
}
const out = frame(); console.log('frame bytes', out.length);
if (process.argv[4]) fs.writeFileSync(process.argv[4], out);
