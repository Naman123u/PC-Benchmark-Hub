'use strict';

const GPU_LIST = [
  { name: 'AMD Radeon RX 460 4GB', score: 20 },
  { name: 'NVIDIA GTX 1650', score: 38 },
  { name: 'NVIDIA GTX 1660 Super', score: 57 },
  { name: 'NVIDIA RTX 2060', score: 68 },
  { name: 'NVIDIA RTX 3060', score: 100 },
  { name: 'NVIDIA RTX 4060', score: 116 },
  { name: 'NVIDIA RTX 4070', score: 172 },
  { name: 'NVIDIA RTX 4080', score: 235 }
];
const CPU_LIST = [
  { name: 'Intel Core i5-9400F', score: 72 },
  { name: 'Intel Core i5-12400F', score: 100 },
  { name: 'Intel Core i5-13400F', score: 112 },
  { name: 'AMD Ryzen 5 5600', score: 98 },
  { name: 'AMD Ryzen 7 5800X', score: 125 },
  { name: 'AMD Ryzen 7 7800X3D', score: 138 }
];
const GAME_MODELS = {
  valorant: { label: 'Valorant', baseline: 230, cpuWeight: 0.78 },
  gtav: { label: 'Grand Theft Auto V', baseline: 105, cpuWeight: 0.48 },
  fortnite: { label: 'Fortnite', baseline: 95, cpuWeight: 0.48 },
  minecraft: { label: 'Minecraft Java (no shaders)', baseline: 155, cpuWeight: 0.72 },
  spiderman: { label: 'Marvel’s Spider-Man Remastered', baseline: 72, cpuWeight: 0.30 },
  cs2: { label: 'Counter-Strike 2', baseline: 175, cpuWeight: 0.70 }
};

const byId = id => document.getElementById(id);
const clamp = (n, min, max) => Math.min(max, Math.max(min, n));
let importedReport = null;

