let CalculatorExpression = "";
let TabletPlayerData = {};
let TabletMiningJobs = [];
let TabletMiningTimer = null;
let RacingOriginalParent = null;
let RacingPlaceholder = null;
let TabletLaunchedFromPhone = false;

function PrpPhoneNotify(title, text, icon, color) {
    PRP.Phone.Notifications.Add(icon || "fas fa-info-circle", title, text, color || "#111827", 3000);
}

function GetPhoneCryptoShort() {
    if (window.PRP && PRP.Phone && PRP.Phone.Functions && PRP.Phone.Functions.GetCryptoDisplayShort) {
        return PRP.Phone.Functions.GetCryptoDisplayShort();
    }

    return "BTC";
}

function GetPhoneCryptoShopLabel() {
    if (window.PRP && PRP.Phone && PRP.Phone.Functions && PRP.Phone.Functions.GetCryptoShopLabel) {
        return PRP.Phone.Functions.GetCryptoShopLabel();
    }

    return GetPhoneCryptoShort() + " only";
}

function FormatMoney(amount) {
    amount = Number(amount) || 0;
    return "$" + amount.toLocaleString("en-US", { maximumFractionDigits: 0 });
}

function PhoneAppRequest(app, action, payload, cb) {
    if (window.PRP && PRP.Phone && PRP.Phone.Functions && PRP.Phone.Functions.AppRequest) {
        PRP.Phone.Functions.AppRequest(app, action, payload, cb);
        return;
    }

    $.post("https://prp-phone/PhoneAppRequest", JSON.stringify({
        app: app,
        action: action,
        payload: payload || {},
    }), cb || function() {});
}

function UpdateCalculatorDisplay() {
    $(".calculator-display").text(CalculatorExpression || "0");
}

function RenderCryptoShop(items) {
    const list = $(".cryptoshop-items");
    list.html("");
    $(".cryptoshop-currency-label").text(GetPhoneCryptoShopLabel());

    if (!items || items.length === 0) {
        list.append('<div class="prp-simple-card"><span class="prp-simple-title">No stock</span><p>Nothing is listed right now.</p></div>');
        return;
    }

    $.each(items, function(_, item) {
        list.append(
            '<div class="cryptoshop-item">' +
                '<div><strong>' + item.label + '</strong><span>x' + item.amount + ' for ' + item.price + ' ' + GetPhoneCryptoShort() + '</span></div>' +
                '<button class="cryptoshop-buy" data-item="' + item.item + '">Buy</button>' +
            '</div>'
        );
    });
}

function LoadCryptoShop() {
    $.post("https://prp-phone/GetCryptoShopItems", JSON.stringify({}), function(resp) {
        RenderCryptoShop(resp || []);
    });
}

function RenderFinances(resp) {
    const summary = $(".finances-summary");
    const products = $(".finances-products");
    const loans = $(".finances-loans");

    summary.html("");
    products.html("");
    loans.html("");

    if (!resp || (resp.success === false && !resp.profile)) {
        $(".finances-score").text("Unavailable");
        summary.append('<div class="prp-simple-card"><span class="prp-simple-title">Finances unavailable</span><p>' + EscapeHtml((resp && resp.message) || "The finance connector is offline.") + '</p></div>');
        return;
    }

    const profile = resp.profile || {};
    const creditScore = Number(profile.creditScore || profile.credit_score || 0);
    $(".finances-score").text("Credit score " + creditScore);
    summary.append(
        '<div class="finance-score-card">' +
            '<span>Credit Score</span>' +
            '<strong>' + creditScore + '</strong>' +
            '<p>' + EscapeHtml(profile.rating || "Building history") + '</p>' +
        '</div>'
    );

    products.append('<span class="finance-section-title">Loan Offers</span>');
    if (!resp.products || resp.products.length === 0) {
        products.append('<div class="prp-simple-card"><span class="prp-simple-title">No offers</span><p>No loans are available for this credit profile.</p></div>');
    } else {
        $.each(resp.products, function(_, product) {
            const disabled = product.available === false ? " disabled" : "";
            const note = product.available === false ? EscapeHtml(product.reason || "Credit score too low") : "Estimated payment " + FormatMoney(product.paymentAmount);
            products.append(
                '<div class="finance-product">' +
                    '<div><strong>' + EscapeHtml(product.label) + '</strong><span>' + FormatMoney(product.amount) + ' at ' + Number(product.interestRate * 100).toFixed(1) + '%</span><p>' + note + '</p></div>' +
                    '<button class="finance-apply" data-product="' + EscapeHtml(product.id) + '"' + disabled + '>Apply</button>' +
                '</div>'
            );
        });
    }

    loans.append('<span class="finance-section-title">Current Loans</span>');
    if (!resp.loans || resp.loans.length === 0) {
        loans.append('<div class="prp-simple-card"><span class="prp-simple-title">No loans</span><p>You do not have any active finance agreements.</p></div>');
    } else {
        $.each(resp.loans, function(_, loan) {
            const status = loan.status || "active";
            const payment = Math.min(Number(loan.paymentAmount) || Number(loan.balance) || 0, Number(loan.balance) || 0);
            loans.append(
                '<div class="finance-loan">' +
                    '<div class="finance-loan-top"><strong>' + EscapeHtml(loan.label || "Loan") + '</strong><span class="finance-loan-status">' + EscapeHtml(status) + '</span></div>' +
                    '<div class="finance-loan-meta"><span>Balance ' + FormatMoney(loan.balance) + '</span><span>Payment ' + FormatMoney(payment) + '</span></div>' +
                    '<button class="finance-pay" data-loan="' + loan.id + '" data-amount="' + payment + '">Pay ' + FormatMoney(payment) + '</button>' +
                '</div>'
            );
        });
    }
}

