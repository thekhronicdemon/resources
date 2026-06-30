local QBCore = exports['qb-core']:GetCoreObject()
local ActiveTrucks = {}

local function HasJob(Player)
    return Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name == Config.JobName
end

RegisterNetEvent('prp-garbage:server:rentTruck', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if ActiveTrucks[src] then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.AlreadyRented, 'error')
        return
    end

    local deposit = Config.Depot.deposit or 250
    if Player.Functions.GetMoney('cash') < deposit then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoDeposit, 'error')
        return
    end

    Player.Functions.RemoveMoney('cash', deposit, 'garbage-truck-deposit')
    ActiveTrucks[src] = { deposit = deposit, plate = nil }

    TriggerClientEvent('prp-garbage:client:spawnTruck', src)
end)

RegisterNetEvent('prp-garbage:server:setTruckPlate', function(plate)
    local src = source
    if ActiveTrucks[src] then
        ActiveTrucks[src].plate = tostring(plate or ''):gsub('%s+', '')
    end
end)

QBCore.Functions.CreateCallback('prp-garbage:server:hasActiveTruck', function(source, cb)
    cb(ActiveTrucks[source] ~= nil)
end)

QBCore.Functions.CreateCallback('prp-garbage:server:isOwnedTruck', function(source, cb, plate)
    local data = ActiveTrucks[source]
    plate = tostring(plate or ''):gsub('%s+', '')
    cb(data ~= nil and data.plate == plate)
end)

RegisterNetEvent('prp-garbage:server:returnTruck', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local data = ActiveTrucks[src]
    if not data then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoRentedTruck, 'error')
        return
    end

    plate = tostring(plate or ''):gsub('%s+', '')
    if data.plate and data.plate ~= plate then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.WrongTruck, 'error')
        return
    end

    Player.Functions.AddMoney('cash', data.deposit or Config.Depot.deposit or 250, 'garbage-truck-deposit-refund')
    ActiveTrucks[src] = nil

    TriggerClientEvent('prp-garbage:client:deleteReturnedTruck', src)
    TriggerClientEvent('QBCore:Notify', src, Config.Notifications.DepotReturnTruck, 'success')
end)

RegisterNetEvent('prp-garbage:server:payRoute', function(payKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not HasJob(Player) then return end

    local cfg = Config.Pay[payKey]
    if not cfg then return end

    local amount = math.random(cfg.min, cfg.max)
    Player.Functions.AddMoney(cfg.account or 'cash', amount, 'garbage-route-pay')
    TriggerClientEvent('QBCore:Notify', src, ('Route complete. You were paid $%s.'):format(amount), 'success')
end)

RegisterNetEvent('prp-garbage:server:breakdownScrap', function(items)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(items) ~= 'table' or #items <= 0 then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NothingCarried, 'error')
        return
    end

    local rewards = {}
    for _, propKey in pairs(items) do
        local propData = Config.HardRubbish.Props[propKey]
        if propData and propData.rewards then
            for item, range in pairs(propData.rewards) do
                local amount = math.random(range.min or 1, range.max or 1)
                rewards[item] = (rewards[item] or 0) + amount
            end
        end
    end

    for item, amount in pairs(rewards) do
        Player.Functions.AddItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', amount)
    end

    TriggerClientEvent('QBCore:Notify', src, Config.Notifications.ScrapItemBroken or 'Hard rubbish broken down.', 'success')
end)

AddEventHandler('playerDropped', function()
    ActiveTrucks[source] = nil
end)
