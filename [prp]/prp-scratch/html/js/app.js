const app = document.getElementById('app');
const titleEl = document.getElementById('ticket-title');
const subtitleEl = document.getElementById('ticket-subtitle');
const gridEl = document.getElementById('scratch-grid');
const statusEl = document.getElementById('status-text');
const legendEl = document.getElementById('legend');
const escLabelEl = document.getElementById('esc-label');

let ticket = null;
let config = null;
let scratchedCount = 0;
let resultData = null;
let isOpen = false;
let closing = false;

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'prp-scratch';

function post(action, data = {}) {
    return fetch(`https://${resourceName}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((res) => res.json()).catch(() => ({ ok: false }));
}

function formatMoney(value) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        maximumFractionDigits: 0,
    }).format(value || 0);
}

function buildCard(square, index) {
    const box = document.createElement('div');
    box.className = 'scratch-box';
    box.dataset.index = index;

    box.innerHTML = `
        <div class="scratch-content" aria-hidden="true">
            <div class="modifier-badge ${square.modifier} ${square.modifier === 'none' ? 'empty' : ''}">${square.modifierIcon || ''}</div>
            <div class="symbol-icon">${square.icon}</div>
            <div class="symbol-label">${square.label}</div>
            <div class="prize-badge">${formatMoney(square.prize)}</div>
        </div>
        <div class="scratch-foil">SCRATCH</div>
    `;

    box.addEventListener('click', async () => {
        if (!isOpen || closing || box.classList.contains('scratched')) return;

        const response = await post('scratchBox', { index });
        if (!response || !response.ok) return;
        if (response.already) {
            box.classList.add('scratched');
            return;
        }

        box.classList.add('scratched');
        scratchedCount += 1;
        statusEl.textContent = `Scratched ${scratchedCount}/${ticket.boxes.length} boxes`;

        if (response.allScratched) {
            statusEl.textContent = 'Checking ticket result...';
        }
    });

    return box;
}

function renderTicket() {
    gridEl.innerHTML = '';
    scratchedCount = 0;
    resultData = null;
    closing = false;

    titleEl.textContent = config.title;
    subtitleEl.textContent = config.subtitle;
    escLabelEl.textContent = config.escLabel;
    legendEl.style.display = config.showLegend ? 'flex' : 'none';
    gridEl.style.gridTemplateColumns = `repeat(${config.gridColumns || 2}, minmax(0, 1fr))`;

    ticket.boxes.forEach((square, idx) => {
        const card = buildCard(square, idx + 1);
        gridEl.appendChild(card);
    });

    statusEl.textContent = 'Click each box to scratch.';
}

function openTicket(data) {
    config = data.config;
    ticket = data.ticket;
    isOpen = true;
    app.classList.remove('hidden');
    renderTicket();
}

function handleResult(result) {
    resultData = result;
    const cards = Array.from(document.querySelectorAll('.scratch-box'));

    if (result.won) {
        const winningSymbol = result.matchedSymbol;
        ticket.boxes.forEach((square, index) => {
            if (square.symbol === winningSymbol && cards[index]) {
                cards[index].classList.add('winner');
            }
        });
        statusEl.innerHTML = `<span class="result-win">WINNER: ${result.formattedPrize}${result.multiplier > 1 ? ' (X2)' : ''}</span>`;
    } else {
        statusEl.innerHTML = '<span class="result-lose">LOSER TICKET</span>';
    }
}

function closeTicketLocal() {
    app.classList.add('hidden');
    ticket = null;
    resultData = null;
    scratchedCount = 0;
    isOpen = false;
    closing = false;
    gridEl.innerHTML = '';
}

async function requestClose() {
    if (!isOpen || closing) return;
    closing = true;
    await post('close');
    closeTicketLocal();
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'open') {
        openTicket(data);
    } else if (data.action === 'result') {
        handleResult(data.result);
    } else if (data.action === 'forceClose') {
        closeTicketLocal();
    }
});

function handleEscape(event) {
    if (event.key !== 'Escape') return;
    if (!isOpen) return;
    event.preventDefault();
    event.stopPropagation();
    requestClose();
}

document.addEventListener('keydown', handleEscape, true);
window.addEventListener('keydown', handleEscape, true);
document.addEventListener('keyup', handleEscape, true);
window.addEventListener('keyup', handleEscape, true);