function LoadFinances() {
    $(".finances-score").text("Loading...");
    $(".finances-summary").html('<div class="prp-simple-card"><span class="prp-simple-title">Loading</span><p>Fetching finance profile...</p></div>');
    $(".finances-products, .finances-loans").html("");
    PhoneAppRequest("finances", "profile", {}, RenderFinances);
}

function LoadGangStatus() {
    $.post("https://prp-phone/GetGangControlData", JSON.stringify({}), function(resp) {
        if (!resp || !resp.gang) {
            $(".gang-status").text("No gang");
            return;
        }

        const bossText = resp.isBoss ? "Boss access" : "Member access";
        $(".gang-status").text(resp.gang.label + " - " + bossText);
    });
}

function LoadPrpPhoneApp(app) {
    if (app === "cryptoshop") {
        LoadCryptoShop();
    } else if (app === "gang") {
        LoadGangStatus();
    } else if (app === "finances") {
        LoadFinances();
    }
}

window.LoadPrpPhoneApp = LoadPrpPhoneApp;

function EscapeHtml(value) {
    return $("<div>").text(value || "").html();
}

function GetTabletDriveMessage(data) {
    const status = data.tabletStatus || {};
    const drive = status.cryptoDrive;

    if (drive && drive.label) {
        return drive.label + " inserted";
    }

    return "No crypto drive inserted";
}

function FormatEta(seconds) {
    seconds = Math.max(Math.ceil(Number(seconds) || 0), 0);
    const minutes = Math.floor(seconds / 60);
    const remainder = seconds % 60;

    if (minutes <= 0) return remainder + "s";
    return minutes + "m " + remainder + "s";
}

function GetMiningJobState(job) {
    const now = Date.now() / 1000;
    const startedAt = Number(job.startedAt) || now;
    const finishesAt = Number(job.finishesAt) || (startedAt + (Number(job.seconds) || 0));
    const total = Math.max(Number(job.seconds) || (finishesAt - startedAt), 1);
    const remaining = Math.max(finishesAt - now, 0);
    const progress = Math.min(Math.max(((total - remaining) / total) * 100, 0), 100);

    return {
        remaining: remaining,
        progress: progress
    };
}

function RenderTabletMiningJobs(jobs) {
    const list = $(".tablet-mining-jobs");
    if (jobs) {
        TabletMiningJobs = jobs;
    }

    list.html("");
    TabletMiningJobs = (TabletMiningJobs || []).filter(function(job) {
        return GetMiningJobState(job).remaining > 0;
    });

    if (TabletMiningJobs.length === 0) {
        list.append('<div class="tablet-empty-state">No active crypto USBs.</div>');
        return;
    }

    $.each(TabletMiningJobs, function(_, job) {
        const state = GetMiningJobState(job);
        const progress = Math.floor(state.progress);
        list.append(
            '<div class="tablet-mining-job" data-rig-id="' + EscapeHtml(job.id) + '">' +
                '<div class="tablet-mining-job-top">' +
                    '<strong>' + EscapeHtml(job.label || "Crypto USB") + '</strong>' +
                    '<span>ETA ' + FormatEta(state.remaining) + '</span>' +
                '</div>' +
                '<div class="tablet-mining-bar"><div style="width: ' + progress + '%"></div></div>' +
                '<div class="tablet-mining-job-bottom">' + progress + '% complete</div>' +
            '</div>'
        );
    });
}

