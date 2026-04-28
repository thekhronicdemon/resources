const tablet = document.getElementById("tablet-root");
const modalLayer = document.getElementById("modal-layer");
const toast = document.getElementById("toast");
const sidebarStack = document.getElementById("sidebar-stack");
const sidebarAppLabel = document.getElementById("sidebar-app-label");
const sidebarPanelLabel = document.getElementById("sidebar-panel-label");

const APP_ICONS = {
    home: "home",
    racing: "flag",
    business: "briefcase",
    ads: "bullhorn",
    crypto: "chip",
    mdt: "shield",
    admin: "settings",
    crime: "search",
    boosting: "bolt",
    royale: "map"
};

const PANEL_DEFAULTS = {
    home: "home",
    racing: "feed",
    business: "overview",
    ads: "feed",
    crypto: "overview",
    mdt: "overview",
    admin: "overview"
};

const PANEL_LABELS = {
    home: { home: "Device apps" },
    racing: {
        feed: "Live grid",
        host: "Hosted race",
        tracks: "Track boards",
        rewards: "Daily rewards",
        settings: "Race tools"
    },
    business: {
        overview: "Overview",
        staff: "Staff",
        chat: "Employee chat",
        finance: "Money and ads"
    },
    ads: {
        feed: "City board",
        create: "Post ad"
    },
    admin: {
        overview: "Control surface",
        races: "Track control",
        moderation: "Moderation"
    },
    mdt: {
        overview: "Open cases",
        suspects: "Suspect search",
        reports: "Report editor",
        personnel: "Personnel"
    },
    crypto: {
        overview: "Rig status",
        jobs: "Rig queue",
        settings: "Rig tools"
    }
};

const state = {
    open: false,
    tab: "home",
    panels: {
        racing: "feed",
        business: "overview",
        ads: "feed",
        crypto: "overview",
        mdt: "overview",
        admin: "overview"
    },
    apps: [],
    player: {},
    data: {
        status: { activeMining: [] },
        permissions: { admin: false, leo: false },
        business: { success: false, employees: [], messages: [] },
        ads: { success: true, items: [] },
        admin: { success: false },
        mdt: { success: false, reports: [] },
        racing: {
            success: false,
            tracks: [],
            personalTracks: [],
            publicRaces: [],
            hotTracks: [],
            popularTracks: [],
            newTracks: [],
            myHostedRace: null,
            currentRace: null,
            canCreateTracks: false,
            raceSetupAllowed: false,
            canManageAllTracks: false,
            profile: { nickname: "Racer", rating: 0, totalRaces: 0 },
            dailyReward: { count: 0, goals: [] },
            lastRace: null
        },
        crypto: 0
    },
    ui: {
        selectedSuspect: null,
        suspectResults: [],
        homeAdIndex: 0,
        claimedRewardTiers: {},
        reportTabs: [{ id: "home", label: "Home", kind: "home" }],
        activeReportTab: "home",
        reportSearchOpen: false,
        reportSearchQuery: "",
        reportSearchResults: [],
        selectedChargeEntries: [],
        reportEvidence: [],
        officerResults: [],
        selectedOfficer: null,
        businessReplyTo: null,
        businessEditId: null,
        showDeletedRecords: false
    }
};

let toastTimer = null;
let homeAdTimer = null;

