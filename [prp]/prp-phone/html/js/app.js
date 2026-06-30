var PRP = window.PRP || {};
window.PRP = PRP;
var QB = PRP;
window.QB = QB;
PRP.Phone = {}
PRP.Screen = {}
PRP.Phone.Functions = {}
PRP.Phone.Animations = {}
PRP.Phone.Notifications = {}
PRP.Phone.ContactColors = {
    0: "#9b59b6",
    1: "#3498db",
    2: "#e67e22",
    3: "#e74c3c",
    4: "#1abc9c",
    5: "#9c88ff",
}

PRP.Phone.Data = {
    currentApplication: null,
    PlayerData: {},
    Applications: {},
    IsOpen: false,
    CallActive: false,
    MetaData: {},
    PlayerJob: {},
    AnonymousCall: false,
    IsEditingApps: false,
    CryptoConfig: {
        ProviderCoin: "btc",
        DisplayName: "Bitcoin",
        DisplayShort: "BTC",
        ShopLabel: "BTC only",
    },
}

PRP.Phone.Data.MaxSlots = 28;
PRP.Phone.ApplicationDrag = {
    fromSlot: null,
    toSlot: null,
    source: null,
    ghost: null,
    holdTimer: null,
    startX: 0,
    startY: 0,
    isDragging: false,
    suppressClick: false,
}

OpenedChatData = {
    number: null,
}

var CanOpenApp = true;
var up = false

PRP.Phone.Functions.PrepareApplicationForOpen = function(app) {
    var AppObject = $("."+app+"-app");

    $(".phone-application-container").stop(true, true).css({"display":"block", "top":""});
    $(".phone-application-container > div").each(function() {
        var RootObject = $(this);
        RootObject.stop(true, true).css({"top":"", "left":""});

        if (!RootObject.hasClass(app+"-app")) {
            RootObject.css({"display":"none"});
        }
    });

    AppObject.stop(true, true).css({"display":"block", "top":"", "left":""});
}

PRP.Phone.Functions.HideApplicationLayer = function(app) {
    var AppObject = app ? $("."+app+"-app") : $(".phone-application-container > div");

    AppObject.stop(true, true).css({"display":"none", "top":"", "left":""});
    $(".phone-application-container").stop(true, true).css({"display":"none", "top":""});
    CanOpenApp = true;
}

PRP.Phone.Functions.GetApplicationSlot = function(app) {
    var defaultSlot = parseInt(app.slot);
    var layout = ((PRP.Phone.Data.MetaData || {}).applayout || {});
    var savedSlot = parseInt(layout[app.app]);

    if (!isNaN(savedSlot) && savedSlot >= 1 && savedSlot <= PRP.Phone.Data.MaxSlots) {
        return savedSlot;
    }

    return defaultSlot;
}

PRP.Phone.Functions.GetApplicationLayout = function() {
    var layout = {};

    $(".phone-applications .phone-application").each(function() {
        var app = $(this).data("app");
        var slot = parseInt($(this).data("appslot"));

        if (app && !isNaN(slot)) {
            layout[app] = slot;
        }
    });

    return layout;
}

PRP.Phone.Functions.SetAppEditMode = function(enabled) {
    PRP.Phone.Data.IsEditingApps = !!enabled;
    $(".phone-applications").toggleClass("editing-app-layout", PRP.Phone.Data.IsEditingApps);
}

PRP.Phone.Functions.SaveApplicationLayout = function() {
    var layout = PRP.Phone.Functions.GetApplicationLayout();
    PRP.Phone.Data.MetaData = PRP.Phone.Data.MetaData || {};
    PRP.Phone.Data.MetaData.applayout = layout;

    $.post('https://prp-phone/SaveAppLayout', JSON.stringify({
        layout: layout,
    }));
}

function IsAppJobBlocked(joblist, myjob) {
    var retval = false;
    var onDuty = !!((((PRP.Phone.Data || {}).PlayerData || {}).job || {}).onduty);
    if (Array.isArray(joblist) && joblist.length > 0) {
        $.each(joblist, function(i, job){
            if (job == myjob && onDuty) {
                retval = true;
            }
        });
    }
    return retval;
}

PRP.Phone.Functions.ClearTooltip = function(element) {
    if (!element) {
        return;
    }

    var $element = $(element);

    if (typeof $element.tooltip === "function") {
        try {
            $element.tooltip("dispose");
        } catch (e) {
            try {
                $element.tooltip("destroy");
            } catch (ignored) {}
        }
    }

    if (window.bootstrap && window.bootstrap.Tooltip && typeof window.bootstrap.Tooltip.getInstance === "function") {
        var instance = window.bootstrap.Tooltip.getInstance(element);
        if (instance) {
            instance.dispose();
        }
    }

    $element
        .removeAttr("title")
        .removeAttr("data-original-title")
        .removeAttr("data-bs-original-title")
        .removeAttr("aria-describedby")
        .removeAttr("data-toggle")
        .removeAttr("data-placement")
        .removeAttr("data-bs-toggle")
        .removeAttr("data-bs-placement")
        .removeData("bs.tooltip")
        .removeData("placement");
}

