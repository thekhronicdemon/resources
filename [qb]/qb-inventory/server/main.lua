QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
Drops = {}
RegisteredShops = {}

local EquipmentSlots = {
    hat = true,
    backpack = true,
    armour = true,
    jacket = true,
    shirt = true,
    pants = true,
    shoes = true,
}

local ArmourItems = {
    armor = true,
    heavyarmor = true,
}

local ArmorPlateItems = {
    armor_plate = true,
    armor_plates = true,
}

local ArmorPlateValue = 25

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or 0
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function CloneTable(value)
    if type(value) ~= 'table' then return {} end
    return json.decode(json.encode(value)) or {}
end

local function GetEquipment(Player)
    local metadata = Player.PlayerData.metadata or {}
    local equipment = type(metadata.equipment) == 'table' and metadata.equipment or {}
    return equipment
end

local function SetEquipment(Player, equipment)
    Player.Functions.SetMetaData('equipment', equipment or {})
end

local function GetPlayerItemBySlotOrName(Player, slot, names)
    if not Player or type(Player.PlayerData.items) ~= 'table' then return nil end

    slot = tonumber(slot)
    if slot then
        local directItem = Player.PlayerData.items[slot] or Player.PlayerData.items[tostring(slot)]
        if directItem and directItem.name and names[directItem.name:lower()] then
            return directItem
        end
    end

    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name and names[item.name:lower()] then
            return item
        end
    end

    return nil
end

local function ClearQuickSlotsForItemSlot(Player, itemSlot)
    if not Player or type(Player.PlayerData.metadata) ~= 'table' then return end

    itemSlot = tonumber(itemSlot)
    local quickslots = Player.PlayerData.metadata.quickslots
    if not itemSlot or type(quickslots) ~= 'table' then return end

    local changed = false
    for i = 1, 4 do
        local assigned = tonumber(quickslots[tostring(i)] or quickslots[i])
        if assigned == itemSlot then
            quickslots[tostring(i)] = nil
            quickslots[i] = nil
            changed = true
        end
    end

    if changed then
        Player.Functions.SetMetaData('quickslots', quickslots)
    end
end

local function FormatEquipmentItem(item, equipmentSlot)
    if not item or not item.name then return nil end

    local itemName = item.name:lower()
    local itemInfo = QBCore.Shared.Items[itemName]
    if not itemInfo then return nil end

    local info = CloneTable(item.info)
    if equipmentSlot == 'armour' then
        info.armor = Clamp(info.armor, 0, 100)
        info.maxArmor = 100
        info.plates = math.floor(info.armor / ArmorPlateValue)
        info.description = ('Armor: %d%% (%d/4 plates)'):format(info.armor, info.plates)
    end

    return {
        name = itemInfo.name,
        amount = 1,
        info = info,
        label = itemInfo.label,
        description = info.description or itemInfo.description or '',
        weight = itemInfo.weight,
        type = itemInfo.type,
        unique = itemInfo.unique,
        useable = itemInfo.useable,
        image = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        slot = equipmentSlot,
        rarity = info.rarity or itemInfo.rarity or 'common',
    }
end

local function SetPlayerArmor(Player, amount)
    amount = Clamp(amount, 0, 100)
    Player.Functions.SetMetaData('armor', amount)
    SetPedArmour(GetPlayerPed(Player.PlayerData.source), amount)
end

function SyncEquippedArmorFromPed(Player)
    if not Player then return nil end

    local equipment = GetEquipment(Player)
    local armour = equipment.armour
    if not armour or not armour.name then return equipment end

    local currentArmor = Clamp(GetPedArmour(GetPlayerPed(Player.PlayerData.source)), 0, 100)
    local info = CloneTable(armour.info)
    local storedArmor = Clamp(info.armor, 0, 100)

    if storedArmor == currentArmor and Clamp(Player.PlayerData.metadata and Player.PlayerData.metadata.armor, 0, 100) == currentArmor then
        return equipment
    end

    info.armor = currentArmor
    info.maxArmor = 100
    info.plates = math.floor(currentArmor / ArmorPlateValue)
    info.description = ('Armor: %d%% (%d/4 plates)'):format(currentArmor, info.plates)
    armour.info = info
    armour.description = info.description
    equipment.armour = armour

    SetEquipment(Player, equipment)
    Player.Functions.SetMetaData('armor', currentArmor)
    return equipment
end

