local QBCore = exports['qb-core']:GetCoreObject()
local ActiveMissions = {}

local function PickRandom(tbl)
    return tbl[math.random(1, #tbl)]
end

RegisterNetEvent('prp-scrapyard:server:requestMission', function()
    local src = source
    if ActiveMissions[src] then
        TriggerClientEvent('QBCore:Notify', src, 'You are already on a scrapyard run.', 'error')
        return
    end

    local keys = {}
    for key in pairs(Config.VehicleSets) do
        keys[#keys+1] = key
    end

    local vehicleSet = PickRandom(keys)
    local model = PickRandom(Config.VehicleSets[vehicleSet].models)
    local location = PickRandom(Config.StealLocations)

    ActiveMissions[src] = {
        vehicleSet = vehicleSet,
        model = model,
        location = location,
    }

    TriggerClientEvent('prp-scrapyard:client:startMission', src, {
        vehicleSet = vehicleSet,
        model = model,
        location = location,
    })
end)

RegisterNetEvent('prp-scrapyard:server:completeJob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not ActiveMissions[src] then return end

    for i = 1, Config.Rewards.guaranteedDrops do
        local item = PickRandom(Config.Items)
        Player.Functions.AddItem(item, 1)
        if QBCore.Shared.Items[item] then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', 1)
        end
    end

    if math.random(1, 100) <= Config.Rewards.perPartBonusChance then
        local rolls = math.random(Config.Rewards.bonusRollsMin, Config.Rewards.bonusRollsMax)
        for i = 1, rolls do
            local item = PickRandom(Config.Items)
            Player.Functions.AddItem(item, 1)
            if QBCore.Shared.Items[item] then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', 1)
            end
        end
    end

    ActiveMissions[src] = nil
end)

AddEventHandler('playerDropped', function()
    ActiveMissions[source] = nil
end)