PRP.Phone.Functions.SetupTooltip = function(element) {
    var $element = $(element);

    if (typeof $element.tooltip === "function") {
        $element.tooltip({container: "body"});
    } else if (window.bootstrap && window.bootstrap.Tooltip) {
        if (typeof window.bootstrap.Tooltip.getOrCreateInstance === "function") {
            window.bootstrap.Tooltip.getOrCreateInstance(element, {container: "body"});
        } else if (typeof window.bootstrap.Tooltip.getInstance !== "function" || !window.bootstrap.Tooltip.getInstance(element)) {
            new window.bootstrap.Tooltip(element, {container: "body"});
        }
    }
}

PRP.Phone.Functions.GetCryptoConfig = function() {
    return PRP.Phone.Data.CryptoConfig || {};
}

PRP.Phone.Functions.GetCryptoProviderCoin = function() {
    return PRP.Phone.Functions.GetCryptoConfig().ProviderCoin || "btc";
}

PRP.Phone.Functions.GetCryptoDisplayName = function() {
    return PRP.Phone.Functions.GetCryptoConfig().DisplayName || "Bitcoin";
}

PRP.Phone.Functions.GetCryptoDisplayShort = function() {
    return PRP.Phone.Functions.GetCryptoConfig().DisplayShort || "BTC";
}

PRP.Phone.Functions.GetCryptoShopLabel = function() {
    return PRP.Phone.Functions.GetCryptoConfig().ShopLabel || (PRP.Phone.Functions.GetCryptoDisplayShort() + " only");
}

PRP.Phone.Functions.AppRequest = function(app, action, payload, cb) {
    $.post("https://prp-phone/PhoneAppRequest", JSON.stringify({
        app: app,
        action: action,
        payload: payload || {},
    }), cb || function() {});
}

PRP.Phone.Functions.SetupApplications = function(data) {
    data = data || {};
    PRP.Phone.Data.Applications = data.applications || {};
    PRP.Phone.Data.PlayerJob = data.PlayerJob || PRP.Phone.Data.PlayerJob || {};
    var currentJobName = ((PRP.Phone.Data.PlayerJob || {}).name) || (((PRP.Phone.Data.PlayerData || {}).job || {}).name) || "";

    var i;
    for (i = 1; i <= PRP.Phone.Data.MaxSlots; i++) {
        var applicationSlot = $(".phone-applications").find('[data-appslot="'+i+'"]');
        $(applicationSlot).find("[data-toggle='tooltip'], [data-bs-toggle='tooltip']").each(function() {
            PRP.Phone.Functions.ClearTooltip(this);
        });
        PRP.Phone.Functions.ClearTooltip(applicationSlot[0]);
        $(applicationSlot).html("");
        $(applicationSlot).css({
            "background-color":"transparent"
        });
        $(applicationSlot).attr("draggable", false);
        $(applicationSlot).attr("data-has-app", "false");
        $(applicationSlot).removeAttr("data-app");
        $(applicationSlot).removeClass("has-app");
        $(applicationSlot).removeData('app');
        $(applicationSlot).removeData('placement')
    }

    $.each(data.applications || [], function(i, app){
        var appSlot = PRP.Phone.Functions.GetApplicationSlot(app);
        var applicationSlot = $(".phone-applications").find('[data-appslot="'+appSlot+'"]');
        var blockedapp = IsAppJobBlocked(app.blockedjobs || [], currentJobName)

        if ((!app.job || app.job === currentJobName) && !blockedapp) {
            $(applicationSlot).css({"background-color":app.color});
            var icon = '<i class="ApplicationIcon '+app.icon+'" style="'+app.style+'"></i>';
            if (app.app == "meos") {
                icon = '<img src="./img/politie.png" class="police-icon">';
            }
            var tooltipPos = app.tooltipPos || "bottom";
            var appIcon = $('<div class="phone-application-icon"></div>');
            appIcon.attr("data-toggle", "tooltip");
            appIcon.attr("data-bs-toggle", "tooltip");
            appIcon.attr("data-placement", tooltipPos);
            appIcon.attr("data-bs-placement", tooltipPos);
            appIcon.attr("data-app", app.app);
            appIcon.prop("title", app.tooltipText || app.app);
            appIcon.html(icon+'<div class="app-unread-alerts">0</div>');
            $(applicationSlot).empty().append(appIcon);
            $(applicationSlot).data('app', app.app);
            $(applicationSlot).attr("data-app", app.app);
            $(applicationSlot).attr("draggable", false);
            $(applicationSlot).attr("data-has-app", "true");
            $(applicationSlot).addClass("has-app");

            if (app.tooltipPos !== undefined) {
                $(applicationSlot).data('placement', app.tooltipPos)
            }
        }
    });

    $('[data-toggle="tooltip"], [data-bs-toggle="tooltip"]').each(function() {
        PRP.Phone.Functions.SetupTooltip(this);
    });
}

PRP.Phone.Functions.SetupAppWarnings = function(AppData) {
    $.each(AppData, function(i, app){
        var appSlot = PRP.Phone.Functions.GetApplicationSlot(app);
        var AppObject = $(".phone-applications").find("[data-appslot='"+appSlot+"']").find('.app-unread-alerts');

        if (app.Alerts > 0) {
            $(AppObject).html(app.Alerts);
            $(AppObject).css({"display":"block"});
        } else {
            $(AppObject).css({"display":"none"});
        }
    });
}

PRP.Phone.Functions.IsAppHeaderAllowed = function(app) {
    var retval = true;
    $.each(Config.HeaderDisabledApps, function(i, blocked){
        if (app == blocked) {
            retval = false;
        }
    });
    return retval;
}

