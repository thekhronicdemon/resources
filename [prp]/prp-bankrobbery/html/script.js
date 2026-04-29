const app = document.getElementById('app');
const title = document.getElementById('title');
const subtitle = document.getElementById('subtitle');
const closeBtn = document.getElementById('closeBtn');
const games = {
  keypad: document.getElementById('keypadGame'),
  lockpick: document.getElementById('lockpickGame'),
  drill: document.getElementById('drillGame'),
};

let active = null;
let keyHandler = null;
let loop = null;

function nui(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
}

function cleanup() {
  if (keyHandler) window.removeEventListener('keydown', keyHandler);
  keyHandler = null;
  if (loop) cancelAnimationFrame(loop);
  loop = null;
  active = null;
}

function close(success = false) {
  cleanup();
  nui('minigameComplete', { success });
}

function cancel() {
  cleanup();
  nui('minigameCancel', {});
}

closeBtn.onclick = cancel;
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !app.classList.contains('hidden')) cancel();
});

function show(game, opts) {
  cleanup();
  app.classList.remove('hidden');
  Object.values(games).forEach(el => el.classList.add('hidden'));
  games[game].classList.remove('hidden');
  title.textContent = opts.title || 'PRP Minigame';
  subtitle.textContent = opts.subtitle || '';
  active = game;
}

const keypadChars = '1234567890ABCD#*';
function startKeypad(opts) {
  show('keypad', opts);
  const grid = document.getElementById('keypadGrid');
  const seqText = document.getElementById('sequenceText');
  const status = document.getElementById('keypadStatus');
  grid.innerHTML = '';

  keypadChars.split('').forEach(ch => {
    const btn = document.createElement('button');
    btn.className = 'key';
    btn.textContent = ch;
    btn.onclick = () => press(ch);
    grid.appendChild(btn);
  });

  const rounds = opts.rounds || 4;
  let round = 0;
  let sequence = [];
  let input = [];
  let accepting = false;
  let timer = null;

  function makeSeq() {
    const len = Math.floor(Math.random() * ((opts.sequenceMax || 7) - (opts.sequenceMin || 4) + 1)) + (opts.sequenceMin || 4);
    return Array.from({ length: len }, () => keypadChars[Math.floor(Math.random() * keypadChars.length)]);
  }

  function nextRound() {
    accepting = false;
    input = [];
    round++;
    if (round > rounds) return close(true);
    sequence = makeSeq();
    status.textContent = `Round ${round}/${rounds} - memorise the sequence`;
    seqText.textContent = sequence.join('');
    setTimeout(() => {
      seqText.textContent = 'INPUT';
      status.textContent = 'Enter the sequence now';
      accepting = true;
      clearTimeout(timer);
      timer = setTimeout(() => close(false), opts.inputTime || 9000);
    }, opts.showTime || 1100);
  }

  function press(ch) {
    if (!accepting) return;
    input.push(ch);
    seqText.textContent = input.join('');
    const idx = input.length - 1;
    if (input[idx] !== sequence[idx]) return close(false);
    if (input.length === sequence.length) {
      clearTimeout(timer);
      status.textContent = 'Sequence accepted';
      setTimeout(nextRound, 450);
    }
  }

  keyHandler = (e) => {
    const key = e.key.toUpperCase();
    if (keypadChars.includes(key)) press(key);
  };
  window.addEventListener('keydown', keyHandler);
  nextRound();
}

function startLockpick(opts) {
  show('lockpick', opts);
  const pin = document.getElementById('lockPin');
  const zone = document.getElementById('lockZone');
  const status = document.getElementById('lockpickStatus');
  const rounds = opts.rounds || 3;
  let round = 1;
  let pos = 0;
  let dir = 1;
  let zoneStart = 30;
  let last = performance.now();

  function setZone() {
    const size = opts.zoneSize || 16;
    zoneStart = Math.random() * (100 - size);
    zone.style.left = `${zoneStart}%`;
    zone.style.width = `${size}%`;
    status.textContent = `Round ${round}/${rounds}`;
  }

  function tick(now) {
    const dt = Math.min(32, now - last);
    last = now;
    pos += dir * dt * (opts.speed || 1.35) * 0.045;
    if (pos >= 100) { pos = 100; dir = -1; }
    if (pos <= 0) { pos = 0; dir = 1; }
    pin.style.left = `${pos}%`;
    loop = requestAnimationFrame(tick);
  }

  keyHandler = (e) => {
    if (e.code !== 'Space') return;
    e.preventDefault();
    const size = opts.zoneSize || 16;
    if (pos >= zoneStart && pos <= zoneStart + size) {
      round++;
      if (round > rounds) return close(true);
      pos = 0;
      dir = 1;
      setZone();
    } else {
      close(false);
    }
  };
  window.addEventListener('keydown', keyHandler);
  setZone();
  loop = requestAnimationFrame(tick);
}

function startDrill(opts) {
  show('drill', opts);
  const progressEl = document.getElementById('drillProgress');
  const heatEl = document.getElementById('drillHeat');
  const status = document.getElementById('drillStatus');
  let progress = 0;
  let heat = 0;
  let holding = false;
  let last = performance.now();

  const down = (e) => { if (e.code === 'Space') { e.preventDefault(); holding = true; } };
  const up = (e) => { if (e.code === 'Space') { e.preventDefault(); holding = false; } };
  window.addEventListener('keydown', down);
  window.addEventListener('keyup', up);
  keyHandler = (e) => {};
  const oldCleanup = cleanup;

  function tick(now) {
    const dt = Math.min(40, now - last) / 16.67;
    last = now;
    if (holding) {
      progress += (opts.progressGain || 0.24) * dt;
      heat += (opts.heatGain || 0.82) * dt;
    } else {
      heat -= (opts.coolRate || 0.48) * dt;
    }
    heat = Math.max(0, Math.min(100, heat));
    progress = Math.max(0, Math.min(100, progress));
    progressEl.style.width = `${progress}%`;
    heatEl.style.width = `${heat}%`;
    if (heat >= 100) return close(false);
    if (progress >= 100) return close(true);
    status.textContent = heat > 78 ? 'Too hot, release SPACE!' : 'Keep it steady.';
    loop = requestAnimationFrame(tick);
  }

  const originalCleanup = cleanup;
  cleanup = function patchedCleanup() {
    window.removeEventListener('keydown', down);
    window.removeEventListener('keyup', up);
    cleanup = originalCleanup;
    originalCleanup();
  };

  loop = requestAnimationFrame(tick);
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'closeMinigame') {
    app.classList.add('hidden');
    Object.values(games).forEach(el => el.classList.add('hidden'));
    return;
  }
  if (data.action !== 'openMinigame') return;
  const opts = data.opts || {};
  if (data.game === 'keypad') startKeypad(opts);
  if (data.game === 'lockpick') startLockpick(opts);
  if (data.game === 'drill') startDrill(opts);
});