local function EquipEquipmentItem(src, equipmentSlot, fromSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return { success = false, message = 'Player not found' } end

    equipmentSlot = tostring(equipmentSlot or 'armour'):lower()
    if not EquipmentSlots[equipmentSlot] then
        return { success = false, message = 'Invalid equipment slot' }
    end

    if equipmentSlot ~= 'armour' then
        return { success = false, message = 'This slot is not wearable yet' }
    end

    local equipment = GetEquipment(Player)
    if equipment[equipmentSlot] then
        return { success = false, message = 'Take off your current armour first' }
    end

    local item = GetPlayerItemBySlotOrName(Player, fromSlot, ArmourItems)
    if not item then
        return { success = false, message = 'No armour item found' }
    end

    local itemSlot = tonumber(item.slot)
    local equippedItem = FormatEquipmentItem(item, equipmentSlot)
    if not equippedItem then
        return { success = false, message = 'This item cannot be equipped' }
    end

    if not RemoveItem(src, item.name, 1, itemSlot, 'equipped armour') then
        return { success = false, message = 'Could not equip armour' }
    end
    ClearQuickSlotsForItemSlot(Player, itemSlot)

    equipment[equipmentSlot] = equippedItem
    SetEquipment(Player, equipment)
    SetPlayerArmor(Player, equippedItem.info and equippedItem.info.armor or 0)

    return {
        success = true,
        equipment = equipment,
        inventory = Player.PlayerData.items,
        quickslots = Player.PlayerData.metadata.quickslots or {},
        itemName = item.name,
        message = 'Armour equipped'
    }
end

local function UnequipEquipmentItem(src, equipmentSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return { success = false, message = 'Player not found' } end

    equipmentSlot = tostring(equipmentSlot or 'armour'):lower()
    if not EquipmentSlots[equipmentSlot] then
        return { success = false, message = 'Invalid equipment slot' }
    end

    local equipment = SyncEquippedArmorFromPed(Player) or GetEquipment(Player)
    local equippedItem = equipment[equipmentSlot]
    if not equippedItem or not equippedItem.name then
        return { success = false, message = 'Nothing equipped there' }
    end

    local info = CloneTable(equippedItem.info)
    if not AddItem(src, equippedItem.name, 1, false, info, 'unequipped item') then
        return { success = false, message = 'No room to unequip this item' }
    end

    equipment[equipmentSlot] = nil
    SetEquipment(Player, equipment)

    if equipmentSlot == 'armour' then
        SetPlayerArmor(Player, 0)
    end

    return {
        success = true,
        equipment = equipment,
        inventory = Player.PlayerData.items,
        quickslots = Player.PlayerData.metadata.quickslots or {},
        itemName = equippedItem.name,
        message = 'Item unequipped'
    }
end

local function ApplyArmorPlate(src, plateSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return { success = false, message = 'Player not found' } end

    local equipment = SyncEquippedArmorFromPed(Player) or GetEquipment(Player)
    local armour = equipment.armour
    if not armour or not armour.name then
        return { success = false, message = 'Wear armour before adding plates' }
    end

    local plate = GetPlayerItemBySlotOrName(Player, plateSlot, ArmorPlateItems)
    if not plate then
        return { success = false, message = 'No armor plate found' }
    end

    local info = CloneTable(armour.info)
    local currentArmor = Clamp(info.armor, 0, 100)
    if currentArmor >= 100 then
        return { success = false, message = 'Armour is already fully plated' }
    end

    local newArmor = Clamp(currentArmor + ArmorPlateValue, 0, 100)
    local plateSlot = tonumber(plate.slot)
    local plateAmount = tonumber(plate.amount) or 1
    if not RemoveItem(src, plate.name, 1, plateSlot, 'applied armor plate') then
        return { success = false, message = 'Could not use armor plate' }
    end
    if plateAmount <= 1 then
        ClearQuickSlotsForItemSlot(Player, plateSlot)
    end

    info.armor = newArmor
    info.maxArmor = 100
    info.plates = math.floor(newArmor / ArmorPlateValue)
    info.description = ('Armor: %d%% (%d/4 plates)'):format(newArmor, info.plates)
    armour.info = info
    armour.description = info.description
    equipment.armour = armour

    SetEquipment(Player, equipment)
    SetPlayerArmor(Player, newArmor)

    return {
        success = true,
        equipment = equipment,
        inventory = Player.PlayerData.items,
        quickslots = Player.PlayerData.metadata.quickslots or {},
        itemName = plate.name,
        armor = newArmor,
        message = 'Armor plate installed'
    }
end

exports('EquipArmorItem', function(source, slot)
    return EquipEquipmentItem(source, 'armour', slot)
end)

exports('ApplyArmorPlate', function(source, slot)
    return ApplyArmorPlate(source, slot)
end)

CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false
                }
            end
            print(#result .. ' inventories successfully loaded')
        end
    end)
end)

CreateThread(function()
    while true do
        for k, v in pairs(Drops) do
            if v and (v.createdTime + (Config.CleanupDropTime * 60) < os.time()) and not Drops[k].isOpen then
                TriggerClientEvent('qb-inventory:client:removeDropObject', -1, k)
                Drops[k] = nil
            end
        end
        Wait(Config.CleanupDropInterval * 60000)
    end
end)

AddEventHandler('playerDropped', function()
    for _, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
        end
    end

    for _, drop in pairs(Drops) do
        if drop.isOpen == source then
            drop.isOpen = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', {
                inventory,
                json.encode(data.items),
                json.encode(data.items)
            })
        end
    end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('qb-inventory:server:openInventory', function(name, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if name and type(name) == 'string' and name:find('drop%-') == 1 then
        OpenDrop(src, name)
        return
    end

    OpenInventory(src, name, data)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(Player.PlayerData.source, item, amount, slot, info, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(Player.PlayerData.source, item, amount, slot, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemBySlot', function(slot)
        return GetItemBySlot(Player.PlayerData.source, slot)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemByName', function(item)
        return GetItemByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemsByName', function(item)
        return GetItemsByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'ClearInventory', function(filterItems)
        ClearInventory(Player.PlayerData.source, filterItems)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'SetInventory', function(items)
        SetInventory(Player.PlayerData.source, items)
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local Players = QBCore.Functions.GetQBPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)

        Player(k).state.inv_busy = false
    end
end)

local function GetShopName(shopInventory)
    if type(shopInventory) ~= 'string' then return nil end
    return shopInventory:gsub('^shop%-', '')
end

local function GetRegisteredShopItem(shopName, slot, itemName)
    local shop = RegisteredShops[shopName]
    if not shop or not shop.items then return nil end

    slot = tonumber(slot)
    if slot and shop.items[slot] and (not itemName or shop.items[slot].name == itemName) then
        return shop.items[slot]
    end

    if itemName then
        for _, item in pairs(shop.items) do
            if item and item.name == itemName then
                return item
            end
        end
    end

    return nil
end

local function UpdateRegisteredShopStock(shopName, slot, amountDelta)
    local shop = RegisteredShops[shopName]
    slot = tonumber(slot)
    if not shop or not shop.items or not slot or not shop.items[slot] then return end
    if shop.items[slot].amount == nil then return end

    shop.items[slot].amount = math.max(0, (tonumber(shop.items[slot].amount) or 0) + amountDelta)
end

local function ComponentMatches(savedComponent, componentHash)
    if savedComponent == componentHash then return true end
    if type(savedComponent) == 'string' and joaat(savedComponent) == componentHash then return true end
    if type(componentHash) == 'string' and joaat(componentHash) == savedComponent then return true end
    return false
end

local function HasWeaponAttachment(component, attachments)
    if type(attachments) ~= 'table' then return false end
    for _, attachment in pairs(attachments) do
        if ComponentMatches(attachment.component, component) then
            return true
        end
    end
    return false
end

QBCore.Functions.CreateCallback('qb-inventory:server:attemptPurchase', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' or type(data.item) ~= 'table' then
        cb(false)
        return
    end

    local shopName = GetShopName(data.shop)
    local amount = math.floor(tonumber(data.amount) or 1)
    local targetSlot = tonumber(data.targetSlot)
    local requestedItem = data.item
    local shopItem = GetRegisteredShopItem(shopName, requestedItem.slot, requestedItem.name)

    if not shopName or not shopItem or amount < 1 then
        cb(false)
        return
    end

    local itemInfo = QBCore.Shared.Items[shopItem.name:lower()]
    if not itemInfo then
        cb(false)
        return
    end

    if itemInfo.unique and amount > 1 then
        amount = 1
    end

    local stockAmount = tonumber(shopItem.amount)
    if shopItem.amount ~= nil and (not stockAmount or stockAmount < amount) then
        TriggerClientEvent('QBCore:Notify', src, 'The shop does not have that many in stock', 'error')
        cb(false)
        return
    end

    local totalPrice = (tonumber(shopItem.price) or 0) * amount
    local paidAccount = nil

    if totalPrice > 0 then
        if Player.Functions.RemoveMoney('cash', totalPrice, 'shop purchase') then
            paidAccount = 'cash'
        elseif Player.Functions.RemoveMoney('bank', totalPrice, 'shop purchase') then
            paidAccount = 'bank'
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.notencash'), 'error')
            cb(false)
            return
        end
    end

    local targetItem = targetSlot and Player.PlayerData.items[targetSlot] or nil
    if targetItem and (targetItem.name ~= shopItem.name or targetItem.unique or itemInfo.unique) then
        targetSlot = false
    end

    local added = AddItem(src, shopItem.name, amount, targetSlot, shopItem.info or {}, 'shop purchase')
    if not added then
        if paidAccount then
            Player.Functions.AddMoney(paidAccount, totalPrice, 'shop purchase refund')
        end
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.giymif'), 'error')
        cb(false)
        return
    end

    UpdateRegisteredShopStock(shopName, shopItem.slot, -amount)
    TriggerEvent('qb-shops:server:UpdateShopItems', shopName, shopItem, amount)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'add', amount)
    TriggerClientEvent('qb-inventory:client:updateInventory', src)

    cb(true)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:sellShopItem', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' or type(data.item) ~= 'table' then
        cb({ success = false })
        return
    end

    local shopName = GetShopName(data.shop)
    local itemName = data.item.name
    local slot = tonumber(data.slot) or tonumber(data.item.slot)
    local amount = math.floor(tonumber(data.amount) or 1)
    local shopItem = GetRegisteredShopItem(shopName, nil, itemName)

    if not shopName or not shopItem or not itemName or not slot or amount < 1 then
        cb({ success = false })
        return
    end

    local itemInfo = QBCore.Shared.Items[itemName:lower()]
    if itemInfo and itemInfo.unique and amount > 1 then
        amount = 1
    end

    local playerItem = Player.PlayerData.items[slot]
    if not playerItem or playerItem.name ~= itemName or playerItem.amount < amount then
        cb({ success = false })
        return
    end

    local sellBackRate = tonumber(Config.ShopSellBackRate) or 0.70
    local unitPrice = math.floor((tonumber(shopItem.price) or 0) * sellBackRate)
    if unitPrice <= 0 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.nosell'), 'error')
        cb({ success = false })
        return
    end

    local removed = RemoveItem(src, itemName, amount, slot, 'shop sell back')
    if not removed then
        cb({ success = false })
        return
    end

    local totalPrice = unitPrice * amount
    Player.Functions.AddMoney('cash', totalPrice, 'shop sell back')
    UpdateRegisteredShopStock(shopName, shopItem.slot, amount)
    TriggerEvent('qb-shops:server:UpdateShopItems', shopName, shopItem, -amount)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo or QBCore.Shared.Items[itemName:lower()], 'remove', amount)
    TriggerClientEvent('qb-inventory:client:updateInventory', src)
    TriggerClientEvent('QBCore:Notify', src, ('Sold %sx %s for $%s'):format(amount, shopItem.label or itemName, totalPrice), 'success')

    cb({
        success = true,
        unitPrice = unitPrice,
        totalPrice = totalPrice
    })
end)