$(document).on('click', '.phone-application', function(e){
    e.preventDefault();

    if (PRP.Phone.ApplicationDrag.isDragging || PRP.Phone.ApplicationDrag.suppressClick) {
        PRP.Phone.ApplicationDrag.suppressClick = false;
        return;
    }

    var PressedApplication = $(this).data('app');
    if (PressedApplication == "tablet") {
        $.post('https://prp-phone/OpenTablet', JSON.stringify({}));
        return;
    }

    var AppObject = $("."+PressedApplication+"-app");

    if (AppObject.length !== 0) {
        if (CanOpenApp) {
            if (PRP.Phone.Data.currentApplication == null) {
                PRP.Phone.Functions.PrepareApplicationForOpen(PressedApplication);
                PRP.Phone.Animations.TopSlideDown('.phone-application-container', 300, 0);

                if (PRP.Phone.Functions.IsAppHeaderAllowed(PressedApplication)) {
                    PRP.Phone.Functions.HeaderTextColor("black", 300);
                }

                PRP.Phone.Data.currentApplication = PressedApplication;

                if (PressedApplication == "settings") {
                    $("#myPhoneNumber").text(PRP.Phone.Data.PlayerData.charinfo.phone);
                    $("#mySerialNumber").text("PRP-" + PRP.Phone.Data.PlayerData.metadata["phonedata"].SerialNumber);
                } else if (PressedApplication == "twitter") {
                    $.post('https://prp-phone/GetMentionedTweets', JSON.stringify({}), function(MentionedTweets){
                        PRP.Phone.Notifications.LoadMentionedTweets(MentionedTweets)
                    })
                    $.post('https://prp-phone/GetHashtags', JSON.stringify({}), function(Hashtags){
                        PRP.Phone.Notifications.LoadHashtags(Hashtags)
                    })
                    if (PRP.Phone.Data.IsOpen) {
                        $.post('https://prp-phone/GetTweets', JSON.stringify({}), function(Tweets){
                            PRP.Phone.Notifications.LoadTweets(Tweets);
                        });
                    }
                } else if (PressedApplication == "bank") {
                    PRP.Phone.Functions.DoBankOpen();
                    $.post('https://prp-phone/GetBankContacts', JSON.stringify({}), function(contacts){
                        PRP.Phone.Functions.LoadContactsWithNumber(contacts);
                    });
                    $.post('https://prp-phone/GetInvoices', JSON.stringify({}), function(invoices){
                        PRP.Phone.Functions.LoadBankInvoices(invoices);
                    });
                } else if (PressedApplication == "whatsapp") {
                    $.post('https://prp-phone/GetWhatsappChats', JSON.stringify({}), function(chats){
                        PRP.Phone.Functions.LoadWhatsappChats(chats);
                    });
                } else if (PressedApplication == "phone") {
                    $.post('https://prp-phone/GetMissedCalls', JSON.stringify({}), function(recent){
                        PRP.Phone.Functions.SetupRecentCalls(recent);
                    });
                    $.post('https://prp-phone/GetSuggestedContacts', JSON.stringify({}), function(suggested){
                        PRP.Phone.Functions.SetupSuggestedContacts(suggested);
                    });
                    $.post('https://prp-phone/ClearGeneralAlerts', JSON.stringify({
                        app: "phone"
                    }));
                } else if (PressedApplication == "mail") {
                    $.post('https://prp-phone/GetMails', JSON.stringify({}), function(mails){
                        PRP.Phone.Functions.SetupMails(mails);
                    });
                    $.post('https://prp-phone/ClearGeneralAlerts', JSON.stringify({
                        app: "mail"
                    }));
                } else if (PressedApplication == "advert") {
                    $.post('https://prp-phone/LoadAdverts', JSON.stringify({}), function(Adverts){
                        PRP.Phone.Functions.RefreshAdverts(Adverts);
                    })
                } else if (PressedApplication == "garage") {
                    $.post('https://prp-phone/SetupGarageVehicles', JSON.stringify({}), function(Vehicles){
                        SetupGarageVehicles(Vehicles);
                    })
                } else if (PressedApplication == "crypto") {
                    $.post('https://prp-phone/GetCryptoData', JSON.stringify({
                        crypto: PRP.Phone.Functions.GetCryptoProviderCoin(),
                    }), function(CryptoData){
                        SetupCryptoData(CryptoData);
                    })

                    $.post('https://prp-phone/GetCryptoTransactions', JSON.stringify({}), function(data){
                        RefreshCryptoTransactions(data);
                    })
                } else if (PressedApplication == "racing") {
                    $.post('https://prp-phone/GetAvailableRaces', JSON.stringify({}), function(Races){
                        SetupRaces(Races);
                    });
                } else if (PressedApplication == "houses") {
                    $.post('https://prp-phone/GetPlayerHouses', JSON.stringify({}), function(Houses){
                        SetupPlayerHouses(Houses);
                    });
                    $.post('https://prp-phone/GetPlayerKeys', JSON.stringify({}), function(Keys){
                        $(".house-app-mykeys-container").html("");
                        if (Keys.length > 0) {
                            $.each(Keys, function(i, key){
                                var elem = '<div class="mykeys-key" id="keyid-'+i+'"><span class="mykeys-key-label">' + key.HouseData.adress + '</span> <span class="mykeys-key-sub">Click to set GPS</span> </div>';
                                $(".house-app-mykeys-container").append(elem);
                                $("#keyid-"+i).data('KeyData', key);
                            });
                        }
                    });
                } else if (PressedApplication == "meos") {
                    SetupMeosHome();
                } else if (PressedApplication == "lawyers") {
                    $.post('https://prp-phone/GetCurrentLawyers', JSON.stringify({}), function(data){
                        SetupLawyers(data);
                    });
                } else if (PressedApplication == "store") {
                    $.post('https://prp-phone/SetupStoreApps', JSON.stringify({}), function(data){
                        SetupAppstore(data);
                    });
                } else if (PressedApplication == "trucker") {
                    $.post('https://prp-phone/GetTruckerData', JSON.stringify({}), function(data){
                        SetupTruckerInfo(data);
                    });
                }
                else if (PressedApplication == "gallery") {
                    $.post('https://prp-phone/GetGalleryData', JSON.stringify({}), function(data){
                        setUpGalleryData(data);
                    });
                }
                else if (PressedApplication == "camera") {
                    $.post('https://prp-phone/TakePhoto', JSON.stringify({}),function(url){
                        setUpCameraApp(url)
                    })
                    PRP.Phone.Functions.Close();
                }

                if (typeof LoadPrpPhoneApp === "function") {
                    LoadPrpPhoneApp(PressedApplication);
                }
                
            }
        }
    } else {
        if (PressedApplication != null){
            PRP.Phone.Notifications.Add("fas fa-exclamation-circle", "System", PRP.Phone.Data.Applications[PressedApplication].tooltipText+" is not available!")
        }
    }
});

