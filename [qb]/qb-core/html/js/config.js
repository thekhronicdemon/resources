export let NOTIFY_CONFIG = null;

const defaultConfig = {
    NotificationStyling: {
        group: false,
        position: "bottom",
        progress: false,
    },
    VariantDefinitions: {
        success: {
            classes: "prp-notify prp-notify-success",
            icon: "check_circle",
        },
        primary: {
            classes: "prp-notify prp-notify-primary",
            icon: "check_circle",
        },
        error: {
            classes: "prp-notify prp-notify-error",
            icon: "cancel",
        },
        warning: {
            classes: "prp-notify prp-notify-warning",
            icon: "cancel",
        },
        police: {
            classes: "prp-notify prp-notify-police",
            icon: "local_police",
        },
        ambulance: {
            classes: "prp-notify prp-notify-ambulance",
            icon: "fas fa-ambulance",
        },
    },
};

export const determineStyleFromVariant = (variant) => {
    const variantData = NOTIFY_CONFIG.VariantDefinitions[variant];
    if (!variantData) throw new Error(`Style of type: ${variant}, does not exist in the config`);
    return variantData;
};

export const fetchNotifyConfig = async () => {
    try {
        NOTIFY_CONFIG = await window.fetchNui("getNotifyConfig", {});
        if (!NOTIFY_CONFIG) {
            NOTIFY_CONFIG = defaultConfig;
        }
    } catch (error) {
        console.error("Failed to fetch notification config, using default", error);
        NOTIFY_CONFIG = defaultConfig;
    }
};

window.addEventListener("load", async () => {
    await fetchNotifyConfig();
});