QBCore.Functions.CreateCallback('qb-inventory:server:equipItem', function(source, cb, equipmentSlot, itemSlot)
    local result = EquipEquipmentItem(source, equipmentSlot, itemSlot)
    if result and not result.success and result.message then
        TriggerClientEvent('QBCore:Notify', source, result.message, 'error')
    end
    cb(result)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:unequipItem', function(source, cb, equipmentSlot)
    local result = UnequipEquipmentItem(source, equipmentSlot)
    if result and not result.success and result.message then
        TriggerClientEvent('QBCore:Notify', source, result.message, 'error')
    end
    cb(result)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:applyArmorPlate', function(source, cb, plateSlot)
    local result = ApplyArmorPlate(source, plateSlot)
    if result and not result.success and result.message then
        TriggerClientEvent('QBCore:Notify', source, result.message, 'error')
    end
    cb(result)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:setQuickSlot', function(source, cb, quickSlot, itemSlot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found' })
        return
    end

    quickSlot = tonumber(quickSlot)
    itemSlot = tonumber(itemSlot)

    if not quickSlot or quickSlot < 1 or quickSlot > 4 then
        cb({ success = false, message = 'Invalid quick slot' })
        return
    end

    local quickslots = type(Player.PlayerData.metadata.quickslots) == 'table' and Player.PlayerData.metadata.quickslots or {}
    quickslots[quickSlot] = nil

    if itemSlot then
        local item = Player.PlayerData.items[itemSlot] or Player.PlayerData.items[tostring(itemSlot)]
        if not item then
            cb({ success = false, message = 'No item in that inventory slot' })
            return
        end
        quickslots[tostring(quickSlot)] = itemSlot
    else
        quickslots[tostring(quickSlot)] = nil
    end

    Player.Functions.SetMetaData('quickslots', quickslots)
    cb({ success = true, quickslots = quickslots })
end)

local DeviceAttachmentItems = {
    phone = {
        simcard = true
    },
    tablet = {
        crypto_usb = true,
        cryptostick = true
    }
}

local function GenerateSimNumber()
    local number = '04'
    for _ = 1, 8 do
        number = number .. tostring(math.random(0, 9))
    end
    return number
end

local function GenerateUniqueSimNumber()
    for _ = 1, 25 do
        local number = GenerateSimNumber()
        local existsOnline = QBCore.Functions.GetPlayerByPhone(number)
        local existsSaved = MySQL.scalar.await('SELECT citizenid FROM players WHERE charinfo LIKE ? LIMIT 1', { '%"phone":"' .. number .. '"%' })
        local existsInventory = MySQL.scalar.await('SELECT citizenid FROM players WHERE inventory LIKE ? LIMIT 1', { '%"simNumber":"' .. number .. '"%' })
        if not existsOnline and not existsSaved and not existsInventory then return number end
    end
    return GenerateSimNumber()
end

local function NormalizeSimCardInfo(info)
    info = type(info) == 'table' and info or {}
    info.simNumber = info.simNumber or GenerateUniqueSimNumber()
    info.simSerial = info.simSerial or ('SIM-' .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(4))
    info.description = ('Phone number: %s'):format(info.simNumber)
    return info
end

local function SetActivePhoneNumber(Player, phoneNumber)
    local charinfo = Player.PlayerData.charinfo or {}
    charinfo.phone = tostring(phoneNumber)
    Player.Functions.SetPlayerData('charinfo', charinfo)

    local phonedata = Player.PlayerData.metadata['phonedata'] or {}
    phonedata.ActiveSim = tostring(phoneNumber)
    Player.Functions.SetMetaData('phonedata', phonedata)
end

local function ClearActivePhoneNumber(Player, phoneNumber)
    if not Player then return end

    local removedNumber = phoneNumber and tostring(phoneNumber) or nil
    local charinfo = Player.PlayerData.charinfo or {}
    if not removedNumber or tostring(charinfo.phone or '') == removedNumber then
        charinfo.phone = ''
        Player.Functions.SetPlayerData('charinfo', charinfo)
    end

    local phonedata = Player.PlayerData.metadata['phonedata'] or {}
    if not removedNumber or tostring(phonedata.ActiveSim or '') == removedNumber then
        phonedata.ActiveSim = nil
    end
    Player.Functions.SetMetaData('phonedata', phonedata)
end

local function LoadContactRows(citizenid)
    local contacts = {}
    if not citizenid then return contacts end

    local rows = MySQL.query.await('SELECT name, number, iban FROM player_contacts WHERE citizenid = ? ORDER BY name ASC', { citizenid }) or {}
    for _, row in pairs(rows) do
        contacts[#contacts + 1] = {
            name = row.name,
            number = row.number,
            iban = row.iban
        }
    end

    return contacts
end

