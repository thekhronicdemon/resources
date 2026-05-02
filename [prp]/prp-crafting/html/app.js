const app = document.getElementById('app');
const dashboard = document.getElementById('dashboard');
const benchView = document.getElementById('bench');
const title = document.getElementById('title');
const subtitle = document.getElementById('subtitle');
const backBtn = document.getElementById('backBtn');
const closeBtn = document.getElementById('closeBtn');
const busy = document.getElementById('busy');
const searchInput = document.getElementById('searchInput');
const filterSelect = document.getElementById('filterSelect');
const recipeList = document.getElementById('recipeList');

let currentBench = null;

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
});

function progressPercent(xp, perLevel) {
    if (!perLevel) return 0;
    return Math.max(0, Math.min(100, (xp % perLevel) / perLevel * 100));
}

function renderMaterialOverlay(items = []) {
    const list = (items || []).map(i => {
        const owned = i.playerAmount === undefined ? '' : `${i.playerAmount}/`;
        return `
            <div class="materialItem ${i.hasEnough === false ? 'missing' : ''}">
                <img src="${i.image}" onerror="this.style.display='none'" />
                <span>${i.label}</span>
                <strong>${owned}${i.amount}</strong>
            </div>
        `;
    }).join('');

    return `
        <div class="materialHover" aria-hidden="true">
            <div class="materialTitle">Required Materials</div>
            ${list || '<p class="muted">No materials required.</p>'}
        </div>
    `;
}

function renderDashboard(benches = []) {
    title.textContent = 'PRP Crafting Skill Tree';
    subtitle.textContent = 'Spend points here. Crafting is only available from physical benches.';
    backBtn.classList.add('hidden');
    dashboard.classList.remove('hidden');
    benchView.classList.add('hidden');

    dashboard.innerHTML = benches.map(b => `
        <article class="treePanel">
            <div class="treeHead">
                <div>
                    <h2>${b.label}</h2>
                    <p class="muted">Level ${b.level} • ${b.xp} XP</p>
                </div>
                <div class="pointsBox">
                    <span>Available Points</span>
                    <strong>${b.availablePoints}</strong>
                </div>
            </div>
            <div class="progress"><span style="width:${progressPercent(b.xp, b.xpPerLevel)}%"></span></div>
            <div class="cardStats">
                <div><span>Total Points</span><strong>${b.totalPoints}</strong></div>
                <div><span>Spent</span><strong>${b.spentPoints}</strong></div>
                <div><span>Unlocked</span><strong>${b.unlockedCount}/${b.totalRecipes}</strong></div>
                <div><span>Next</span><strong>${b.nextUnlock ? `${b.nextUnlock.label} (${b.nextUnlock.unlockCost} pts)` : 'Done'}</strong></div>
            </div>
            <div class="skillGrid">
                ${(b.tree || []).map(node => `
                    <div class="skillNode ${node.unlocked ? 'unlocked' : ''} ${node.canBuy ? 'canBuy' : ''}">
                        <img src="${node.image}" onerror="this.style.display='none'" />
                        <div class="nodeInfo">
                            <h3>${node.label}</h3>
                            <p>${node.unlockCost} point${node.unlockCost === 1 ? '' : 's'} • ${node.xpRequired} XP req</p>
                        </div>
                        ${node.unlocked
                            ? '<button disabled>Unlocked</button>'
                            : `<button ${node.canBuy ? '' : 'disabled'} data-unlock="${node.item}" data-bench="${b.benchType}">${node.canBuy ? 'Unlock' : 'Locked'}</button>`}
                        ${renderMaterialOverlay(node.requiredItems)}
                    </div>
                `).join('')}
            </div>
        </article>
    `).join('');

    dashboard.querySelectorAll('[data-unlock]').forEach(btn => {
        btn.addEventListener('click', () => {
            btn.disabled = true;
            btn.textContent = 'Unlocking...';
            post('unlockRecipe', { benchType: btn.dataset.bench, item: btn.dataset.unlock });
        });
    });
}

