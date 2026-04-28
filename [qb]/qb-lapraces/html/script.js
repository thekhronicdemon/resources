let creatorActive = false;
let raceActive = false;

function byId(id) {
    return document.getElementById(id);
}

function setUiVisibility(visible) {
    document.documentElement.classList.toggle("races-visible", visible);
    document.body.classList.toggle("races-visible", visible);
    document.documentElement.style.background = "transparent";
    document.documentElement.style.backgroundColor = "transparent";
    document.body.style.background = "transparent";
    document.body.style.backgroundColor = "transparent";
    document.documentElement.style.display = visible ? "block" : "none";
    document.body.style.display = visible ? "block" : "none";
    document.documentElement.style.visibility = visible ? "visible" : "hidden";
    document.body.style.visibility = visible ? "visible" : "hidden";
    document.documentElement.style.opacity = visible ? "1" : "0";
    document.body.style.opacity = visible ? "1" : "0";

    const container = document.querySelector(".container");
    if (container) {
        container.classList.toggle("is-visible", visible);
        container.style.display = visible ? "block" : "none";
        container.style.visibility = visible ? "visible" : "hidden";
        container.style.opacity = visible ? "1" : "0";
    }
}

function syncVisibility() {
    setUiVisibility(creatorActive || raceActive);
}

function formatRaceMs(value) {
    const total = Math.max(Number(value || 0), 0);
    const minutes = Math.floor(total / 60000);
    const seconds = Math.floor((total % 60000) / 1000);
    const milliseconds = Math.floor(total % 1000);
    return `${String(minutes).padStart(2, "0")}.${String(seconds).padStart(2, "0")}.${String(milliseconds).padStart(3, "0")}`;
}

function formatLegacyTime(value) {
    const total = Math.max(Number(value || 0), 0);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const seconds = Math.floor(total % 60);
    return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function formatDelta(value) {
    if (!value) return "+00.00.000";
    const delta = Number(value || 0);
    const sign = delta > 0 ? "+" : delta < 0 ? "-" : "+";
    return `${sign}${formatRaceMs(Math.abs(delta))}`;
}

function visibleLeaderboardRows(rows) {
    if (!Array.isArray(rows) || rows.length <= 8) {
        return rows || [];
    }

    const currentIndex = rows.findIndex((entry) => entry && entry.isPlayer);
    if (currentIndex === -1) {
        return rows.slice(0, 8);
    }

    const start = Math.max(currentIndex - 3, 0);
    const end = Math.min(start + 8, rows.length);
    return rows.slice(Math.max(end - 8, 0), end);
}

function renderLeaderboard(rows) {
    const list = byId("race-leaderboard");
    const items = visibleLeaderboardRows(rows);
    if (!items.length) {
        list.innerHTML = `<div class="leaderboard-empty">Leaderboard updates at each checkpoint.</div>`;
        return;
    }

    list.innerHTML = items.map((entry) => `
        <article class="leaderboard-row ${entry.isPlayer ? "is-player" : ""}">
            <div class="leaderboard-position">${entry.position || "-"}</div>
            <div class="leaderboard-copy">
                <strong>${entry.name || "Racer"}</strong>
                <span>Lap ${entry.lap || 1} | CP ${entry.checkpoint || 0}</span>
            </div>
            <div class="leaderboard-delta ${entry.deltaLeaderMs > 0 ? "behind" : "ahead"}">
                ${entry.isPlayer ? "+00.00.000" : formatDelta(entry.deltaLeaderMs || 0)}
            </div>
        </article>
    `).join("");
}

function updateCreator(data) {
    const editor = document.querySelector(".editor");
    if (data.active) {
        creatorActive = true;
        editor.classList.add("is-visible");
        byId("editor-racename").innerHTML = `Race: ${data.data.RaceName}`;
        byId("editor-checkpoints").innerHTML = `Checkpoints: ${data.data.Checkpoints.length} / ?`;
        byId("editor-keys-tiredistance").innerHTML = `<span class="key good">]</span> / <span class="key bad">[</span> Tire Distance [${data.data.TireDistance}.0]`;
        if (data.racedata.ClosestCheckpoint !== undefined && data.racedata.ClosestCheckpoint !== 0) {
            byId("editor-keys-delete").innerHTML = `<span class="key bad">8</span> Delete Checkpoint [${data.racedata.ClosestCheckpoint}]`;
        } else {
            byId("editor-keys-delete").innerHTML = "";
        }
    } else if (creatorActive) {
        creatorActive = false;
        editor.classList.remove("is-visible");
    }

    syncVisibility();
}

function updateRace(data) {
    const race = document.querySelector(".race");
    const payload = data.data || {};
    const shouldShow = !!data.active && !!payload.RaceStarted;
    if (!shouldShow) {
        raceActive = false;
        race.classList.remove("is-visible");
        syncVisibility();
        return;
    }

    raceActive = true;
    race.classList.add("is-visible");

    const totalLaps = Number(payload.TotalLaps || 0);
    const leaderboard = Array.isArray(payload.Leaderboard) ? payload.Leaderboard : [];
    const position = Number(payload.Position || 1);

    byId("race-racename").textContent = payload.RaceName || "Race";
    byId("race-position").textContent = `P${position}/${leaderboard.length || 1}`;
    byId("race-lap").textContent = totalLaps === 0 ? "Sprint" : `${payload.CurrentLap || 1}/${totalLaps}`;
    byId("race-checkpoints").textContent = `${payload.CurrentCheckpoint || 0}/${payload.TotalCheckpoints || 0}`;
    byId("race-time").textContent = payload.CurrentLapTimeMs ? formatRaceMs(payload.CurrentLapTimeMs) : formatLegacyTime(payload.Time || 0);
    byId("race-totaltime").textContent = payload.TotalTimeMs ? formatRaceMs(payload.TotalTimeMs) : formatLegacyTime(payload.TotalTime || 0);
    byId("race-gap-leader").textContent = `Leader ${formatDelta(payload.GapLeaderMs || 0)}`;
    byId("race-gap-lastlap").textContent = `Last Lap ${formatDelta(payload.LastLapDeltaMs || 0)}`;

    renderLeaderboard(leaderboard);
    syncVisibility();
}

window.addEventListener("load", () => {
    setUiVisibility(false);
});

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action !== "Update") return;

    if (data.type === "creator") {
        updateCreator(data);
        return;
    }

    if (data.type === "race") {
        updateRace(data);
    }
});