function normalizedName(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function inferGpuScore(name) {
  const n = normalizedName(name).toLowerCase();
  const exact = GPU_LIST.find(g => n.includes(g.name.toLowerCase().replace('nvidia ', '').replace('amd ', '')) || g.name.toLowerCase().includes(n));
  if (exact) return exact.score;
  const rtx = n.match(/rtx\s*(\d{3,4})/);
  if (rtx) {
    const model = Number(rtx[1]);
    if (model >= 4090) return 285;
    if (model >= 4080) return 235;
    if (model >= 4070) return 172;
    if (model >= 4060) return 116;
    if (model >= 3090) return 210;
    if (model >= 3080) return 185;
    if (model >= 3070) return 145;
    if (model >= 3060) return 100;
    if (model >= 2080) return 115;
    if (model >= 2070) return 90;
    if (model >= 2060) return 68;
  }
  const gtx = n.match(/gtx\s*(\d{3,4})/);
  if (gtx) {
    const model = Number(gtx[1]);
    if (model >= 1080) return 75;
    if (model >= 1070) return 65;
    if (model >= 1660) return 57;
    if (model >= 1650) return 38;
    if (model >= 1060) return 50;
  }
  if (n.includes('rx 7')) return 150;
  if (n.includes('rx 6')) return 95;
  if (n.includes('rx 5')) return 55;
  if (n.includes('rx 4')) return 30;
  if (n.includes('radeon graphics') || n.includes('uhd graphics') || n.includes('vega')) return 18;
  return 65; // Neutral fallback for unknown devices; this is not a measured score.
}

function inferCpuScore(name) {
  const n = normalizedName(name).toLowerCase();
  const exact = CPU_LIST.find(c => n.includes(c.name.toLowerCase()) || c.name.toLowerCase().includes(n));
  if (exact) return exact.score;
  const intel = n.match(/i[3579][ -]?(\d{4,5})/);
  if (intel) {
    const gen = Number(intel[1].slice(0, -3));
    const tier = Number(n.match(/i([3579])/)?.[1] || 5);
    return clamp(45 + gen * 4 + tier * 5, 55, 145);
  }
  const ryzen = n.match(/ryzen\s*[3579]\s*(\d{4,5})/);
  if (ryzen) return clamp(65 + Number(ryzen[1].slice(0, 1)) * 14, 70, 145);
  if (n.includes('xeon')) return 75;
  return 80; // Neutral fallback for unknown devices; this is not a measured score.
}

function setSelectToHardware(selectId, name, score, list) {
  const select = byId(selectId);
  if (!select || !name) return;
  const normalized = normalizedName(name);
  const match = Array.from(select.options).find(o => normalizedName(o.textContent).toLowerCase() === normalized.toLowerCase());
  if (match) {
    select.value = match.value;
    return;
  }
  const option = document.createElement('option');
  option.value = String(score);
  option.textContent = `${normalized} (detected)`;
  option.dataset.detected = 'true';
  select.insertBefore(option, select.firstChild);
  select.value = option.value;
}

function formatGB(value) {
  return Number.isFinite(Number(value)) ? `${Number(value).toFixed(Number(value) % 1 ? 1 : 0)} GB` : 'Not reported';
}

function safeText(value, fallback = 'Not reported') {
  const text = normalizedName(value);
  return text || fallback;
}

function makeHardwareItem(label, value, detail = '') {
  const box = document.createElement('div');
  box.className = 'hardware-item';
  const title = document.createElement('span');
  title.textContent = label;
  const strong = document.createElement('strong');
  strong.textContent = value;
  box.append(title, strong);
  if (detail) {
    const small = document.createElement('small');
    small.textContent = detail;
    box.append(small);
  }
  return box;
}

function validateReport(data) {
  if (!data || typeof data !== 'object' || data.schemaVersion !== 1 || data.source !== 'PC Benchmark Hub Scanner') {
    throw new Error('This does not look like a PC Benchmark Hub scanner report. Run the latest scanner and import its JSON file.');
  }
  if (!data.cpu || !Array.isArray(data.gpus) || !data.memory) {
    throw new Error('The report is missing required hardware information. Please run the scanner again.');
  }
  return data;
}

function showReport(data) {
  importedReport = data;
  const grid = byId('hardwareGrid');
  grid.replaceChildren();
  const mainGpu = data.gpus.find(g => g.name) || {};
  const memoryModules = Array.isArray(data.memory.modules) ? data.memory.modules : [];
  const moduleDetail = memoryModules.length ? memoryModules.map(m => `${m.capacityGB || '?'} GB${m.speedMHz ? ` @ ${m.speedMHz} MHz` : ''}`).join(' · ') : '';
  const storage = Array.isArray(data.storage) ? data.storage : [];
  const storageText = storage.length ? storage.map(d => `${safeText(d.model, 'Drive')} (${formatGB(d.sizeGB)})`).join(' / ') : 'Not reported';
  const display = mainGpu.currentResolution || data.display?.resolution || '';
  const hardware = [
    ['PROCESSOR', safeText(data.cpu.name), `${data.cpu.cores || '?'} cores · ${data.cpu.logicalProcessors || '?'} threads`],
    ['GRAPHICS', safeText(mainGpu.name), mainGpu.vramGB ? `${mainGpu.vramGB} GB video memory` : safeText(mainGpu.driverVersion, 'Video adapter detected')],
    ['MEMORY', formatGB(data.memory.totalGB), moduleDetail],
    ['OPERATING SYSTEM', safeText(data.os?.name), data.os?.version ? `Version ${data.os.version} · Build ${data.os.build || '—'}` : ''],
    ['MOTHERBOARD', safeText(data.motherboard?.model), safeText(data.motherboard?.manufacturer, '')],
    ['STORAGE', storageText, `${storage.length} drive(s) reported`],
    ['DISPLAY MODE', safeText(display, 'Not reported'), 'Current display mode, when available'],
    ['SCAN SOURCE', 'Windows read-only scan', data.generatedAt ? new Date(data.generatedAt).toLocaleString() : 'Timestamp unavailable']
  ];
  hardware.forEach(([label, value, detail]) => grid.append(makeHardwareItem(label, value, detail)));
  byId('hardwarePanel').hidden = false;
  byId('scanStatus').classList.add('status-ready');
  byId('scanStatusLabel').textContent = 'PC REPORT IMPORTED';
  byId('scanTimestamp').textContent = 'Report loaded into this browser tab. It is not sent to a server by this website.';
  byId('hardwareTitle').textContent = safeText(data.cpu.name, 'Detected hardware');

  setSelectToHardware('cpu', data.cpu.name, inferCpuScore(data.cpu.name), CPU_LIST);
  if (mainGpu.name) setSelectToHardware('gpu', mainGpu.name, inferGpuScore(mainGpu.name), GPU_LIST);
  const ram = Number(data.memory.totalGB);
  if (ram > 0) {
    const closest = [8, 16, 32, 64].reduce((a, b) => Math.abs(b - ram) < Math.abs(a - ram) ? b : a);
    byId('ram').value = String(closest);
  }
  if (display) {
    const match = String(display).match(/(\d{3,5})\s*[x×]\s*(\d{3,5})/i);
    if (match) {
      const height = Number(match[2]);
      const target = height >= 2000 ? '0.43' : height >= 1300 ? '0.72' : height >= 850 ? '1' : '1.28';
      byId('resolution').value = target;
    }
  }
  populateGpuCompare(data.gpus.map(g => g.name).filter(Boolean));
}

async function importReport(file) {
  if (!file) return;
  try {
    const raw = (await file.text()).replace(/^\uFEFF/, '');
    const data = validateReport(JSON.parse(raw));
    showReport(data);
  } catch (error) {
    byId('scanStatusLabel').textContent = 'COULD NOT READ REPORT';
    alert(error.message || 'Could not read that JSON file.');
  }
}

function populateGpuCompare(detectedNames = []) {
  const names = [...GPU_LIST.map(g => g.name)];
  detectedNames.forEach(name => { if (name && !names.some(n => n.toLowerCase() === name.toLowerCase())) names.unshift(name); });
  ['gpuA', 'gpuB'].forEach((id, index) => {
    const select = byId(id);
    const old = select.value;
    select.replaceChildren();
    names.forEach(name => {
      const option = document.createElement('option');
      option.textContent = name;
      const ref = GPU_LIST.find(g => g.name.toLowerCase() === name.toLowerCase());
      option.value = String(ref ? ref.score : inferGpuScore(name));
      option.dataset.name = name;
      select.append(option);
    });
    if (old && Array.from(select.options).some(o => o.value === old)) select.value = old;
    else select.selectedIndex = index === 0 ? 0 : Math.min(4, select.options.length - 1);
  });
}

function estimateFPS() {
  const cpuScore = Number(byId('cpu').value);
  const gpuScore = Number(byId('gpu').value);
  const ram = Number(byId('ram').value);
  const resolutionFactor = Number(byId('resolution').value);
  const qualityFactor = Number(byId('quality').value);
  const game = GAME_MODELS[byId('game').value];
  const cpuFactor = clamp(cpuScore / 100, 0.45, 1.55);
  const gpuFactor = clamp(gpuScore / 100, 0.18, 2.5);
  const cpuWeighted = cpuFactor * game.cpuWeight + gpuFactor * (1 - game.cpuWeight);
  const ramFactor = ram < 16 ? 0.82 : ram < 32 ? 1 : 1.015;
  const estimate = Math.max(5, game.baseline * cpuWeighted * ramFactor * resolutionFactor * qualityFactor);
  const low = Math.max(3, Math.round(estimate * 0.78 / 5) * 5);
  const high = Math.max(low + 5, Math.round(estimate * 1.22 / 5) * 5);
  byId('fpsRange').innerHTML = `${low}–${high} <small>FPS</small>`;
  const mid = (low + high) / 2;
  byId('fpsVerdict').textContent = mid >= 120 ? 'Smooth range in this simplified model.' : mid >= 60 ? 'Around 60 FPS or better in this simplified model.' : mid >= 30 ? 'May be playable with settings adjustments.' : 'This combination may struggle at the selected settings.';
  byId('fpsResult').hidden = false;
}

function compareGPUs() {
  const a = byId('gpuA');
  const b = byId('gpuB');
  const scoreA = Number(a.value);
  const scoreB = Number(b.value);
  const nameA = a.options[a.selectedIndex].dataset.name || a.options[a.selectedIndex].textContent;
  const nameB = b.options[b.selectedIndex].dataset.name || b.options[b.selectedIndex].textContent;
  const winner = scoreA === scoreB ? 'These GPUs have the same reference index.' : scoreA > scoreB ? `${nameA} has the higher reference index.` : `${nameB} has the higher reference index.`;
  const stronger = Math.max(scoreA, scoreB);
  const weaker = Math.max(1, Math.min(scoreA, scoreB));
  const difference = Math.round((stronger / weaker - 1) * 100);
  byId('compareWinner').textContent = winner + (scoreA === scoreB ? '' : ` (${difference}% higher by this index)`);
  const max = Math.max(scoreA, scoreB, 1);
  const bars = byId('compareBars');
  bars.replaceChildren();
  [[nameA, scoreA, false], [nameB, scoreB, true]].forEach(([name, score, second]) => {
    const row = document.createElement('div'); row.className = 'bar-row';
    const label = document.createElement('span'); label.className = 'bar-name'; label.textContent = name;
    const track = document.createElement('div'); track.className = 'bar-track';
    const fill = document.createElement('div'); fill.className = `bar-fill${second ? ' second' : ''}`; fill.style.width = `${Math.max(2, score / max * 100)}%`; track.append(fill);
    const value = document.createElement('span'); value.className = 'bar-score'; value.textContent = score;
    row.append(label, track, value); bars.append(row);
  });
  byId('compareResult').hidden = false;
}

byId('specFile').addEventListener('change', event => importReport(event.target.files?.[0]));
byId('clearSpecs').addEventListener('click', () => {
  importedReport = null; byId('hardwarePanel').hidden = true; byId('scanStatus').classList.remove('status-ready');
  byId('scanStatusLabel').textContent = 'WAITING FOR YOUR REPORT'; byId('specFile').value = '';
});
byId('estimateButton').addEventListener('click', estimateFPS);
byId('compareButton').addEventListener('click', compareGPUs);
populateGpuCompare();
