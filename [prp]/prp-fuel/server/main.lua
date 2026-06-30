local QBCore = exports[Config.CoreName]:GetCoreObject()

local function ClampFuel(fuel)
    fuel = tonumber(fuel) or Config.DefaultFuel
    if fuel < 0.0 then return 0.0 end
    if fuel > Config.MaxFuel then return Config.MaxFuel end
    return fuel + 0.0
end

local function GetFuelCanInfo(amount)
    amount = ClampFuel(amount or Config.FuelCan.StartingFuel)
    local key = Config.FuelCan.MetadataKey or 'quality'
    local info = {
        fuel = amount,
        description = ('Fuel: %s%%'):format(math.floor(amount + 0.5)),
    }
    info[key] = amount
    return info
end

local function GetItemBySlot(Player, slot)
    slot = tonumber(slot)
    if not Player or not slot then return nil end

    local item = Player.PlayerData.items and Player.PlayerData.items[slot]
    if not item or tostring(item.name or ''):lower() ~= tostring(Config.FuelCan.Item):lower() then return nil end
    return item
end

local function GetFuelCanAmount(item)
    local info = item and item.info or {}
    local key = Config.FuelCan.MetadataKey or 'quality'
    return ClampFuel(info.fuel or info[key] or info.health or Config.FuelCan.StartingFuel)
end

if Config.FuelCan.Enabled then
    QBCore.Functions.CreateUseableItem(Config.FuelCan.Item, function(source, item)
        TriggerClientEvent('prp-fuel:client:useFuelCan', source, item)
    end)
end

QBCore.Functions.CreateCallback('prp-fuel:server:canPay', function(source, cb, amount, paymentType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    amount = math.floor(tonumber(amount) or 0)
    paymentType = paymentType == 'bank' and 'bank' or 'cash'

    cb((Player.PlayerData.money[paymentType] or 0) >= amount)
end)

RegisterNetEvent('prp-fuel:server:payFuel', function(amount, paymentType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    paymentType = paymentType == 'bank' and 'bank' or 'cash'

    if (Player.PlayerData.money[paymentType] or 0) >= amount then
        Player.Functions.RemoveMoney(paymentType, amount, 'prp-fuel-refuel')
    end
end)

RegisterNetEvent('prp-fuel:server:buyFuelCan', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.FuelCan.Enabled then return end

    local itemName = Config.FuelCan.Item
    local price = math.floor(tonumber(Config.FuelCan.Price) or 500)
    local paymentType = Config.FuelCan.PaymentType == 'bank' and 'bank' or 'cash'

    if (Player.PlayerData.money[paymentType] or 0) < price then
        TriggerClientEvent('QBCore:Notify', src, Config.Text.NoMoney, 'error')
        return
    end

    local info = GetFuelCanInfo(Config.FuelCan.StartingFuel)
    if not Player.Functions.AddItem(itemName, 1, false, info, 'prp-fuel-can-purchase') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have room for a fuel can.', 'error')
        return
    end

    Player.Functions.RemoveMoney(paymentType, price, 'prp-fuel-can-purchase')
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', 1)
    TriggerClientEvent('QBCore:Notify', src, Config.Text.FuelCanBought, 'success')
end)

RegisterNetEvent('prp-fuel:server:updateFuelCan', function(slot, usedAmount, removeOnly)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.FuelCan.Enabled then return end

    local item = GetItemBySlot(Player, slot)
    if not item then return end

    if removeOnly then
        Player.Functions.RemoveItem(Config.FuelCan.Item, 1, item.slot, 'empty fuel can')
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.FuelCan.Item], 'remove', 1)
        return
    end

    usedAmount = math.abs(tonumber(usedAmount) or 0.0)
    if usedAmount <= 0.0 then return end
    if usedAmount > Config.FuelCan.StartingFuel then usedAmount = Config.FuelCan.StartingFuel end

    local remaining = ClampFuel(GetFuelCanAmount(item) - usedAmount)
    if remaining <= 0.0 then
        Player.Functions.RemoveItem(Config.FuelCan.Item, 1, item.slot, 'fuel can emptied')
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.FuelCan.Item], 'remove', 1)
        return
    end

    item.info = GetFuelCanInfo(remaining)
    item.description = item.info.description
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
end)

RegisterNetEvent('prp-fuel:server:setFuelState', function(netId, fuel)
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 or not DoesEntityExist(entity) then return end

    Entity(entity).state:set(Config.FuelStateName, ClampFuel(fuel), true)
end)