PRP.Phone.Functions.GetPointerPosition = function(event) {
    var original = event.originalEvent || event;
    var pointer = (original.touches && original.touches[0]) || (original.changedTouches && original.changedTouches[0]) || original;

    return {
        x: pointer.clientX,
        y: pointer.clientY,
    };
}

PRP.Phone.Functions.GetDropSlotAt = function(pointer) {
    if (!pointer || pointer.x === undefined || pointer.y === undefined) {
        return $();
    }

    var element = document.elementFromPoint(pointer.x, pointer.y);
    var slot = $(element).closest(".phone-application");

    if (slot.length > 0 && slot.closest(".phone-applications").length > 0) {
        return slot;
    }

    return $();
}

PRP.Phone.Functions.MoveApplicationSlot = function(fromSlot, toSlot) {
    if (!fromSlot || !toSlot || fromSlot === toSlot) {
        return;
    }

    var fromApp = $(".phone-applications").find('[data-appslot="'+fromSlot+'"]').data("app");
    var toApp = $(".phone-applications").find('[data-appslot="'+toSlot+'"]').data("app");
    var layout = PRP.Phone.Functions.GetApplicationLayout();

    if (!fromApp) {
        return;
    }

    if (fromApp) {
        layout[fromApp] = toSlot;
    }

    if (toApp) {
        layout[toApp] = fromSlot;
    }

    PRP.Phone.Data.MetaData = PRP.Phone.Data.MetaData || {};
    PRP.Phone.Data.MetaData.applayout = layout;
    PRP.Phone.Functions.SetupApplications({
        applications: PRP.Phone.Data.Applications,
        PlayerJob: PRP.Phone.Data.PlayerJob,
    });
    PRP.Phone.Functions.SetupAppWarnings(PRP.Phone.Data.Applications);
    PRP.Phone.Functions.SaveApplicationLayout();
}

PRP.Phone.Functions.UpdateApplicationDrag = function(event) {
    var drag = PRP.Phone.ApplicationDrag;
    var pointer = PRP.Phone.Functions.GetPointerPosition(event);

    if (!pointer || pointer.x === undefined || pointer.y === undefined) {
        return;
    }

    if (drag.ghost) {
        drag.ghost.css({
            left: pointer.x + "px",
            top: pointer.y + "px",
        });
    }

    $(".phone-application").removeClass("app-drop-target");

    var targetSlot = PRP.Phone.Functions.GetDropSlotAt(pointer);
    if (targetSlot.length > 0) {
        drag.toSlot = parseInt(targetSlot.data("appslot"));
        targetSlot.addClass("app-drop-target");
    } else {
        drag.toSlot = null;
    }
}

PRP.Phone.Functions.BeginApplicationDrag = function(source, event) {
    var drag = PRP.Phone.ApplicationDrag;

    if (!source || drag.isDragging) {
        return;
    }

    drag.source = $(source);
    drag.fromSlot = parseInt(drag.source.data("appslot"));
    drag.toSlot = drag.fromSlot;
    drag.isDragging = true;
    drag.suppressClick = true;

    drag.source.addClass("app-dragging-source");
    drag.ghost = drag.source.clone();
    drag.ghost
        .removeAttr("data-toggle")
        .removeAttr("data-bs-toggle")
        .removeAttr("title")
        .removeAttr("data-original-title")
        .removeAttr("data-bs-original-title")
        .removeAttr("aria-describedby")
        .addClass("prp-app-drag-ghost");
    drag.ghost.find("[data-toggle='tooltip'], [data-bs-toggle='tooltip']").each(function() {
        PRP.Phone.Functions.ClearTooltip(this);
    });
    $("body").append(drag.ghost);

    PRP.Phone.Functions.SetAppEditMode(true);
    PRP.Phone.Functions.UpdateApplicationDrag(event);
}

