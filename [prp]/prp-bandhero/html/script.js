const app = document.getElementById("app");
const menu = document.getElementById("menu");
const game = document.getElementById("game");
const songSelect = document.getElementById("songSelect");
const difficultySelect = document.getElementById("difficultySelect");
const startButton = document.getElementById("startButton");
const closeButton = document.getElementById("closeButton");
const modeTitle = document.getElementById("modeTitle");
const help = document.getElementById("help");
const lanesEl = document.getElementById("lanes");
const songName = document.getElementById("songName");
const statusEl = document.getElementById("status");
const keysHelp = document.getElementById("keysHelp");

const scoreEl = document.getElementById("score");
const comboEl = document.getElementById("combo");
const missesEl = document.getElementById("misses");

const keySets = {
    easy: ["a", "s", "d", "f"],
    hard: ["a", "s", "d", "f", "g", "h"],
    expert: ["a", "s", "d", "f", "g", "h"]
};

const hitWindow = 170;
const travelMs = 2200;
const judgementBottom = 80;

let mode = "play";
let songs = [];
let currentSong = null;
let currentDifficulty = "easy";
let audio = null;
let chart = [];
let liveNotes = [];
let animationFrame = null;
let score = 0;
let combo = 0;
let misses = 0;
let pressed = {};
let activeHolds = {};
let editorChart = [];

window.addEventListener("message", async (event) => {
    if (event.data.action === "openPlayer") await openMenu("play");
    if (event.data.action === "openEditor") await openMenu("edit");
});

async function openMenu(nextMode) {
    mode = nextMode;
    app.classList.remove("hidden");
    menu.classList.remove("hidden");
    game.classList.add("hidden");

    modeTitle.innerText = mode === "edit" ? "Admin Chart Editor" : "Select Song";

    help.innerHTML = mode === "edit"
        ? "Pick a song and difficulty. Tap keys live while the song plays. Hold keys to create hold notes. ENTER saves. ESC saves and exits. Song end auto-saves."
        : "Pick a song and difficulty. Easy uses A S D F. Hard/Expert use A S D F G H.";

    await loadSongs();
}

async function loadSongs() {
    songSelect.innerHTML = "";
    try {
        const res = await fetch("songs/songs.json?t=" + Date.now());
        songs = await res.json();
    } catch (e) {
        songs = [{ id: "numb", title: "Numb", artist: "Linkin Park", file: "numb.mp3" }];
    }

    songs.forEach(song => {
        const option = document.createElement("option");
        option.value = song.id;
        option.textContent = `${song.title}${song.artist ? " - " + song.artist : ""}`;
        songSelect.appendChild(option);
    });
}

startButton.onclick = async () => {
    currentSong = songs.find(s => s.id === songSelect.value);
    currentDifficulty = difficultySelect.value;
    if (!currentSong) return;

    if (mode === "edit") startEditor();
    else startPlayer();
};

closeButton.onclick = () => closeAll();

async function loadChart(songId, difficulty) {
    try {
        const res = await fetch(`https://${GetParentResourceName()}/loadChart`, {
            method: "POST",
            body: JSON.stringify({
                songId: songId,
                difficulty: difficulty
            })
        });

        const data = await res.json();
        if (data && data.ok && Array.isArray(data.notes)) {
            return data.notes;
        }
    } catch (e) {
        console.log("Failed to load live chart", e);
    }

    return [];
}

function setupGameScreen() {
    menu.classList.add("hidden");
    game.classList.remove("hidden");
    lanesEl.innerHTML = "";

    const keys = keySets[currentDifficulty];
    keysHelp.innerText = keys.map(k => k.toUpperCase()).join(" ");

    keys.forEach((key, index) => {
        const lane = document.createElement("div");
        lane.className = "lane";
        lane.dataset.lane = index;

        const line = document.createElement("div");
        line.className = "judgementLine";

        const label = document.createElement("div");
        label.className = "keyLabel";
        label.innerText = key.toUpperCase();

        lane.appendChild(line);
        lane.appendChild(label);
        lanesEl.appendChild(lane);
    });

    songName.innerText = `${currentSong.title}${currentSong.artist ? " - " + currentSong.artist : ""} / ${currentDifficulty.toUpperCase()}`;
}

