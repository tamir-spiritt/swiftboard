// Entry for the Telegram-on-wasm demo page: loads the app wasm next to this module and adds iOS chrome.
import { startUIKitApp } from './uikit-host.js';
import { paintChrome } from './engine.js';

const logEl = document.getElementById('log');
const statsEl = document.getElementById('stats');
const params = new URLSearchParams(location.search);
const app = params.get('app') || document.documentElement.dataset.app || 'telegram-display';
const log = (line) => { logEl.textContent += line + '\n'; logEl.scrollTop = 1e9; console.log(line); };
try {
  const { stats } = await startUIKitApp(document.getElementById('screen'), {
    wasm: new URL(`${app}.wasm`, import.meta.url),
    assets: new URL('assets/manifest.json', import.meta.url).href,
    width: 390, height: 844,
    chrome: (g, w, h) => paintChrome(g, { w, h, island: true, home: true }, false),
    onLog: log,
  });
  const show = () => { statsEl.textContent = `wasm loaded in ${Math.round(stats.loadMs)} ms · frames ${stats.frames} · last frame ${stats.lastFrameMs.toFixed(1)} ms`; };
  setInterval(show, 500); show();
  window.__uikit = stats;
} catch (e) {
  log('error: ' + (e.stack || e));
  window.__uikitError = String(e);
}