PRP.Phone.Functions.EndApplicationDrag = function(event) {
    var drag = PRP.Phone.ApplicationDrag;

    if (drag.holdTimer) {
        clearTimeout(drag.holdTimer);
        drag.holdTimer = null;
    }

    if (drag.isDragging) {
        PRP.Phone.Functions.UpdateApplicationDrag(event);
        PRP.Phone.Functions.MoveApplicationSlot(drag.fromSlot, drag.toSlot);
    }

    if (drag.ghost) {
        drag.ghost.remove();
    }

    $(".phone-application").removeClass("app-dragging-source app-drop-target");
    PRP.Phone.Functions.SetAppEditMode(false);

    drag.fromSlot = null;
    drag.toSlot = null;
    drag.source = null;
    drag.ghost = null;
    drag.isDragging = false;
    drag.suppressClick = true;

    setTimeout(function() {
        PRP.Phone.ApplicationDrag.suppressClick = false;
    }, 180);
}

$(document).on('mousedown touchstart', '.phone-application.has-app', function(e) {
    var original = e.originalEvent || e;
    if (original.button !== undefined && original.button !== 0) {
        return;
    }

    var drag = PRP.Phone.ApplicationDrag;
    var pointer = PRP.Phone.Functions.GetPointerPosition(e);

    if (drag.holdTimer) {
        clearTimeout(drag.holdTimer);
    }

    drag.startX = pointer.x;
    drag.startY = pointer.y;
    drag.source = $(this);
    drag.holdTimer = setTimeout(function() {
        drag.holdTimer = null;
        PRP.Phone.Functions.BeginApplicationDrag(drag.source, e);
    }, 450);
});

$(document).on('mousemove touchmove', function(e) {
    var drag = PRP.Phone.ApplicationDrag;

    if (drag.holdTimer && !drag.isDragging) {
        var pointer = PRP.Phone.Functions.GetPointerPosition(e);
        if (Math.abs(pointer.x - drag.startX) > 8 || Math.abs(pointer.y - drag.startY) > 8) {
            clearTimeout(drag.holdTimer);
            drag.holdTimer = null;
        }
        return;
    }

    if (drag.isDragging) {
        e.preventDefault();
        PRP.Phone.Functions.UpdateApplicationDrag(e);
    }
});

$(document).on('mouseup touchend touchcancel', function(e) {
    var drag = PRP.Phone.ApplicationDrag;

    if (drag.holdTimer) {
        clearTimeout(drag.holdTimer);
        drag.holdTimer = null;
        return;
    }

    if (drag.isDragging) {
        e.preventDefault();
        PRP.Phone.Functions.EndApplicationDrag(e);
    }
});

$(document).on('click', '.mykeys-key', function(e){
    e.preventDefault();

    var KeyData = $(this).data('KeyData');

    $.post('https://prp-phone/SetHouseLocation', JSON.stringify({
        HouseData: KeyData
    }))
});

$(document).on('click', '.phone-home-container', function(event){
    event.preventDefault();

    if (PRP.Phone.Data.currentApplication === null) {
        PRP.Phone.Functions.Close();
    } else {
        var ClosingApplication = PRP.Phone.Data.currentApplication;

        PRP.Phone.Animations.TopSlideUp('.phone-application-container', 400, -160);
        PRP.Phone.Animations.TopSlideUp('.'+ClosingApplication+"-app", 400, -160);
        CanOpenApp = false;
        setTimeout(function(){
            PRP.Phone.Functions.ToggleApp(ClosingApplication, "none");
            $("."+ClosingApplication+"-app").css({"top":"", "left":""});
            $(".phone-application-container").css({"display":"none", "top":""});
            CanOpenApp = true;
        }, 400)
        PRP.Phone.Functions.HeaderTextColor("white", 300);

        if (ClosingApplication == "whatsapp") {
            if (OpenedChatData.number !== null) {
                setTimeout(function(){
                    $(".whatsapp-chats").css({"display":"block"});
                    $(".whatsapp-chats").animate({
                        left: 0+"vh"
                    }, 1);
                    $(".whatsapp-openedchat").animate({
                        left: -30+"vh"
                    }, 1, function(){
                        $(".whatsapp-openedchat").css({"display":"none"});
                    });
                    OpenedChatPicture = null;
                    OpenedChatData.number = null;
                }, 450);
            }
        } else if (ClosingApplication == "bank") {
            if (CurrentTab == "invoices") {
                setTimeout(function(){
                    $(".bank-app-invoices").animate({"left": "30vh"});
                    $(".bank-app-invoices").css({"display":"none"})
                    $(".bank-app-accounts").css({"display":"block"})
                    $(".bank-app-accounts").css({"left": "0vh"});

                    var InvoicesObjectBank = $(".bank-app-header").find('[data-headertype="invoices"]');
                    var HomeObjectBank = $(".bank-app-header").find('[data-headertype="accounts"]');

                    $(InvoicesObjectBank).removeClass('bank-app-header-button-selected');
                    $(HomeObjectBank).addClass('bank-app-header-button-selected');

                    CurrentTab = "accounts";
                }, 400)
            }
        } else if (ClosingApplication == "meos") {
            $(".meos-alert-new").remove();
            setTimeout(function(){
                $(".meos-recent-alert").removeClass("noodknop");
                $(".meos-recent-alert").css({"background-color":"#004682"});
            }, 400)
        }

        PRP.Phone.Data.currentApplication = null;
    }
});