async function startPlayer() {
    setupGameScreen();

    score = 0; combo = 0; misses = 0;
    updateStats();

    statusEl.innerText = "Loading latest server chart...";
    chart = await loadChart(currentSong.id, currentDifficulty);

    liveNotes = chart.map((n, i) => ({
        id: i,
        time: Number(n.time || 0),
        lane: Number(n.lane || 0),
        duration: Number(n.duration || 0),
        hit: false,
        missed: false,
        holding: false,
        completed: false
    }));

    audio = new Audio(`songs/${currentSong.file}`);
    audio.addEventListener("ended", () => statusEl.innerText = "Song finished");
    audio.play();

    statusEl.innerText = liveNotes.length > 0
        ? `Playing LIVE chart: ${liveNotes.length} notes`
        : `No chart found for ${currentDifficulty.toUpperCase()}. Use /bandheroedit first.`;

    cancelAnimationFrame(animationFrame);
    gameLoop();
}

function startEditor() {
    setupGameScreen();

    editorChart = [];
    activeHolds = {};
    score = 0; combo = 0; misses = 0;
    updateStats();

    audio = new Audio(`songs/${currentSong.file}`);
    audio.addEventListener("ended", () => {
        finishActiveHolds();
        saveChart(false);
        statusEl.innerText = "Song ended. Chart auto-saved.";
    });

    audio.play();
    statusEl.innerText = "Recording admin chart...";

    cancelAnimationFrame(animationFrame);
    editorLoop();
}

function currentMs() {
    if (!audio) return 0;
    return audio.currentTime * 1000;
}

function gameLoop() {
    renderNotes(currentMs());
    animationFrame = requestAnimationFrame(gameLoop);
}

function editorLoop() {
    renderEditorPreview();
    animationFrame = requestAnimationFrame(editorLoop);
}

function renderNotes(now) {
    document.querySelectorAll(".note, .holdTail").forEach(el => el.remove());

    const laneEls = [...document.querySelectorAll(".lane")];
    const laneHeight = lanesEl.clientHeight;
    const judgeY = laneHeight - judgementBottom;

    liveNotes.forEach(note => {
        if (note.completed || note.missed) return;

        if (!note.hit && now - note.time > hitWindow) {
            note.missed = true;
            misses++;
            combo = 0;
            updateStats();
            return;
        }

        if (note.holding) {
            const key = keySets[currentDifficulty][note.lane];
            if (!pressed[key] && now < note.time + note.duration - 120) {
                note.holding = false;
                note.missed = true;
                misses++;
                combo = 0;
                updateStats();
            }

            if (now >= note.time + note.duration) {
                note.completed = true;
                score += 50;
                combo++;
                updateStats();
            }
        }

        const y = judgeY - ((note.time - now) / travelMs) * laneHeight;
        const lane = laneEls[note.lane];
        if (!lane || y < -160 || y > laneHeight + 120) return;

        if (note.duration > 0) {
            const tailStart = y;
            const tailEnd = judgeY - (((note.time + note.duration) - now) / travelMs) * laneHeight;
            const tail = document.createElement("div");
            tail.className = "holdTail";
            tail.style.top = `${Math.min(tailStart, tailEnd)}px`;
            tail.style.height = `${Math.abs(tailEnd - tailStart) + 30}px`;
            lane.appendChild(tail);
        }

        if (!note.hit) {
            const el = document.createElement("div");
            el.className = "note";
            el.style.top = `${y}px`;
            lane.appendChild(el);
        }
    });
}

function renderEditorPreview() {
    document.querySelectorAll(".lane").forEach(lane => lane.classList.remove("hit"));

    Object.keys(pressed).forEach(key => {
        if (!pressed[key]) return;
        const laneIndex = keySets[currentDifficulty].indexOf(key);
        const lane = document.querySelector(`.lane[data-lane="${laneIndex}"]`);
        if (lane) lane.classList.add("hit");
    });

    scoreEl.innerText = editorChart.length;
    comboEl.innerText = "REC";
    missesEl.innerText = "0";
}