function post(name, data = {}) {
    return fetch(`https://prp-tablet/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data)
    }).then((response) => response.json());
}

function $(selector) {
    return document.querySelector(selector);
}

function escapeHtml(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "\"": "&quot;",
        "'": "&#039;"
    }[char]));
}

function money(value) {
    return `$${Math.round(Number(value || 0)).toLocaleString("en-US")}`;
}

function qbit(value) {
    return `${Number(value || 0).toFixed(6)} Qbit`;
}

function clamp(value, min, max) {
    const number = Number(value) || 0;
    return Math.min(Math.max(number, min), max);
}

function eta(seconds) {
    const safe = Math.max(Number(seconds || 0), 0);
    const mins = Math.floor(safe / 60);
    const secs = Math.floor(safe % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
}

function fullName(player) {
    const charinfo = (player && player.charinfo) || {};
    const first = charinfo.firstname || player.firstname || "Driver";
    const last = charinfo.lastname || player.lastname || "";
    return `${first} ${last}`.trim();
}

function joinMeta(...parts) {
    return parts.map((part) => String(part || "").trim()).filter(Boolean).join(" | ");
}

function rewardTierKey(tier) {
    const value = Number(tier);
    if (!Number.isFinite(value) || value <= 0) {
        return null;
    }
    return String(value);
}

function mergeClaimedRewardState(racing) {
    if (!racing || !racing.dailyReward || !Array.isArray(racing.dailyReward.goals)) {
        return racing;
    }

    const rememberedClaims = { ...(state.ui.claimedRewardTiers || {}) };
    let changed = false;

    const goals = racing.dailyReward.goals.map((goal) => {
        const key = rewardTierKey(goal.races);
        if (goal.claimed && key) {
            rememberedClaims[key] = true;
        }

        if (!key || !rememberedClaims[key]) {
            return goal;
        }

        if (goal.claimed !== true || goal.claimable !== false) {
            changed = true;
        }

        return {
            ...goal,
            claimed: true,
            claimable: false
        };
    });

    state.ui.claimedRewardTiers = rememberedClaims;
    if (!changed) {
        return racing;
    }

    return {
        ...racing,
        dailyReward: {
            ...racing.dailyReward,
            goals
        }
    };
}

function rememberClaimedRewardTier(tier) {
    const key = rewardTierKey(tier);
    if (!key) {
        return;
    }

    state.ui.claimedRewardTiers = {
        ...(state.ui.claimedRewardTiers || {}),
        [key]: true
    };

    state.data.racing = mergeClaimedRewardState(state.data.racing);
}

function setNodeText(selector, value) {
    const node = $(selector);
    if (node) {
        node.textContent = value;
    }
}

function setNodeValue(selector, value) {
    const node = $(selector);
    if (node) {
        node.value = value == null ? "" : value;
    }
}

function formatRaceMs(value) {
    const total = Math.max(Number(value || 0), 0);
    const minutes = Math.floor(total / 60000);
    const seconds = Math.floor((total % 60000) / 1000);
    const milliseconds = Math.floor(total % 1000);
    return `${String(minutes).padStart(2, "0")}.${String(seconds).padStart(2, "0")}.${String(milliseconds).padStart(3, "0")}`;
}

function formatDeltaMs(value) {
    const delta = Number(value || 0);
    const sign = delta > 0 ? "+" : delta < 0 ? "-" : "";
    return `${sign}${formatRaceMs(Math.abs(delta))}`;
}

function setMessage(id, message, tone = "neutral") {
    const node = document.getElementById(id);
    if (!node) return;
    node.textContent = message || "";
    node.dataset.tone = message ? tone : "";
}

function showToast(message, tone = "neutral") {
    clearTimeout(toastTimer);
    toast.textContent = message || "";
    toast.dataset.tone = tone;
    toast.classList.toggle("hidden", !message);
    if (!message) return;
    toastTimer = setTimeout(() => {
        toast.classList.add("hidden");
    }, 3200);
}

function syncClock() {
    const now = new Date();
    document.getElementById("system-time").textContent = now.toLocaleTimeString([], {
        hour: "numeric",
        minute: "2-digit"
    });
}

function isAppVisible(app) {
    if (!app) return false;
    const permissions = state.data.permissions || {};
    if (app.adminOnly && !permissions.admin) return false;
    if (app.leoOnly && !(permissions.leo || permissions.admin)) return false;
    return true;
}

function visibleApps() {
    return state.apps.filter(isAppVisible);
}

function currentPanel(app = state.tab) {
    return state.panels[app] || PANEL_DEFAULTS[app] || "overview";
}

function raceBadge(label, tone = "") {
    return `<span class="pill ${tone}">${escapeHtml(label)}</span>`;
}

function pageLabel(appId) {
    if (appId === "home") return "Home";
    return visibleApps().find((entry) => entry.id === appId)?.label || appId;
}

function sidebarItemsFor(app) {
    if (app === "home") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            ...visibleApps().map((entry) => ({
                kind: "app",
                app: entry.id,
                icon: APP_ICONS[entry.id] || "home",
                label: entry.label || entry.id,
                disabled: entry.disabled === true
            }))
        ];
    }

    if (app === "racing") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            { kind: "panel", app: "racing", panel: "feed", icon: "flag", label: "Live Grid" },
            { kind: "panel", app: "racing", panel: "host", icon: "users", label: "Hosted Race" },
            { kind: "panel", app: "racing", panel: "tracks", icon: "map", label: "Tracks" },
            { kind: "panel", app: "racing", panel: "rewards", icon: "trophy", label: "Rewards" },
            { kind: "panel", app: "racing", panel: "settings", icon: "settings", label: "Settings" }
        ];
    }

    if (app === "business") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            { kind: "panel", app: "business", panel: "overview", icon: "briefcase", label: "Overview" },
            { kind: "panel", app: "business", panel: "staff", icon: "users", label: "Staff" },
            { kind: "panel", app: "business", panel: "chat", icon: "chat", label: "Chat" },
            { kind: "panel", app: "business", panel: "finance", icon: "cash", label: "Finance" }
        ];
    }

    if (app === "ads") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            { kind: "panel", app: "ads", panel: "feed", icon: "bullhorn", label: "Board" },
            { kind: "panel", app: "ads", panel: "create", icon: "note", label: "Create" }
        ];
    }

    if (app === "admin") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            { kind: "panel", app: "admin", panel: "overview", icon: "settings", label: "Overview" },
            { kind: "panel", app: "admin", panel: "races", icon: "flag", label: "Tracks" },
            { kind: "panel", app: "admin", panel: "moderation", icon: "shield", label: "Moderation" }
        ];
    }

    if (app === "mdt") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            { kind: "panel", app: "mdt", panel: "overview", icon: "shield", label: "Overview" },
            { kind: "panel", app: "mdt", panel: "suspects", icon: "search", label: "Suspects" },
            { kind: "panel", app: "mdt", panel: "reports", icon: "note", label: "Reports" },
            { kind: "panel", app: "mdt", panel: "personnel", icon: "users", label: "Personnel" }
        ];
    }

    if (app === "crypto") {
        return [
            { kind: "app", app: "home", icon: "home", label: "Home" },
            { kind: "panel", app: "crypto", panel: "overview", icon: "chip", label: "Overview" },
            { kind: "panel", app: "crypto", panel: "jobs", icon: "clock", label: "Jobs" },
            { kind: "panel", app: "crypto", panel: "settings", icon: "settings", label: "Tools" }
        ];
    }

    return [{ kind: "app", app: "home", icon: "home", label: "Home" }];
}

function renderSidebar() {
    const app = state.tab;
    const panel = currentPanel(app);
    const items = sidebarItemsFor(app);
    const labelMap = PANEL_LABELS[app] || PANEL_LABELS.home;

    sidebarAppLabel.textContent = pageLabel(app);
    sidebarPanelLabel.textContent = labelMap[panel] || "Device apps";

    sidebarStack.innerHTML = items.map((item) => {
        const isActive = item.kind === "app"
            ? item.app === app
            : (item.app === app && item.panel === panel);

        const attrs = item.disabled
            ? "disabled"
            : item.kind === "app"
                ? `data-open-app="${escapeHtml(item.app)}"`
                : `data-open-panel="${escapeHtml(item.panel)}" data-panel-app="${escapeHtml(item.app)}"`;

        return `
            <button class="sidebar-link ${isActive ? "active" : ""} ${item.disabled ? "muted" : ""}" ${attrs} aria-label="${escapeHtml(item.label)}" title="${escapeHtml(item.label)}">
                <svg><use href="#icon-${escapeHtml(item.icon)}"></use></svg>
            </button>
        `;
    }).join("");
}

function syncView() {
    const activeApp = state.tab;
    const activePanel = currentPanel(activeApp);
    tablet.dataset.activeApp = activeApp;

    document.querySelectorAll(".page").forEach((page) => {
        page.classList.toggle("active", page.dataset.page === activeApp);
    });

    document.querySelectorAll(".app-panel").forEach((panel) => {
        panel.classList.toggle("active", panel.dataset.app === activeApp && panel.dataset.panel === activePanel);
    });

    renderSidebar();
    document.getElementById("page-status").textContent = activeApp === "home"
        ? "Device Apps"
        : `${pageLabel(activeApp)} - ${sidebarPanelLabel.textContent}`;
}

function setView(app, panel = null) {
    state.tab = app;
    if (app !== "home") {
        state.panels[app] = panel || currentPanel(app);
    }
    syncView();
}

function closeModal() {
    modalLayer.classList.add("hidden");
    document.querySelectorAll(".modal-card").forEach((card) => card.classList.remove("active"));
}

function openModal(name, payload = {}) {
    closeModal();
    modalLayer.classList.remove("hidden");
    const card = document.querySelector(`[data-modal="${name}"]`);
    if (!card) return;
    card.classList.add("active");

    if (name === "create-track") {
        $("#track-name-input").value = "";
        $("#track-name-input").focus();
    }

    if (name === "host-race") {
        $("#host-track-id").value = payload.raceId || "";
        $("#host-track-title").textContent = payload.name || "Open Race";
        $("#host-race-laps").value = payload.laps || 3;
        $("#host-race-buyin").value = payload.buyIn || 0;
        $("#host-race-jackpot").value = payload.hostJackpot || 0;
        $("#host-race-countdown").value = payload.countdownSeconds || 10;
        $("#host-race-maxplayers").value = payload.maxPlayers || 10;
        $("#host-race-password").value = "";
        $("#host-race-ghostcars").checked = payload.ghostCars === true;
        $("#host-race-laps").focus();
    }

    if (name === "private-race") {
        $("#private-race-password").value = "";
        $("#private-race-password").focus();
    }

    if (name === "rename-track") {
        $("#rename-track-id").value = payload.raceId || "";
        $("#rename-track-input").value = payload.name || "";
        $("#rename-track-input").focus();
    }
}

function activeHomeAd() {
    const ads = ((state.data.ads || {}).items) || [];
    if (!ads.length) return null;
    const index = clamp(state.ui.homeAdIndex, 0, Math.max(ads.length - 1, 0)) % ads.length;
    return ads[index];
}

function renderHome() {
    const business = state.data.business || {};
    const job = business.job || {};
    const racing = state.data.racing || {};
    const ad = activeHomeAd();
    const adCard = $("#home-ad-card");

    setNodeText("#welcome-name", fullName(state.player));
    setNodeText("#home-business", job.label || "Offline");
    setNodeText("#home-open-races", String((racing.publicRaces || []).length));
    setNodeText("#home-rating", String((racing.profile && racing.profile.rating) || 0));

    if (ad) {
        $("#home-ad-badge").textContent = `${ad.jobName || "City"} Broadcast`;
        $("#home-ad-title").textContent = ad.title || "City Board";
        $("#home-ad-copy").textContent = ad.body || "Open Ads to see what is live in the city.";
        $("#home-ad-author").textContent = `${ad.authorName || "Unknown"} • ${ad.createdAt || ""}`;
        adCard.style.backgroundImage = ad.backgroundUrl
            ? `linear-gradient(120deg, rgba(8, 10, 16, 0.22), rgba(8, 10, 16, 0.9)), url("${ad.backgroundUrl}")`
            : "";
    } else {
        $("#home-ad-badge").textContent = "Latest Advertisement";
        $("#home-ad-title").textContent = "City board is warming up";
        $("#home-ad-copy").textContent = "Drop an ad with a background image and it will rotate here on the home screen.";
        $("#home-ad-author").textContent = "Open Advertisements to post your first promo.";
        adCard.style.backgroundImage = "";
    }

    if (ad) {
        $("#home-ad-author").textContent = joinMeta(ad.authorName || "Unknown", ad.createdAt || "");
    }

    const appGrid = $("#app-grid");
    appGrid.innerHTML = visibleApps().map((app) => {
        const supported = ["racing", "business", "ads", "crypto", "mdt", "admin"].includes(app.id) && !app.disabled;
        const icon = APP_ICONS[app.id] || "home";
        let statusText = "Soon";

        if (app.id === "racing") {
            statusText = `${(racing.publicRaces || []).length} live`;
        } else if (app.id === "business") {
            statusText = job.label || "Offline";
        } else if (app.id === "ads") {
            statusText = `${((state.data.ads || {}).items || []).length} ads`;
        } else if (app.id === "crypto") {
            statusText = `${(((state.data.status || {}).activeMining) || []).length} active`;
        } else if (app.id === "mdt") {
            statusText = `${((state.data.mdt || {}).openReports) || 0} open`;
        } else if (app.id === "admin") {
            statusText = `${(((state.data.admin || {}).summary) || {}).reports || 0} reports`;
        }

        return `
            <button class="app-tile ${app.disabled ? "is-disabled" : ""}" ${supported ? `data-open-app="${escapeHtml(app.id)}"` : `data-disabled-app="${escapeHtml(app.id)}"`}>
                <span class="app-icon-shell">
                    <svg><use href="#icon-${escapeHtml(icon)}"></use></svg>
                </span>
                <span class="app-name">${escapeHtml(app.label)}</span>
                <strong class="app-status">${escapeHtml(statusText)}</strong>
                <span class="app-copy">${escapeHtml(app.description || "")}</span>
                ${supported ? `<span class="app-link">Open</span>` : `<span class="app-link muted">Stand by</span>`}
            </button>
        `;
    }).join("");
}

function renderRaceRow(race) {
    const tags = [
        raceBadge(race.isPrivate ? "Private" : "Public", race.isPrivate ? "warn" : "good"),
        raceBadge(`${race.laps} laps`),
        raceBadge(`${race.racers}/${race.maxPlayers || 0} racers`),
        raceBadge(`Buy-in ${money(race.buyIn || 0)}`),
        raceBadge(`Jackpot ${money(race.jackpotTotal || 0)}`, "good"),
        raceBadge(race.collisionMode || "Contact")
    ].join("");

    let action = `<button class="row-action accent" data-join-race="${escapeHtml(race.raceId)}">Join Race</button>`;
    if (race.started) {
        action = `<button class="row-action disabled" disabled>Race Live</button>`;
    } else if (race.isJoined) {
        action = `<button class="row-action" data-leave-race>Leave Race</button>`;
    }

    const waypointButton = race.startPoint && race.startPoint.x && race.startPoint.y
        ? `<button class="row-action" data-race-waypoint="${escapeHtml(race.raceId)}">Set Start GPS</button>`
        : "";

    const roster = (race.racersList || []).slice(0, 4).map((racer) => `
        <span class="mini-chip">${escapeHtml(racer.nickname || racer.name)} ${racer.isHost ? "(Host)" : ""}</span>
    `).join("");

    return `
        <article class="race-row">
            <div class="row-tags">${tags}</div>
            <div class="row-main">
                <div class="row-copy">
                    <span class="row-label">Host ${(race.hostProfile && race.hostProfile.nickname) ? escapeHtml(race.hostProfile.nickname) : escapeHtml(race.host || "Unknown")}</span>
                    <h2 class="row-title">${escapeHtml(race.name)}</h2>
                    <div class="mini-chip-row">${roster || '<span class="meta-copy">No racers on the grid yet.</span>'}</div>
                </div>
                <div class="row-metrics">
                    <div><span>1st</span><strong>${money((race.prizeBreakdown || {}).first || 0)}</strong></div>
                    <div><span>2nd</span><strong>${money((race.prizeBreakdown || {}).second || 0)}</strong></div>
                    <div><span>3rd</span><strong>${money((race.prizeBreakdown || {}).third || 0)}</strong></div>
                    <div><span>Start</span><strong>${Number(race.countdownSeconds || 10)}s</strong></div>
                </div>
                <div class="row-actions-inline">
                    ${waypointButton}
                    ${action}
                </div>
            </div>
        </article>
    `;
}

function renderPublicRaces() {
    const racing = state.data.racing || {};
    const publicRaces = racing.publicRaces || [];
    $("#racing-public-count").textContent = String(publicRaces.length);
    $("#racing-track-count").textContent = String((racing.tracks || []).length);
    $("#racing-rating-count").textContent = String((racing.profile && racing.profile.rating) || 0);

    const list = $("#public-race-list");
    if (!publicRaces.length) {
        list.innerHTML = `
            <article class="race-row empty-row">
                <div>
                    <p class="eyebrow">Happening now</p>
                    <h2 class="row-title">No public hosts</h2>
                    <span class="meta-copy">Host a track and fill the grid.</span>
                </div>
            </article>
        `;
        return;
    }

    list.innerHTML = publicRaces.map(renderRaceRow).join("");
}

function renderRaceRoster() {
    const racing = state.data.racing || {};
    const active = racing.myHostedRace || racing.currentRace;
    const list = $("#race-roster-list");

    if (!active || !(active.racersList || []).length) {
        list.innerHTML = `
            <article class="race-row empty-row">
                <div>
                    <h2 class="row-title">No roster yet</h2>
                    <span class="meta-copy">Once racers join the grid they will show here.</span>
                </div>
            </article>
        `;
        return;
    }

    list.innerHTML = active.racersList.map((racer) => `
        <article class="message-card">
            <div class="message-head">
                <strong>${escapeHtml(racer.nickname || racer.name)}</strong>
                <span class="meta-copy">${racer.isHost ? "Host" : "Racer"}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(`${racer.rating || 0} rating`)}
                ${raceBadge(`Lap ${racer.lap || 1}`)}
                ${racer.finished ? raceBadge("Finished", "good") : raceBadge("On grid")}
            </div>
        </article>
    `).join("");
}

function renderMyRace() {
    const racing = state.data.racing || {};
    const hosted = racing.myHostedRace;
    const current = racing.currentRace;
    const card = $("#my-race-card");
    const title = $("#my-race-title");

    if (hosted) {
        title.textContent = hosted.name;
        card.className = "focus-card";
        card.innerHTML = `
            <div class="focus-header">
                <div>
                    <span class="focus-label">${hosted.isPrivate ? "Private host" : "Public host"}</span>
                    <strong>${escapeHtml((hosted.hostProfile && hosted.hostProfile.nickname) || hosted.host || "You")}</strong>
                </div>
                <div class="row-tags">
                    ${raceBadge(`${hosted.racers} racers`, hosted.started ? "danger" : "good")}
                    ${raceBadge(`Jackpot ${money(hosted.jackpotTotal || 0)}`)}
                </div>
            </div>
            <div class="focus-meta">
                <span>${hosted.distance}m route</span>
                <span>${hosted.countdownSeconds || 10}s countdown</span>
                <span>${hosted.collisionMode || "Contact On"}</span>
                <span>${hosted.racers}/${hosted.maxPlayers || 0} racers</span>
                <span>${hosted.buyIn ? `Buy-in ${money(hosted.buyIn)}` : "No buy-in"}</span>
            </div>
            <div class="focus-actions">
                ${hosted.startPoint && hosted.startPoint.x && hosted.startPoint.y ? `<button class="action-button" data-race-waypoint="${escapeHtml(hosted.raceId)}">Set Start GPS</button>` : ""}
                ${hosted.started ? "" : `<button class="action-button primary" data-start-hosted="${escapeHtml(hosted.raceId)}">Start Race</button>`}
                <button class="action-button" data-cancel-hosted="${escapeHtml(hosted.raceId)}">Close Host</button>
            </div>
        `;
        return;
    }

    if (current) {
        title.textContent = current.name;
        card.className = "focus-card";
        card.innerHTML = `
            <div class="focus-header">
                <div>
                    <span class="focus-label">${current.started ? "On grid" : "Joined host"}</span>
                    <strong>${escapeHtml((current.hostProfile && current.hostProfile.nickname) || current.host || "Unknown")}</strong>
                </div>
                <div class="row-tags">
                    ${raceBadge(`Lap count ${current.laps}`)}
                    ${raceBadge(`Pot ${money(current.jackpotTotal || 0)}`, "good")}
                </div>
            </div>
            <div class="focus-meta">
                <span>${current.distance}m route</span>
                <span>${current.racers} linked racers</span>
                <span>${current.collisionMode || "Contact On"}</span>
                <span>${current.maxPlayers || 0} max racers</span>
            </div>
            <div class="focus-actions">
                ${current.startPoint && current.startPoint.x && current.startPoint.y ? `<button class="action-button" data-race-waypoint="${escapeHtml(current.raceId)}">Set Start GPS</button>` : ""}
                <button class="action-button" data-leave-race>Leave Race</button>
            </div>
        `;
        return;
    }

    title.textContent = "No hosted race";
    card.className = "focus-card empty-card";
    card.innerHTML = `<span class="meta-copy">Host your own track, open someone else's line, or join a live grid.</span>`;
}

function renderTrackList(id, tracks, options = {}) {
    const list = document.getElementById(id);
    if (!list) return;

    if (!tracks.length) {
        list.innerHTML = `
            <article class="track-row empty-row">
                <div>
                    <h2 class="row-title">${escapeHtml(options.emptyTitle || "Nothing saved")}</h2>
                    <span class="meta-copy">${escapeHtml(options.emptyCopy || "No tracks loaded.")}</span>
                </div>
            </article>
        `;
        return;
    }

    list.innerHTML = tracks.map((track) => {
        const actionButtons = [
            `<button class="row-action" data-open-host="${escapeHtml(track.raceId)}" data-track-name="${escapeHtml(track.name)}">Host</button>`
        ];

        if (track.canManage || options.allowAdmin) {
            actionButtons.push(`<button class="row-action" data-open-rename="${escapeHtml(track.raceId)}" data-track-name="${escapeHtml(track.name)}">Rename</button>`);
            actionButtons.push(`<button class="row-action" data-delete-track="${escapeHtml(track.raceId)}">Delete</button>`);
        }

        return `
            <article class="track-row">
                <div class="track-copy">
                    <h2 class="row-title">${escapeHtml(track.name)}</h2>
                    <span class="meta-copy">${escapeHtml(track.creator || "Unknown")} - ${Number(track.checkpoints || 0)} checkpoints - ${Number(track.distance || 0)}m</span>
                </div>
                <div class="track-meta">
                    ${raceBadge(`${track.uses || 0} uses`)}
                    ${track.record ? raceBadge(`WR ${track.record.label}`, "good") : raceBadge("No WR")}
                    ${actionButtons.join("")}
                </div>
            </article>
        `;
    }).join("");
}