local function EnsurePhoneDeviceInfo(Player, phoneInfo)
    phoneInfo = type(phoneInfo) == 'table' and phoneInfo or {}
    if not phoneInfo.deviceId then
        phoneInfo.deviceId = 'PHONE-' .. QBCore.Shared.RandomStr(4) .. QBCore.Shared.RandomInt(4)
    end
    if not phoneInfo.deviceOwnerCitizenid and Player and Player.PlayerData then
        phoneInfo.deviceOwnerCitizenid = Player.PlayerData.citizenid
    end
    return phoneInfo
end

local function CopyTable(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, data in pairs(value) do
        copy[key] = CopyTable(data)
    end

    return copy
end

local function GetInventoryItemBySlot(inventory, slot, expectedName)
    slot = tonumber(slot)
    if not inventory or not slot then return nil, nil end

    local directItem = inventory[slot]
    if directItem and tonumber(directItem.slot) == slot then
        if not expectedName or (directItem.name and directItem.name:lower() == expectedName:lower()) then
            return directItem, slot
        end
    end

    directItem = inventory[tostring(slot)]
    if directItem and tonumber(directItem.slot) == slot then
        if not expectedName or (directItem.name and directItem.name:lower() == expectedName:lower()) then
            return directItem, tostring(slot)
        end
    end

    for key, item in pairs(inventory) do
        if item and tonumber(item.slot) == slot then
            if not expectedName or (item.name and item.name:lower() == expectedName:lower()) then
                return item, key
            end
        end
    end

    return nil, nil
end

local function SetInventoryItemInfoBySlot(Player, slot, info, description)
    if not Player or not slot then return nil end

    local inventory = Player.PlayerData.items or {}
    local item, key = GetInventoryItemBySlot(inventory, slot)
    if not item or not key then return nil end

    item.info = info or {}
    item.description = description or item.info.description or item.description
    inventory[key] = item
    Player.Functions.SetPlayerData('items', inventory)

    return item
end

local function RemoveInventoryItemBySlot(Player, itemName, slot, amount)
    if not Player or not itemName or not slot then return false end

    amount = tonumber(amount) or 1
    local inventory = Player.PlayerData.items or {}
    local item, key = GetInventoryItemBySlot(inventory, slot, itemName)
    if not item or not key then return false end

    item.amount = tonumber(item.amount) or 0
    if item.amount < amount then return false end

    item.amount = item.amount - amount
    if item.amount <= 0 then
        inventory[key] = nil
    else
        inventory[key] = item
    end

    Player.Functions.SetPlayerData('items', inventory)
    return true
end

local function RemoveMatchingInventoryItems(Player, itemName, matcher)
    if not Player or not itemName or type(matcher) ~= 'function' then return false end

    local inventory = Player.PlayerData.items or {}
    local changed = false
    for key, item in pairs(inventory) do
        if item and item.name and item.name:lower() == itemName:lower() and matcher(item) then
            inventory[key] = nil
            changed = true
        end
    end

    if changed then
        Player.Functions.SetPlayerData('items', inventory)
    end

    return changed
end

local function FindMatchingInventoryItem(Player, itemName, matcher)
    if not Player or not itemName or type(matcher) ~= 'function' then return nil end

    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name and item.name:lower() == itemName:lower() and matcher(item) then
            return item
        end
    end

    return nil
end

local function GetFirstFreeRegularSlot(Player)
    if not Player then return false end

    for slot = 5, Config.MaxSlots do
        if not GetInventoryItemBySlot(Player.PlayerData.items or {}, slot) then
            return slot
        end
    end

    return false
end

local function BuildItemSnapshot(itemName, amount, slot, info)
    local itemInfo = itemName and QBCore.Shared.Items[itemName:lower()]
    if not itemInfo or not slot then return nil end

    return {
        name = itemInfo.name,
        amount = amount or 1,
        info = info or {},
        label = itemInfo.label,
        description = (info and info.description) or itemInfo.description or '',
        weight = itemInfo.weight,
        type = itemInfo.type,
        unique = itemInfo.unique,
        useable = itemInfo.useable,
        image = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        slot = slot,
        combinable = itemInfo.combinable,
        rarity = (info and info.rarity) or itemInfo.rarity or 'common'
    }
end

local function UpsertInventoryItemBySlot(Player, item)
    if not Player or not item or not item.slot then return nil end

    local slot = tonumber(item.slot) or item.slot
    local numericSlot = tonumber(item.slot)
    local inventory = Player.PlayerData.items or {}

    if numericSlot then
        for key, invItem in pairs(inventory) do
            if invItem and tonumber(invItem.slot) == numericSlot then
                inventory[key] = nil
            end
        end
    end

    item.slot = slot
    inventory[slot] = item
    Player.Functions.SetPlayerData('items', inventory)
    return inventory
end

local function GetDeviceAttachmentMode(deviceItem, attachmentItem)
    if not deviceItem or not attachmentItem or not deviceItem.name or not attachmentItem.name then return nil end
    local deviceName = deviceItem.name:lower()
    local attachmentName = attachmentItem.name:lower()

    if DeviceAttachmentItems[deviceName] and DeviceAttachmentItems[deviceName][attachmentName] then
        return deviceName
    end

    return nil
end

local function ApplyDeviceAttachment(src, deviceSlot, attachmentSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return { success = false, message = 'Player not found' } end

    deviceSlot = tonumber(deviceSlot)
    attachmentSlot = tonumber(attachmentSlot)
    if not deviceSlot or not attachmentSlot or deviceSlot == attachmentSlot then
        return { success = false, message = 'No device attachment selected' }
    end

    local inventory = Player.PlayerData.items or {}
    local deviceItem = GetInventoryItemBySlot(inventory, deviceSlot)
    local attachmentItem = GetInventoryItemBySlot(inventory, attachmentSlot)
    local mode = GetDeviceAttachmentMode(deviceItem, attachmentItem)

    if not mode then
        return { success = false, message = 'That item cannot be installed here' }
    end

    local deviceInfo = type(deviceItem.info) == 'table' and CopyTable(deviceItem.info) or {}
    local attachmentInfo = type(attachmentItem.info) == 'table' and CopyTable(attachmentItem.info) or {}

    if mode == 'phone' then
        if deviceInfo.simNumber then
            return { success = false, message = 'This phone already has a SIM card' }
        end

        local simInfo = NormalizeSimCardInfo(attachmentInfo)
        local simNumber = simInfo.simNumber
        local simSerial = simInfo.simSerial
        local simContacts = simInfo.contacts or simInfo.simContacts or LoadContactRows(Player.PlayerData.citizenid)
        simInfo.contacts = simContacts
        simInfo.simContacts = simContacts
        simInfo.description = ('Phone number: %s'):format(simNumber)

        if not RemoveInventoryItemBySlot(Player, attachmentItem.name, attachmentSlot, 1) then
            return { success = false, message = 'Could not install SIM card' }
        end

        inventory = Player.PlayerData.items or {}
        deviceItem = GetInventoryItemBySlot(inventory, deviceSlot, 'phone')
        if not deviceItem or not deviceItem.name or deviceItem.name:lower() ~= 'phone' then
            AddItem(src, 'simcard', 1, false, simInfo, 'failed sim install refund')
            return { success = false, message = 'Phone not found' }
        end

        deviceInfo = EnsurePhoneDeviceInfo(Player, CopyTable(deviceItem.info))
        deviceInfo.simNumber = simNumber
        deviceInfo.simSerial = simSerial
        deviceInfo.simContacts = simContacts
        deviceInfo.description = 'SIM: ' .. simNumber
        deviceItem = SetInventoryItemInfoBySlot(Player, deviceSlot, deviceInfo, deviceInfo.description)
        if not deviceItem then
            AddItem(src, 'simcard', 1, false, simInfo, 'failed sim install refund')
            return { success = false, message = 'Could not save SIM to phone' }
        end

        RemoveMatchingInventoryItems(Player, 'simcard', function(item)
            local info = type(item.info) == 'table' and item.info or {}
            return tostring(info.simNumber or '') == tostring(simNumber)
        end)
        SetActivePhoneNumber(Player, simNumber)

        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['simcard'], 'remove')
        TriggerClientEvent('qb-inventory:client:updateInventory', src, Player.PlayerData.items or {})
        TriggerClientEvent('QBCore:Notify', src, ('SIM installed. Phone number %s is now active.'):format(simNumber), 'success')
        return { success = true, message = 'SIM card installed', DeviceData = deviceItem, Inventory = Player.PlayerData.items or {}, removedSlot = attachmentSlot, removedItem = attachmentItem.name }
    end

    if mode == 'tablet' then
        if deviceInfo.cryptoDrive then
            return { success = false, message = 'This tablet already has a crypto drive inserted' }
        end

        local attachmentName = attachmentItem.name
        local attachmentConfig = QBCore.Shared.Items[attachmentName]
        if not attachmentInfo.serial and not attachmentInfo.serie then
            attachmentInfo.serial = 'DRIVE-' .. QBCore.Shared.RandomStr(4) .. QBCore.Shared.RandomInt(4)
        end
        local driveData = {
            item = attachmentName,
            label = attachmentConfig and attachmentConfig.label or attachmentItem.label or attachmentName,
            image = attachmentConfig and attachmentConfig.image or attachmentItem.image or (attachmentName .. '.png'),
            inserted = os.time(),
            serial = attachmentInfo.serie or attachmentInfo.serial or attachmentInfo.simSerial,
            info = attachmentInfo
        }

        if not RemoveInventoryItemBySlot(Player, attachmentName, attachmentSlot, 1) then
            return { success = false, message = 'Could not insert crypto drive' }
        end

        inventory = Player.PlayerData.items or {}
        deviceItem = GetInventoryItemBySlot(inventory, deviceSlot, 'tablet')
        if not deviceItem or not deviceItem.name or deviceItem.name:lower() ~= 'tablet' then
            AddItem(src, attachmentName, 1, false, attachmentInfo, 'failed tablet drive refund')
            return { success = false, message = 'Tablet not found' }
        end

        deviceInfo = type(deviceItem.info) == 'table' and CopyTable(deviceItem.info) or {}
        deviceInfo.cryptoDrive = driveData
        deviceInfo.description = 'Crypto drive: ' .. driveData.label
        deviceItem = SetInventoryItemInfoBySlot(Player, deviceSlot, deviceInfo, deviceInfo.description)
        if not deviceItem then
            AddItem(src, attachmentName, 1, false, attachmentInfo, 'failed tablet drive refund')
            return { success = false, message = 'Could not save crypto drive to tablet' }
        end

        RemoveMatchingInventoryItems(Player, attachmentName, function(item)
            local info = type(item.info) == 'table' and item.info or {}
            local serial = info.serial or info.serie
            return driveData.serial and serial and tostring(serial) == tostring(driveData.serial)
        end)

        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[attachmentName], 'remove')
        TriggerClientEvent('qb-inventory:client:updateInventory', src, Player.PlayerData.items or {})
        TriggerClientEvent('QBCore:Notify', src, driveData.label .. ' inserted into tablet.', 'success')
        return { success = true, message = driveData.label .. ' inserted', DeviceData = deviceItem, Inventory = Player.PlayerData.items or {}, removedSlot = attachmentSlot, removedItem = attachmentName }
    end

    return { success = false, message = 'That item cannot be installed here' }
