local QBCore = exports['qb-core']:GetCoreObject()
local digCooldowns = {}

local function notify(src, message, kind)
    TriggerClientEvent('prp-drugs:client:notify', src, message, kind)
end

local function getInventoryResource()
    local primary = Config.Inventory or 'prp-inventory'
    local primaryState = GetResourceState(primary)
    if primaryState == 'started' or primaryState == 'starting' then return primary end

    local fallback = Config.InventoryFallback or 'qb-inventory'
    local fallbackState = GetResourceState(fallback)
    if fallback ~= primary and (fallbackState == 'started' or fallbackState == 'starting') then return fallback end

    return primary
end

local function getSharedItem(item)
    if type(item) ~= 'string' then return nil end
    return QBCore.Shared.Items[item:lower()]
end

local function showItemBox(src, item, action, amount)
    local itemData = getSharedItem(item)
    if not itemData then return end
    TriggerClientEvent(Config.ItemBoxEvent or 'qb-inventory:client:ItemBox', src, itemData, action, amount or 1)
end

local function canAddItem(src, item, amount)
    local inventory = getInventoryResource()
    local ok, canAdd, reason = pcall(function()
        return exports[inventory]:CanAddItem(src, item, amount)
    end)

    if not ok then return true end
    return canAdd == true, reason
end

local function addItem(Player, item, amount, info, reason)
    if not Player then return false, 'player' end

    amount = tonumber(amount) or 1
    if not getSharedItem(item) then
        print(('[prp-drugs] Cannot add unknown item "%s". Check qb-core/shared/items.lua.'):format(tostring(item)))
        return false, 'item'
    end

    local src = Player.PlayerData.source
    local canAdd, cannotReason = canAddItem(src, item, amount)
    if not canAdd then return false, cannotReason or 'capacity' end

    local inventory = getInventoryResource()
    local ok = exports[inventory]:AddItem(src, item, amount, false, info or false, reason or 'prp-drugs')
    if ok then
        showItemBox(src, item, 'add', amount)
    end
    return ok, ok and nil or 'capacity'
end

local function removeItem(Player, item, amount, slot, reason)
    if not Player then return false, 'player' end

    amount = tonumber(amount) or 1
    if not getSharedItem(item) then
        print(('[prp-drugs] Cannot remove unknown item "%s". Check qb-core/shared/items.lua.'):format(tostring(item)))
        return false, 'item'
    end

    local src = Player.PlayerData.source
    local inventory = getInventoryResource()
    local ok = exports[inventory]:RemoveItem(src, item, amount, slot or false, reason or 'prp-drugs')
    if ok then
        showItemBox(src, item, 'remove', amount)
    end
    return ok, ok and nil or 'missing'
end

local function getItemByName(Player, item)
    if not Player then return nil end
    return exports[getInventoryResource()]:GetItemByName(Player.PlayerData.source, item)
end

local function getItemsByName(Player, item)
    if not Player then return {} end
    return exports[getInventoryResource()]:GetItemsByName(Player.PlayerData.source, item) or {}
end

local function getItemBySlot(Player, slot)
    if not Player then return nil end
    return exports[getInventoryResource()]:GetItemBySlot(Player.PlayerData.source, tonumber(slot))
end

local function chooseDirtGrade()
    local roll = math.random(1, 100)
    local running = 0
    for _, entry in ipairs(Config.Digging.Grades) do
        running = running + entry.chance
        if roll <= running then return entry.grade end
    end
    return 'D'
end

QBCore.Functions.CreateUseableItem(Config.Items.Shovel, function(source)
    TriggerClientEvent('prp-drugs:client:useShovel', source)
end)

QBCore.Functions.CreateUseableItem(Config.Items.PlantPot, function(source)
    TriggerClientEvent('prp-drugs:client:usePlantPot', source)
end)

QBCore.Functions.CreateUseableItem(Config.Items.Bud, function(source)
    TriggerClientEvent('prp-drugs:client:bagBud', source)
end)

QBCore.Functions.CreateUseableItem(Config.Items.RollingPaper, function(source)
    TriggerClientEvent('prp-drugs:client:rollJoint', source)
end)

QBCore.Functions.CreateUseableItem(Config.Items.Bagged, function(source, item)
    TriggerClientEvent('prp-drugs:client:unbagWeed', source, item.slot)
end)

RegisterNetEvent('prp-drugs:server:digDirt', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(coords) ~= 'table' then return end

    local now = os.time()
    if digCooldowns[src] and now - digCooldowns[src] < Config.Digging.CooldownSeconds then
        return notify(src, 'The ground here needs time before you can dig again.', 'error')
    end

    local ped = GetPlayerPed(src)
    local actual = GetEntityCoords(ped)
    local claimed = vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0)
    if #(actual - claimed) > 5.0 then return end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return end

    local shovel = getItemByName(Player, Config.Items.Shovel)
    if not shovel then return notify(src, 'You need a shovel.', 'error') end

    local grade = chooseDirtGrade()
    local dirt = Config.DirtGrades[grade]
    local quality = math.random(dirt.minQuality * 10, dirt.maxQuality * 10) / 10
    local info = {
        grade = grade,
        quality = quality,
        description = ('Class %s dirt | %.1f%% soil quality'):format(grade, quality),
    }

    local added, addReason = addItem(Player, dirt.item, 1, info, 'prp-drugs-dig')
    if added then
        digCooldowns[src] = now
        notify(src, ('You dug up Class %s dirt (%.1f%%).'):format(grade, quality), grade == 'A' and 'success' or 'primary')
    elseif addReason == 'item' then
        notify(src, 'This dirt item is not configured correctly. Tell staff to check shared items.', 'error')
    elseif addReason == 'weight' then
        notify(src, 'Your inventory is too heavy for more dirt.', 'error')
    elseif addReason == 'slots' then
        notify(src, 'You need a free inventory slot for graded dirt.', 'error')
    else
        notify(src, 'Your inventory is full.', 'error')
    end
end)

RegisterNetEvent('prp-drugs:server:buyShopItem', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local entry = Config.Shop.items[tonumber(index or 0)]
    if not Player or not entry then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    if #(coords - vector3(Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z)) > 5.0 then return end

    if not Player.Functions.RemoveMoney(Config.MoneyType, entry.price, 'prp-drugs-shop') then
        return notify(src, 'You do not have enough money.', 'error')
    end

    if not addItem(Player, entry.item, entry.amount, false, 'prp-drugs-shop') then
        Player.Functions.AddMoney(Config.MoneyType, entry.price, 'prp-drugs-shop-refund')
        return notify(src, 'Your inventory is full. Your money was refunded.', 'error')
    end

    notify(src, ('Purchased %sx %s for $%s.'):format(entry.amount, entry.item, entry.price), 'success')
end)

AddEventHandler('playerDropped', function()
    digCooldowns[source] = nil
end)

exports('AddItem', addItem)
exports('RemoveItem', removeItem)
exports('GetItemByName', getItemByName)
exports('GetItemsByName', getItemsByName)
exports('GetItemBySlot', getItemBySlot)
exports('Notify', notify)