function EnsureTabletMiningTimer() {
    if (TabletMiningTimer) return;

    TabletMiningTimer = setInterval(function() {
        if (!$(".tablet-container").is(":visible")) return;
        RenderTabletMiningJobs();
    }, 1000);
}

function UpdateTabletCryptoStatus(data) {
    data = data || {};
    const status = data.tabletStatus || data || {};
    $(".tablet-mining-status").text(GetTabletDriveMessage({ tabletStatus: status }));
    RenderTabletMiningJobs(status.activeMining || data.activeMining || []);
    EnsureTabletMiningTimer();
}

function OpenTablet(data) {
    TabletLaunchedFromPhone = !!(window.PRP && PRP.Phone && PRP.Phone.Data && PRP.Phone.Data.IsOpen && $(".container").is(":visible"));
    TabletPlayerData = data.PlayerData || {};
    if (window.PRP && PRP.Phone && PRP.Phone.Data && data.PlayerData) {
        PRP.Phone.Data.PlayerData = data.PlayerData;
    }

    $(".container").toggleClass("phone-covered-by-tablet", TabletLaunchedFromPhone);
    $(".tablet-container").fadeIn(120);
    $(".tablet-app-grid").html("");
    UpdateTabletCryptoStatus(data);
    SetTabletPage("home");

    $.each(data.applications || {}, function(key, app) {
        $(".tablet-app-grid").append(
            '<div class="tablet-app-card" data-tablet-card="' + key + '">' +
                '<i class="' + app.icon + '"></i>' +
                '<strong>' + app.label + '</strong>' +
                '<span>' + app.description + '</span>' +
            '</div>'
        );
    });
}

function AttachRacingToTablet() {
    const racingApp = $(".racing-app");
    const host = $(".tablet-racing-host");

    if (!host.length) return;
    if (!racingApp.length) {
        host.html('<div class="tablet-empty-state">Racing is unavailable.</div>');
        return;
    }

    if (!RacingOriginalParent) {
        RacingOriginalParent = racingApp.parent();
        RacingPlaceholder = $('<div class="racing-phone-placeholder"></div>');
        racingApp.before(RacingPlaceholder);
    }

    host.append(racingApp);
    racingApp.show();

    if (typeof SetupRaces === "function") {
        $.post("https://prp-phone/GetAvailableRaces", JSON.stringify({}), function(races) {
            SetupRaces(races || []);
        });
    }
}

function RestoreRacingFromTablet() {
    const racingApp = $(".racing-app");
    if (!RacingOriginalParent || !RacingPlaceholder || !racingApp.length) return;

    racingApp.hide();
    RacingPlaceholder.before(racingApp);
    RacingPlaceholder.remove();
    RacingOriginalParent = null;
    RacingPlaceholder = null;
}

function RenderTabletBusiness(resp) {
    const status = $(".tablet-business-status");
    const list = $(".tablet-business-list");
    list.html("");

    if (!resp || !resp.success) {
        status.text((resp && resp.message) || "Business data unavailable.");
        return;
    }

    const employees = resp.employees || [];
    const job = resp.job || {};
    status.text((job.label || job.name || "Business") + " - " + employees.length + " employee(s)");

    if (employees.length === 0) {
        list.append('<div class="tablet-empty-state">No employees found.</div>');
        return;
    }

    $.each(employees, function(_, employee) {
        const isSelf = employee.citizenid === TabletPlayerData.citizenid;
        const onlineText = employee.online ? "Online" : "Offline";
        const bossText = employee.isBoss ? "Boss" : "Staff";
        const action = isSelf
            ? '<span class="tablet-business-self">You</span>'
            : '<button class="tablet-business-fire" data-citizenid="' + EscapeHtml(employee.citizenid) + '">Fire</button>';

        list.append(
            '<div class="tablet-business-row">' +
                '<div class="tablet-business-main">' +
                    '<strong>' + EscapeHtml(employee.name) + '</strong>' +
                    '<span>' + EscapeHtml(employee.grade) + ' - ' + bossText + '</span>' +
                '</div>' +
                '<div class="tablet-business-meta ' + (employee.online ? 'online' : '') + '">' + onlineText + '</div>' +
                action +
            '</div>'
        );
    });
}