end

local function RemoveDeviceAttachment(src, deviceSlot, attachmentName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return { success = false, message = 'Player not found' } end

    deviceSlot = tonumber(deviceSlot)
    if not deviceSlot or not attachmentName then
        return { success = false, message = 'No device attachment selected' }
    end

    local inventory = Player.PlayerData.items or {}
    local deviceItem = GetInventoryItemBySlot(inventory, deviceSlot)
    if not deviceItem or not deviceItem.name then
        return { success = false, message = 'Device not found' }
    end

    local deviceName = deviceItem.name:lower()
    local originalInfo = type(deviceItem.info) == 'table' and CopyTable(deviceItem.info) or {}

    if deviceName == 'phone' and attachmentName == 'simcard' then
        local simNumber = originalInfo.simNumber
        if not simNumber then
            return { success = false, message = 'No SIM card installed' }
        end

        local contacts = originalInfo.simContacts
        if type(contacts) ~= 'table' or next(contacts) == nil then
            contacts = LoadContactRows(originalInfo.deviceOwnerCitizenid or Player.PlayerData.citizenid)
        end

        local simInfo = {
            simNumber = simNumber,
            simSerial = originalInfo.simSerial,
            contacts = contacts,
            simContacts = contacts,
            description = ('Phone number: %s'):format(simNumber)
        }

        local newInfo = EnsurePhoneDeviceInfo(Player, CopyTable(originalInfo))
        newInfo.simNumber = nil
        newInfo.simSerial = nil
        newInfo.simContacts = nil
        newInfo.description = 'No SIM installed'

        deviceItem = SetInventoryItemInfoBySlot(Player, deviceSlot, newInfo, newInfo.description)
        if not deviceItem then
            return { success = false, message = 'Could not remove the SIM from this phone' }
        end

        local addSlot = GetFirstFreeRegularSlot(Player)
        if not addSlot then
            SetInventoryItemInfoBySlot(Player, deviceSlot, originalInfo, originalInfo.description)
            TriggerClientEvent('QBCore:Notify', src, 'Make room in your inventory before removing the SIM card.', 'error')
            return { success = false, message = 'No room to remove the SIM card' }
        end

        if not AddItem(src, 'simcard', 1, addSlot, simInfo, 'removed phone sim') then
            SetInventoryItemInfoBySlot(Player, deviceSlot, originalInfo, originalInfo.description)
            TriggerClientEvent('QBCore:Notify', src, 'Make room in your inventory before removing the SIM card.', 'error')
            return { success = false, message = 'No room to remove the SIM card' }
        end

        local addedItem = GetInventoryItemBySlot(Player.PlayerData.items or {}, addSlot, 'simcard') or BuildItemSnapshot('simcard', 1, addSlot, simInfo)
        UpsertInventoryItemBySlot(Player, addedItem)
        RemoveMatchingInventoryItems(Player, 'simcard', function(item)
            local info = type(item.info) == 'table' and item.info or {}
            return tonumber(item.slot) ~= tonumber(addSlot) and tostring(info.simNumber or '') == tostring(simNumber)
        end)
        ClearActivePhoneNumber(Player, simNumber)

        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['simcard'], 'add')
        TriggerClientEvent('qb-inventory:client:updateInventory', src, Player.PlayerData.items or {})
        TriggerClientEvent('QBCore:Notify', src, 'SIM card removed.', 'success')
        return { success = true, message = 'SIM card removed', DeviceData = deviceItem, Inventory = Player.PlayerData.items or {}, AddedItem = addedItem }
    end

    if deviceName == 'tablet' and (attachmentName == 'crypto_usb' or attachmentName == 'cryptostick') then
        local driveData = originalInfo.cryptoDrive
        if not driveData or not driveData.item then
            return { success = false, message = 'No crypto drive inserted' }
        end

        local itemName = driveData.item
        local itemInfo = driveData.info or {}
        local newInfo = CopyTable(originalInfo)
        newInfo.cryptoDrive = nil
        newInfo.description = 'No crypto drive inserted'

        deviceItem = SetInventoryItemInfoBySlot(Player, deviceSlot, newInfo, newInfo.description)
        if not deviceItem then
            return { success = false, message = 'Could not remove the crypto drive from this tablet' }
        end

        local addSlot = GetFirstFreeRegularSlot(Player)
        if not addSlot then
            SetInventoryItemInfoBySlot(Player, deviceSlot, originalInfo, originalInfo.description)
            TriggerClientEvent('QBCore:Notify', src, 'Make room in your inventory before removing the crypto drive.', 'error')
            return { success = false, message = 'No room to remove the crypto drive' }
        end

        if not AddItem(src, itemName, 1, addSlot, itemInfo, 'removed tablet crypto drive') then
            SetInventoryItemInfoBySlot(Player, deviceSlot, originalInfo, originalInfo.description)
            TriggerClientEvent('QBCore:Notify', src, 'Make room in your inventory before removing the crypto drive.', 'error')
            return { success = false, message = 'No room to remove the crypto drive' }
        end

        local driveSerial = driveData.serial or itemInfo.serial or itemInfo.serie
        local addedItem = GetInventoryItemBySlot(Player.PlayerData.items or {}, addSlot, itemName) or BuildItemSnapshot(itemName, 1, addSlot, itemInfo)
        UpsertInventoryItemBySlot(Player, addedItem)
        if driveSerial then
            RemoveMatchingInventoryItems(Player, itemName, function(item)
                local info = type(item.info) == 'table' and item.info or {}
                local serial = info.serial or info.serie
                return tonumber(item.slot) ~= tonumber(addSlot) and serial and tostring(serial) == tostring(driveSerial)
            end)
        end

        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
        TriggerClientEvent('qb-inventory:client:updateInventory', src, Player.PlayerData.items or {})
        TriggerClientEvent('QBCore:Notify', src, 'Crypto drive removed.', 'success')
        return { success = true, message = 'Crypto drive removed', DeviceData = deviceItem, Inventory = Player.PlayerData.items or {}, AddedItem = addedItem }
    end

    return { success = false, message = 'That installed item cannot be removed here' }
