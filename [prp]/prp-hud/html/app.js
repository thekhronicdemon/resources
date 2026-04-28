(() => {
    const hud = document.getElementById("hud");
    const compass = document.getElementById("compass");
    const vehicleHud = document.getElementById("vehicle-hud");
    const money = document.getElementById("money");
    const moneyLabel = document.getElementById("money-label");
    const moneyAmount = document.getElementById("money-amount");
    const armorRow = document.getElementById("armor-row");
    const staminaRow = document.getElementById("stamina-row");
    const healthValue = document.getElementById("health-value");
    const armorValue = document.getElementById("armor-value");
    const staminaValue = document.getElementById("stamina-value");
    const healthBar = document.getElementById("health-bar");
    const armorBar = document.getElementById("armor-bar");
    const staminaBar = document.getElementById("stamina-bar");
    const hungerAccent = document.getElementById("hunger-accent");
    const thirstAccent = document.getElementById("thirst-accent");
    const stressAccent = document.getElementById("stress-accent");
    const voiceAccent = document.getElementById("voice-accent");
    const radioAccent = document.getElementById("radio-accent");
    const oxygenAccent = document.getElementById("oxygen-accent");
    const oxygenChip = document.getElementById("oxygen-chip");
    const voiceChip = document.getElementById("voice-chip");
    const radioChip = document.getElementById("radio-chip");
    const directionPill = document.getElementById("direction-pill");
    const streetPill = document.getElementById("street-pill");
    const areaPill = document.getElementById("area-pill");
    const speedValue = document.getElementById("speed-value");
    const speedUnit = document.getElementById("speed-unit");
    const ammoHud = document.getElementById("ammo-hud");
    const ammoClip = document.getElementById("ammo-clip");
    const ammoReserve = document.getElementById("ammo-reserve");
    const speedArc = document.getElementById("speed-arc");
    const fuelBar = document.getElementById("fuel-bar");
    const engineBar = document.getElementById("engine-bar");
    const beltBar = document.getElementById("belt-bar");
    const nitroWidget = document.getElementById("nitro-widget");
    const nitroBar = document.getElementById("nitro-bar");
    const gear = document.getElementById("gear");
    const speedometer = document.querySelector(".speedometer");
    const statusChips = {
        hunger: document.querySelector('[data-stat="hunger"]'),
        thirst: document.querySelector('[data-stat="thirst"]'),
        stress: document.querySelector('[data-stat="stress"]'),
    };

    let moneyTimer = null;
    let unit = "MPH";

    function clamp(value, min, max) {
        const number = Number(value) || 0;
        return Math.max(min, Math.min(max, number));
    }

    function setVisible(element, visible) {
        element.classList.toggle("is-hidden", !visible);
    }

    function setChipVisible(element, visible) {
        element.classList.toggle("is-collapsed", !visible);
    }

    function setPercent(element, value) {
        element.style.width = `${clamp(value, 0, 100)}%`;
    }

    function setAccent(element, value, minimum = 0.12) {
        const scale = clamp(value, 0, 100) / 100;
        element.style.transform = `scaleY(${Math.max(minimum, scale)})`;
    }

    function setInlinePercent(element, value) {
        element.style.setProperty("--value", `${clamp(value, 0, 100)}%`);
    }

    function formatMoney(value) {
        return `$${Math.round(Number(value) || 0).toLocaleString("en-US")}`;
    }

    function showMoney(label, amount, isMinus) {
        clearTimeout(moneyTimer);
        moneyLabel.textContent = label || "cash";
        moneyAmount.textContent = `${isMinus ? "-" : ""}${formatMoney(amount)}`;
        moneyAmount.style.color = isMinus ? "#ff6b6b" : "#f5f8fb";
        setVisible(money, true);
        moneyTimer = setTimeout(() => setVisible(money, false), 3200);
    }

    function voiceLevel(distance) {
        if (distance <= 0) return 20;
        if (distance <= 2) return 34;
        if (distance <= 5) return 67;
        return 100;
    }

    function updateStatus(data) {
        const health = clamp(data.health, 0, 100);
        const armor = clamp(data.armor, 0, 100);
        const hunger = clamp(data.hunger, 0, 100);
        const thirst = clamp(data.thirst, 0, 100);
        const stress = clamp(data.stress, 0, 100);
        const stamina = clamp(data.stamina, 0, 100);
        const oxygen = clamp(data.oxygen, 0, 100);

        healthValue.textContent = Math.round(health);
        armorValue.textContent = Math.round(armor);
        staminaValue.textContent = Math.round(stamina);
        setPercent(healthBar, health);
        setPercent(armorBar, armor);
        setPercent(staminaBar, stamina);
        setAccent(hungerAccent, hunger);
        setAccent(thirstAccent, thirst);
        setAccent(stressAccent, stress, stress > 0 ? 0.18 : 0);
        setAccent(oxygenAccent, oxygen);

        setVisible(armorRow, armor > 0);
        setVisible(staminaRow, Boolean(data.showStamina));
        setChipVisible(statusChips.hunger, hunger < 100);
        setChipVisible(statusChips.thirst, thirst < 100);
        setChipVisible(statusChips.stress, stress > 0);
        statusChips.hunger.classList.toggle("is-warning", hunger <= 25);
        statusChips.thirst.classList.toggle("is-warning", thirst <= 25);
        statusChips.stress.classList.toggle("is-warning", stress >= 55);
        setVisible(oxygenChip, oxygen < 99 && !data.showStamina);

        setAccent(voiceAccent, voiceLevel(Number(data.voice) || 0));
        voiceChip.classList.toggle("is-active", Boolean(data.talking));
        setAccent(radioAccent, data.radioActive ? 100 : 18);
        radioChip.classList.toggle("is-active", Boolean(data.radioActive));
    }

    function updateCompass(data) {
        setVisible(compass, Boolean(data.showCompass));
        directionPill.textContent = data.direction || "N";
        streetPill.textContent = data.street || "Unknown Road";
        areaPill.textContent = data.area || "";
        setVisible(areaPill, Boolean(data.area));
    }

    function updateVehicle(data) {
        const inVehicle = Boolean(data.inVehicle);
        const speed = clamp(data.speed, 0, 999);
        const rpm = clamp(data.rpm, 0, 100);
        unit = data.speedUnit || unit;
        const fuel = clamp(data.fuel, 0, 100);
        const engine = clamp(data.engine, 0, 100);
        const nitro = clamp(data.nos, 0, 100);
        const nitroActive = Boolean(data.nitroActive);
        const showNitro = inVehicle && (nitro > 0 || nitroActive);

        setVisible(vehicleHud, inVehicle);
        speedValue.textContent = Math.round(speed);
        speedUnit.textContent = unit;
        speedArc.style.strokeDashoffset = `${100 - rpm}`;
        setInlinePercent(fuelBar, fuel);
        setInlinePercent(engineBar, engine);
        setInlinePercent(beltBar, data.showSeatbelt ? 100 : 0);
        fuelBar.style.setProperty("--color", fuel <= 20 ? "#ff5757" : "#f6ff00");
        engineBar.style.setProperty("--color", engine <= 35 ? "#ff5757" : "#e75656");
        beltBar.classList.toggle("is-on", Boolean(data.seatbelt));
        speedometer.classList.toggle("is-limiter", rpm >= 96);
        speedometer.classList.toggle("is-nitro-active", nitroActive);
        gear.textContent = data.gear || "N";
        setVisible(nitroWidget, showNitro);
        setInlinePercent(nitroBar, nitro);
        nitroWidget.classList.toggle("is-active", nitroActive);
    }

    function updateAmmo(data) {
        const visible = Boolean(data.showAmmo) && !Boolean(data.dead);
        setVisible(ammoHud, visible);
        ammoClip.textContent = Math.max(0, Math.round(Number(data.ammoClip) || 0)).toLocaleString("en-US");
        ammoReserve.textContent = Math.max(0, Math.round(Number(data.ammoReserve) || 0)).toLocaleString("en-US");
    }

    function updateHud(data) {
        setVisible(hud, Boolean(data.visible));
        hud.classList.toggle("in-vehicle", Boolean(data.inVehicle));
        updateStatus(data);
        updateCompass(data);
        updateVehicle(data);
        updateAmmo(data);
    }

    window.addEventListener("message", (event) => {
        const data = event.data || {};

        if (data.action === "update") {
            updateHud(data);
            return;
        }

        if (data.action === "setVisible") {
            setVisible(hud, Boolean(data.visible));
            return;
        }

        if (data.action === "setUnit") {
            unit = data.unit || unit;
            speedUnit.textContent = unit;
            return;
        }

        if (data.action === "money") {
            showMoney(data.account, data.amount, false);
            return;
        }

        if (data.action === "moneyChange") {
            showMoney(data.account, data.amount, data.isMinus);
        }
    });
})();