function renderCompactTrackCollection(id, tracks) {
    const list = document.getElementById(id);
    if (!list) return;

    if (!tracks.length) {
        list.innerHTML = `<span class="meta-copy">No tracks in this board.</span>`;
        return;
    }

    list.innerHTML = tracks.map((track) => `
        <button class="compact-item" data-open-host="${escapeHtml(track.raceId)}" data-track-name="${escapeHtml(track.name)}">
            <strong>${escapeHtml(track.name)}</strong>
            <span>${track.uses || 0} uses</span>
        </button>
    `).join("");
}

function renderRewardBoard() {
    const reward = (state.data.racing || {}).dailyReward || { count: 0, goals: [], progressPercent: 0, resetLabel: "00:00:00" };
    const goals = reward.goals || [];
    const progressPercent = clamp(reward.progressPercent || 0, 0, 100);

    $("#daily-reward-card").innerHTML = `
        <div class="reward-progress">
            <div class="reward-progress-head">
                <strong>${reward.count || 0} races today</strong>
                <span class="meta-copy">Reset in ${escapeHtml(reward.resetLabel || "00:00:00")}</span>
            </div>
            <div class="exp-bar-shell">
                <div class="exp-bar-track">
                    <div class="exp-bar-fill" style="width:${progressPercent}%"></div>
                </div>
                <div class="exp-bar-copy">
                    <span>Daily cache progress</span>
                    <strong>${progressPercent}%</strong>
                </div>
            </div>
            <div class="reward-tier-list">
                ${goals.map((goal) => `
                    <article class="reward-tier ${goal.claimed ? "claimed" : goal.claimable ? "claimable" : ""}">
                        <div>
                            <strong>${goal.races} races</strong>
                            <span>${goal.claimed ? "Claimed" : goal.claimable ? "Ready to claim" : "Locked"}</span>
                        </div>
                        <button class="row-action ${goal.claimable && !goal.claimed ? "accent" : "disabled"}" ${goal.claimable && !goal.claimed ? `data-claim-reward="${goal.races}"` : "disabled"}>
                            ${goal.claimed ? "Claimed" : "Claim"}
                        </button>
                    </article>
                `).join("")}
            </div>
        </div>
    `;
}

function renderRaceProfileCard() {
    const racing = state.data.racing || {};
    const profile = racing.profile || {};
    const lastRace = racing.lastRace;

    $("#race-profile-card").innerHTML = `
        <article class="tool-row"><span>Nickname</span><strong>${escapeHtml(profile.nickname || "Racer")}</strong></article>
        <article class="tool-row"><span>Rating</span><strong>${Number(profile.rating || 0)}</strong></article>
        <article class="tool-row"><span>Total races</span><strong>${Number(profile.totalRaces || 0)}</strong></article>
        <article class="tool-row"><span>Last race</span><strong>${lastRace ? escapeHtml(`${lastRace.name} (${lastRace.time || "N/A"})`) : "No race yet"}</strong></article>
        <article class="tool-row"><span>Last position</span><strong>${lastRace ? (Number(lastRace.position) > 0 ? `#${lastRace.position}` : "DNF") : "N/A"}</strong></article>
    `;

    const nicknameInput = $("#race-nickname-input");
    if (document.activeElement !== nicknameInput) {
        nicknameInput.value = profile.nickname || "";
    }
}

function renderRacing() {
    const racing = state.data.racing || {};
    renderPublicRaces();
    renderMyRace();
    renderRaceRoster();
    renderTrackList("personal-track-list", racing.personalTracks || [], {
        emptyTitle: "No personal tracks",
        emptyCopy: "Make a race zone and save your first line."
    });
    renderCompactTrackCollection("hot-track-list", racing.hotTracks || []);
    renderCompactTrackCollection("popular-track-list", racing.popularTracks || []);
    renderCompactTrackCollection("new-track-list", racing.newTracks || []);
    renderRewardBoard();
    renderRaceProfileCard();

    $("#racing-tool-create-access").textContent = racing.canCreateTracks ? "Unlocked" : "Locked";
    $("#racing-tool-host-access").textContent = racing.raceSetupAllowed ? "Open" : "Locked";
    $("#racing-tool-track-total").textContent = String((racing.personalTracks || []).length);
    $("#racing-tool-host-total").textContent = String((racing.publicRaces || []).length);
}

function renderBusinessOverview() {
    const business = state.data.business || {};
    const job = business.job || {};
    $("#business-label").textContent = job.label || "Business";
    $("#business-income").textContent = `${money(job.dailyIncome || 0)} today`;
    $("#business-balance").textContent = `${money(job.balance || 0)} account balance`;
    $("#toggle-duty").textContent = job.duty ? "Clock off" : "Clock on";
    $("#set-business-waypoint").disabled = !job.waypoint;
    $("#hire-closest").disabled = !job.isBoss;
    $("#hire-by-citizenid").disabled = !job.isBoss;
    $("#business-deposit").disabled = !job.isBoss;
    $("#business-withdraw").disabled = !job.isBoss;

    $("#business-overview-card").innerHTML = business.success ? `
        <article class="tool-row"><span>Role</span><strong>${escapeHtml(job.role || "Staff")}</strong></article>
        <article class="tool-row"><span>Salary</span><strong>${money(job.salary || 0)}</strong></article>
        <article class="tool-row"><span>Duty state</span><strong>${job.duty ? "On duty" : "Off duty"}</strong></article>
        <article class="tool-row"><span>Boss access</span><strong>${job.isBoss ? "Yes" : "No"}</strong></article>
    ` : `
        <article class="tool-row"><span>Status</span><strong>${escapeHtml(business.message || "Unavailable")}</strong></article>
    `;

    $("#business-metrics-card").innerHTML = business.success ? `
        <article class="tool-row"><span>Employees</span><strong>${(business.employees || []).length}</strong></article>
        <article class="tool-row"><span>Chat messages</span><strong>${(business.messages || []).length}</strong></article>
        <article class="tool-row"><span>Waypoint</span><strong>${job.waypoint ? "Ready" : "Missing"}</strong></article>
    ` : "";
}

function renderBusinessStaff() {
    const business = state.data.business || {};
    const job = business.job || {};
    const employees = business.employees || [];
    const list = $("#employee-list");

    if (!business.success) {
        list.innerHTML = `
            <article class="employee-row empty-row">
                <div>
                    <h2 class="row-title">No business access</h2>
                    <span class="meta-copy">${escapeHtml(business.message || "Business unavailable.")}</span>
                </div>
            </article>
        `;
        return;
    }

    if (!employees.length) {
        list.innerHTML = `
            <article class="employee-row empty-row">
                <div>
                    <h2 class="row-title">No employees</h2>
                    <span class="meta-copy">Your staff list will show here.</span>
                </div>
            </article>
        `;
        return;
    }

    list.innerHTML = employees.map((employee) => `
        <article class="employee-row">
            <div>
                <h2 class="row-title">${escapeHtml(employee.name)}</h2>
                <div class="row-tags">
                    ${raceBadge(employee.grade)}
                    ${raceBadge(employee.online ? "Online" : "Offline", employee.online ? "good" : "warn")}
                    ${raceBadge(employee.duty ? "On duty" : "Off duty")}
                    ${employee.isBoss ? raceBadge("Boss", "warn") : ""}
                    ${raceBadge(`Salary ${money(employee.salary || 0)}`)}
                </div>
            </div>
            ${job.isBoss && !employee.isBoss ? `<button class="row-action" data-fire="${escapeHtml(employee.citizenid)}">Fire</button>` : ""}
        </article>
    `).join("");
}

function renderBusinessChat() {
    const business = state.data.business || {};
    const job = business.job || {};
    const list = $("#business-chat-list");
    const context = $("#business-chat-context");
    const messages = business.messages || [];

    if (!business.success) {
        list.innerHTML = `<span class="meta-copy">${escapeHtml(business.message || "Business unavailable.")}</span>`;
        context.classList.add("hidden");
        return;
    }

    if (!messages.length) {
        list.innerHTML = `<span class="meta-copy">No messages yet.</span>`;
        context.classList.add("hidden");
        return;
    }

    list.innerHTML = messages.map((message) => `
        <article class="message-card">
            <div class="message-head">
                <strong>${escapeHtml(message.authorName)}</strong>
                <span class="meta-copy">${escapeHtml(message.createdAt || "")}</span>
            </div>
            ${message.replyMessage ? `
                <div class="message-reply-snippet">
                    <strong>${escapeHtml(message.replyAuthorName || "Reply")}</strong>
                    <span>${escapeHtml(message.replyMessage)}</span>
                </div>
            ` : ""}
            <p>${escapeHtml(message.message)}</p>
            <div class="message-foot">
                <span class="meta-copy">${message.editedAt ? `Edited ${formatStamp(message.editedAt)}` : "Posted"}</span>
                <div class="row-tags">
                    <button class="row-action" data-business-reply="${escapeHtml(message.id)}">Reply</button>
                    ${job.isBoss || message.authorCitizenId === state.player.citizenid ? `
                        <button class="row-action" data-business-edit="${escapeHtml(message.id)}">Edit</button>
                        <button class="row-action" data-business-delete="${escapeHtml(message.id)}">Delete</button>
                    ` : ""}
                </div>
            </div>
        </article>
    `).join("");

    const editing = messages.find((entry) => String(entry.id) === String(state.ui.businessEditId));
    const replying = messages.find((entry) => String(entry.id) === String(state.ui.businessReplyTo));
    if (!editing && !replying) {
        context.classList.add("hidden");
        context.innerHTML = "";
        return;
    }

    if (editing) {
        context.classList.remove("hidden");
        context.innerHTML = `
            <div class="message-head">
                <strong>Editing Message</strong>
                <span class="meta-copy">${escapeHtml(editing.authorName || "You")}</span>
            </div>
            <p>${escapeHtml(editing.message || "")}</p>
        `;
        return;
    }

    context.classList.remove("hidden");
    context.innerHTML = `
        <div class="message-head">
            <strong>Replying To</strong>
            <span class="meta-copy">${escapeHtml(replying.authorName || "Staff")}</span>
        </div>
        <p>${escapeHtml(replying.message || "")}</p>
    `;
}

function renderAdsList(containerId, items, adminMode = false) {
    const list = document.getElementById(containerId);
    if (!list) return;

    if (!items.length) {
        list.innerHTML = `<span class="meta-copy">Nothing posted right now.</span>`;
        return;
    }

    const isAdmin = (state.data.permissions || {}).admin;
    const citizenid = state.player.citizenid;

    list.innerHTML = items.map((item) => {
        const canDelete = adminMode || isAdmin || item.authorCitizenId === citizenid;
        return `
            <article class="message-card ad-card" ${item.backgroundUrl ? `style="background-image:linear-gradient(120deg, rgba(8, 10, 16, 0.32), rgba(8, 10, 16, 0.92)), url('${escapeHtml(item.backgroundUrl)}')"` : ""}>
                <div class="message-head">
                    <strong>${escapeHtml(item.title)}</strong>
                    <span class="meta-copy">${escapeHtml(item.jobName || "City")}</span>
                </div>
                <p>${escapeHtml(item.body)}</p>
                <div class="row-tags">
                    ${item.backgroundUrl ? raceBadge("Image attached", "good") : raceBadge("Text only")}
                </div>
                <div class="message-foot">
                    <span class="meta-copy">${escapeHtml(joinMeta(item.authorName || "Unknown", item.createdAt || ""))}</span>
                    ${canDelete ? `<button class="row-action" data-ad-delete="${escapeHtml(item.id)}">Delete</button>` : ""}
                </div>
            </article>
        `;
    }).join("");
}

function renderBusiness() {
    renderBusinessOverview();
    renderBusinessStaff();
    renderBusinessChat();
}

function renderAds() {
    const items = ((state.data.ads || {}).items) || [];
    renderAdsList("ads-feed-list", items, false);
}

function renderAdmin() {
    const admin = state.data.admin || {};

    $("#admin-summary-card").innerHTML = admin.success ? `
        <article class="tool-row"><span>Saved tracks</span><strong>${(((admin.summary || {}).tracks) || 0)}</strong></article>
        <article class="tool-row"><span>Live races</span><strong>${(((admin.summary || {}).liveRaces) || 0)}</strong></article>
        <article class="tool-row"><span>Advertisements</span><strong>${(((admin.summary || {}).ads) || 0)}</strong></article>
        <article class="tool-row"><span>Reports</span><strong>${(((admin.summary || {}).reports) || 0)}</strong></article>
    ` : `
        <article class="tool-row"><span>Status</span><strong>${escapeHtml(admin.message || "Admin unavailable")}</strong></article>
    `;

    renderTrackList("admin-track-list", (state.data.racing || {}).tracks || [], { allowAdmin: true, emptyTitle: "No tracks", emptyCopy: "Track list empty." });
    renderAdsList("admin-ads-list", admin.ads || [], true);

    const reportList = $("#admin-report-list");
    const reports = admin.reports || [];
    if (!reports.length) {
        reportList.innerHTML = `<span class="meta-copy">No reports to moderate.</span>`;
    } else {
        reportList.innerHTML = reports.map((report) => `
            <article class="message-card">
                <div class="message-head">
                    <strong>${escapeHtml(report.title)}</strong>
                    <span class="meta-copy">${escapeHtml(report.status || "Open")}</span>
                </div>
                <p>${escapeHtml(report.suspectName || "Unknown suspect")} - ${escapeHtml(report.charges || "No charges")}</p>
                <div class="message-foot">
                    <span class="meta-copy">${escapeHtml(report.createdAt || "")}</span>
                    <button class="row-action" data-delete-report="${escapeHtml(report.id)}">Delete</button>
                </div>
            </article>
        `).join("");
    }
}

function formatStamp(value) {
    if (!value) return "Now";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return date.toLocaleString([], {
        month: "2-digit",
        day: "2-digit",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit"
    });
}

function reportKey(entry) {
    return String(entry && (entry.id || entry.reportId || entry.label || "draft"));
}

function ensureReportTabs() {
    const tabs = Array.isArray(state.ui.reportTabs) ? state.ui.reportTabs : [];
    if (!tabs.find((tab) => tab.id === "home")) {
        tabs.unshift({ id: "home", label: "Home", kind: "home" });
    }
    state.ui.reportTabs = tabs;
}

function reportById(id) {
    return ((state.data.mdt || {}).reports || []).find((report) => String(report.id) === String(id));
}

function normalizeChargeEntry(entry) {
    return {
        chargeId: entry.chargeId || entry.id || null,
        category: entry.category || "General",
        label: entry.label || "Charge",
        scope: entry.scope || "Principal",
        fineAmount: Number(entry.fineAmount || entry.fine || 0),
        jailTime: Number(entry.jailTime || entry.jail || 0),
        quantity: Math.max(1, Number(entry.quantity || 1)),
        description: entry.description || ""
    };
}

function selectedChargeEntries() {
    return Array.isArray(state.ui.selectedChargeEntries) ? state.ui.selectedChargeEntries : [];
}

function chargeTotals() {
    return selectedChargeEntries().reduce((totals, entry) => {
        totals.fine += Number(entry.fineAmount || 0) * Number(entry.quantity || 1);
        totals.jail += Number(entry.jailTime || 0) * Number(entry.quantity || 1);
        return totals;
    }, { fine: 0, jail: 0 });
}

function chargeSummaryText() {
    return selectedChargeEntries().map((entry) => {
        const qty = Math.max(1, Number(entry.quantity || 1));
        return qty > 1 ? `${qty}x ${entry.label}` : entry.label;
    }).join(", ");
}

function openReportTab(report) {
    ensureReportTabs();
    const id = report && report.id ? String(report.id) : "draft";
    const label = (report && report.title) ? report.title : "New Report";
    const existing = state.ui.reportTabs.find((tab) => String(tab.id) === id);
    if (existing) {
        existing.label = label;
    } else {
        state.ui.reportTabs.push({ id, label, kind: id === "draft" ? "draft" : "report" });
    }
    state.ui.activeReportTab = id;
}

function activateReportTab(tabId) {
    ensureReportTabs();
    if (tabId === "home") {
        state.ui.activeReportTab = "home";
        setView("mdt", "overview");
        return;
    }

    state.ui.activeReportTab = String(tabId);
    const report = reportById(tabId);
    if (report) {
        fillReportForm(report);
    } else {
        clearReportForm();
    }
    setView("mdt", "reports");
}

function closeReportTab(tabId) {
    if (tabId === "home") return;
    state.ui.reportTabs = (state.ui.reportTabs || []).filter((tab) => String(tab.id) !== String(tabId));
    if (String(state.ui.activeReportTab) === String(tabId)) {
        state.ui.activeReportTab = "home";
        clearReportForm();
        setView("mdt", "overview");
    } else {
        renderMdtTabs();
    }
}

function renderMdtTabs() {
    ensureReportTabs();
    const strip = $("#mdt-report-tabs");
    strip.innerHTML = state.ui.reportTabs.map((tab) => `
        <button class="report-tab ${String(state.ui.activeReportTab) === String(tab.id) ? "active" : ""}" data-report-tab="${escapeHtml(tab.id)}">
            <span>${escapeHtml(tab.label)}</span>
            ${tab.id !== "home" ? `<span class="report-tab-close" data-close-report-tab="${escapeHtml(tab.id)}">x</span>` : ""}
        </button>
    `).join("") + `
        <button class="report-tab add" data-create-report-tab>+</button>
    `;
}

function renderMdtReportSearch() {
    const panel = $("#mdt-report-search-panel");
    const input = $("#mdt-report-search-input");
    const list = $("#mdt-report-search-results");
    if (!panel || !input || !list) return;

    panel.classList.toggle("hidden", !state.ui.reportSearchOpen);
    if (!state.ui.reportSearchOpen) return;

    if (document.activeElement !== input) {
        input.value = state.ui.reportSearchQuery || "";
    }

    const results = state.ui.reportSearchResults || [];
    list.innerHTML = results.length ? results.map((report) => `
        <article class="message-card compact-card">
            <div class="message-head">
                <strong>${escapeHtml(report.title || `Report ${report.id}`)}</strong>
                <span class="meta-copy">#${escapeHtml(report.id)}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(report.reportType || "Incident")}
                ${raceBadge(report.status || "Open", report.status === "Open" ? "good" : "")}
                ${raceBadge(report.suspectName || "Unknown suspect")}
            </div>
            <div class="message-foot">
                <span class="meta-copy">${formatStamp(report.updatedAt)}</span>
                <button class="row-action accent" data-open-search-report="${escapeHtml(report.id)}">Open Tab</button>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">Search reports or tap + to load recent case tabs.</span>`;
}