end

local function TryApplyDeviceAttachmentFromDrag(src, fromItem, toItem, fromSlot, toSlot)
    if not fromItem or not toItem then return false end

    if GetDeviceAttachmentMode(toItem, fromItem) then
        return true, ApplyDeviceAttachment(src, toSlot, fromSlot)
    end

    if GetDeviceAttachmentMode(fromItem, toItem) then
        return true, ApplyDeviceAttachment(src, fromSlot, toSlot)
    end

    return false
end

QBCore.Functions.CreateCallback('qb-inventory:server:applyDeviceAttachment', function(source, cb, deviceData, attachmentData)
    if type(deviceData) ~= 'table' or type(attachmentData) ~= 'table' then
        cb({ success = false, message = 'No device attachment selected' })
        return
    end

    cb(ApplyDeviceAttachment(source, deviceData.slot, attachmentData.slot))
end)

QBCore.Functions.CreateCallback('qb-inventory:server:removeDeviceAttachment', function(source, cb, deviceData, attachmentData)
    if type(deviceData) ~= 'table' or type(attachmentData) ~= 'table' then
        cb({ success = false, message = 'No device attachment selected' })
        return
    end

    cb(RemoveDeviceAttachment(source, deviceData.slot, attachmentData.attachment))
end)

QBCore.Functions.CreateCallback('qb-inventory:server:applyWeaponAttachment', function(source, cb, weaponData, attachmentData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(weaponData) ~= 'table' or type(attachmentData) ~= 'table' then
        cb({ success = false, message = 'No weapon mod selected' })
        return
    end

    local weaponSlot = tonumber(weaponData.slot)
    local attachmentSlot = tonumber(attachmentData.slot)
    local attachmentName = attachmentData.attachment

    if not weaponSlot or not attachmentSlot or not attachmentName then
        cb({ success = false, message = 'No weapon mod selected' })
        return
    end

    local inventory = Player.PlayerData.items or {}
    local weaponItem = GetInventoryItemBySlot(inventory, weaponSlot, weaponData.name)
    local attachmentItem = GetInventoryItemBySlot(inventory, attachmentSlot, attachmentName)

    if not weaponItem or weaponItem.name ~= weaponData.name or weaponItem.type ~= 'weapon' then
        cb({ success = false, message = 'Weapon not found' })
        return
    end

    if not attachmentItem or attachmentItem.name ~= attachmentName or attachmentItem.amount < 1 then
        cb({ success = false, message = 'Mod item not found' })
        return
    end

    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    local component = allAttachments and allAttachments[attachmentName] and allAttachments[attachmentName][weaponItem.name]
    if not component then
        TriggerClientEvent('QBCore:Notify', src, 'This attachment is not valid for the selected weapon.', 'error')
        cb({ success = false, message = 'This mod does not fit this weapon' })
        return
    end

    weaponItem.info = type(weaponItem.info) == 'table' and weaponItem.info or {}
    weaponItem.info.attachments = weaponItem.info.attachments or {}

    if HasWeaponAttachment(component, weaponItem.info.attachments) then
        TriggerClientEvent('QBCore:Notify', src, 'This attachment is already on the weapon.', 'error')
        cb({ success = false, message = 'This mod is already installed' })
        return
    end

    if not RemoveItem(src, attachmentName, 1, attachmentSlot, 'weapon attachment applied') then
        cb({ success = false, message = 'Could not remove mod item' })
        return
    end

    inventory = Player.PlayerData.items or {}
    weaponItem = GetInventoryItemBySlot(inventory, weaponSlot, weaponData.name)
    if not weaponItem or weaponItem.name ~= weaponData.name then
        cb({ success = false, message = 'Weapon not found' })
        return
    end

    weaponItem.info = type(weaponItem.info) == 'table' and weaponItem.info or {}
    weaponItem.info.attachments = weaponItem.info.attachments or {}
    weaponItem.info.attachments[#weaponItem.info.attachments + 1] = {
        component = component
    }

    local _, weaponKey = GetInventoryItemBySlot(inventory, weaponSlot, weaponData.name)
    inventory[weaponKey or weaponSlot] = weaponItem
    Player.Functions.SetPlayerData('items', inventory)

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[attachmentName], 'remove')
    TriggerClientEvent('qb-inventory:client:updateInventory', src)

    cb({
        success = true,
        message = 'Mod applied',
        component = component,
        WeaponData = weaponItem
    })
end)

