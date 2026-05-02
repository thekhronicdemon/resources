(function () {
    var state = {
        shop: null,
        vehicles: [],
        categories: [],
        colors: [],
        payments: {},
        selected: null,
        activeCategory: "all",
        search: "",
        paintTarget: "primary",
        primary: null,
        secondary: null,
        canManage: false,
        management: null,
        finance: []
    };

    function $(selector) {
        return document.querySelector(selector);
    }

    function addClass(element, name) {
        if (element && element.classList) element.classList.add(name);
    }

    function removeClass(element, name) {
        if (element && element.classList) element.classList.remove(name);
    }

    function hasClass(element, name) {
        return !!(element && element.classList && element.classList.contains(name));
    }

    function toggleClass(element, name, enabled) {
        if (!element || !element.classList) return;
        if (enabled) element.classList.add(name);
        else element.classList.remove(name);
    }

    function fallback(value, defaultValue) {
        return value === undefined || value === null ? defaultValue : value;
    }

    function showApp() {
        removeClass(document.body, "hidden");
    }

    function hideApp() {
        addClass(document.body, "hidden");
        removeClass(document.body, "panel-only");
    }

    function post(name, data) {
        var resource = "qb-vehicleshop";
        if (typeof GetParentResourceName === "function") resource = GetParentResourceName();
        return fetch("https://" + resource + "/" + name, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }

    function money(value) {
        return "$" + Number(value || 0).toLocaleString();
    }

    function selectedColorPayload() {
        var primary = state.primary || state.colors[0] || {};
        var secondary = state.secondary || primary;
        var primaryValue = fallback(primary.primary, 111);
        return {
            primary: Number(primaryValue),
            secondary: Number(fallback(fallback(secondary.secondary, secondary.primary), primaryValue))
        };
    }

    function colorLabel() {
        var primary = state.primary || state.colors[0] || {};
        var secondary = state.secondary || primary;
        return state.paintTarget === "primary" ? primary.label : secondary.label;
    }

    function setText(selector, text) {
        var element = $(selector);
        if (element) element.textContent = text;
    }

    function setSelected(vehicle) {
        if (!vehicle) return;
        state.selected = vehicle;
        setText("#categoryTitle", String(vehicle.category || "catalog").toUpperCase());
        setText("#vehicleName", vehicle.name || vehicle.model || "Vehicle");
        setText("#statVehicle", (vehicle.brand || "Vehicle") + " " + (vehicle.name || vehicle.model || ""));
        setText("#priceValue", money(vehicle.price));

        var color = selectedColorPayload();
        var previewPayload = {};
        for (var key in vehicle) previewPayload[key] = vehicle[key];
        previewPayload.primary = color.primary;
        previewPayload.secondary = color.secondary;
        post("previewVehicle", previewPayload);
        renderVehicles();
    }

    function filteredVehicles() {
        var search = String(state.search || "").toLowerCase();
        var output = [];
        for (var i = 0; i < state.vehicles.length; i++) {
            var vehicle = state.vehicles[i];
            var categoryOk = state.activeCategory === "all" || vehicle.category === state.activeCategory;
            var haystack = String((vehicle.name || "") + " " + (vehicle.brand || "") + " " + (vehicle.model || "") + " " + (vehicle.category || "")).toLowerCase();
            if (categoryOk && (!search || haystack.indexOf(search) !== -1)) output.push(vehicle);
        }
        return output;
    }

    function renderCategories() {
        var list = $("#categoryList");
        if (!list) return;
        list.innerHTML = "";
        var categories = ["all"].concat(state.categories || []);
        for (var i = 0; i < categories.length; i++) {
            var category = categories[i];
            var button = document.createElement("button");
            button.textContent = category === "all" ? "All" : category;
            toggleClass(button, "active", category === state.activeCategory);
            button.setAttribute("data-category", category);
            button.addEventListener("click", function () {
                state.activeCategory = this.getAttribute("data-category");
                renderCategories();
                renderVehicles();
            });
            list.appendChild(button);
        }
    }

    function renderVehicles() {
        var list = $("#vehicleList");
        if (!list) return;
        var vehicles = filteredVehicles();
        list.innerHTML = "";
        setText("#catalogCount", vehicles.length + " vehicles");
        for (var i = 0; i < vehicles.length; i++) {
            var vehicle = vehicles[i];
            var card = document.createElement("article");
            card.className = "vehicle-card";
            toggleClass(card, "active", !!(state.selected && vehicle.model === state.selected.model));
            toggleClass(card, "out", Number(vehicle.stock) <= 0);
            card.innerHTML =
                "<div>" +
                    "<small>" + (vehicle.category || "catalog") + "</small>" +
                    "<h3>" + (vehicle.brand || "") + " " + (vehicle.name || vehicle.model || "Vehicle") + "</h3>" +
                    "<span>" + (Number(vehicle.stock) > 0 ? vehicle.stock + " in stock" : "Out of stock") + "</span>" +
                "</div>" +
                "<strong>" + money(vehicle.price) + "</strong>";
            card.setAttribute("data-model", vehicle.model || "");
            card.addEventListener("click", function () {
                var model = this.getAttribute("data-model");
                for (var j = 0; j < state.vehicles.length; j++) {
                    if (state.vehicles[j].model === model) {
                        setSelected(state.vehicles[j]);
                        return;
                    }
                }
            });
            list.appendChild(card);
        }
    }

    function renderColors() {
        var grid = $("#colorGrid");
        if (!grid) return;
        grid.innerHTML = "";
        for (var i = 0; i < state.colors.length; i++) {
            var color = state.colors[i];
            var swatch = document.createElement("button");
            swatch.className = "swatch";
            swatch.style.background = color.hex || "#fff";
            swatch.title = color.label || "Color " + (i + 1);
            swatch.setAttribute("data-index", String(i));
            var active = state.paintTarget === "primary" ? (state.primary || state.colors[0]) === color : (state.secondary || state.primary || state.colors[0]) === color;
            toggleClass(swatch, "active", active);
            swatch.addEventListener("click", function () {
                var selected = state.colors[Number(this.getAttribute("data-index"))] || state.colors[0];
                if (state.paintTarget === "primary") {
                    state.primary = selected;
                    if (!state.secondary) state.secondary = selected;
                } else {
                    state.secondary = selected;
                }
                setText("#colorLabel", colorLabel() || "Factory");
                renderColors();
                post("setColor", selectedColorPayload());
            });
            grid.appendChild(swatch);
        }
        setText("#colorLabel", colorLabel() || "Factory");
    }

    function renderPayments() {
        var select = $("#paymentSelect");
        if (!select) return;
        select.innerHTML = "";
        var labels = { cash: "Cash", bank: "Bank", finance: "Finance" };
        var methods = ["cash", "bank", "finance"];
        for (var i = 0; i < methods.length; i++) {
            var method = methods[i];
            if (state.payments[method]) {
                var option = document.createElement("option");
                option.value = method;
                option.textContent = labels[method];
                select.appendChild(option);
            }
        }
        select.value = state.payments.bank ? "bank" : ((select.options[0] && select.options[0].value) || "cash");
        toggleFinanceFields();
    }

    function toggleFinanceFields() {
        var fields = $("#financeFields");
        var select = $("#paymentSelect");
        toggleClass(fields, "active", !!(select && select.value === "finance"));
    }

    function updateStats(stats) {
        stats = stats || {};
        var speed = Number(stats.speed || 0);
        var acceleration = Number(stats.acceleration || 0);
        var traction = Number(stats.traction || 0);
        var braking = Number(stats.braking || 0);
        setText("#speedValue", speed + " KM/H");
        setText("#handlingValue", traction.toFixed(1));
        setText("#powerValue", acceleration.toFixed(1));
        setText("#brakeValue", braking.toFixed(1));
        if ($("#speedBar")) $("#speedBar").style.width = Math.min(speed / 3.8, 100) + "%";
        if ($("#handlingBar")) $("#handlingBar").style.width = Math.min((traction / 30.0) * 100, 100) + "%";
        if ($("#powerBar")) $("#powerBar").style.width = Math.min((acceleration / 30.0) * 100, 100) + "%";
        if ($("#brakeBar")) $("#brakeBar").style.width = Math.min((braking / 30.0) * 100, 100) + "%";
    }

    function openCatalog(payload) {
        payload = payload || {};
        showApp();
        removeClass(document.body, "panel-only");
        addClass($("#managementPanel"), "hidden");
        addClass($("#financePanel"), "hidden");

        state.shop = payload.shop || {};
        state.vehicles = payload.vehicles || [];
        state.categories = payload.categories || [];
        state.colors = payload.colors || [{ label: "Factory White", primary: 111, secondary: 111, hex: "#f2f4f7" }];
        state.payments = payload.payments || { cash: true, bank: true, finance: true };
        state.canManage = !!payload.canManage;
        state.primary = state.colors[0] || null;
        state.secondary = state.colors[0] || null;
        state.activeCategory = "all";
        state.search = "";

        if ($("#searchInput")) $("#searchInput").value = "";
        var shopLabel = (state.shop && state.shop.label) || "PDM Vehicle Shop";
        setText("#shopName", shopLabel);
        setText("#catalogShopName", shopLabel);
        if ($("#managementBtn")) $("#managementBtn").style.display = state.canManage ? "block" : "none";

        renderCategories();
        renderColors();
        renderPayments();
        if (state.vehicles[0]) {
            setSelected(state.vehicles[0]);
        } else {
            state.selected = null;
            setText("#categoryTitle", "CATALOG");
            setText("#vehicleName", "No Vehicles");
            setText("#priceValue", "$0");
            renderVehicles();
        }
    }

    function renderManagement() {
        var panel = $("#managementPanel");
        var rows = $("#managementRows");
        if (!panel || !rows) return;
        addClass($("#financePanel"), "hidden");
        var search = String(($("#managementSearch") && $("#managementSearch").value) || "").toLowerCase();
        var source = (state.management && state.management.vehicles) || [];
        var vehicles = [];
        for (var i = 0; i < source.length; i++) {
            var vehicle = source[i];
            var haystack = String((vehicle.name || "") + " " + (vehicle.brand || "") + " " + (vehicle.model || "") + " " + (vehicle.category || "")).toLowerCase();
            if (!search || haystack.indexOf(search) !== -1) vehicles.push(vehicle);
        }
        setText("#managementShop", (state.management && state.management.shop && state.management.shop.label) || "Stock and price control");
        rows.innerHTML = "";
        for (var j = 0; j < vehicles.length; j++) {
            var item = vehicles[j];
            var row = document.createElement("div");
            row.className = "management-row";
            row.innerHTML =
                "<div>" +
                    "<h3>" + (item.brand || "") + " " + (item.name || item.model || "Vehicle") + "</h3>" +
                    "<small>" + (item.category || "catalog") + " | " + (item.model || "") + "</small>" +
                "</div>" +
                "<input class=\"stock\" type=\"number\" min=\"0\" value=\"" + (Number(item.stock) || 0) + "\">" +
                "<input class=\"price\" type=\"number\" min=\"0\" value=\"" + (Number(item.price) || 0) + "\">" +
                "<label><input class=\"enabled\" type=\"checkbox\" " + (item.enabled ? "checked" : "") + "> Listed</label>" +
                "<button>Save</button>";
            row.setAttribute("data-model", item.model || "");
            row.querySelector("button").addEventListener("click", function () {
                post("saveStock", {
                    model: this.parentNode.getAttribute("data-model"),
                    stock: Number(this.parentNode.querySelector(".stock").value) || 0,
                    price: Number(this.parentNode.querySelector(".price").value) || 0,
                    enabled: this.parentNode.querySelector(".enabled").checked
                });
            });
            rows.appendChild(row);
        }
        removeClass(panel, "hidden");
    }

    function renderFinance() {
        var panel = $("#financePanel");
        var rows = $("#financeRows");
        if (!panel || !rows) return;
        addClass($("#managementPanel"), "hidden");
        rows.innerHTML = "";
        if (!state.finance.length) {
            rows.innerHTML = "<div class=\"finance-empty\">No active vehicle finance.</div>";
            removeClass(panel, "hidden");
            return;
        }
        for (var i = 0; i < state.finance.length; i++) {
            var vehicle = state.finance[i];
            var row = document.createElement("div");
            row.className = "finance-row";
            row.innerHTML =
                "<div>" +
                    "<h3>" + (vehicle.brand || "") + " " + (vehicle.name || vehicle.model || "Vehicle") + "</h3>" +
                    "<small>" + (vehicle.plate || "NO PLATE") + " | " + (vehicle.model || "unknown") + "</small>" +
                "</div>" +
                "<span>Balance " + money(vehicle.balance) + "</span>" +
                "<span>Due " + money(vehicle.paymentAmount) + " | " + (vehicle.paymentsLeft || 0) + " left</span>" +
                "<input type=\"number\" min=\"" + (Number(vehicle.paymentAmount) || 1) + "\" placeholder=\"Payment\">" +
                "<button class=\"pay\">Pay</button>" +
                "<button class=\"full\">Pay Off</button>";
            row.setAttribute("data-index", String(i));
            row.querySelector(".pay").addEventListener("click", function () {
                var item = state.finance[Number(this.parentNode.getAttribute("data-index"))];
                post("makeFinancePayment", {
                    plate: item.plate,
                    amount: Number(this.parentNode.querySelector("input").value) || 0,
                    balance: item.balance,
                    paymentsLeft: item.paymentsLeft,
                    paymentAmount: item.paymentAmount
                });
            });
            row.querySelector(".full").addEventListener("click", function () {
                var item = state.finance[Number(this.parentNode.getAttribute("data-index"))];
                post("payFinanceFull", {
                    plate: item.plate,
                    balance: item.balance
                });
            });
            rows.appendChild(row);
        }
        removeClass(panel, "hidden");
    }

    function debugOpen() {
        showApp();
        removeClass(document.body, "panel-only");
        addClass($("#managementPanel"), "hidden");
        addClass($("#financePanel"), "hidden");
        setText("#categoryTitle", "NUI");
        setText("#vehicleName", "Online");
        setText("#shopName", "Debug Open");
        setText("#catalogShopName", "NUI is rendering");
        setText("#catalogCount", "0 vehicles");
        setText("#priceValue", "$0");
    }

    function bindEvents() {
        if ($("#closeBtn")) $("#closeBtn").addEventListener("click", function () { post("close"); });
        if ($("#searchInput")) $("#searchInput").addEventListener("input", function (event) {
            state.search = event.target.value;
            renderVehicles();
        });
        var paintButtons = document.querySelectorAll("[data-paint]");
        for (var i = 0; i < paintButtons.length; i++) {
            paintButtons[i].addEventListener("click", function () {
                state.paintTarget = this.getAttribute("data-paint");
                for (var j = 0; j < paintButtons.length; j++) removeClass(paintButtons[j], "active");
                addClass(this, "active");
                renderColors();
            });
        }
        if ($("#paymentSelect")) $("#paymentSelect").addEventListener("change", toggleFinanceFields);
        if ($("#testDriveBtn")) $("#testDriveBtn").addEventListener("click", function () {
            if (state.selected) post("testDrive", { model: state.selected.model });
        });
        if ($("#buyBtn")) $("#buyBtn").addEventListener("click", function () {
            if (!state.selected) return;
            var payment = $("#paymentSelect").value;
            var color = selectedColorPayload();
            post("purchaseVehicle", {
                model: state.selected.model,
                payment: payment,
                primary: color.primary,
                secondary: color.secondary,
                downPayment: Number($("#downPayment").value) || 0,
                payments: Number($("#paymentCount").value) || 0,
                financeAccount: $("#financeAccount").value
            });
        });
        if ($("#managementBtn")) $("#managementBtn").addEventListener("click", function () { post("openManagement"); });
        if ($("#closeManagement")) $("#closeManagement").addEventListener("click", function () {
            if (hasClass(document.body, "panel-only")) post("close");
            else addClass($("#managementPanel"), "hidden");
        });
        if ($("#managementSearch")) $("#managementSearch").addEventListener("input", renderManagement);
        if ($("#closeFinance")) $("#closeFinance").addEventListener("click", function () {
            if (hasClass(document.body, "panel-only")) post("close");
            else addClass($("#financePanel"), "hidden");
        });
        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape") post("close");
        });
    }

    window.addEventListener("message", function (event) {
        var data = event.data || {};
        if (data.action === "open") openCatalog(data);
        if (data.action === "close") hideApp();
        if (data.action === "stats") updateStats(data.stats || {});
        if (data.action === "openManagementShell") {
            showApp();
            addClass(document.body, "panel-only");
            removeClass($("#managementPanel"), "hidden");
            addClass($("#financePanel"), "hidden");
        }
        if (data.action === "managementData") {
            state.management = data.data;
            renderManagement();
        }
        if (data.action === "openFinanceShell") {
            showApp();
            addClass(document.body, "panel-only");
            removeClass($("#financePanel"), "hidden");
            addClass($("#managementPanel"), "hidden");
        }
        if (data.action === "financeData") {
            state.finance = data.vehicles || [];
            renderFinance();
        }
        if (data.action === "debugOpen") debugOpen();
    });

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", function () {
            bindEvents();
            setTimeout(function () { post("ready", { loaded: true }); }, 100);
        });
    } else {
        bindEvents();
        setTimeout(function () { post("ready", { loaded: true }); }, 100);
    }
})();
