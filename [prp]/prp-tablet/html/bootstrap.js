const root = document.getElementById("bootstrap-root");
let appFrame = null;
let appFrameLoaded = false;
let pendingMessages = [];

function resetTransparency() {
    document.documentElement.style.background = "transparent";
    document.documentElement.style.backgroundColor = "transparent";
    document.body.style.background = "transparent";
    document.body.style.backgroundColor = "transparent";
}

function flushPendingMessages() {
    if (!appFrame || !appFrame.contentWindow || pendingMessages.length === 0) return;

    pendingMessages.forEach((message) => {
        appFrame.contentWindow.postMessage(message, "*");
    });
    pendingMessages = [];
}

function mountAppFrame() {
    if (appFrame) return appFrame;

    appFrameLoaded = false;
    appFrame = document.createElement("iframe");
    appFrame.id = "tablet-app-frame";
    appFrame.src = "index.html";
    appFrame.setAttribute("frameborder", "0");
    appFrame.setAttribute("scrolling", "no");
    appFrame.addEventListener("load", () => {
        appFrameLoaded = true;
        resetTransparency();
        flushPendingMessages();
    });

    root.innerHTML = "";
    root.appendChild(appFrame);
    return appFrame;
}

function unmountAppFrame() {
    if (!appFrame) return;
    appFrame.remove();
    appFrame = null;
    appFrameLoaded = false;
    pendingMessages = [];
}

function forwardMessage(message) {
    const frame = mountAppFrame();
    if (!frame.contentWindow || !appFrameLoaded) {
        pendingMessages.push(message);
        return;
    }

    try {
        frame.contentWindow.postMessage(message, "*");
    } catch (error) {
        pendingMessages.push(message);
    }
}

resetTransparency();

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (!data.action) return;

    resetTransparency();

    if (data.action === "openTablet") {
        root.classList.add("is-open");
        forwardMessage(data);
        return;
    }

    if (data.action === "closeTablet") {
        if (appFrame && appFrame.contentWindow) {
            try {
                appFrame.contentWindow.postMessage(data, "*");
            } catch (error) {
                // Ignore teardown messaging errors.
            }
        }

        root.classList.remove("is-open");
        setTimeout(() => {
            if (!root.classList.contains("is-open")) {
                unmountAppFrame();
            }
        }, 50);
        return;
    }

    if (!appFrame) return;
    forwardMessage(data);
});
