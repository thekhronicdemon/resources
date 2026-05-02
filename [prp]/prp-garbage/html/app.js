const app = document.getElementById('app');
const jobs = document.getElementById('jobs');
const closeBtn = document.getElementById('closeBtn');

function post(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function closeMenu() {
    app.classList.add('hidden');
    post('close');
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'open') {
        jobs.innerHTML = '';
        if (data.canStopScrap) {
            const stopBtn = document.createElement('button');
            stopBtn.className = 'job-card stop-card';
            stopBtn.innerHTML = '<h2>Stop Scrap Job</h2><p>Cancel the active hard rubbish run and clear the truck load.</p>';
            stopBtn.addEventListener('click', () => {
                app.classList.add('hidden');
                post('stopScrapJob');
            });
            jobs.appendChild(stopBtn);
        }

        (data.areas || []).forEach(area => {
            const btn = document.createElement('button');
            btn.className = 'job-card';
            btn.innerHTML = `<h2>${area.label}</h2><p>${area.description || ''}</p>`;
            btn.addEventListener('click', () => {
                app.classList.add('hidden');
                post('selectJob', { id: area.id });
            });
            jobs.appendChild(btn);
        });
        app.classList.remove('hidden');
    }
});

closeBtn.addEventListener('click', closeMenu);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeMenu();
});
