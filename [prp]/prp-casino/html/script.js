const app = document.getElementById('app');
const setup = document.getElementById('setup');
const game = document.getElementById('game');
const limits = document.getElementById('limits');
const betInput = document.getElementById('betInput');

const dealerScore = document.getElementById('dealerScore');
const playerScore = document.getElementById('playerScore');
const statusEl = document.getElementById('status');

let currentMin = 100;
let currentMax = 5000;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function renderState(state) {
    dealerScore.textContent = state.dealerScore ?? 0;
    playerScore.textContent = state.playerScore ?? 0;
    statusEl.textContent = state.status || 'playing';
    app.classList.add('hidden');

    const disabled = state.finished === true;
    document.getElementById('hitBtn').disabled = disabled;
    document.getElementById('standBtn').disabled = disabled;
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        app.classList.remove('hidden');
        setup.classList.remove('hidden');
        game.classList.add('hidden');

        currentMin = data.minBet;
        currentMax = data.maxBet;

        limits.textContent = `Table Limits: $${currentMin} - $${currentMax}`;
        betInput.min = currentMin;
        betInput.max = currentMax;
        betInput.value = currentMin;
        statusEl.textContent = '';
    }

    if (data.action === 'hideSetup') {
        app.classList.add('hidden');
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
    }

    if (data.action === 'state') {
        renderState(data.state);
    }
});

document.getElementById('dealBtn').addEventListener('click', () => {
    const bet = Number(betInput.value || 0);

    if (bet < currentMin || bet > currentMax) {
        statusEl.textContent = `Bet must be between $${currentMin} and $${currentMax}.`;
        return;
    }

    post('startGame', { bet });
});

document.getElementById('hitBtn').addEventListener('click', () => post('hit'));
document.getElementById('standBtn').addEventListener('click', () => post('stand'));
document.getElementById('closeBtn').addEventListener('click', () => post('close'));

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close');
});
