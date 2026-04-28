local QBCore = exports['qb-core']:GetCoreObject()

local function cloneTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = cloneTable(entry)
    end

    return copy
end

local function getSkinConfig(itemName)
    if not itemName then return nil end
    return Config.WeaponSkins[string.lower(itemName)]
end

local function getItemBySlot(Player, slot)
    if not Player or not slot then return nil end

    if Player.Functions.GetItemBySlot then
        return Player.Functions.GetItemBySlot(slot)
    end

    local items = Player.PlayerData.items or {}
    return items[slot] or items[tostring(slot)]
end

local function getFirstItemByName(Player, itemName)
    if not Player or not itemName then return nil end

    if Player.Functions.GetItemByName then
        return Player.Functions.GetItemByName(itemName)
    end

    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == itemName then
            return item
        end
    end

    return nil
end

local function notify(src, message, messageType)
    TriggerClientEvent('QBCore:Notify', src, message, messageType or 'error')
end

for itemName in pairs(Config.WeaponSkins) do
    QBCore.Functions.CreateUseableItem(itemName, function(source, item)
        if not item or not item.slot then return end
        TriggerClientEvent('prp-camo:client:beginApply', source, item.name, item.slot)
    end)
end

QBCore.Functions.CreateCallback('prp-camo:server:canApply', function(source, cb, itemName, itemSlot)
    local Player = QBCore.Functions.GetPlayer(source)
    local skin = getSkinConfig(itemName)

    if not Player then
        cb(false, 'Player not found.')
        return
    end

    if not skin then
        cb(false, 'This paint is not configured.')
        return
    end

    local paintItem = getItemBySlot(Player, tonumber(itemSlot))
    if not paintItem or paintItem.name ~= itemName then
        cb(false, 'Paint item not found.')
        return
    end

    if getFirstItemByName(Player, skin.skinnedWeapon) then
        cb(false, skin.alreadySkinnedMessage or 'You already have this skinned weapon.')
        return
    end

    if not getFirstItemByName(Player, skin.baseWeapon) then
        cb(false, skin.missingBaseMessage or 'You do not have the required weapon.')
        return
    end

    cb(true)
end)

RegisterNetEvent('prp-camo:server:applySkin', function(itemName, itemSlot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local skin = getSkinConfig(itemName)

    if not Player or not skin then return end

    itemSlot = tonumber(itemSlot)

    local paintItem = getItemBySlot(Player, itemSlot)
    if not paintItem or paintItem.name ~= itemName then
        notify(src, 'Paint item not found.')
        return
    end

    if getFirstItemByName(Player, skin.skinnedWeapon) then
        notify(src, skin.alreadySkinnedMessage or 'You already have this skinned weapon.')
        return
    end

    local baseWeaponItem = getFirstItemByName(Player, skin.baseWeapon)
    if not baseWeaponItem then
        notify(src, skin.missingBaseMessage or 'You do not have the required weapon.')
        return
    end

    local baseWeaponSlot = tonumber(baseWeaponItem.slot)
    local baseWeaponInfo = cloneTable(baseWeaponItem.info or {})
    local paintInfo = cloneTable(paintItem.info or {})

    if not Player.Functions.RemoveItem(itemName, 1, itemSlot, ('used %s'):format(itemName)) then
        notify(src, 'Could not remove paint item.')
        return
    end

    local paintShared = QBCore.Shared.Items[itemName]
    if paintShared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, paintShared, 'remove')
    end

    if not Player.Functions.RemoveItem(skin.baseWeapon, 1, baseWeaponSlot, ('converted %s to %s'):format(skin.baseWeapon, skin.skinnedWeapon)) then
        Player.Functions.AddItem(itemName, 1, false, paintInfo, ('refund %s after failed weapon removal'):format(itemName))
        if paintShared then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, paintShared, 'add')
        end
        notify(src, 'Could not remove base weapon. Your paint was returned.')
        return
    end

    local baseWeaponShared = QBCore.Shared.Items[skin.baseWeapon]
    if baseWeaponShared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, baseWeaponShared, 'remove')
    end

    if not Player.Functions.AddItem(skin.skinnedWeapon, 1, baseWeaponSlot, baseWeaponInfo, ('applied %s'):format(itemName)) then
        Player.Functions.AddItem(skin.baseWeapon, 1, baseWeaponSlot, baseWeaponInfo, ('refund %s after failed skin add'):format(skin.baseWeapon))
        Player.Functions.AddItem(itemName, 1, false, paintInfo, ('refund %s after failed skin add'):format(itemName))

        if baseWeaponShared then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, baseWeaponShared, 'add')
        end
        if paintShared then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, paintShared, 'add')
        end

        notify(src, 'Could not add the skinned weapon. Your items were returned.')
        return
    end

    local skinnedShared = QBCore.Shared.Items[skin.skinnedWeapon]
    if skinnedShared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, skinnedShared, 'add')
    end

    TriggerClientEvent('prp-camo:client:finishApply', src, skin.baseWeapon, skin.skinnedWeapon, skin.successMessage)
end)
