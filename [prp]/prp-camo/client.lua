local QBCore = exports['qb-core']:GetCoreObject()

local function getSkinConfig(itemName)
    if not itemName then return nil end
    return Config.WeaponSkins[string.lower(itemName)]
end

RegisterNetEvent('prp-camo:client:beginApply', function(itemName, itemSlot)
    local skin = getSkinConfig(itemName)
    if not skin then
        QBCore.Functions.Notify('This paint is not configured.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('prp-camo:server:canApply', function(canApply, message)
        if not canApply then
            QBCore.Functions.Notify(message or 'Unable to attach weapon skin.', 'error')
            return
        end

        QBCore.Functions.Progressbar(
            ('attach_%s'):format(itemName),
            skin.progressLabel or 'Attaching weapon skin...',
            tonumber(skin.duration) or Config.DefaultDuration,
            Config.Progressbar.useWhileDead,
            Config.Progressbar.canCancel,
            Config.Progressbar.disableControls,
            Config.Progressbar.animation,
            {},
            {},
            function()
                TriggerServerEvent('prp-camo:server:applySkin', itemName, itemSlot)
            end,
            function()
                QBCore.Functions.Notify('Cancelled attaching weapon skin.', 'error')
            end
        )
    end, itemName, itemSlot)
end)

RegisterNetEvent('prp-camo:client:finishApply', function(baseWeapon, skinnedWeapon, successMessage)
    local ped = PlayerPedId()
    local selectedWeapon = GetSelectedPedWeapon(ped)
    local baseHash = joaat(baseWeapon)
    local skinnedHash = joaat(skinnedWeapon)

    if selectedWeapon == baseHash or selectedWeapon == skinnedHash then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        RemoveWeaponFromPed(ped, baseHash)
        RemoveWeaponFromPed(ped, skinnedHash)
    end

    QBCore.Functions.Notify(successMessage or 'Weapon skin attached.', 'success')
end)