function renderBench(bench) {
    currentBench = bench;
    title.textContent = bench.label;
    subtitle.textContent = 'Bench crafting. Locked recipes must be unlocked in /crafting first.';
    backBtn.classList.remove('hidden');
    dashboard.classList.add('hidden');
    benchView.classList.remove('hidden');

    document.getElementById('benchLevel').textContent = bench.level;
    document.getElementById('benchXP').textContent = bench.xp;
    document.getElementById('benchPoints').textContent = bench.availablePoints;
    document.getElementById('benchRecipes').textContent = `${bench.unlockedCount}/${bench.totalRecipes}`;
    document.getElementById('benchNext').textContent = bench.nextUnlock ? `${bench.nextUnlock.label} • ${bench.nextUnlock.unlockCost} pts • ${bench.nextUnlock.xpRequired} XP` : 'All recipes unlocked';

    renderRecipes();
}

function renderRecipes() {
    if (!currentBench) return;

    const q = searchInput.value.toLowerCase().trim();
    const filter = filterSelect.value;

    const recipes = currentBench.recipes.filter(r => {
        if (q && !r.label.toLowerCase().includes(q)) return false;
        if (filter === 'craftable' && !r.canCraft) return false;
        if (filter === 'locked' && r.unlocked) return false;
        return true;
    });

    recipeList.innerHTML = recipes.map(r => `
        <article class="recipe ${!r.unlocked ? 'locked' : ''}">
            <img src="${r.image}" onerror="this.style.display='none'" />
            <div>
                <h3>${r.label}</h3>
                <div class="tags">
                    <span class="tag">+${r.xpGain} XP</span>
                    <span class="tag">${r.unlockCost} pts</span>
                    ${r.unlocked ? '<span class="tag good">Unlocked</span>' : `<span class="tag bad">Locked</span>`}
                    ${r.canCraft ? '<span class="tag good">Craftable</span>' : ''}
                </div>
                <div class="requirements">
                    ${r.requiredItems.map(i => `<div class="req ${i.hasEnough ? '' : 'missing'}"><span><img src="${i.image}" onerror="this.style.display='none'" />${i.label}</span><strong>${i.playerAmount}/${i.amount}</strong></div>`).join('')}
                </div>
                <div class="amountRow">
                    <input type="number" min="1" value="1" data-amount="${r.item}" ${r.unlocked ? '' : 'disabled'} />
                    <button ${r.canCraft ? '' : 'disabled'} data-craft="${r.item}">${r.unlocked ? 'Craft' : 'Unlock in /crafting'}</button>
                </div>
            </div>
            ${renderMaterialOverlay(r.requiredItems)}
        </article>
    `).join('') || '<p class="muted">No recipes found.</p>';

    recipeList.querySelectorAll('[data-craft]').forEach(btn => {
        btn.addEventListener('click', () => {
            const item = btn.dataset.craft;
            const amountInput = recipeList.querySelector(`[data-amount="${item}"]`);
            const amount = Math.max(1, Number(amountInput?.value || 1));
            post('craft', { benchType: currentBench.benchType, item, amount });
        });
    });
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'open') {
        const data = msg.data || {};
        document.body.classList.add('active');
        app.classList.remove('hidden');
        busy.classList.add('hidden');

        if (data.mode === 'bench' && data.bench) {
            renderBench(data.bench);
        } else {
            renderDashboard(data.dashboard || []);
        }
    }

    if (msg.action === 'setBusy') {
        busy.classList.toggle('hidden', !msg.busy);
    }
});

searchInput.addEventListener('input', renderRecipes);
filterSelect.addEventListener('change', renderRecipes);
backBtn.addEventListener('click', () => post('backDashboard'));
closeBtn.addEventListener('click', () => {
    document.body.classList.remove('active');
    app.classList.add('hidden');
    post('close');
});
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
        document.body.classList.remove('active');
        app.classList.add('hidden');
        post('close');
    }
});
