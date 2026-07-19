const app = document.getElementById('app');
const tablet = document.getElementById('tablet');
const stanceControls = document.getElementById('stanceControls');
const positionKey = 'prpMechanicTabletPosition';
let state = { data: null, limits: null, defaults: null, stance: null, airbagsDown: false };
let dragState = null;

const resourceName = GetParentResourceName();
const airbagAudio = document.createElement('audio');
airbagAudio.src = `nui://${resourceName}/shared/airbag.mp3`;
airbagAudio.preload = 'auto';
document.body.appendChild(airbagAudio);

const fields = [
  ['suspension', 'Ride Height'],
  ['wheelWidth', 'Wheel Width'],
  ['frontCamber', 'Front Camber'],
  ['rearCamber', 'Rear Camber'],
  ['frontTrack', 'Front Track'],
  ['rearTrack', 'Rear Track']
];

const post = (name, body = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body)
});

function clampTabletPosition(left, top) {
  const margin = 8;
  const width = tablet.offsetWidth;
  const height = tablet.offsetHeight;
  const maxLeft = Math.max(margin, window.innerWidth - width - margin);
  const maxTop = Math.max(margin, window.innerHeight - height - margin);
  return {
    left: Math.min(Math.max(left, margin), maxLeft),
    top: Math.min(Math.max(top, margin), maxTop)
  };
}

function setTabletPosition(left, top, save) {
  const pos = clampTabletPosition(left, top);
  tablet.style.transform = 'none';
  tablet.style.left = `${pos.left}px`;
  tablet.style.top = `${pos.top}px`;
  if (save) localStorage.setItem(positionKey, JSON.stringify(pos));
}

function restoreTabletPosition() {
  const saved = localStorage.getItem(positionKey);
  if (!saved) return;

  try {
    const pos = JSON.parse(saved);
    if (Number.isFinite(pos.left) && Number.isFinite(pos.top)) {
      setTabletPosition(pos.left, pos.top, false);
    }
  } catch (_) {
    localStorage.removeItem(positionKey);
  }
}

function renderControls() {
  stanceControls.innerHTML = '';
  fields.forEach(([key, label]) => {
    const lim = state.limits[key];
    const wrap = document.createElement('div');
    wrap.className = 'control';
    wrap.innerHTML = `<div class="control-head"><label>${label}</label><output id="${key}Out">${Number(state.stance[key]).toFixed(3)}</output></div><input id="${key}" type="range" min="${lim.min}" max="${lim.max}" step="${lim.step}" value="${state.stance[key]}">`;
    stanceControls.appendChild(wrap);

    const input = wrap.querySelector('input');
    input.addEventListener('input', () => {
      state.stance[key] = Number(input.value);
      wrap.querySelector('output').textContent = Number(input.value).toFixed(3);
      post('previewStance', { stance: state.stance });
    });
  });
}

function asInstalled(value) {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function setInstalled(id, installed) {
  installed = asInstalled(installed);
  document.getElementById(`${id}Locked`).classList.toggle('hidden', installed);
  document.getElementById(`${id}Controls`).classList.toggle('hidden', !installed);
}

function applyUpgradeData(data, airbagsDown) {
  data = data || {};
  state.data = data;
  state.airbagsDown = airbagsDown === true;
  state.stance = { ...state.defaults, ...(data.stance_data || {}) };

  setInstalled('stance', data.stancer);
  setInstalled('hydraulics', data.hydraulics);
  renderControls();
}

function playAirbagSound(volume) {
  airbagAudio.pause();
  airbagAudio.currentTime = 0;
  airbagAudio.volume = Math.min(Math.max(Number(volume) || 0.65, 0), 1);
  airbagAudio.play().catch(error => {
    post('airbagSoundFailed', {
      src: airbagAudio.src,
      message: error && error.message ? error.message : 'playback rejected'
    });
  });
}

tablet.querySelector('header').addEventListener('mousedown', event => {
  if (event.button !== 0 || event.target.closest('button')) return;
  const rect = tablet.getBoundingClientRect();
  dragState = {
    offsetX: event.clientX - rect.left,
    offsetY: event.clientY - rect.top
  };
  tablet.style.transform = 'none';
  event.preventDefault();
});

window.addEventListener('mousemove', event => {
  if (!dragState) return;
  setTabletPosition(event.clientX - dragState.offsetX, event.clientY - dragState.offsetY, false);
});

window.addEventListener('mouseup', () => {
  if (!dragState) return;
  const rect = tablet.getBoundingClientRect();
  dragState = null;
  setTabletPosition(rect.left, rect.top, true);
});

window.addEventListener('resize', () => {
  if (app.classList.contains('hidden')) return;
  const rect = tablet.getBoundingClientRect();
  setTabletPosition(rect.left, rect.top, true);
});

window.addEventListener('message', e => {
  if (e.data.action === 'open') {
    state = { ...state, ...e.data };
    document.getElementById('vehicleLabel').textContent = `${e.data.label} - ${e.data.plate}`;
    applyUpgradeData(e.data.data, e.data.airbagsDown);
    app.classList.remove('hidden');
    restoreTabletPosition();
  }
  if (e.data.action === 'refreshData') {
    applyUpgradeData(e.data.data, e.data.airbagsDown);
  }
  if (e.data.action === 'airbagsState') state.airbagsDown = e.data.down;
  if (e.data.action === 'playAirbagSound') playAirbagSound(e.data.volume);
  if (e.data.action === 'close') app.classList.add('hidden');
});

document.querySelectorAll('.tab').forEach(btn => {
  btn.onclick = () => {
    document.querySelectorAll('.tab,.page').forEach(x => x.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById(btn.dataset.page).classList.add('active');
  };
});

document.getElementById('close').onclick = () => post('close');
document.addEventListener('keyup', e => { if (e.key === 'Escape') post('close'); });
document.getElementById('saveStance').onclick = () => post('saveStance', { stance: state.stance });
document.getElementById('resetStance').onclick = () => {
  state.stance = { ...state.defaults };
  renderControls();
  post('previewStance', { stance: state.stance });
};
