const app = document.getElementById('app');
const closeBtn = document.getElementById('closeBtn');

const strengthText = document.getElementById('strengthText');
const staminaText = document.getElementById('staminaText');
const enduranceText = document.getElementById('enduranceText');

const strengthBar = document.getElementById('strengthBar');
const staminaBar = document.getElementById('staminaBar');
const enduranceBar = document.getElementById('enduranceBar');

const limitText = document.getElementById('limitText');
const resetText = document.getElementById('resetText');

let cachedStats = {
    strength: 0,
    stamina: 0,
    endurance: 0,
    activity_count: 0,
    max_activities: 5,
    reset_in: 0
};

function clamp(n) {
    n = Number(n) || 0;
    return Math.max(0, Math.min(100, n));
}

function formatTime(seconds) {
    seconds = Number(seconds) || 0;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
}

function updateStats(stats) {
    cachedStats = Object.assign(cachedStats, stats || {});

    const strength = clamp(cachedStats.strength);
    const stamina = clamp(cachedStats.stamina);
    const endurance = clamp(cachedStats.endurance);

    strengthText.innerText = `${strength}%`;
    staminaText.innerText = `${stamina}%`;
    enduranceText.innerText = `${endurance}%`;

    strengthBar.style.width = `${strength}%`;
    staminaBar.style.width = `${stamina}%`;
    enduranceBar.style.width = `${endurance}%`;

    limitText.innerText = `${cachedStats.activity_count || 0} / ${cachedStats.max_activities || 5}`;
    resetText.innerText = `Limit reset in: ${formatTime(cachedStats.reset_in || 0)}`;
}

function openUI(stats) {
    updateStats(stats);
    app.classList.remove('hidden');
}

function closeUI() {
    app.classList.add('hidden');

    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({})
    });
}

window.addEventListener('message', function(event) {
    const data = event.data || {};

    if (data.action === 'open') {
        openUI(data.stats);
    }

    if (data.action === 'update' || data.action === 'cache') {
        updateStats(data.stats);
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
    }
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeUI();
    }
});

closeBtn.addEventListener('click', closeUI);
app.classList.add('hidden');
