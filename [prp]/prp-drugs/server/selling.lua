local QBCore = exports['qb-core']:GetCoreObject()
local saleCooldowns = {}
local soldNpcs = {}

local function notify(src, message, kind)
    exports['prp-drugs']:Notify(src, message, kind)
end

local function policeCount()
    local count = 0
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        if Player.PlayerData.job.name == Config.PoliceJobName and Player.PlayerData.job.onduty then
            count = count + 1
        end
    end
    return count
end

local function chooseSaleItem(Player)
    for _, name in ipairs({Config.Items.Brick, Config.Items.Bagged, Config.Items.Joint}) do
        local item = exports['prp-drugs']:GetItemByName(Player, name)
        if item then return item end
    end
end

RegisterNetEvent('prp-drugs:server:sellToNpc', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.Selling.enabled then return end

    local now = os.time()
    if saleCooldowns[src] and now - saleCooldowns[src] < Config.Selling.cooldownSeconds then return end
    saleCooldowns[src] = now

    if policeCount() < Config.MinimumPoliceForSelling then
        return notify(src, 'There are not enough police around to sell right now.', 'error')
    end

    netId = tonumber(netId)
    local npc = NetworkGetEntityFromNetworkId(netId)
    if npc == 0 or not DoesEntityExist(npc) or not IsEntityAPed(npc) or IsPedAPlayer(npc) then return end
    if IsPedDeadOrDying(npc, true) or IsPedInAnyVehicle(npc, false) then return end
    if Config.Selling.blacklistedPedModels[GetEntityModel(npc)] then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local npcCoords = GetEntityCoords(npc)
    if #(playerCoords - npcCoords) > 4.0 then return end

    local npcKey = ('%s:%s'):format(netId, math.floor(npcCoords.x + npcCoords.y))
    if soldNpcs[npcKey] and now - soldNpcs[npcKey] < 300 then
        return notify(src, 'This person has already bought enough.', 'error')
    end

    local item = chooseSaleItem(Player)
    if not item then return notify(src, 'You have no packaged drugs to sell.', 'error') end

    if math.random(1, 100) <= Config.Selling.npcRejectChance then
        TriggerClientEvent('prp-drugs:client:npcSaleResult', src, netId, false)
        if math.random(1, 100) <= Config.Selling.policeAlertChance then
            TriggerClientEvent('prp-drugs:client:notify', src, 'The NPC looks suspicious and walks away.', 'error')
            TriggerClientEvent('prp-drugs:client:dispatch', src, npcCoords)
        else
            notify(src, 'The NPC refused your offer.', 'error')
        end
        return
    end

    local priceRange = Config.Selling.prices[item.name]
    if not priceRange then return end

    local info = PRPDrugs.DecodeInfo(item)
    local quality = PRPDrugs.Clamp(tonumber(info.quality or info.potency) or 50, 1, 100)
    local base = math.random(priceRange.min, priceRange.max)
    local qualityMultiplier = 0.55 + (quality / 100) * 0.75
    local price = math.floor(base * qualityMultiplier)

    if not exports['prp-drugs']:RemoveItem(Player, item.name, 1, item.slot, 'prp-drugs-npc-sale') then return end
    Player.Functions.AddMoney(Config.MoneyType, price, 'prp-drugs-npc-sale')
    soldNpcs[npcKey] = now

    TriggerClientEvent('prp-drugs:client:npcSaleResult', src, netId, true)
    notify(src, ('Sold %s %s for $%s.'):format(info.strain or '', item.label or item.name, price), 'success')

    if math.random(1, 100) <= Config.Selling.policeAlertChance then
        TriggerClientEvent('prp-drugs:client:dispatch', src, npcCoords)
    end
end)


AddEventHandler('playerDropped', function()
    saleCooldowns[source] = nil
end)