function requestMdtReportSearch(showMessage = false) {
    state.ui.reportSearchQuery = ($("#mdt-report-search-input") || {}).value || state.ui.reportSearchQuery || "";
    return post("TabletSearchMdtReports", {
        query: state.ui.reportSearchQuery
    }).then((resp) => {
        state.ui.reportSearchResults = resp.reports || [];
        renderMdtReportSearch();
        if (showMessage) {
            setMessage("mdt-message", resp.message || "Report search updated.", resp.success === false ? "bad" : "good");
        }
        return resp;
    });
}

function renderMdtOverview() {
    const mdt = state.data.mdt || {};
    $("#mdt-summary-card").innerHTML = mdt.success ? `
        <article class="tool-row"><span>Total reports</span><strong>${Number(mdt.reportsCount || 0)}</strong></article>
        <article class="tool-row"><span>Open reports</span><strong>${Number(mdt.openReports || 0)}</strong></article>
        <article class="tool-row"><span>Active warrants</span><strong>${Number(mdt.warrants || 0)}</strong></article>
        <article class="tool-row"><span>Charge library</span><strong>${Number((mdt.chargesCatalog || []).length)}</strong></article>
    ` : `
        <article class="tool-row"><span>Status</span><strong>${escapeHtml(mdt.message || "MDT unavailable")}</strong></article>
    `;

    const assigned = $("#mdt-assigned-reports");
    const assignedReports = mdt.assignedReports || [];
    assigned.innerHTML = assignedReports.length ? assignedReports.map((report) => `
        <article class="message-card compact-card">
            <div class="message-head">
                <strong>${escapeHtml(report.title)}</strong>
                <span class="meta-copy">${escapeHtml(report.reportType || "Incident")}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(report.status || "Open", report.status === "Open" ? "good" : "")}
                ${raceBadge(report.suspectName || "Unknown suspect")}
            </div>
            <div class="message-foot">
                <span class="meta-copy">${formatStamp(report.updatedAt)}</span>
                <button class="row-action" data-load-report="${escapeHtml(report.id)}">Open</button>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No reports assigned to you yet.</span>`;

    const overview = $("#mdt-overview-reports");
    const reports = mdt.reports || [];
    overview.innerHTML = reports.length ? reports.slice(0, 6).map((report) => `
        <article class="message-card compact-card">
            <div class="message-head">
                <strong>${escapeHtml(report.title)}</strong>
                <span class="meta-copy">${escapeHtml(report.status || "Open")}</span>
            </div>
            <p>${escapeHtml(report.suspectName || "Unknown suspect")}</p>
            <div class="message-foot">
                <span class="meta-copy">${formatStamp(report.updatedAt)}</span>
                <button class="row-action" data-load-report="${escapeHtml(report.id)}">Open</button>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No recent MDT reports.</span>`;

    const warningFeed = $("#mdt-warning-feed");
    const warnings = mdt.recentWarnings || [];
    warningFeed.innerHTML = warnings.length ? warnings.map((warning) => `
        <article class="message-card compact-card">
            <div class="message-head">
                <strong>${escapeHtml(warning.officerName)}</strong>
                <span class="meta-copy">${escapeHtml(warning.severity || "Warning")}</span>
            </div>
            <p>${escapeHtml(warning.title)}</p>
            <div class="message-foot">
                <span class="meta-copy">${escapeHtml(warning.issuerName || "Unknown")} • ${formatStamp(warning.createdAt)}</span>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No recent personnel warnings.</span>`;

    const personnelFeed = $("#mdt-personnel-feed");
    const personnel = mdt.personnel || [];
    personnelFeed.innerHTML = personnel.length ? personnel.slice(0, 10).map((officer) => `
        <button class="message-card select-card compact-card" data-select-officer="${escapeHtml(officer.citizenid)}">
            <div class="message-head">
                <strong>${escapeHtml(officer.name)}</strong>
                <span class="meta-copy">${escapeHtml(officer.role || "Officer")}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(officer.department || "Police")}
                ${raceBadge(`${Number(officer.warningCount || 0)} warnings`, Number(officer.warningCount || 0) > 0 ? "warn" : "good")}
            </div>
        </button>
    `).join("") : `<span class="meta-copy">No police roster loaded.</span>`;

    const warrantList = $("#mdt-warrant-list");
    const warrants = mdt.warrantList || [];
    warrantList.innerHTML = warrants.length ? warrants.map((warrant) => `
        <article class="message-card compact-card warrant-card">
            <div class="message-head">
                <strong>${escapeHtml(warrant.name || "Unknown")}</strong>
                <span class="meta-copy">${escapeHtml(warrant.citizenid || "")}</span>
            </div>
            <p>${escapeHtml(warrant.warrantNote || "Active warrant on file.")}</p>
            <div class="message-foot">
                <span class="meta-copy">${escapeHtml((warrant.fingerprint || "NIL") || "NIL")} | ${formatStamp(warrant.updatedAt)}</span>
                <div class="row-tags">
                    <button class="row-action" data-open-warrant="${escapeHtml(warrant.citizenid)}">Open</button>
                    <button class="row-action" data-clear-warrant="${escapeHtml(warrant.citizenid)}">Clear</button>
                </div>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No active warrants.</span>`;
}

function fillSuspectForm(suspect) {
    state.ui.selectedSuspect = suspect;
    setNodeText("#mdt-suspect-name", suspect ? suspect.name : "No suspect selected");
    setNodeValue("#mdt-warrant-input", suspect ? (suspect.warrantNote || "") : "");
    setNodeValue("#mdt-note-input", suspect ? (suspect.note || "") : "");
    setNodeValue("#mdt-mugshot-input", suspect ? (suspect.mugshotUrl || "") : "");
    $("#mdt-warrant-toggle").checked = !!(suspect && suspect.warrantActive);
    $("#mdt-profile-entry-title").value = "";
    $("#mdt-profile-entry-body").value = "";
}

function renderMdtSuspects() {
    const results = state.ui.suspectResults || [];
    const selected = state.ui.selectedSuspect;
    const resultList = $("#mdt-suspect-results");
    const mugshot = $("#mdt-suspect-mugshot");
    const vehicles = $("#mdt-suspect-vehicles");
    const meta = $("#mdt-suspect-meta");
    const entries = $("#mdt-profile-entry-list");
    const deleted = $("#mdt-deleted-records-list");
    const deletedToggle = $("#mdt-show-deleted-records");
    const canViewDeleted = !!((state.data.mdt || {}).canViewDeletedRecords);

    resultList.innerHTML = results.length ? results.map((suspect) => `
        <button class="message-card select-card" data-select-suspect="${escapeHtml(suspect.citizenid)}">
            <div class="message-head">
                <strong>${escapeHtml(suspect.name)}</strong>
                <span class="meta-copy">${escapeHtml(suspect.citizenid)}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(suspect.job || "Unknown")}
                ${suspect.warrantActive ? raceBadge("Warrant", "danger") : raceBadge("Clear", "good")}
            </div>
        </button>
    `).join("") : `<span class="meta-copy">Search results will show here.</span>`;

    if (!selected) {
        mugshot.innerHTML = `<span class="meta-copy">No mugshot on file.</span>`;
        meta.innerHTML = `<article class="tool-row"><span>Details</span><strong>No suspect selected</strong></article>`;
        vehicles.innerHTML = `<span class="meta-copy">Vehicle records will show here.</span>`;
        entries.innerHTML = `<span class="meta-copy">Profile history will show here.</span>`;
        deleted.innerHTML = `<span class="meta-copy">Deleted records will show here.</span>`;
        deletedToggle.disabled = true;
        deletedToggle.textContent = "Show Deleted Records";
        return;
    }

    deletedToggle.disabled = !canViewDeleted;
    deletedToggle.textContent = state.ui.showDeletedRecords ? "Hide Deleted Records" : "Show Deleted Records";

    mugshot.innerHTML = selected.mugshotUrl
        ? `<img src="${escapeHtml(selected.mugshotUrl)}" alt="${escapeHtml(selected.name || "Mugshot")}">`
        : `<span class="meta-copy">No mugshot on file.</span>`;

    meta.innerHTML = `
        <article class="tool-row"><span>Citizen ID</span><strong>${escapeHtml(selected.citizenid)}</strong></article>
        <article class="tool-row"><span>Job</span><strong>${escapeHtml(selected.job || "Unknown")}</strong></article>
        <article class="tool-row"><span>Fingerprint</span><strong>${escapeHtml(selected.fingerprint || "NIL")}</strong></article>
        <article class="tool-row"><span>Reports</span><strong>${(selected.reports || []).length}</strong></article>
    `;

    vehicles.innerHTML = (selected.vehicles || []).length ? (selected.vehicles || []).map((vehicle) => `
        <article class="message-card compact-card">
            <div class="message-head">
                <strong>${escapeHtml(vehicle.plate)}</strong>
                <span class="meta-copy">${escapeHtml(vehicle.vehicle || "Vehicle")}</span>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No vehicles found.</span>`;

    entries.innerHTML = (selected.profileEntries || []).length ? (selected.profileEntries || []).map((entry) => `
        <article class="message-card">
            <div class="message-head">
                <strong>${escapeHtml(entry.title)}</strong>
                <span class="meta-copy">${escapeHtml(entry.entryType || "Note")}</span>
            </div>
            <p>${escapeHtml(entry.body || "")}</p>
            <div class="message-foot">
                <span class="meta-copy">${escapeHtml(entry.authorName || "Unknown")} • ${formatStamp(entry.createdAt)}</span>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No profile history yet.</span>`;

    if (!canViewDeleted) {
        deleted.innerHTML = `<span class="meta-copy">Chief rank, command, or admin access required.</span>`;
        return;
    }

    if (!state.ui.showDeletedRecords) {
        deleted.innerHTML = `<span class="meta-copy">Deleted records are hidden.</span>`;
        return;
    }

    deleted.innerHTML = (selected.deletedRecords || []).length ? (selected.deletedRecords || []).map((entry) => `
        <article class="message-card compact-card">
            <div class="message-head">
                <strong>${escapeHtml(entry.title || entry.recordType || "Deleted Record")}</strong>
                <span class="meta-copy">${escapeHtml(entry.recordType || "Record")}</span>
            </div>
            <p>${escapeHtml(joinMeta(entry.deletedByName || "Unknown Officer", formatStamp(entry.deletedAt)))}</p>
            <div class="row-tags">
                ${entry.payload && entry.payload.reportTitle ? raceBadge(entry.payload.reportTitle) : ""}
                ${entry.payload && entry.payload.warrantNote ? raceBadge(entry.payload.warrantNote) : ""}
                ${entry.payload && entry.payload.evidence && entry.payload.evidence.url ? `<a class="row-action" href="${escapeHtml(entry.payload.evidence.url)}" target="_blank" rel="noreferrer">View File</a>` : ""}
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No deleted records on file.</span>`;
}

function renderReportSuspectCard(report = null) {
    const card = $("#mdt-report-suspect-card");
    if (!card) return;

    if (!report || (!report.suspectName && !report.suspectCitizenId)) {
        card.innerHTML = `<span class="meta-copy">Select or enter a suspect to load mugshot and fingerprint.</span>`;
        return;
    }

    card.innerHTML = `
        <div class="message-head">
            <strong>${escapeHtml(report.suspectName || "Unknown suspect")}</strong>
            <span class="meta-copy">${escapeHtml(report.suspectCitizenId || "")}</span>
        </div>
        <div class="row-tags">
            ${report.suspectMugshotUrl ? `<a class="row-action" href="${escapeHtml(report.suspectMugshotUrl)}" target="_blank" rel="noreferrer">View Mugshot</a>` : raceBadge("No mugshot")}
            ${raceBadge(`Fingerprint ${(report.suspectFingerprint || "NIL") || "NIL"}`)}
        </div>
    `;
}

function refreshReportSuspectCard() {
    const citizenId = ($("#mdt-report-cid") || {}).value || "";
    const suspectName = ($("#mdt-report-name") || {}).value || "";
    if (!citizenId) {
        renderReportSuspectCard(suspectName ? { suspectName } : null);
        return;
    }

    post("TabletGetMdtSuspect", { citizenid: citizenId }).then((resp) => {
        if (resp && resp.success && resp.suspect) {
            if (!($("#mdt-report-name").value || "").trim()) {
                $("#mdt-report-name").value = resp.suspect.name || "";
            }
            renderReportSuspectCard({
                suspectName: resp.suspect.name,
                suspectCitizenId: resp.suspect.citizenid,
                suspectMugshotUrl: resp.suspect.mugshotUrl,
                suspectFingerprint: resp.suspect.fingerprint,
            });
        } else {
            renderReportSuspectCard({
                suspectName,
                suspectCitizenId: citizenId,
            });
        }
    });
}

function clearReportForm() {
    $("#mdt-editor-title").textContent = "New or edit report";
    $("#mdt-report-id").value = "";
    $("#mdt-report-type").value = "Incident";
    $("#mdt-report-title").value = "";
    $("#mdt-report-cid").value = "";
    $("#mdt-report-name").value = "";
    $("#mdt-report-charges").value = "";
    $("#mdt-report-warrants").value = "";
    $("#mdt-report-fine").value = "";
    $("#mdt-report-jail").value = "";
    $("#mdt-report-status").value = "Open";
    $("#mdt-report-details").value = "";
    $("#mdt-report-incident-date").value = "";
    $("#mdt-report-due-date").value = "";
    $("#mdt-report-officers").value = "";
    $("#mdt-charge-search").value = "";
    state.ui.selectedChargeEntries = [];
    state.ui.reportEvidence = [{ label: "", url: "" }];
    state.ui.activeReportTab = "draft";
    openReportTab({ id: "draft", title: "New Report" });
    renderReportSuspectCard(null);
    renderMdtTabs();
    renderMdtReportSearch();
    renderChargeCatalog();
    renderChargeCart();
    renderEvidenceEditor();
}

function fillReportForm(report) {
    if (!report) return;
    $("#mdt-editor-title").textContent = report.title || "Edit report";
    $("#mdt-report-id").value = report.id || "";
    $("#mdt-report-type").value = report.reportType || "Incident";
    $("#mdt-report-title").value = report.title || "";
    $("#mdt-report-cid").value = report.suspectCitizenId || "";
    $("#mdt-report-name").value = report.suspectName || "";
    $("#mdt-report-charges").value = report.charges || "";
    $("#mdt-report-warrants").value = report.warrants || "";
    $("#mdt-report-fine").value = report.fineAmount || 0;
    $("#mdt-report-jail").value = report.jailTime || 0;
    $("#mdt-report-status").value = report.status || "Open";
    $("#mdt-report-details").value = report.details || "";
    $("#mdt-report-incident-date").value = report.incidentDate || "";
    $("#mdt-report-due-date").value = report.dueDate || "";
    $("#mdt-report-officers").value = (report.officers || []).map((officer) => officer.name || officer).join(", ");
    state.ui.selectedChargeEntries = (report.chargeSelections || []).map(normalizeChargeEntry);
    state.ui.reportEvidence = (report.evidence || []).length ? (report.evidence || []).map((entry) => ({
        label: entry.label || "",
        url: entry.url || ""
    })) : [{ label: "", url: "" }];
    openReportTab(report);
    renderReportSuspectCard(report);
    renderMdtTabs();
    renderMdtReportSearch();
    renderChargeCatalog();
    renderChargeCart();
    renderEvidenceEditor();
}

function chargeCatalogResults() {
    const catalog = (state.data.mdt || {}).chargesCatalog || [];
    const query = String($("#mdt-charge-search").value || "").trim().toLowerCase();
    if (!query) return catalog.slice(0, 24);
    return catalog.filter((entry) => {
        const haystack = `${entry.label} ${entry.category} ${entry.scope} ${entry.description || ""}`.toLowerCase();
        return haystack.includes(query);
    }).slice(0, 24);
}

function addChargeToCase(charge) {
    const key = reportKey({ id: charge.chargeId || charge.id || `${charge.label}:${charge.scope}` });
    const existing = selectedChargeEntries().find((entry) => reportKey({ id: entry.chargeId || `${entry.label}:${entry.scope}` }) === key);
    if (existing) {
        existing.quantity = Math.max(1, Number(existing.quantity || 1) + 1);
    } else {
        state.ui.selectedChargeEntries.push(normalizeChargeEntry(charge));
    }
    renderChargeCart();
}

function updateChargeQuantity(key, delta) {
    state.ui.selectedChargeEntries = selectedChargeEntries().map((entry) => {
        const entryKey = reportKey({ id: entry.chargeId || `${entry.label}:${entry.scope}` });
        if (entryKey !== String(key)) return entry;
        return { ...entry, quantity: Math.max(1, Number(entry.quantity || 1) + delta) };
    });
    renderChargeCart();
}

function removeChargeFromCase(key) {
    state.ui.selectedChargeEntries = selectedChargeEntries().filter((entry) => {
        const entryKey = reportKey({ id: entry.chargeId || `${entry.label}:${entry.scope}` });
        return entryKey !== String(key);
    });
    renderChargeCart();
}

function renderChargeCatalog() {
    const catalog = chargeCatalogResults();
    $("#mdt-charge-catalog").innerHTML = catalog.length ? catalog.map((charge) => `
        <article class="charge-card">
            <div class="message-head">
                <strong>${escapeHtml(charge.label)}</strong>
                <span class="meta-copy">${escapeHtml(charge.scope || "Principal")}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(charge.category || "General")}
                ${raceBadge(money(charge.fineAmount || 0))}
                ${raceBadge(`${Number(charge.jailTime || 0)} months`)}
            </div>
            <p>${escapeHtml(charge.description || "")}</p>
            <button class="row-action accent" data-add-charge="${escapeHtml(charge.id)}">Add Charge</button>
        </article>
    `).join("") : `<span class="meta-copy">No charges match that search.</span>`;
}

function renderChargeCart() {
    const cart = $("#mdt-charge-cart");
    const summary = $("#mdt-charge-summary");
    const totals = chargeTotals();
    const summaryText = chargeSummaryText();

    cart.innerHTML = selectedChargeEntries().length ? selectedChargeEntries().map((entry) => {
        const key = reportKey({ id: entry.chargeId || `${entry.label}:${entry.scope}` });
        return `
            <article class="message-card compact-card">
                <div class="message-head">
                    <strong>${escapeHtml(entry.label)}</strong>
                    <span class="meta-copy">${escapeHtml(entry.scope || "Principal")}</span>
                </div>
                <div class="row-tags">
                    ${raceBadge(money(entry.fineAmount || 0))}
                    ${raceBadge(`${Number(entry.jailTime || 0)} months`)}
                    ${raceBadge(`Qty ${Number(entry.quantity || 1)}`)}
                </div>
                <div class="message-foot">
                    <div class="row-tags">
                        <button class="row-action" data-charge-dec="${escapeHtml(key)}">-</button>
                        <button class="row-action" data-charge-inc="${escapeHtml(key)}">+</button>
                        <button class="row-action" data-charge-remove="${escapeHtml(key)}">Remove</button>
                    </div>
                </div>
            </article>
        `;
    }).join("") : `<span class="meta-copy">Selected charges will stack here.</span>`;

    summary.innerHTML = `
        <article class="tool-row"><span>Total fine</span><strong>${money(totals.fine)}</strong></article>
        <article class="tool-row"><span>Total jail</span><strong>${Number(totals.jail)} months</strong></article>
        <article class="tool-row"><span>Charge count</span><strong>${selectedChargeEntries().length}</strong></article>
    `;

    if (summaryText && document.activeElement !== $("#mdt-report-charges")) {
        $("#mdt-report-charges").value = summaryText;
    }

    if (document.activeElement !== $("#mdt-report-fine")) {
        $("#mdt-report-fine").value = totals.fine || 0;
    }

    if (document.activeElement !== $("#mdt-report-jail")) {
        $("#mdt-report-jail").value = totals.jail || 0;
    }
}

function renderEvidenceEditor() {
    const evidence = Array.isArray(state.ui.reportEvidence) && state.ui.reportEvidence.length
        ? state.ui.reportEvidence
        : [{ label: "", url: "" }];

    state.ui.reportEvidence = evidence;
    $("#mdt-evidence-list").innerHTML = evidence.map((entry, index) => `
        <div class="evidence-row">
            <input class="field-input" data-evidence-field="label" data-evidence-index="${index}" value="${escapeHtml(entry.label || "")}" maxlength="80" placeholder="Evidence label">
            <input class="field-input" data-evidence-field="url" data-evidence-index="${index}" value="${escapeHtml(entry.url || "")}" maxlength="255" placeholder="https://image.url/evidence.jpg">
            ${(entry.url || "").trim()
                ? `<a class="evidence-preview" href="${escapeHtml(entry.url || "")}" target="_blank" rel="noreferrer">
                        <img src="${escapeHtml(entry.url || "")}" alt="${escapeHtml(entry.label || "Evidence preview")}">
                   </a>`
                : `<div class="evidence-preview placeholder"><span>Preview</span></div>`}
            <button class="row-action" data-remove-evidence="${index}">Remove</button>
        </div>
    `).join("");
}

function renderMdtReports() {
    const reports = (state.data.mdt || {}).reports || [];
    const list = $("#mdt-report-list");

    list.innerHTML = reports.length ? reports.map((report) => `
        <article class="message-card">
            <div class="message-head">
                <strong>${escapeHtml(report.title)}</strong>
                <span class="meta-copy">${escapeHtml(report.reportType || "Incident")}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(report.status || "Open", report.status === "Open" ? "good" : "")}
                ${raceBadge(report.suspectName || "Unknown suspect")}
                ${raceBadge(money(report.fineAmount || 0))}
                ${raceBadge(`${Number(report.jailTime || 0)} months`)}
            </div>
            <p>${escapeHtml(report.charges || "No charges selected")}</p>
            <div class="message-foot">
                <span class="meta-copy">${formatStamp(report.updatedAt)}</span>
                <div class="row-tags">
                    <button class="row-action" data-load-report="${escapeHtml(report.id)}">Open</button>
                    <button class="row-action" data-delete-report="${escapeHtml(report.id)}">Delete</button>
                </div>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No reports saved yet.</span>`;

    renderMdtTabs();
    renderMdtReportSearch();
    renderChargeCatalog();
    renderChargeCart();
    renderEvidenceEditor();
}

function fillOfficerForm(officer) {
    state.ui.selectedOfficer = officer;
    $("#mdt-officer-name").textContent = officer ? officer.name : "No officer selected";
    $("#mdt-warning-title").value = "";
    $("#mdt-warning-severity").value = "Warning";
    $("#mdt-warning-body").value = "";
}

function renderMdtPersonnel() {
    const mdt = state.data.mdt || {};
    const selected = state.ui.selectedOfficer;
    const canIssueWarnings = !!mdt.canIssueWarnings || !!mdt.success && !!(state.data.permissions || {}).admin;
    const results = (state.ui.officerResults && state.ui.officerResults.length) ? state.ui.officerResults : (mdt.personnel || []);
    const list = $("#mdt-officer-results");
    const meta = $("#mdt-officer-meta");
    const warnings = $("#mdt-officer-warning-list");

    list.innerHTML = results.length ? results.map((officer) => `
        <button class="message-card select-card compact-card" data-select-officer="${escapeHtml(officer.citizenid)}">
            <div class="message-head">
                <strong>${escapeHtml(officer.name)}</strong>
                <span class="meta-copy">${escapeHtml(officer.role || "Officer")}</span>
            </div>
            <div class="row-tags">
                ${raceBadge(officer.department || "Police")}
                ${raceBadge(`${Number(officer.warningCount || 0)} warnings`, Number(officer.warningCount || 0) > 0 ? "warn" : "good")}
            </div>
        </button>
    `).join("") : `<span class="meta-copy">Search police personnel to begin.</span>`;

    $("#mdt-warning-title").disabled = !selected || !canIssueWarnings;
    $("#mdt-warning-body").disabled = !selected || !canIssueWarnings;
    $("#mdt-warning-severity").disabled = !selected || !canIssueWarnings;
    $("#mdt-save-warning").disabled = !selected || !canIssueWarnings;

    if (!selected) {
        meta.innerHTML = `<article class="tool-row"><span>Status</span><strong>Select an officer to review warnings.</strong></article>`;
        warnings.innerHTML = `<span class="meta-copy">Officer warnings will show here.</span>`;
        return;
    }

    meta.innerHTML = `
        <article class="tool-row"><span>Citizen ID</span><strong>${escapeHtml(selected.citizenid)}</strong></article>
        <article class="tool-row"><span>Department</span><strong>${escapeHtml(selected.department || "Police")}</strong></article>
        <article class="tool-row"><span>Role</span><strong>${escapeHtml(selected.role || "Officer")}</strong></article>
        <article class="tool-row"><span>Warning access</span><strong>${canIssueWarnings ? "Enabled" : "Chief+"}</strong></article>
    `;

    warnings.innerHTML = (selected.warnings || []).length ? (selected.warnings || []).map((warning) => `
        <article class="message-card">
            <div class="message-head">
                <strong>${escapeHtml(warning.title)}</strong>
                <span class="meta-copy">${escapeHtml(warning.severity || "Warning")}</span>
            </div>
            <p>${escapeHtml(warning.body || "")}</p>
            <div class="message-foot">
                <span class="meta-copy">${escapeHtml(warning.issuerName || "Unknown")} • ${formatStamp(warning.createdAt)}</span>
            </div>
        </article>
    `).join("") : `<span class="meta-copy">No warnings on file for this officer.</span>`;
}

function renderMdt() {
    renderMdtOverview();
    renderMdtSuspects();
    renderMdtReports();
    renderMdtPersonnel();
}

function renderCrypto() {
    const status = state.data.status || {};
    const drive = status.cryptoDrive || null;
    const active = status.activeMining || [];

    $("#crypto-drive").textContent = drive ? (drive.label || "Crypto USB") : "No drive installed";
    $("#crypto-balance").textContent = qbit(state.data.crypto);
    $("#crypto-tool-drive").textContent = drive ? (drive.label || "Crypto USB") : "None";
    $("#crypto-tool-active-count").textContent = String(active.length);
    $("#crypto-tool-balance").textContent = qbit(state.data.crypto);

    const list = $("#mining-list");
    if (!active.length) {
        list.innerHTML = `
            <article class="mining-row empty-row">
                <div>
                    <h2 class="row-title">No active USBs</h2>
                    <span class="meta-copy">Insert a drive and wake the rig.</span>
                </div>
            </article>
        `;
        return;
    }

    list.innerHTML = active.map((job) => `
        <article class="mining-row">
            <div class="mining-copy">
                <h2 class="row-title">${escapeHtml(job.label || "Crypto USB")}</h2>
                <div class="row-tags">
                    ${raceBadge(`${Math.floor(job.progress || 0)}%`, "good")}
                    ${raceBadge(`${eta(job.remaining)} ETA`)}
                </div>
            </div>
            <div class="progress">
                <div class="progress-fill" style="width:${clamp(job.progress, 0, 100)}%"></div>
            </div>
        </article>
    `).join("");
}

function render() {
    renderHome();
    renderRacing();
    renderBusiness();
    renderAds();
    renderAdmin();
    renderMdt();
    renderCrypto();
    syncView();
}

function triggerMiningStart() {
    post("TabletStartCryptoMine").then((resp) => {
        if (resp.status) {
            state.data.status = resp.status;
        } else if (resp.activeMining) {
            state.data.status = state.data.status || {};
            state.data.status.activeMining = resp.activeMining;
            if (resp.success !== false) {
                state.data.status.cryptoDrive = null;
            }
        }
        setMessage("crypto-message", resp.message || "", resp.success === false ? "bad" : "good");
        renderHome();
        renderCrypto();
    });
}

function openTablet(payload) {
    state.open = true;
    state.apps = payload.applications || [];
    state.player = payload.PlayerData || {};
    state.data = payload.tabletData || state.data;
    state.ui.suspectResults = [];
    state.ui.selectedSuspect = null;
    state.ui.officerResults = [];
    state.ui.selectedOfficer = null;
    state.ui.claimedRewardTiers = {};
    state.ui.reportTabs = [{ id: "home", label: "Home", kind: "home" }];
    state.ui.activeReportTab = "home";
    state.ui.reportSearchOpen = false;
    state.ui.reportSearchQuery = "";
    state.ui.reportSearchResults = [];
    state.ui.selectedChargeEntries = [];
    state.ui.reportEvidence = [{ label: "", url: "" }];
    state.ui.businessReplyTo = null;
    state.ui.businessEditId = null;
    state.ui.showDeletedRecords = false;
    state.ui.homeAdIndex = 0;
    state.data.racing = mergeClaimedRewardState(state.data.racing);
    document.documentElement.classList.add("tablet-visible");
    document.body.classList.add("tablet-visible");
    document.documentElement.style.background = "transparent";
    document.documentElement.style.backgroundColor = "transparent";
    document.body.style.background = "transparent";
    document.body.style.backgroundColor = "transparent";
    tablet.style.display = "block";
    tablet.style.visibility = "visible";
    tablet.classList.add("is-open");
    clearReportForm();
    fillSuspectForm(null);
    fillOfficerForm(null);
    setView("home");
    syncClock();
    render();
    clearInterval(homeAdTimer);
    homeAdTimer = setInterval(() => {
        const ads = ((state.data.ads || {}).items) || [];
        if (!state.open || state.tab !== "home" || ads.length <= 1) return;
        state.ui.homeAdIndex = (state.ui.homeAdIndex + 1) % ads.length;
        renderHome();
    }, 6000);
}

function closeTablet() {
    state.open = false;
    state.ui.claimedRewardTiers = {};
    clearInterval(homeAdTimer);
    homeAdTimer = null;
    document.documentElement.classList.remove("tablet-visible");
    document.body.classList.remove("tablet-visible");
    document.documentElement.style.background = "transparent";
    document.documentElement.style.backgroundColor = "transparent";
    document.body.style.background = "transparent";
    document.body.style.backgroundColor = "transparent";
    tablet.classList.remove("is-open");
    tablet.style.display = "none";
    tablet.style.visibility = "hidden";
    closeModal();
}

window.addEventListener("load", () => {
    closeTablet();
    syncClock();
});

function refreshTablet() {
    return post("TabletRefresh").then((data) => {
        if (data && data.success !== false) {
            state.data = data;
            render();
        }
        return data;
    });
}

function refreshRacing(showMessage = false) {
    return post("TabletGetRacingData").then((data) => {
        if (data) {
            state.data.racing = mergeClaimedRewardState(data);
            renderHome();
            renderRacing();
            renderAdmin();
            if (showMessage && data.message) {
                setMessage("race-message", data.message, data.success === false ? "bad" : "good");
            }
        }
        return data;
    });
}

function refreshBusiness(showMessage = false) {
    return post("TabletGetBusinessData").then((resp) => {
        state.data.business = resp;
        renderHome();
        renderBusiness();
        if (showMessage) {
            setMessage("business-message", resp.message || "Business refreshed.", resp.success === false ? "bad" : "good");
        }
        return resp;
    });
}

function refreshAds(showMessage = false) {
    return post("TabletGetAdsData").then((resp) => {
        state.data.ads = resp;
        renderAds();
        renderHome();
        renderAdmin();
        if (showMessage) {
            setMessage("ads-message", resp.message || "Ads refreshed.", resp.success === false ? "bad" : "good");
        }
        return resp;
    });
}

function refreshAdmin(showMessage = false) {
    return post("TabletGetAdminData").then((resp) => {
        state.data.admin = resp;
        renderAdmin();
        if (showMessage) {
            setMessage("admin-message", resp.message || "Admin refreshed.", resp.success === false ? "bad" : "good");
        }
        return resp;
    });
}

function refreshMdt(showMessage = false) {
    return post("TabletGetMdtData").then((resp) => {
        state.data.mdt = resp;
        if (state.ui.activeReportTab && state.ui.activeReportTab !== "home" && state.ui.activeReportTab !== "draft") {
            const report = (resp.reports || []).find((entry) => String(entry.id) === String(state.ui.activeReportTab));
            if (report) {
                fillReportForm(report);
            } else {
                closeReportTab(state.ui.activeReportTab);
                clearReportForm();
            }
        }
        renderMdt();
        if (showMessage) {
            setMessage("mdt-message", resp.message || "MDT refreshed.", resp.success === false ? "bad" : "good");
        }
        return resp;
    });
}

window.addEventListener("message", (event) => {
    const data = event.data || {};

    if (data.action === "openTablet") {
        openTablet(data);
        return;
    }

    if (data.action === "closeTablet") {
        closeTablet();
        return;
    }

    if (data.action === "tabletMiningComplete") {
        setMessage("crypto-message", data.message || "Crypto reward received.", "good");
        state.data.status = state.data.status || {};
        state.data.status.activeMining = data.activeMining || [];
        renderHome();
        renderCrypto();
        return;
    }

    if (data.action === "tabletRacingUpdate") {
        state.data.racing = mergeClaimedRewardState(data.racing || state.data.racing);
        renderHome();
        renderRacing();
        renderAdmin();
    }
});

document.addEventListener("click", (event) => {
    const closeReportTabButton = event.target.closest("[data-close-report-tab]");
    if (closeReportTabButton) {
        event.stopPropagation();
        closeReportTab(closeReportTabButton.dataset.closeReportTab);
        return;
    }

    const createReportTabButton = event.target.closest("[data-create-report-tab]");
    if (createReportTabButton) {
        state.ui.reportSearchOpen = !state.ui.reportSearchOpen;
        if (state.ui.reportSearchOpen) {
            requestMdtReportSearch();
        } else {
            renderMdtReportSearch();
        }
        return;
    }

    const reportTabButton = event.target.closest("[data-report-tab]");
    if (reportTabButton) {
        activateReportTab(reportTabButton.dataset.reportTab);
        return;
    }

    const openApp = event.target.closest("[data-open-app]");
    if (openApp) {
        const appId = openApp.dataset.openApp;
        const app = appId === "home" ? { id: "home" } : visibleApps().find((entry) => entry.id === appId);
        if (appId === "home" || (app && app.disabled !== true)) {
            setView(appId);
        } else {
            showToast("Stand by.", "neutral");
        }
    }

    const disabledApp = event.target.closest("[data-disabled-app]");
    if (disabledApp) {
        showToast("Stand by.", "neutral");
    }

    const openPanel = event.target.closest("[data-open-panel]");
    if (openPanel) {
        setView(openPanel.dataset.panelApp, openPanel.dataset.openPanel);
    }

    const close = event.target.closest("[data-close-modal]");
    if (close || event.target === modalLayer) {
        closeModal();
    }

    const hostOpen = event.target.closest("[data-open-host]");
    if (hostOpen) {
        openModal("host-race", {
            raceId: hostOpen.dataset.openHost,
            name: hostOpen.dataset.trackName
        });
    }

    const raceWaypoint = event.target.closest("[data-race-waypoint]");
    if (raceWaypoint) {
        const allRaces = [
            ...(((state.data.racing || {}).publicRaces) || []),
            ((state.data.racing || {}).myHostedRace) || null,
            ((state.data.racing || {}).currentRace) || null,
        ].filter(Boolean);
        const race = allRaces.find((entry) => String(entry.raceId) === String(raceWaypoint.dataset.raceWaypoint));
        const point = race && race.startPoint;
        if (point) {
            post("TabletSetWaypoint", point).then((resp) => {
                setMessage("race-message", resp.message || "Race start GPS set.", resp.success === false ? "bad" : "good");
            });
        }
    }

    const renameOpen = event.target.closest("[data-open-rename]");
    if (renameOpen) {
        openModal("rename-track", {
            raceId: renameOpen.dataset.openRename,
            name: renameOpen.dataset.trackName
        });
    }

    const joinRace = event.target.closest("[data-join-race]");
    if (joinRace) {
        post("TabletJoinRace", { raceId: joinRace.dataset.joinRace }).then((resp) => {
            state.data.racing = resp || state.data.racing;
            renderHome();
            renderRacing();
            renderAdmin();
            setMessage("race-message", resp.message || "Race joined.", resp.success === false ? "bad" : "good");
        });
    }

    const leaveRace = event.target.closest("[data-leave-race]");
    if (leaveRace) {
        post("TabletLeaveRace").then((resp) => {
            state.data.racing = resp || state.data.racing;
            renderHome();
            renderRacing();
            renderAdmin();
            setMessage("race-message", resp.message || "Race left.", resp.success === false ? "bad" : "good");
        });
    }

    const startHosted = event.target.closest("[data-start-hosted]");
    if (startHosted) {
        post("TabletStartHostedRace", { raceId: startHosted.dataset.startHosted }).then((resp) => {
            state.data.racing = resp || state.data.racing;
            renderHome();
            renderRacing();
            renderAdmin();
            setMessage("race-message", resp.message || "Hosted race started.", resp.success === false ? "bad" : "good");
        });
    }

    const cancelHosted = event.target.closest("[data-cancel-hosted]");
    if (cancelHosted) {
        post("TabletCancelHostedRace", { raceId: cancelHosted.dataset.cancelHosted }).then((resp) => {
            state.data.racing = resp || state.data.racing;
            renderHome();
            renderRacing();
            renderAdmin();
            setMessage("race-message", resp.message || "Hosted race closed.", resp.success === false ? "bad" : "good");
        });
    }

    const deleteTrack = event.target.closest("[data-delete-track]");
    if (deleteTrack) {
        post("TabletDeleteTrack", { raceId: deleteTrack.dataset.deleteTrack }).then((resp) => {
            state.data.racing = resp || state.data.racing;
            renderHome();
            renderRacing();
            renderAdmin();
            setMessage(state.tab === "admin" ? "admin-message" : "race-message", resp.message || "Track deleted.", resp.success === false ? "bad" : "good");
        });
    }

    const fire = event.target.closest("[data-fire]");
    if (fire) {
        post("TabletBusinessFireMember", { citizenid: fire.dataset.fire }).then((resp) => {
            state.data.business = resp;
            renderBusiness();
            setMessage("business-message", resp.message || "Employee fired.", resp.success === false ? "bad" : "good");
        });
    }

    const replyBusiness = event.target.closest("[data-business-reply]");
    if (replyBusiness) {
        state.ui.businessReplyTo = replyBusiness.dataset.businessReply;
        state.ui.businessEditId = null;
        const business = state.data.business || {};
        const target = (business.messages || []).find((entry) => String(entry.id) === String(state.ui.businessReplyTo));
        setNodeValue("#business-chat-input", target ? `@${target.authorName} ` : "");
        renderBusinessChat();
        $("#business-chat-input").focus();
    }

    const editBusiness = event.target.closest("[data-business-edit]");
    if (editBusiness) {
        state.ui.businessEditId = editBusiness.dataset.businessEdit;
        state.ui.businessReplyTo = null;
        const business = state.data.business || {};
        const target = (business.messages || []).find((entry) => String(entry.id) === String(state.ui.businessEditId));
        setNodeValue("#business-chat-input", target ? (target.message || "") : "");
        renderBusinessChat();
        $("#business-chat-input").focus();
    }

    const deleteBusiness = event.target.closest("[data-business-delete]");
    if (deleteBusiness) {
        post("TabletBusinessDeleteMessage", { id: deleteBusiness.dataset.businessDelete }).then((resp) => {
            state.data.business = resp;
            if (String(state.ui.businessEditId) === String(deleteBusiness.dataset.businessDelete)) {
                state.ui.businessEditId = null;
            }
            if (String(state.ui.businessReplyTo) === String(deleteBusiness.dataset.businessDelete)) {
                state.ui.businessReplyTo = null;
            }
            renderBusiness();
            setMessage("business-message", resp.message || "Message deleted.", resp.success === false ? "bad" : "good");
        });
    }

    const deleteAd = event.target.closest("[data-ad-delete]");
    if (deleteAd) {
        post("TabletDeleteAdvertisement", { id: deleteAd.dataset.adDelete }).then((resp) => {
            state.data.ads = resp;
            renderAds();
            refreshAdmin();
            setMessage(state.tab === "admin" ? "admin-message" : "ads-message", resp.message || "Ad deleted.", resp.success === false ? "bad" : "good");
        });
    }

    const claimReward = event.target.closest("[data-claim-reward]");
    if (claimReward) {
        const tier = Number(claimReward.dataset.claimReward);
        claimReward.disabled = true;
        claimReward.classList.add("disabled");
        claimReward.textContent = "Claiming...";
        post("TabletClaimDailyReward", { tier }).then((resp) => {
            state.data.racing = mergeClaimedRewardState(resp || state.data.racing);
            if (resp && resp.success) {
                rememberClaimedRewardTier(tier);
            }
            renderHome();
            renderRacing();
            setMessage("race-message", resp.message || "Reward claimed.", resp.success === false ? "bad" : "good");
        });
    }

    const addCharge = event.target.closest("[data-add-charge]");
    if (addCharge) {
        const charge = ((state.data.mdt || {}).chargesCatalog || []).find((entry) => String(entry.id) === String(addCharge.dataset.addCharge));
        if (charge) {
            addChargeToCase(charge);
        }
    }

    const incCharge = event.target.closest("[data-charge-inc]");
    if (incCharge) {
        updateChargeQuantity(incCharge.dataset.chargeInc, 1);
    }

    const decCharge = event.target.closest("[data-charge-dec]");
    if (decCharge) {
        updateChargeQuantity(decCharge.dataset.chargeDec, -1);
    }

    const removeCharge = event.target.closest("[data-charge-remove]");
    if (removeCharge) {
        removeChargeFromCase(removeCharge.dataset.chargeRemove);
    }

    const removeEvidence = event.target.closest("[data-remove-evidence]");
    if (removeEvidence) {
        const index = Number(removeEvidence.dataset.removeEvidence);
        state.ui.reportEvidence = (state.ui.reportEvidence || []).filter((_, entryIndex) => entryIndex !== index);
        if (!state.ui.reportEvidence.length) {
            state.ui.reportEvidence = [{ label: "", url: "" }];
        }
        renderEvidenceEditor();
    }

    const suspectButton = event.target.closest("[data-select-suspect]");
    if (suspectButton) {
        post("TabletGetMdtSuspect", { citizenid: suspectButton.dataset.selectSuspect }).then((resp) => {
            if (resp.success) {
                state.ui.showDeletedRecords = false;
                fillSuspectForm(resp.suspect);
                renderMdt();
            }
            setMessage("mdt-message", resp.message || "Suspect loaded.", resp.success === false ? "bad" : "good");
        });
    }

    const warrantButton = event.target.closest("[data-open-warrant]");
    if (warrantButton) {
        post("TabletGetMdtSuspect", { citizenid: warrantButton.dataset.openWarrant }).then((resp) => {
            if (resp.success) {
                state.ui.showDeletedRecords = false;
                fillSuspectForm(resp.suspect);
                renderMdt();
                setView("mdt", "suspects");
            }
            setMessage("mdt-message", resp.message || "Warrant opened.", resp.success === false ? "bad" : "good");
        });
    }

    const clearWarrant = event.target.closest("[data-clear-warrant]");
    if (clearWarrant) {
        post("TabletClearMdtWarrant", { citizenid: clearWarrant.dataset.clearWarrant }).then((resp) => {
            if (resp.suspect) {
                fillSuspectForm(resp.suspect);
            }
            if (resp.warrants) {
                state.data.mdt = state.data.mdt || {};
                state.data.mdt.warrantList = resp.warrants;
                state.data.mdt.warrants = resp.warrants.length;
            }
            renderMdt();
            refreshMdt();
            setMessage("mdt-message", resp.message || "Warrant cleared.", resp.success === false ? "bad" : "good");
        });
    }

    const officerButton = event.target.closest("[data-select-officer]");
    if (officerButton) {
        post("TabletGetPoliceOfficer", { citizenid: officerButton.dataset.selectOfficer }).then((resp) => {
            if (resp.success) {
                state.data.mdt = state.data.mdt || {};
                if (typeof resp.canIssueWarnings === "boolean") {
                    state.data.mdt.canIssueWarnings = resp.canIssueWarnings;
                }
                fillOfficerForm(resp.officer);
                renderMdtPersonnel();
                setView("mdt", "personnel");
            }
            setMessage("mdt-message", resp.message || "Officer loaded.", resp.success === false ? "bad" : "good");
        });
    }

    const loadReport = event.target.closest("[data-load-report]");
    if (loadReport) {
        const reports = (state.data.mdt || {}).reports || [];
        const report = reports.find((entry) => String(entry.id) === String(loadReport.dataset.loadReport));
        if (report) {
            fillReportForm(report);
            setView("mdt", "reports");
            showToast("Report loaded.", "good");
        }
    }

    const openSearchReport = event.target.closest("[data-open-search-report]");
    if (openSearchReport) {
        const reportId = openSearchReport.dataset.openSearchReport;
        const report = (state.ui.reportSearchResults || []).find((entry) => String(entry.id) === String(reportId))
            || ((state.data.mdt || {}).reports || []).find((entry) => String(entry.id) === String(reportId));
        if (report) {
            fillReportForm(report);
            state.ui.reportSearchOpen = false;
            renderMdtReportSearch();
            setView("mdt", "reports");
            showToast("Report tab opened.", "good");
        }
    }

    const deleteReport = event.target.closest("[data-delete-report]");
    if (deleteReport) {
        post("TabletDeleteMdtReport", { id: deleteReport.dataset.deleteReport }).then((resp) => {
            if (resp.reports) {
                state.data.mdt = state.data.mdt || {};
                state.data.mdt.reports = resp.reports;
            }
            renderMdt();
            refreshAdmin();
            setMessage(state.tab === "admin" ? "admin-message" : "mdt-message", resp.message || "Report deleted.", resp.success === false ? "bad" : "good");
            refreshMdt();
        });
    }

    const toggleDeletedRecords = event.target.closest("[data-toggle-deleted-records]");
    if (toggleDeletedRecords) {
        state.ui.showDeletedRecords = !state.ui.showDeletedRecords;
        renderMdtSuspects();
    }

    if (event.target.closest("[data-start-mining-shortcut]")) {
        triggerMiningStart();
    }
});

$("#close-tablet").addEventListener("click", () => post("CloseTablet").then(closeTablet));
$("#create-zone-open").addEventListener("click", () => openModal("create-track"));
$("#join-private-open").addEventListener("click", () => openModal("private-race"));
$("#refresh-racing").addEventListener("click", () => refreshRacing(true));
$("#refresh-business").addEventListener("click", () => refreshBusiness(true));
$("#refresh-admin").addEventListener("click", () => refreshAdmin(true));
$("#start-mining").addEventListener("click", triggerMiningStart);

$("#launch-track-creator").addEventListener("click", () => {
    post("TabletCreateRaceZone", { name: $("#track-name-input").value }).then((resp) => {
        setMessage("race-message", resp.message || "Race zone creator loaded.", resp.success === false ? "bad" : "good");
        if (resp.success !== false) {
            closeModal();
        }
    });
});

$("#host-race-submit").addEventListener("click", () => {
    post("TabletHostRace", {
        raceId: $("#host-track-id").value,
        laps: $("#host-race-laps").value,
        buyIn: $("#host-race-buyin").value,
        hostJackpot: $("#host-race-jackpot").value,
        countdownSeconds: $("#host-race-countdown").value,
        maxPlayers: $("#host-race-maxplayers").value,
        password: $("#host-race-password").value,
        ghostCars: $("#host-race-ghostcars").checked
    }).then((resp) => {
        state.data.racing = resp || state.data.racing;
        renderHome();
        renderRacing();
        renderAdmin();
        setMessage("race-message", resp.message || "Race hosted.", resp.success === false ? "bad" : "good");
        if (resp.success !== false) {
            closeModal();
        }
    });
});

$("#private-race-submit").addEventListener("click", () => {
    post("TabletJoinPrivateRace", { password: $("#private-race-password").value }).then((resp) => {
        if (resp && resp.publicRaces) {
            state.data.racing = resp;
            renderHome();
            renderRacing();
            renderAdmin();
        }
        setMessage("race-message", resp.message || "Private race joined.", resp.success === false ? "bad" : "good");
        if (resp.success !== false) {
            closeModal();
        }
    });
});

$("#rename-track-submit").addEventListener("click", () => {
    post("TabletRenameTrack", {
        raceId: $("#rename-track-id").value,
        name: $("#rename-track-input").value
    }).then((resp) => {
        state.data.racing = resp || state.data.racing;
        renderHome();
        renderRacing();
        renderAdmin();
        setMessage(state.tab === "admin" ? "admin-message" : "race-message", resp.message || "Track renamed.", resp.success === false ? "bad" : "good");
        if (resp.success !== false) {
            closeModal();
        }
    });
});

$("#save-race-profile").addEventListener("click", () => {
    post("TabletUpdateRaceProfile", { nickname: $("#race-nickname-input").value }).then((resp) => {
        state.data.racing = resp || state.data.racing;
        renderHome();
        renderRacing();
        setMessage("race-message", resp.message || "Nickname updated.", resp.success === false ? "bad" : "good");
    });
});

$("#toggle-duty").addEventListener("click", () => {
    post("TabletToggleDuty").then((resp) => {
        state.data.business = resp;
        renderHome();
        renderBusiness();
        setMessage("business-message", resp.message || "Duty updated.", resp.success === false ? "bad" : "good");
    });
});

$("#set-business-waypoint").addEventListener("click", () => {
    const waypoint = (((state.data.business || {}).job) || {}).waypoint;
    post("TabletSetWaypoint", waypoint || {}).then((resp) => {
        setMessage("business-message", resp.message || "Waypoint set.", resp.success === false ? "bad" : "good");
    });
});

$("#hire-closest").addEventListener("click", () => {
    post("TabletBusinessHireClosest").then((resp) => {
        state.data.business = resp;
        renderBusiness();
        setMessage("business-message", resp.message || "Player hired.", resp.success === false ? "bad" : "good");
    });
});

$("#hire-by-citizenid").addEventListener("click", () => {
    post("TabletBusinessHireCitizen", { citizenid: $("#hire-citizenid-input").value }).then((resp) => {
        state.data.business = resp;
        renderBusiness();
        setMessage("business-message", resp.message || "Citizen hired.", resp.success === false ? "bad" : "good");
        if (resp.success) {
            $("#hire-citizenid-input").value = "";
        }
    });
});

$("#send-business-message").addEventListener("click", () => {
    const action = state.ui.businessEditId ? "TabletBusinessEditMessage" : "TabletBusinessSendMessage";
    const payload = {
        id: state.ui.businessEditId,
        replyToId: state.ui.businessReplyTo,
        message: $("#business-chat-input").value
    };
    post(action, payload).then((resp) => {
        state.data.business = resp;
        if (resp.success !== false) {
            state.ui.businessEditId = null;
            state.ui.businessReplyTo = null;
        }
        renderBusiness();
        setMessage("business-message", resp.message || "Message sent.", resp.success === false ? "bad" : "good");
        if (resp.success) {
            $("#business-chat-input").value = "";
        }
    });
});

$("#cancel-business-chat").addEventListener("click", () => {
    state.ui.businessEditId = null;
    state.ui.businessReplyTo = null;
    $("#business-chat-input").value = "";
    renderBusinessChat();
});

$("#business-deposit").addEventListener("click", () => {
    post("TabletBusinessAdjustMoney", { action: "deposit", amount: $("#business-money-input").value }).then((resp) => {
        state.data.business = resp;
        renderBusiness();
        setMessage("business-message", resp.message || "Deposit complete.", resp.success === false ? "bad" : "good");
    });
});

$("#business-withdraw").addEventListener("click", () => {
    post("TabletBusinessAdjustMoney", { action: "withdraw", amount: $("#business-money-input").value }).then((resp) => {
        state.data.business = resp;
        renderBusiness();
        setMessage("business-message", resp.message || "Withdraw complete.", resp.success === false ? "bad" : "good");
    });
});

function handleAdPost(titleId, bodyId, backgroundId, messageId) {
    post("TabletCreateAdvertisement", {
        title: document.getElementById(titleId).value,
        body: document.getElementById(bodyId).value,
        backgroundUrl: document.getElementById(backgroundId).value
    }).then((resp) => {
        state.data.ads = resp;
        renderAds();
        renderHome();
        refreshAdmin();
        setMessage(messageId, resp.message || "Advertisement posted.", resp.success === false ? "bad" : "good");
        if (resp.success) {
            document.getElementById(titleId).value = "";
            document.getElementById(bodyId).value = "";
            document.getElementById(backgroundId).value = "";
        }
    });
}

$("#post-advertisement").addEventListener("click", () => handleAdPost("ads-title-input", "ads-body-input", "ads-background-input", "ads-message"));
$("#post-business-ad").addEventListener("click", () => handleAdPost("business-ad-title", "business-ad-body", "business-ad-background", "business-message"));

$("#mdt-search-button").addEventListener("click", () => {
    post("TabletSearchMdtSuspects", { query: $("#mdt-search-input").value }).then((resp) => {
        state.ui.suspectResults = resp.suspects || [];
        renderMdt();
        setMessage("mdt-message", resp.message || "Search updated.", resp.success === false ? "bad" : "good");
    });
});

$("#mdt-save-suspect").addEventListener("click", () => {
    if (!state.ui.selectedSuspect) {
        setMessage("mdt-message", "Select a suspect first.", "bad");
        return;
    }

    post("TabletSaveMdtSuspect", {
        citizenid: state.ui.selectedSuspect.citizenid,
        warrantActive: $("#mdt-warrant-toggle").checked,
        warrantNote: $("#mdt-warrant-input").value,
        note: $("#mdt-note-input").value,
        mugshotUrl: $("#mdt-mugshot-input").value
    }).then((resp) => {
        if (resp.suspect) {
            fillSuspectForm(resp.suspect);
            renderMdt();
        }
        refreshMdt();
        setMessage("mdt-message", resp.message || "Suspect saved.", resp.success === false ? "bad" : "good");
    });
});

$("#mdt-save-profile-entry").addEventListener("click", () => {
    if (!state.ui.selectedSuspect) {
        setMessage("mdt-message", "Select a suspect first.", "bad");
        return;
    }

    post("TabletAddMdtProfileEntry", {
        citizenid: state.ui.selectedSuspect.citizenid,
        title: $("#mdt-profile-entry-title").value,
        body: $("#mdt-profile-entry-body").value,
        entryType: "Write-Up"
    }).then((resp) => {
        if (resp.suspect) {
            fillSuspectForm(resp.suspect);
            renderMdt();
        }
        setMessage("mdt-message", resp.message || "Profile write-up saved.", resp.success === false ? "bad" : "good");
        refreshMdt();
    });
});

$("#mdt-save-report").addEventListener("click", () => {
    post("TabletSaveMdtReport", {
        id: $("#mdt-report-id").value || null,
        reportType: $("#mdt-report-type").value,
        title: $("#mdt-report-title").value,
        suspectCitizenId: $("#mdt-report-cid").value,
        suspectName: $("#mdt-report-name").value,
        charges: $("#mdt-report-charges").value,
        warrants: $("#mdt-report-warrants").value,
        fineAmount: $("#mdt-report-fine").value,
        jailTime: $("#mdt-report-jail").value,
        status: $("#mdt-report-status").value,
        details: $("#mdt-report-details").value,
        incidentDate: $("#mdt-report-incident-date").value,
        dueDate: $("#mdt-report-due-date").value,
        chargeSelections: selectedChargeEntries(),
        evidence: (state.ui.reportEvidence || []).filter((entry) => (entry.url || "").trim() !== ""),
        officers: ($("#mdt-report-officers").value || "").split(",").map((name) => ({ name: name.trim() })).filter((entry) => entry.name)
    }).then((resp) => {
        if (resp.reports) {
            state.data.mdt = state.data.mdt || {};
            state.data.mdt.reports = resp.reports;
        }
        if (resp.report) {
            fillReportForm(resp.report);
        }
        renderMdt();
        refreshAdmin();
        setMessage("mdt-message", resp.message || "Report saved.", resp.success === false ? "bad" : "good");
        refreshMdt();
    });
});

$("#mdt-delete-current-report").addEventListener("click", () => {
    const reportId = $("#mdt-report-id").value;
    if (!reportId) {
        setMessage("mdt-message", "Load a report first.", "bad");
        return;
    }

    post("TabletDeleteMdtReport", { id: reportId }).then((resp) => {
        if (resp.reports) {
            state.data.mdt = state.data.mdt || {};
            state.data.mdt.reports = resp.reports;
        }
        closeReportTab(reportId);
        clearReportForm();
        renderMdt();
        refreshAdmin();
        refreshMdt();
        setMessage("mdt-message", resp.message || "Report deleted.", resp.success === false ? "bad" : "good");
    });
});

$("#mdt-clear-report").addEventListener("click", clearReportForm);
$("#mdt-new-report").addEventListener("click", () => {
    state.ui.reportSearchOpen = false;
    clearReportForm();
    setView("mdt", "reports");
});
$("#mdt-report-cid").addEventListener("change", refreshReportSuspectCard);
$("#mdt-report-name").addEventListener("input", () => {
    if (!($("#mdt-report-cid").value || "").trim()) {
        renderReportSuspectCard({ suspectName: $("#mdt-report-name").value });
    }
});
$("#mdt-charge-search").addEventListener("input", renderChargeCatalog);
$("#mdt-add-evidence").addEventListener("click", () => {
    state.ui.reportEvidence = state.ui.reportEvidence || [];
    state.ui.reportEvidence.push({ label: "", url: "" });
    renderEvidenceEditor();
});
$("#mdt-report-search-button").addEventListener("click", () => requestMdtReportSearch(true));
$("#mdt-report-search-input").addEventListener("input", () => {
    if (state.ui.reportSearchOpen) {
        requestMdtReportSearch(false);
    }
});
$("#mdt-officer-search-button").addEventListener("click", () => {
    post("TabletSearchPolicePersonnel", { query: $("#mdt-officer-search-input").value }).then((resp) => {
        state.ui.officerResults = resp.personnel || [];
        if (typeof resp.canIssueWarnings === "boolean") {
            state.data.mdt = state.data.mdt || {};
            state.data.mdt.canIssueWarnings = resp.canIssueWarnings;
        }
        renderMdtPersonnel();
        setMessage("mdt-message", resp.message || "Personnel search updated.", resp.success === false ? "bad" : "good");
    });
});
$("#mdt-save-warning").addEventListener("click", () => {
    if (!state.ui.selectedOfficer) {
        setMessage("mdt-message", "Select an officer first.", "bad");
        return;
    }

    post("TabletSavePoliceWarning", {
        officerCitizenId: state.ui.selectedOfficer.citizenid,
        title: $("#mdt-warning-title").value,
        body: $("#mdt-warning-body").value,
        severity: $("#mdt-warning-severity").value
    }).then((resp) => {
        if (resp.warnings) {
            state.data.mdt = state.data.mdt || {};
            state.data.mdt.recentWarnings = resp.warnings;
        }
        if (resp.personnel) {
            state.data.mdt = state.data.mdt || {};
            state.data.mdt.personnel = resp.personnel;
            state.ui.officerResults = resp.personnel;
        }
        if (resp.officer) {
            fillOfficerForm(resp.officer);
        }
        renderMdt();
        setMessage("mdt-message", resp.message || "Police warning saved.", resp.success === false ? "bad" : "good");
        refreshMdt();
    });
});

document.addEventListener("input", (event) => {
    const evidenceField = event.target.dataset.evidenceField;
    if (evidenceField) {
        const index = Number(event.target.dataset.evidenceIndex);
        state.ui.reportEvidence = state.ui.reportEvidence || [];
        state.ui.reportEvidence[index] = state.ui.reportEvidence[index] || { label: "", url: "" };
        state.ui.reportEvidence[index][evidenceField] = event.target.value;
    }
});

document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && state.open) {
        if (!modalLayer.classList.contains("hidden")) {
            closeModal();
            return;
        }
        post("CloseTablet").then(closeTablet);
    }
});

setInterval(() => {
    syncClock();

    const active = state.data.status && state.data.status.activeMining;
    if (Array.isArray(active) && active.length) {
        const now = Math.floor(Date.now() / 1000);
        active.forEach((job) => {
            job.remaining = Math.max((Number(job.finishesAt) || now) - now, 0);
            const elapsed = Math.max(now - (Number(job.startedAt) || now), 0);
            job.progress = job.seconds > 0 ? Math.min(Math.floor((elapsed / job.seconds) * 100), 100) : 0;
        });
        if (state.open && state.tab === "crypto") {
            renderCrypto();
        }
    }
}, 1000);

setInterval(() => {
    if (!state.open || state.tab !== "racing") return;
    refreshRacing();
}, 5000);