PRP.Phone.Functions.Open = function(data) {
    PRP.Phone.Functions.HideApplicationLayer();
    PRP.Phone.Data.currentApplication = null;
    PRP.Phone.Animations.BottomSlideUp('.container', 300, 0);
    PRP.Phone.Notifications.LoadTweets(data.Tweets);
    PRP.Phone.Data.IsOpen = true;
}

PRP.Phone.Functions.ToggleApp = function(app, show) {
    $("."+app+"-app").css({"display":show});
}

PRP.Phone.Functions.Close = function() {
    var ClosingApplication = PRP.Phone.Data.currentApplication;

    if (ClosingApplication == "whatsapp") {
        $(".whatsapp-chats").stop(true, true).css({"display":"block", "left":"0vh"});
        $(".whatsapp-openedchat").stop(true, true).css({"display":"none", "left":"-30vh"});
        OpenedChatPicture = null;
        OpenedChatData.number = null;
    } else if (ClosingApplication == "meos") {
        $(".meos-alert-new").remove();
        $(".meos-recent-alert").removeClass("noodknop");
        $(".meos-recent-alert").css({"background-color":"#004682"});
    }

    if (ClosingApplication !== null) {
        PRP.Phone.Functions.HideApplicationLayer(ClosingApplication);
        PRP.Phone.Functions.HeaderTextColor("white", 300);
        PRP.Phone.Data.currentApplication = null;
    }

    PRP.Phone.Animations.BottomSlideDown('.container', 300, -70);
    $.post('https://prp-phone/Close');
    PRP.Phone.Data.IsOpen = false;
}

PRP.Phone.Functions.HeaderTextColor = function(newColor, Timeout) {
    $(".phone-header").animate({color: newColor}, Timeout);
}

PRP.Phone.Animations.BottomSlideUp = function(Object, Timeout, Percentage) {
    $(Object).css({'display':'block'}).animate({
        bottom: Percentage+"%",
    }, Timeout);
}

PRP.Phone.Animations.BottomSlideDown = function(Object, Timeout, Percentage) {
    $(Object).css({'display':'block'}).animate({
        bottom: Percentage+"%",
    }, Timeout, function(){
        $(Object).css({'display':'none'});
    });
}

PRP.Phone.Animations.TopSlideDown = function(Object, Timeout, Percentage) {
    $(Object).css({'display':'block'}).animate({
        top: Percentage+"%",
    }, Timeout);
}

PRP.Phone.Animations.TopSlideUp = function(Object, Timeout, Percentage, cb) {
    $(Object).css({'display':'block'}).animate({
        top: Percentage+"%",
    }, Timeout, function(){
        $(Object).css({'display':'none'});
    });
}

PRP.Phone.Notifications.Add = function(icon, title, text, color, timeout) {
    $.post('https://prp-phone/HasPhone', JSON.stringify({}), function(HasPhone){
        if (HasPhone) {
            if (timeout == null && timeout == undefined) {
                timeout = 1500;
            }
            if (PRP.Phone.Notifications.Timeout == undefined || PRP.Phone.Notifications.Timeout == null) {
                if (color != null || color != undefined) {
                    $(".notification-icon").css({"color":color});
                    $(".notification-title").css({"color":color});
                } else if (color == "default" || color == null || color == undefined) {
                    $(".notification-icon").css({"color":"#e74c3c"});
                    $(".notification-title").css({"color":"#e74c3c"});
                }
                if (!PRP.Phone.Data.IsOpen) {
                    PRP.Phone.Animations.BottomSlideUp('.container', 300, -52);
                }
                PRP.Phone.Animations.TopSlideDown(".phone-notification-container", 200, 8);
                if (icon !== "politie") {
                    $(".notification-icon").html('<i class="'+icon+'"></i>');
                } else {
                    $(".notification-icon").html('<img src="./img/politie.png" class="police-icon-notify">');
                }
                $(".notification-title").html(title);
                $(".notification-text").html(text);
                if (PRP.Phone.Notifications.Timeout !== undefined || PRP.Phone.Notifications.Timeout !== null) {
                    clearTimeout(PRP.Phone.Notifications.Timeout);
                }
                PRP.Phone.Notifications.Timeout = setTimeout(function(){
                    PRP.Phone.Animations.TopSlideUp(".phone-notification-container", 200, -8);
                    if (!PRP.Phone.Data.IsOpen) {
                        PRP.Phone.Animations.BottomSlideUp('.container', 300, -100);
                    }
                    PRP.Phone.Notifications.Timeout = null;
                }, timeout);
            } else {
                if (color != null || color != undefined) {
                    $(".notification-icon").css({"color":color});
                    $(".notification-title").css({"color":color});
                } else {
                    $(".notification-icon").css({"color":"#e74c3c"});
                    $(".notification-title").css({"color":"#e74c3c"});
                }
                if (!PRP.Phone.Data.IsOpen) {
                    PRP.Phone.Animations.BottomSlideUp('.container', 300, -52);
                }
                $(".notification-icon").html('<i class="'+icon+'"></i>');
                $(".notification-title").html(title);
                $(".notification-text").html(text);
                if (PRP.Phone.Notifications.Timeout !== undefined || PRP.Phone.Notifications.Timeout !== null) {
                    clearTimeout(PRP.Phone.Notifications.Timeout);
                }
                PRP.Phone.Notifications.Timeout = setTimeout(function(){
                    PRP.Phone.Animations.TopSlideUp(".phone-notification-container", 200, -8);
                    if (!PRP.Phone.Data.IsOpen) {
                        PRP.Phone.Animations.BottomSlideUp('.container', 300, -100);
                    }
                    PRP.Phone.Notifications.Timeout = null;
                }, timeout);
            }
        }
    });
}

