let state = {
  profile: null,
  nextLevelXp: 250,
  skills: {},
  issues: {},
  towJobs: [],
  lastIssues: null,
  activeTow: null,
};

let toastTimer = null;

const $ = (id) => document.getElementById(id);
const resourceName = () => (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'prp-mechanic');

async function post(name, data = {}) {
  try {
    const response = await fetch(`https://${resourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    const text = await response.text();
    if (!text) return {};

    try {
      return JSON.parse(text);
    } catch (_) {
      return text === 'ok' ? { ok: true } : { ok: false, message: text };
    }
  } catch (_) {
    return { ok: false, message: 'Tablet request failed.' };
  }
}

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[ch]));
}

function clampPercent(value) {
  const number = Number(value);
  if (Number.isNaN(number)) return 100;
  return Math.max(0, Math.min(100, Math.round(number)));
}

function toast(message, type = 'primary') {
  if (!message) return;
  const box = $('toast');
  box.textContent = message;
  box.className = `toast ${type}`;
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => box.classList.add('hidden'), 3200);
}

window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.action === 'open') {
    $('app').classList.remove('hidden');
    hydrate(msg.data || {});
  }
  if (msg.action === 'profile') {
    state.profile = msg.profile || state.profile;
    state.nextLevelXp = msg.nextLevelXp || state.nextLevelXp;
    renderProfile();
    renderSkills();
  }
  if (msg.action === 'towCancelled') {
    state.activeTow = null;
    renderCurrentWork();
    renderTow();
  }
});

function hydrate(data) {
  state.profile = data.profile || state.profile;
  state.nextLevelXp = data.nextLevelXp || state.nextLevelXp;
  state.skills = data.skills || state.skills || {};
  state.issues = data.issues || state.issues || {};
  state.towJobs = data.towJobs || state.towJobs || [];
  state.activeTow = data.activeTow || null;

  renderProfile();
  renderCurrentWork();
  renderDiagnostics();
  renderIssues();
  renderSkills();
  renderTow();
}

function renderProfile() {
  const p = state.profile || {};
  $('level').textContent = p.level || 1;
  $('xp').textContent = `${p.xp || 0} / ${state.nextLevelXp || 250}`;
  $('points').textContent = p.skill_points || 0;
  $('rep').textContent = p.reputation || 0;
}

function renderCurrentWork() {
  const tow = state.activeTow;
  $('currentWork').textContent = tow ? `${tow.label || 'Tow contract'} active. ${towInstruction(tow)}` : 'No active tow contract.';
}

function issueStatus(value) {
  const v = clampPercent(value);
  if (v <= 25) return ['Critical', 'danger'];
  if (v <= 55) return ['Damaged', 'warn'];
  return ['Healthy', 'good'];
}

function renderIssues() {
  const list = $('repairList');
  const scanned = !!state.lastIssues;
  const profileLevel = (state.profile || {}).level || 1;
  list.innerHTML = '';

  Object.entries(state.issues).forEach(([key, cfg]) => {
    const val = scanned ? clampPercent(state.lastIssues[key] ?? 100) : 100;
    const [txt, cls] = issueStatus(val);
    const levelOk = profileLevel >= (cfg.minLevel || 1);
    const needsRepair = val < 100;
    const disabled = !scanned || !levelOk || !needsRepair;
    const buttonText = !scanned ? 'Scan first' : !levelOk ? `Level ${cfg.minLevel} required` : !needsRepair ? 'No repair needed' : `Repair ${cfg.label}`;

    const div = document.createElement('div');
    div.className = 'issue';
    div.innerHTML = `
      <h3>${esc(cfg.label)}</h3>
      <div class="small">Level Required: ${esc(cfg.minLevel || 1)}</div>
      <div class="${cls}">${txt} - ${val}%</div>
      <div class="bar"><div class="fill" style="width:${val}%"></div></div>
      <button class="repairBtn" data-issue="${esc(key)}" ${disabled ? 'disabled' : ''}>${esc(buttonText)}</button>
    `;
    list.appendChild(div);
  });

  document.querySelectorAll('.repairBtn').forEach((button) => {
    button.onclick = async () => {
      const res = await post('repairIssue', { issue: button.dataset.issue });
      toast(res.message, res.ok ? 'success' : 'error');
      if (res.issues) state.lastIssues = res.issues;
      renderIssues();
      renderDiagnostics();
    };
  });
}

function renderDiagnostics() {
  const box = $('diagnosticResults');
  box.innerHTML = '';

  if (!state.lastIssues) {
    box.innerHTML = '<p class="muted">No scan results yet.</p>';
    return;
  }

  Object.entries(state.lastIssues).forEach(([key, value]) => {
    const cfg = state.issues[key] || { label: key };
    const val = clampPercent(value);
    const [txt, cls] = issueStatus(val);
    const div = document.createElement('div');
    div.className = 'issue';
    div.innerHTML = `
      <h3>${esc(cfg.label)}</h3>
      <div class="${cls}">${txt} - ${val}%</div>
      <div class="bar"><div class="fill" style="width:${val}%"></div></div>
    `;
    box.appendChild(div);
  });
}

function renderSkills() {
  const box = $('skillsList');
  const profile = state.profile || {};
  const owned = profile.skills || {};
  const level = profile.level || 1;
  const points = profile.skill_points || 0;
  box.innerHTML = '';

  Object.entries(state.skills).forEach(([key, skill]) => {
    const has = !!owned[key];
    const levelOk = level >= (skill.minLevel || 1);
    const pointsOk = points >= (skill.cost || 1);
    const disabled = has || !levelOk || !pointsOk;
    const label = has ? 'Unlocked' : !levelOk ? `Level ${skill.minLevel} required` : !pointsOk ? 'Need more points' : 'Unlock';

    const div = document.createElement('div');
    div.className = 'skill';
    div.innerHTML = `
      <h3>${esc(skill.label)}</h3>
      <p>${esc(skill.description)}</p>
      <div class="small">Cost: ${esc(skill.cost)} point(s) | Required Level: ${esc(skill.minLevel)}</div>
      <button class="unlockBtn" data-skill="${esc(key)}" ${disabled ? 'disabled' : ''}>${esc(label)}</button>
    `;
    box.appendChild(div);
  });

  document.querySelectorAll('.unlockBtn').forEach((button) => {
    button.onclick = async () => {
      const res = await post('unlockSkill', { skill: button.dataset.skill });
      toast(res.message, res.ok ? 'success' : 'error');
      if (res.ok && res.profile) {
        state.profile = res.profile;
        renderProfile();
        renderSkills();
      }
    };
  });
}

function rewardText(job) {
  if (job.reward) return `$${job.reward}`;
  if (job.rewardMin && job.rewardMax) return `$${job.rewardMin} - $${job.rewardMax}`;
  return 'Variable';
}

function towInstruction(tow) {
  if (!tow) return '';
  if (tow.id === 'basic_breakdown') return 'Go to the customer, repair the vehicle on site, then the NPC will drive away.';
  if (tow.id === 'accident_recovery') return 'Tow the damaged vehicle and bring the accident customer with you to a mechanic shop.';
  return 'Retrieve a tow truck, attach the vehicle, and deliver it to the marked drop-off.';
}

function renderTow() {
  const activeBox = $('activeTow');
  const jobsBox = $('towJobs');
  jobsBox.innerHTML = '';

  if (state.activeTow) {
    const tow = state.activeTow;
    activeBox.classList.remove('hidden');
    activeBox.innerHTML = `
      <h3>${esc(tow.label || 'Active Tow Contract')}</h3>
      <div class="small">Difficulty: ${esc(tow.difficulty || 'Standard')} | Reward: ${esc(rewardText(tow))}</div>
      <p>${esc(towInstruction(tow))}</p>
      <button class="acceptBtn" id="cancelTowBtn">Cancel Contract</button>
    `;
  } else {
    activeBox.classList.add('hidden');
    activeBox.innerHTML = '';
  }

  state.towJobs.forEach((job) => {
    const div = document.createElement('div');
    div.className = 'job';
    div.innerHTML = `
      <h3>${esc(job.label)}</h3>
      <p>${esc(job.description)}</p>
      <div class="small">Difficulty: ${esc(job.difficulty)} | Reward: ${esc(rewardText(job))} | EXP: ${esc(job.xp)}</div>
      <button class="acceptBtn" data-job="${esc(job.id)}" ${state.activeTow ? 'disabled' : ''}>${state.activeTow ? 'Contract Active' : 'Accept Contract'}</button>
    `;
    jobsBox.appendChild(div);
  });

  document.querySelectorAll('.acceptBtn').forEach((button) => {
    button.onclick = async () => {
      if (button.id === 'cancelTowBtn') return;
      const res = await post('acceptTow', { jobId: button.dataset.job });
      toast(res.message, res.ok ? 'success' : 'error');
      if (res.ok && res.tow) {
        state.activeTow = res.tow;
        renderCurrentWork();
        renderTow();
      }
    };
  });

  const cancelButton = $('cancelTowBtn');
  if (cancelButton) {
    cancelButton.onclick = async () => {
      const res = await post('cancelTow');
      toast(res.message, res.ok ? 'success' : 'error');
      if (res.ok) {
        state.activeTow = null;
        renderCurrentWork();
        renderTow();
      }
    };
  }
}

async function refreshTablet() {
  const res = await post('refresh');
  toast(res.message || (res.ok ? 'Tablet refreshed.' : 'Unable to refresh tablet.'), res.ok ? 'success' : 'error');
  if (res.ok) hydrate(res);
}

document.querySelectorAll('.nav').forEach((button) => {
  button.onclick = () => {
    document.querySelectorAll('.nav,.page').forEach((element) => element.classList.remove('active'));
    button.classList.add('active');
    $(button.dataset.page).classList.add('active');
  };
});

$('close').onclick = async () => {
  await post('close');
  $('app').classList.add('hidden');
};

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') $('close').click();
});

$('refreshBtn').onclick = refreshTablet;

$('inspectBtn').onclick = async () => {
  const res = await post('inspect');
  toast(res.message || (res.ok ? 'Vehicle scan complete.' : 'Scan failed.'), res.ok ? 'success' : 'error');
  if (res.ok) {
    state.lastIssues = res.issues || {};
    renderDiagnostics();
    renderIssues();
  }
};

document.querySelectorAll('.action').forEach((button) => {
  button.onclick = async () => {
    const res = await post('basicRepair', { kind: button.dataset.basic });
    toast(res.message, res.ok ? 'success' : 'error');
  };
});