QBCore.Functions.CreateCallback('qb-inventory:server:removeWeaponAttachment', function(source, cb, weaponData, attachmentData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(weaponData) ~= 'table' or type(attachmentData) ~= 'table' then
        cb({ success = false, message = 'No weapon mod selected' })
        return
    end

    local weaponSlot = tonumber(weaponData.slot)
    local attachmentName = attachmentData.attachment

    if not weaponSlot or not attachmentName then
        cb({ success = false, message = 'No weapon mod selected' })
        return
    end

    local inventory = Player.PlayerData.items or {}
    local weaponItem = GetInventoryItemBySlot(inventory, weaponSlot, weaponData.name)
    if not weaponItem or weaponItem.name ~= weaponData.name or weaponItem.type ~= 'weapon' then
        cb({ success = false, message = 'Weapon not found' })
        return
    end

    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    local component = allAttachments and allAttachments[attachmentName] and allAttachments[attachmentName][weaponItem.name]
    if not component or type(weaponItem.info) ~= 'table' or type(weaponItem.info.attachments) ~= 'table' then
        cb({ success = false, message = 'This mod is not installed' })
        return
    end

    local removeIndex = nil
    for index, installedAttachment in pairs(weaponItem.info.attachments) do
        if ComponentMatches(installedAttachment.component, component) then
            removeIndex = index
            break
        end
    end

    if not removeIndex then
        cb({ success = false, message = 'This mod is not installed' })
        return
    end

    if not AddItem(src, attachmentName, 1, false, false, 'weapon attachment removed') then
        cb({ success = false, message = 'No space for removed mod' })
        return
    end

    table.remove(weaponItem.info.attachments, removeIndex)
    local _, weaponKey = GetInventoryItemBySlot(inventory, weaponSlot, weaponData.name)
    inventory[weaponKey or weaponSlot] = weaponItem
    Player.Functions.SetPlayerData('items', inventory)

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[attachmentName], 'add')
    TriggerClientEvent('qb-inventory:client:updateInventory', src)

    cb({
        success = true,
        message = 'Mod removed',
        component = component,
        WeaponData = weaponItem
    })
end)

QBCore.Functions.CreateCallback('qb-inventory:server:giveItem', function(source, cb, target, itemName, amount, slot, info)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(target))

    if not Player or not Target then
        cb(false)
        return
    end

    if src == tonumber(target) then
        cb(false)
        return
    end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(tonumber(target))
    if srcPed == 0 or targetPed == 0 or #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.0 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.nonb'), 'error')
        cb(false)
        return
    end

    amount = tonumber(amount) or 1
    slot = tonumber(slot)

    if amount < 1 or not slot then
        cb(false)
        return
    end

    local item = Player.PlayerData.items[slot]
    if not item or item.name ~= itemName or item.amount < amount then
        cb(false)
        return
    end

    local added = AddItem(Target.PlayerData.source, itemName, amount, false, item.info or info or {}, 'given item')
    if not added then
        cb(false)
        return
    end

    local removed = RemoveItem(src, itemName, amount, slot, 'given item')
    if not removed then
        RemoveItem(Target.PlayerData.source, itemName, amount, false, 'rollback given item')
        cb(false)
        return
    end

    TriggerClientEvent('qb-inventory:client:updateInventory', src)
    TriggerClientEvent('qb-inventory:client:updateInventory', Target.PlayerData.source)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName:lower()], 'remove', amount)
    TriggerClientEvent('qb-inventory:client:ItemBox', Target.PlayerData.source, QBCore.Shared.Items[itemName:lower()], 'add', amount)

    cb(true)
end)

function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]

    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

local function CreateFloorDrop(src, itemData, amount, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    amount = math.floor(tonumber(amount) or 1)
    slot = tonumber(slot)

    if not slot or amount < 1 then return false end

    local item = Player.PlayerData.items[slot]
    if not item or item.amount < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Could not drop item', 'error')
        return false
    end

    if itemData and itemData.name and itemData.name ~= item.name then
        TriggerClientEvent('QBCore:Notify', src, 'Could not drop item', 'error')
        return false
    end

    local removed = RemoveItem(src, item.name, amount, slot, 'dropped item')
    if not removed then
        TriggerClientEvent('QBCore:Notify', src, 'Could not drop item', 'error')
        return false
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dropCoords = vector3(coords.x, coords.y, coords.z)
    local dropId
    repeat
        dropId = 'drop-' .. tostring(math.random(10000, 99999))
    until not Drops[dropId]

    Drops[dropId] = {
        items = {
            {
                name = item.name,
                amount = amount,
                info = item.info or {},
                label = item.label,
                description = item.description,
                weight = item.weight,
                type = item.type,
                unique = item.unique,
                useable = item.useable,
                image = item.image,
                slot = 1
            }
        },
        isOpen = false,
        label = 'Drop',
        maxweight = Config.DropSize.maxweight,
        slots = Config.DropSize.slots,
        coords = dropCoords,
        createdTime = os.time()
    }

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item.name:lower()], 'remove', amount)
    TriggerClientEvent('qb-inventory:client:updateInventory', src)
    TriggerClientEvent('qb-inventory:client:createDrop', -1, dropId, dropCoords)
    return true, dropId
end

RegisterNetEvent('qb-inventory:server:dropItem', function(itemData, amount, slot)
    CreateFloorDrop(source, itemData, amount, slot)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:dropItem', function(source, cb, itemData, amount, slot)
    local success = CreateFloorDrop(source, itemData, amount, slot)
    cb(success)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(_, cb)
    local currentDrops = {}
    for dropId, drop in pairs(Drops) do
        if drop and drop.coords then
            currentDrops[dropId] = {
                coords = {
                    x = drop.coords.x,
                    y = drop.coords.y,
                    z = drop.coords.z
                }
            }
        end
    end

    cb(currentDrops)
end)

function OpenDrop(src, dropId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not dropId or not Drops[dropId] then return end

    local drop = Drops[dropId]
    if drop.isOpen and drop.isOpen ~= src then
        TriggerClientEvent('QBCore:Notify', src, 'Drop is already open', 'error')
        return
    end

    if drop.coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local dropCoords = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
        if #(playerCoords - dropCoords) > 3.0 then
            TriggerClientEvent('QBCore:Notify', src, 'You are too far away from the drop', 'error')
            return
        end
    end

    if SyncEquippedArmorFromPed then SyncEquippedArmorFromPed(Player) end

    drop.isOpen = src
    TriggerClientEvent('qb-inventory:client:openInventory', src, Player.PlayerData.items, {
        name = dropId,
        label = drop.label or 'Drop',
        maxweight = Config.DropSize.maxweight,
        slots = Config.DropSize.slots,
        inventory = drop.items or {}
    }, Player.PlayerData.metadata)
end

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    OpenDrop(source, dropId)
end)

RegisterNetEvent('qb-inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    CreateShop({
        name = 'vending',
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    OpenShop(src, 'vending')
end)

