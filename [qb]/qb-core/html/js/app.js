import { determineStyleFromVariant, fetchNotifyConfig, NOTIFY_CONFIG } from "./config.js";

const fetchNui = async (evName, data) => {
    const resourceName = window.GetParentResourceName();

    const rawResp = await fetch(`https://${resourceName}/${evName}`, {
        body: JSON.stringify(data),
        headers: {
            "Content-Type": "application/json; charset=UTF8",
        },
        method: "POST",
    });

    return await rawResp.json();
};

window.fetchNui = fetchNui;

const activeNotifications = new Map();

const getNotifyRoot = () => {
    let root = document.getElementById("prp-notify-root");
    if (!root) {
        root = document.createElement("div");
        root.id = "prp-notify-root";
        root.className = "prp-notify-root";
        document.body.appendChild(root);
    }
    return root;
};

const normalizeNotifyText = (value, fallback = "") => {
    if (value === null || value === undefined) return fallback;
    return String(value);
};

const resolveVariant = (type) => {
    try {
        return determineStyleFromVariant(type || "primary");
    } catch (error) {
        return determineStyleFromVariant("primary");
    }
};

const defaultIconForType = (type) => {
    const normalized = String(type || "primary").toLowerCase();
    if (normalized === "error" || normalized === "warning" || normalized === "ambulance") {
        return "cancel";
    }
    return "check_circle";
};

const isGenericNotifyIcon = (icon) => {
    if (!icon) return true;

    return [
        "notifications",
        "notifications_active",
        "check",
        "check_circle",
        "done",
        "cancel",
        "close",
        "dangerous",
        "error",
        "warning",
        "info",
    ].includes(String(icon).toLowerCase());
};

const inferNotifyContext = ({ type, text, caption }) => {
    const normalizedType = String(type || "primary").toLowerCase();
    const body = `${normalizedType} ${text || ""} ${caption || ""}`.toLowerCase();
    const isOffState = /\b(off|disabled|unbuckled|removed|false|unfastened)\b|not\s+(buckled|fastened|secured)/.test(body);
    const isOnState = /\b(on|enabled|buckled|fastened|true|secured|active)\b/.test(body);

    if (/\b(engine|motor|ignition)\b/.test(body)) {
        return {
            icon: "prp-engine",
            stateClass: isOffState ? "prp-notify-state-off" : (isOnState ? "prp-notify-state-on" : ""),
        };
    }

    if (/\b(seat\s*belt|seatbelt|safety\s*belt|belt|buckle|buckled|unbuckled|harness)\b/.test(body)) {
        return {
            icon: "prp-seatbelt",
            stateClass: isOffState ? "prp-notify-state-off" : (isOnState ? "prp-notify-state-on" : ""),
        };
    }

    if (normalizedType === "police") {
        return { icon: "local_police", stateClass: "" };
    }

    if (normalizedType === "ambulance") {
        return { icon: "fas fa-ambulance", stateClass: "" };
    }

    return { icon: null, stateClass: "" };
};

const resolveNotifyIcon = ({ type, text, caption, dataIcon, variantIcon }) => {
    const inferred = inferNotifyContext({ type, text, caption });
    if (inferred.icon && isGenericNotifyIcon(dataIcon)) return inferred.icon;
    if (dataIcon) return dataIcon;
    if (inferred.icon) return inferred.icon;

    return variantIcon || defaultIconForType(type);
};

const getNotifyKey = ({ type, text, caption }) => {
    return `${type || "primary"}::${text || ""}::${caption || ""}`;
};

const createSvgIcon = (type) => {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", `prp-notify-icon prp-notify-svg-icon ${type}`);
    svg.setAttribute("viewBox", "0 0 64 64");
    svg.setAttribute("aria-hidden", "true");

    if (type === "prp-engine") {
        svg.innerHTML = `
            <path d="M12 30h7v-7h12v5h8l5 5h5v-7h6v22h-6v-7h-6l-7 7H21l-7-7h-2V30Z" />
            <path d="M24 18h15" />
            <path d="M31 18v7" />
            <path d="M8 35H4" />
            <path d="M8 43H4" />
        `;
        return svg;
    }

    svg.innerHTML = `
        <circle cx="28" cy="12" r="6" />
        <path d="M22 24h12l4 15h8" />
        <path d="M18 54 43 23" />
        <path d="M20 33h17" />
        <path d="M18 54h24" />
        <path d="M43 39l8 15" />
    `;
    return svg;
};

const createMaskedIcon = (type, source) => {
    const icon = document.createElement("span");
    icon.className = `prp-notify-icon prp-notify-mask-icon ${type}`;
    icon.style.setProperty("--mask-url", `url("${source}")`);
    icon.style.webkitMask = `url("${source}") center / contain no-repeat`;
    icon.style.mask = `url("${source}") center / contain no-repeat`;
    icon.setAttribute("aria-hidden", "true");
    return icon;
};