function LoadTabletBusiness() {
    $(".tablet-business-status").text("Loading business data...");
    $(".tablet-business-list").html("");
    $.post("https://prp-phone/GetBusinessControlData", JSON.stringify({}), RenderTabletBusiness);
}

function HideTablet() {
    RestoreRacingFromTablet();
    $(".container").removeClass("phone-covered-by-tablet");
    TabletLaunchedFromPhone = false;
    $(".tablet-container").fadeOut(120);
}

function CloseTablet() {
    HideTablet();
    $.post("https://prp-phone/CloseTablet", JSON.stringify({}));
}

$(document).on("keydown", function(event) {
    if ((event.key === "Escape" || event.keyCode === 27) && $(".tablet-container").is(":visible")) {
        event.preventDefault();
        CloseTablet();
    }
});

function SetTabletPage(page) {
    $(".tablet-nav").removeClass("active");
    $('.tablet-nav[data-tablet-tab="' + page + '"]').addClass("active");
    $(".tablet-page").removeClass("active");
    $(".tablet-page-" + page).addClass("active");

    if (page === "racing") {
        AttachRacingToTablet();
    } else {
        RestoreRacingFromTablet();
    }

    if (page === "business") {
        LoadTabletBusiness();
    }
}

$(document).on("click", ".cryptoshop-buy", function() {
    const item = $(this).data("item");
    $.post("https://prp-phone/BuyCryptoShopItem", JSON.stringify({ item: item }), function(resp) {
        if (resp && resp.success) {
            PrpPhoneNotify("Crypto Shop", resp.message || "Purchased", "fas fa-shopping-bag", "#0f766e");
            LoadCryptoShop();
        } else {
            PrpPhoneNotify("Crypto Shop", (resp && resp.message) || "Purchase failed", "fas fa-shopping-bag", "#b91c1c");
        }
    });
});

$(document).on("click", ".finance-apply", function() {
    const productId = $(this).data("product");
    PhoneAppRequest("finances", "applyLoan", { productId: productId }, function(resp) {
        if (resp && resp.success) {
            PrpPhoneNotify("Finances", resp.message || "Loan approved", "fas fa-chart-line", "#0f766e");
        } else {
            PrpPhoneNotify("Finances", (resp && resp.message) || "Loan declined", "fas fa-chart-line", "#b91c1c");
        }
        RenderFinances(resp);
    });
});

$(document).on("click", ".finance-pay", function() {
    const loanId = Number($(this).data("loan"));
    const amount = Number($(this).data("amount"));
    PhoneAppRequest("finances", "makePayment", { loanId: loanId, amount: amount }, function(resp) {
        if (resp && resp.success) {
            PrpPhoneNotify("Finances", resp.message || "Payment made", "fas fa-chart-line", "#0f766e");
        } else {
            PrpPhoneNotify("Finances", (resp && resp.message) || "Payment failed", "fas fa-chart-line", "#b91c1c");
        }
        RenderFinances(resp);
    });
});

$(document).on("click", "#gang-hire-closest", function() {
    $.post("https://prp-phone/GangHireClosest", JSON.stringify({}), function(resp) {
        PrpPhoneNotify("Gang Control", (resp && resp.message) || "Done", "fas fa-users-cog", resp && resp.success ? "#111827" : "#b91c1c");
    });
});

$(document).on("click", "#gang-fire-closest", function() {
    $.post("https://prp-phone/GangFireClosest", JSON.stringify({}), function(resp) {
        PrpPhoneNotify("Gang Control", (resp && resp.message) || "Done", "fas fa-users-cog", resp && resp.success ? "#111827" : "#b91c1c");
    });
});

$(document).on("click", "#gang-give-keys", function() {
    $.post("https://prp-phone/GangGiveKeys", JSON.stringify({}), function(resp) {
        PrpPhoneNotify("Gang Control", (resp && resp.message) || "Done", "fas fa-key", resp && resp.success ? "#111827" : "#b91c1c");
    });
});