RegisterNetEvent('qb-inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return end
    Player(source).state.inv_busy = false

    inventory = inventory or ''
    if inventory ~= '' and inventory:find('shop%-') then return end
    if inventory ~= '' and inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        if targetId then
            Player(targetId).state.inv_busy = false
        end
        return
    end
    if inventory ~= '' and Drops[inventory] then
        Drops[inventory].isOpen = false
        if not next(Drops[inventory].items or {}) and not Drops[inventory].isOpen then
            TriggerClientEvent('qb-inventory:client:removeDropObject', -1, inventory)
            Drops[inventory] = nil
        end
        return
    end
    if inventory == '' or not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', {
        inventory,
        json.encode(Inventories[inventory].items),
        json.encode(Inventories[inventory].items)
    })
end)

RegisterNetEvent('qb-inventory:server:useItem', function(item)
    local src = source
    if not item or not item.slot then return end
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = QBCore.Shared.Items[itemData.name:lower()]
    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, itemData.info.quality and itemData.info.quality > 0)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)
-- =========================
-- INVENTORY HELPERS
-- =========================

local function getItem(inventoryId, src, slot)
    local items = {}

    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end

    elseif type(inventoryId) == 'string' and inventoryId:find('otherplayer%-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end

    elseif type(inventoryId) == 'string' and inventoryId:find('drop%-') == 1 then
        if Drops[inventoryId] then
            items = Drops[inventoryId].items or {}
        end

    else
        if Inventories[inventoryId] then
            items = Inventories[inventoryId].items or {}
        end
    end

    for _, item in pairs(items) do
        if item and item.slot == slot then
            return item
        end
    end

    return nil
end

local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif type(inventoryId) == 'string' and inventoryId:find('otherplayer%-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

local function SetQuickSlotValue(quickslots, quickSlot, itemSlot)
    quickslots[quickSlot] = nil
    quickslots[tostring(quickSlot)] = itemSlot
end

local function UpdateQuickSlotsForInventoryMove(Player, fromInventory, toInventory, fromSlot, toSlot, fromAmount, sourceAmountBefore, toItem, sameItemStack)
    if not Player or type(Player.PlayerData.metadata) ~= 'table' then return end

    local quickslots = Player.PlayerData.metadata.quickslots
    if type(quickslots) ~= 'table' then return end

    local movingAll = (tonumber(fromAmount) or 1) >= (tonumber(sourceAmountBefore) or 1)
    local changed = false

    for i = 1, 4 do
        local assigned = tonumber(quickslots[tostring(i)] or quickslots[i])
        if assigned then
            if fromInventory == 'player' and toInventory == 'player' then
                if toItem and sameItemStack then
                    if movingAll and assigned == fromSlot then
                        SetQuickSlotValue(quickslots, i, toSlot)
                        changed = true
                    end
                elseif toItem then
                    if assigned == fromSlot then
                        SetQuickSlotValue(quickslots, i, toSlot)
                        changed = true
                    elseif assigned == toSlot then
                        SetQuickSlotValue(quickslots, i, fromSlot)
                        changed = true
                    end
                elseif movingAll and assigned == fromSlot then
                    SetQuickSlotValue(quickslots, i, toSlot)
                    changed = true
                end
            elseif fromInventory == 'player' and movingAll and assigned == fromSlot then
                SetQuickSlotValue(quickslots, i, nil)
                changed = true
            elseif toInventory == 'player' and toItem and not sameItemStack and assigned == toSlot then
                SetQuickSlotValue(quickslots, i, nil)
                changed = true
            end
        end
    end

    if changed then
        Player.Functions.SetMetaData('quickslots', quickslots)
    end
end

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- safety checks
    if not fromInventory or not toInventory then return end
    if not fromSlot or not toSlot then return end

    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    fromAmount = tonumber(fromAmount) or 1
    toAmount = tonumber(toAmount) or 0

    if fromAmount < 1 then return end

    -- block shop drag weirdness
    if type(toInventory) == 'string' and toInventory:find('shop%-') then return end

    local fromItem = getItem(fromInventory, src, fromSlot)
    if not fromItem then return end

    local toItem = getItem(toInventory, src, toSlot)

    -- weapon safety
    if fromInventory == 'player' and fromItem.type == 'weapon' then
        checkWeapon(src, fromItem)
    end

    local fromId = getIdentifier(fromInventory, src)
    local toId = getIdentifier(toInventory, src)
    local inventoryChanged = false
    local sourceAmountBefore = tonumber(fromItem.amount) or 1

    if fromInventory == 'player' and toInventory == 'player' and toItem then
        local handled, result = TryApplyDeviceAttachmentFromDrag(src, fromItem, toItem, fromSlot, toSlot)
        if handled then
            if result and not result.success and result.message then
                TriggerClientEvent('QBCore:Notify', src, result.message, 'error')
            end
            TriggerClientEvent('qb-inventory:client:updateInventory', src)
            return
        end
    end

    if toItem and fromItem.name == toItem.name then
        if RemoveItem(fromId, fromItem.name, fromAmount, fromSlot, 'stacked item') then
            AddItem(toId, toItem.name, fromAmount, toSlot, toItem.info, 'stacked item')
            inventoryChanged = true
        end
        
    elseif not toItem and fromAmount < fromItem.amount then
        if RemoveItem(fromId, fromItem.name, fromAmount, fromSlot, 'split item') then
            AddItem(toId, fromItem.name, fromAmount, toSlot, fromItem.info, 'split item')
            inventoryChanged = true
        end

    elseif toItem then
        local fromAmt = fromItem.amount
        local toAmt = toItem.amount

        if RemoveItem(fromId, fromItem.name, fromAmt, fromSlot, 'swap')
        and RemoveItem(toId, toItem.name, toAmt, toSlot, 'swap') then

            AddItem(toId, fromItem.name, fromAmt, toSlot, fromItem.info, 'swap')
            AddItem(fromId, toItem.name, toAmt, fromSlot, toItem.info, 'swap')
            inventoryChanged = true
        end

    else
        if RemoveItem(fromId, fromItem.name, fromAmount, fromSlot, 'move') then
            AddItem(toId, fromItem.name, fromAmount, toSlot, fromItem.info, 'move')
            inventoryChanged = true
        end
    end

    if inventoryChanged then
        UpdateQuickSlotsForInventoryMove(Player, fromInventory, toInventory, fromSlot, toSlot, fromAmount, sourceAmountBefore, toItem, toItem and fromItem.name == toItem.name)
    end

    TriggerClientEvent('qb-inventory:client:updateInventory', src)

    if type(toInventory) == 'string' and toInventory:find('otherplayer%-') then
        local targetId = tonumber(toInventory:match('otherplayer%-(.+)'))
        if targetId then
            TriggerClientEvent('qb-inventory:client:updateInventory', targetId)
        end
    elseif type(fromInventory) == 'string' and fromInventory:find('otherplayer%-') then
        local targetId = tonumber(fromInventory:match('otherplayer%-(.+)'))
        if targetId then
            TriggerClientEvent('qb-inventory:client:updateInventory', targetId)
        end
    end
end)