PRP.Phone.Functions.LoadPhoneData = function(data) {
    PRP.Phone.Data.PlayerData = data.PlayerData;
    PRP.Phone.Data.PlayerJob = data.PlayerJob;
    PRP.Phone.Data.CryptoConfig = data.CryptoConfig || PRP.Phone.Data.CryptoConfig;
    PRP.Phone.Data.DeviceProfile = data.PhoneData.DeviceProfile || {};
    PRP.Phone.Data.ActiveSim = data.PhoneData.ActiveSim || null;
    if (PRP.Phone.Data.ActiveSim && PRP.Phone.Data.PlayerData && PRP.Phone.Data.PlayerData.charinfo) {
        PRP.Phone.Data.PlayerData.charinfo.phone = PRP.Phone.Data.ActiveSim;
    }
    PRP.Phone.Data.MetaData = data.PhoneData.MetaData || {};
    PRP.Phone.Functions.LoadMetaData(PRP.Phone.Data.MetaData);
    PRP.Phone.Functions.LoadContacts(data.PhoneData.Contacts);
    PRP.Phone.Functions.SetupApplications(data);

    $("#player-id").html("<span>" + "ID: " + data.PlayerId + "</span>")
}

PRP.Phone.Functions.GetActivePhoneCitizenId = function() {
    return ((PRP.Phone.Data.DeviceProfile || {}).citizenid) || ((PRP.Phone.Data.PlayerData || {}).citizenid);
}

PRP.Phone.Functions.UpdateTime = function(data) {
    var NewDate = new Date();
    var NewHour = NewDate.getHours();
    var NewMinute = NewDate.getMinutes();
    var Minutessss = NewMinute;
    var Hourssssss = NewHour;
    if (NewHour < 10) {
        Hourssssss = "0" + Hourssssss;
    }
    if (NewMinute < 10) {
        Minutessss = "0" + NewMinute;
    }
    var MessageTime = Hourssssss + ":" + Minutessss

    $("#phone-time").html("<span>" + data.InGameTime.hour + ":" + data.InGameTime.minute + "</span>");
}

var NotificationTimeout = null;

PRP.Screen.Notification = function(title, content, icon, timeout, color) {
    $.post('https://prp-phone/HasPhone', JSON.stringify({}), function(HasPhone){
        if (HasPhone) {
            if (color != null && color != undefined) {
                $(".screen-notifications-container").css({"background-color":color});
            }
            $(".screen-notification-icon").html('<i class="'+icon+'"></i>');
            $(".screen-notification-title").text(title);
            $(".screen-notification-content").text(content);
            $(".screen-notifications-container").css({'display':'block'}).animate({
                right: 5+"vh",
            }, 200);

            if (NotificationTimeout != null) {
                clearTimeout(NotificationTimeout);
            }

            NotificationTimeout = setTimeout(function(){
                $(".screen-notifications-container").animate({
                    right: -35+"vh",
                }, 200, function(){
                    $(".screen-notifications-container").css({'display':'none'});
                });
                NotificationTimeout = null;
            }, timeout);
        }
    });
}

$(document).on('keydown', function(event) {
    if ($(".tablet-container").is(":visible")) return;
    switch(event.keyCode) {
        case 27: // ESCAPE
        if (up){
            $('#popup').fadeOut('slow');
            $('.popupclass').fadeOut('slow');
            $('.popupclass').html("");
            up = false
        } else {
            PRP.Phone.Functions.Close();
            break;
        }
    }
});

PRP.Screen.popUp = function(source){
    if(!up){
        $('#popup').fadeIn('slow');
        $('.popupclass').fadeIn('slow');
        $('<img  src='+source+' style = "width:100%; height: 100%;">').appendTo('.popupclass')
        up = true
    }
}

PRP.Screen.popDown = function(){
    if(up){
        $('#popup').fadeOut('slow');
        $('.popupclass').fadeOut('slow');
        $('.popupclass').html("");
        up = false
    }
}