$(document).on("click", "#gang-open-menu", function() {
    $.post("https://prp-phone/OpenGangMenu", JSON.stringify({}), function(resp) {
        if (resp && !resp.success) {
            PrpPhoneNotify("Gang Control", resp.message || "Access denied", "fas fa-users-cog", "#b91c1c");
        }
    });
});

$(document).on("click", ".calculator-grid button", function() {
    const value = String($(this).data("calc"));
    if (value === "clear") {
        CalculatorExpression = "";
    } else if (value === "back") {
        CalculatorExpression = CalculatorExpression.slice(0, -1);
    } else if (value === "equals") {
        try {
            if (/^[0-9+\-*/. ()]+$/.test(CalculatorExpression)) {
                CalculatorExpression = String(Function("return (" + CalculatorExpression + ")")());
            }
        } catch (e) {
            CalculatorExpression = "Error";
        }
    } else {
        if (CalculatorExpression === "Error") CalculatorExpression = "";
        CalculatorExpression += value;
    }

    UpdateCalculatorDisplay();
});

$(document).on("click", ".tablet-nav", function() {
    SetTabletPage($(this).data("tablet-tab"));
});

$(document).on("click", ".tablet-app-card", function() {
    SetTabletPage($(this).data("tablet-card"));
});

$(document).on("click", "#tablet-close", CloseTablet);

$(document).on("click", "#tablet-business-refresh", function() {
    LoadTabletBusiness();
});

$(document).on("click", "#tablet-business-hire", function() {
    $.post("https://prp-phone/BusinessHireClosest", JSON.stringify({}), function(resp) {
        if (resp && resp.success) {
            PrpPhoneNotify("Business", resp.message || "Player hired", "fas fa-briefcase", "#0f766e");
            LoadTabletBusiness();
        } else {
            PrpPhoneNotify("Business", (resp && resp.message) || "No one nearby", "fas fa-briefcase", "#b91c1c");
        }
    });
});

$(document).on("click", ".tablet-business-fire", function() {
    const citizenid = $(this).data("citizenid");
    $.post("https://prp-phone/BusinessFireMember", JSON.stringify({ citizenid: citizenid }), function(resp) {
        if (resp && resp.success) {
            PrpPhoneNotify("Business", resp.message || "Employee fired", "fas fa-briefcase", "#0f766e");
            LoadTabletBusiness();
        } else {
            PrpPhoneNotify("Business", (resp && resp.message) || "Could not fire employee", "fas fa-briefcase", "#b91c1c");
        }
    });
});

$(document).on("click", "#tablet-start-mining", function() {
    $.post("https://prp-phone/TabletStartCryptoMine", JSON.stringify({}), function(resp) {
        if (resp && resp.activeMining) {
            RenderTabletMiningJobs(resp.activeMining);
        }

        if (resp && resp.success) {
            $(".tablet-mining-status").text(resp.message || "Mining started");
        } else {
            $(".tablet-mining-status").text((resp && resp.message) || "Crypto drive required");
        }
    });
});

$(document).ready(function() {
    window.addEventListener("message", function(event) {
        switch (event.data.action) {
            case "openTablet":
                OpenTablet(event.data);
                break;
            case "closeTablet":
                HideTablet();
                break;
            case "forceClosePhone":
                HideTablet();
                if (PRP.Phone && PRP.Phone.Functions && PRP.Phone.Functions.Close) {
                    PRP.Phone.Functions.Close();
                }
                break;
            case "openPhoneApplication": {
                let attempts = 0;
                const appOpenTimer = setInterval(function() {
                    const appButton = $('.phone-application[data-app="' + event.data.app + '"]');
                    attempts += 1;
                    if (appButton.length > 0 || attempts >= 10) {
                        clearInterval(appOpenTimer);
                        appButton.trigger("click");
                    }
                }, 150);
                break;
            }
            case "tabletMiningComplete":
                if (event.data.activeMining) {
                    RenderTabletMiningJobs(event.data.activeMining);
                } else {
                    RenderTabletMiningJobs();
                }
                $(".tablet-mining-status").text(event.data.message || "Crypto reward received");
                PrpPhoneNotify("Crypto Rig", event.data.message || "Crypto reward received", "fas fa-microchip", "#0f766e");
                break;
        }
    });
});
