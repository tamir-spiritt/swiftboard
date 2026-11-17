// Node host for the Display test: WASI preview1 + the Swiftboard host imports (text measurement).
import { WASI } from 'node:wasi'; import fs from 'node:fs';
const wasi = new WASI({ version: 'preview1', args: ['display'], env: {}, stdout: 1, stderr: 2, returnOnExit: true });
let memory;
const dec = new TextDecoder();
// Approximate SF Pro advances in em (no canvas in Node; the browser host uses canvas measureText).
const narrow = new Set([...'iljtfrI!.,:;|\'"()[] ']), wide = new Set([...'mwMW@']);
function measure(fontPtr, fontLen, textPtr, textLen) {
  const font = dec.decode(new Uint8Array(memory.buffer, fontPtr, fontLen));
  const text = dec.decode(new Uint8Array(memory.buffer, textPtr, textLen));
  const m = /([\d.]+)px/.exec(font); const size = m ? parseFloat(m[1]) : 17;
  const bold = /\b(6|7|8|9)00\b/.test(font) ? 1.04 : 1;
  let w = 0;
  for (const ch of text) w += ch === ' ' ? 0.26 : narrow.has(ch) ? 0.3 : wide.has(ch) ? 0.85 : /[A-Z]/.test(ch) ? 0.66 : 0.53;
  return w * size * bold;
}
const { instance } = await WebAssembly.instantiate(fs.readFileSync(process.argv[2]), {
  wasi_snapshot_preview1: wasi.wasiImport,
  swiftboard: { measure_text: measure },
});
memory = instance.exports.memory;
try { const code = wasi.start(instance); if (code) console.error('exit', code); } catch (e) { console.error('trap', e); process.exitCode = 1; }