$(document).ready(function(){
    window.addEventListener('message', function(event) {
        switch(event.data.action) {
            case "open":
                PRP.Phone.Functions.Open(event.data);
                PRP.Phone.Functions.SetupAppWarnings(event.data.AppData);
                PRP.Phone.Functions.SetupCurrentCall(event.data.CallData);
                PRP.Phone.Data.IsOpen = true;
                PRP.Phone.Data.PlayerData = event.data.PlayerData;
                break;
            case "LoadPhoneData":
                PRP.Phone.Functions.LoadPhoneData(event.data);
                break;
            case "UpdateTime":
                PRP.Phone.Functions.UpdateTime(event.data);
                break;
            case "Notification":
                PRP.Screen.Notification(event.data.NotifyData.title, event.data.NotifyData.content, event.data.NotifyData.icon, event.data.NotifyData.timeout, event.data.NotifyData.color);
                break;
            case "PhoneNotification":
                PRP.Phone.Notifications.Add(event.data.PhoneNotify.icon, event.data.PhoneNotify.title, event.data.PhoneNotify.text, event.data.PhoneNotify.color, event.data.PhoneNotify.timeout);
                break;
            case "RefreshAppAlerts":
                PRP.Phone.Functions.SetupAppWarnings(event.data.AppData);
                break;
            case "UpdateMentionedTweets":
                PRP.Phone.Notifications.LoadMentionedTweets(event.data.Tweets);
                break;
            case "UpdateBank":
                $(".bank-app-account-balance").html("&#36; "+event.data.NewBalance);
                $(".bank-app-account-balance").data('balance', event.data.NewBalance);
                break;
            case "UpdateChat":
                if (PRP.Phone.Data.currentApplication == "whatsapp") {
                    if (OpenedChatData.number !== null && OpenedChatData.number == event.data.chatNumber) {
                        PRP.Phone.Functions.SetupChatMessages(event.data.chatData);
                    } else {
                        PRP.Phone.Functions.LoadWhatsappChats(event.data.Chats);
                    }
                }
                break;
            case "UpdateHashtags":
                PRP.Phone.Notifications.LoadHashtags(event.data.Hashtags);
                break;
            case "RefreshWhatsappAlerts":
                PRP.Phone.Functions.ReloadWhatsappAlerts(event.data.Chats);
                break;
            case "CancelOutgoingCall":
                $.post('https://prp-phone/HasPhone', JSON.stringify({}), function(HasPhone){
                    if (HasPhone) {
                        CancelOutgoingCall();
                    }
                });
                break;
            case "IncomingCallAlert":
                $.post('https://prp-phone/HasPhone', JSON.stringify({}), function(HasPhone){
                    if (HasPhone) {
                        IncomingCallAlert(event.data.CallData, event.data.Canceled, event.data.AnonymousCall);
                    }
                });
                break;
            case "SetupHomeCall":
                PRP.Phone.Functions.SetupCurrentCall(event.data.CallData);
                break;
            case "SetSpeakerPhone":
                if (PRP.Phone.Functions.SetSpeakerPhone !== undefined) {
                    PRP.Phone.Functions.SetSpeakerPhone(event.data.enabled);
                }
                break;
            case "AnswerCall":
                PRP.Phone.Functions.AnswerCall(event.data.CallData);
                break;
            case "UpdateCallTime":
                var CallTime = event.data.Time;
                var date = new Date(null);
                date.setSeconds(CallTime);
                var timeString = date.toISOString().substr(11, 8);
                if (!PRP.Phone.Data.IsOpen) {
                    if ($(".call-notifications").css("right") !== "52.1px") {
                        $(".call-notifications").css({"display":"block"});
                        $(".call-notifications").animate({right: 5+"vh"});
                    }
                    $(".call-notifications-title").html("In conversation ("+timeString+")");
                    $(".call-notifications-content").html("Calling with "+event.data.Name);
                    $(".call-notifications").removeClass('call-notifications-shake');
                } else {
                    $(".call-notifications").animate({
                        right: -35+"vh"
                    }, 400, function(){
                        $(".call-notifications").css({"display":"none"});
                    });
                }
                $(".phone-call-ongoing-time").html(timeString);
                $(".phone-currentcall-title").html("In conversation ("+timeString+")");
                break;
            case "CancelOngoingCall":
                if (PRP.Phone.Functions.SetSpeakerPhone !== undefined) {
                    PRP.Phone.Functions.SetSpeakerPhone(false);
                }
                $(".call-notifications").animate({right: -35+"vh"}, function(){
                    $(".call-notifications").css({"display":"none"});
                });
                PRP.Phone.Animations.TopSlideUp('.phone-application-container', 400, -160);
                setTimeout(function(){
                    PRP.Phone.Functions.ToggleApp("phone-call", "none");
                    $(".phone-application-container").css({"display":"none"});
                }, 400)
                PRP.Phone.Functions.HeaderTextColor("white", 300);

                PRP.Phone.Data.CallActive = false;
                PRP.Phone.Data.currentApplication = null;
                break;
            case "RefreshContacts":
                PRP.Phone.Functions.LoadContacts(event.data.Contacts);
                break;
            case "UpdateMails":
                PRP.Phone.Functions.SetupMails(event.data.Mails);
                break;
            case "RefreshAdverts":
                if (PRP.Phone.Data.currentApplication == "advert") {
                    PRP.Phone.Functions.RefreshAdverts(event.data.Adverts);
                }
                break;
            case "UpdateTweets":
                if (PRP.Phone.Data.currentApplication == "twitter") {
                    PRP.Phone.Notifications.LoadTweets(event.data.Tweets);
                }
                break;
            case "AddPoliceAlert":
                AddPoliceAlert(event.data)
                break;
            case "UpdateApplications":
                PRP.Phone.Data.PlayerJob = event.data.JobData;
                PRP.Phone.Functions.SetupApplications(event.data);
                break;
            case "UpdateTransactions":
                RefreshCryptoTransactions(event.data);
                break;
            case "UpdateRacingApp":
                $.post('https://prp-phone/GetAvailableRaces', JSON.stringify({}), function(Races){
                    SetupRaces(Races);
                });
                break;
            case "RefreshAlerts":
                PRP.Phone.Functions.SetupAppWarnings(event.data.AppData);
                break;
        }
    })
});