const createIconElement = (icon) => {
    const customIconAliases = {
        engine: "prp-engine",
        ignition: "prp-engine",
        motor: "prp-engine",
        car_engine: "prp-engine",
        seatbelt: "prp-seatbelt",
        seat_belt: "prp-seatbelt",
        "seat-belt": "prp-seatbelt",
        safety_belt: "prp-seatbelt",
        harness: "prp-seatbelt",
    };
    const rawIconName = normalizeNotifyText(icon || "check_circle", "check_circle");
    const iconName = customIconAliases[rawIconName.toLowerCase()] || rawIconName;
    if (iconName === "prp-seatbelt") {
        return createMaskedIcon(iconName, "img/seatbelt.png");
    }
    if (iconName === "prp-engine") {
        return createSvgIcon(iconName);
    }

    const iconElement = document.createElement(iconName.includes("fa-") ? "i" : "span");

    if (iconName.includes("fa-")) {
        iconElement.className = `prp-notify-icon ${iconName}`;
    } else {
        iconElement.className = "material-icons prp-notify-icon";
        iconElement.textContent = iconName;
    }

    return iconElement;
};

const restartProgress = (state, timeout) => {
    if (!state.progressElement) return;

    const nextProgress = state.progressElement.cloneNode(false);
    nextProgress.style.animationDuration = `${timeout}ms`;
    state.progressElement.replaceWith(nextProgress);
    state.progressElement = nextProgress;
};

const pulseNotifyCard = (card) => {
    card.classList.remove("prp-notify-pulse");
    void card.offsetWidth;
    card.classList.add("prp-notify-pulse");
};

const removeNotifyCard = (card, key) => {
    const state = activeNotifications.get(key);
    if (state && state.card === card) {
        activeNotifications.delete(key);
    }

    card.classList.add("prp-notify-leaving");
    setTimeout(() => card.remove(), 180);
};

const showPrpNotify = async ({ data }) => {
    if (data?.action !== "notify" && data?.action !== "prp-notify") return;

    if (!NOTIFY_CONFIG) {
        await fetchNotifyConfig();
    }

    const type = data.type || "primary";
    const variant = resolveVariant(type);
    const timeout = Math.max(1000, Number(data.length) || 5000);
    const text = normalizeNotifyText(data.text, "Notification");
    const caption = normalizeNotifyText(data.caption, "");
    const inferredContext = inferNotifyContext({ type, text, caption });
    const icon = resolveNotifyIcon({
        type,
        text,
        caption,
        dataIcon: data.icon,
        variantIcon: variant.icon,
    });
    const key = getNotifyKey({ type, text, caption });

    const existing = activeNotifications.get(key);
    if (existing) {
        existing.count += 1;
        existing.countElement.textContent = `x${existing.count}`;
        existing.countElement.hidden = false;
        clearTimeout(existing.timer);
        existing.timer = setTimeout(() => removeNotifyCard(existing.card, key), timeout);
        restartProgress(existing, timeout);
        pulseNotifyCard(existing.card);
        return;
    }

    const root = getNotifyRoot();
    const card = document.createElement("div");
    card.className = `prp-notify-card ${variant.classes || ""} ${inferredContext.stateClass || ""}`;

    const iconWrap = document.createElement("div");
    iconWrap.className = "prp-notify-icon-wrap";
    iconWrap.appendChild(createIconElement(icon));

    const content = document.createElement("div");
    content.className = "prp-notify-content";

    const title = document.createElement("div");
    title.className = "prp-notify-title";
    title.textContent = text;
    content.appendChild(title);

    if (caption) {
        const sub = document.createElement("div");
        sub.className = "prp-notify-caption";
        sub.textContent = caption;
        content.appendChild(sub);
    }

    card.append(iconWrap, content);

    const count = document.createElement("div");
    count.className = "prp-notify-count";
    count.textContent = "x1";
    count.hidden = true;
    card.appendChild(count);

    let progressElement = null;
    if (NOTIFY_CONFIG?.NotificationStyling?.progress) {
        const progress = document.createElement("div");
        progress.className = "prp-notify-progress";
        progress.style.animationDuration = `${timeout}ms`;
        card.appendChild(progress);
        progressElement = progress;
    }

    root.appendChild(card);
    const timer = setTimeout(() => removeNotifyCard(card, key), timeout);
    activeNotifications.set(key, {
        card,
        count: 1,
        countElement: count,
        progressElement,
        timer,
    });
};

const app = Vue.createApp({
    setup() {
        Vue.onMounted(() => {
            window.addEventListener("message", showPrpNotify);
        });

        Vue.onUnmounted(() => {
            window.removeEventListener("message", showPrpNotify);
        });

        return {};
    },
});

app.use(Quasar, { config: {} });
app.mount("#q-app");