function tryHit(key) {
    if (mode !== "play") return;

    const keys = keySets[currentDifficulty];
    const lane = keys.indexOf(key);
    if (lane === -1) return;

    const now = currentMs();
    let target = null;
    let best = Infinity;

    liveNotes.forEach(note => {
        if (note.lane !== lane || note.hit || note.missed || note.completed) return;
        const diff = Math.abs(note.time - now);
        if (diff < best && diff <= hitWindow) {
            best = diff;
            target = note;
        }
    });

    if (!target) {
        combo = 0;
        misses++;
        updateStats();
        return;
    }

    target.hit = true;

    if (target.duration > 0) {
        target.holding = true;
        score += 100;
    } else {
        target.completed = true;
        score += 100;
        combo++;
    }

    updateStats();
}

document.addEventListener("keydown", (e) => {
    const key = e.key.toLowerCase();

    if (key === "escape") {
        if (mode === "edit" && game && !game.classList.contains("hidden")) {
            finishActiveHolds();
            saveChart(true);
            return;
        }

        closeAll();
        return;
    }

    if (key === "enter" && mode === "edit" && game && !game.classList.contains("hidden")) {
        finishActiveHolds();
        saveChart(false);
        return;
    }

    const keys = keySets[currentDifficulty] || [];
    if (!keys.includes(key)) return;

    if (pressed[key]) return;
    pressed[key] = true;

    if (mode === "edit" && game && !game.classList.contains("hidden")) {
        activeHolds[key] = {
            time: Math.round(currentMs()),
            lane: keys.indexOf(key)
        };
        statusEl.innerText = `Recording note ${key.toUpperCase()}...`;
    } else {
        tryHit(key);
    }
});

document.addEventListener("keyup", (e) => {
    const key = e.key.toLowerCase();
    pressed[key] = false;

    if (mode !== "edit") return;
    if (!activeHolds[key]) return;

    const start = activeHolds[key];
    const end = Math.round(currentMs());
    const duration = Math.max(0, end - start.time);

    const note = { time: start.time, lane: start.lane };
    if (duration >= 180) note.duration = duration;

    editorChart.push(note);
    delete activeHolds[key];

    statusEl.innerText = `Notes recorded: ${editorChart.length}`;
});

function finishActiveHolds() {
    Object.keys(activeHolds).forEach(key => {
        const start = activeHolds[key];
        const end = Math.round(currentMs());
        const duration = Math.max(0, end - start.time);

        const note = { time: start.time, lane: start.lane };
        if (duration >= 180) note.duration = duration;

        editorChart.push(note);
        delete activeHolds[key];
    });
}

async function saveChart(closeAfter) {
    if (!currentSong) return;

    await fetch(`https://${GetParentResourceName()}/saveChart`, {
        method: "POST",
        body: JSON.stringify({
            songId: currentSong.id,
            difficulty: currentDifficulty,
            notes: editorChart.sort((a, b) => a.time - b.time)
        })
    });

    statusEl.innerText = `Saved ${editorChart.length} notes for ${currentDifficulty.toUpperCase()}`;

    fetch(`https://${GetParentResourceName()}/notify`, {
        method: "POST",
        body: JSON.stringify({
            message: `Saved ${currentSong.title} ${currentDifficulty.toUpperCase()} chart (${editorChart.length} notes)`
        })
    });

    if (closeAfter) setTimeout(closeAll, 250);
}

function updateStats() {
    scoreEl.innerText = score;
    comboEl.innerText = combo;
    missesEl.innerText = misses;
}

function closeAll() {
    if (audio) {
        audio.pause();
        audio.currentTime = 0;
        audio = null;
    }

    cancelAnimationFrame(animationFrame);
    app.classList.add("hidden");
    menu.classList.add("hidden");
    game.classList.add("hidden");

    fetch(`https://${GetParentResourceName()}/close`, {
        method: "POST",
        body: "{}"
    });
}
