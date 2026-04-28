local QBCore = exports['qb-core']:GetCoreObject()

local ActiveRolls = {}

local function round(num, places)
    local mult = 10 ^ (places or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function normalizeRarity(rarity)
    if type(rarity) ~= 'string' then return 'common' end
    rarity = rarity:lower()
    if rarity == 'un-common' then rarity = 'uncommon' end
    return rarity
end

local function buildPool()
    local pool = {}
    local totalWeight = 0

    for _, entry in ipairs(Config.ItemsRolled or {}) do
        local itemName = entry.item
        local shared = itemName and QBCore.Shared.Items[itemName]

        if shared then
            local rarity = normalizeRarity(shared.rarity)
            local weight = tonumber(entry.overrideWeight) or tonumber(Config.RarityWeights[rarity]) or 1
            if weight > 0 then
                totalWeight = totalWeight + weight
                pool[#pool + 1] = {
                    item = itemName,
                    amount = tonumber(entry.amount) or 1,
                    label = shared.label or itemName,
                    image = shared.image or 'placeholder.png',
                    description = shared.description or '',
                    rarity = rarity,
                    weight = weight,
                    color = Config.RarityColors[rarity] or '#b8c0cc'
                }
            end
        else
            print(('[prp-crates] Skipped missing item from Config.ItemsRolled: %s'):format(tostring(itemName)))
        end
    end

    if totalWeight <= 0 then return {}, 0 end

    for _, entry in ipairs(pool) do
        entry.percent = round((entry.weight / totalWeight) * 100, 2)
    end

    return pool, totalWeight
end

local function weightedPick(pool, totalWeight)
    if #pool == 0 or totalWeight <= 0 then return nil end
    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry
        end
    end
    return pool[#pool]
end

local function buildSpinItems(pool, totalWeight, forcedWinner, count)
    local items = {}
    count = count or Config.RollItemCount or 60
    if count < 15 then count = 15 end

    for i = 1, count do
        local pick = weightedPick(pool, totalWeight)
        items[i] = pick
    end

    local winningIndex = math.max(10, math.floor(count * 0.72))
    items[winningIndex] = forcedWinner

    return items, winningIndex
end

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function clearActive(src)
    ActiveRolls[src] = nil
end

local function giveReward(src, reward)
    local Player = getPlayer(src)
    if not Player then return false, 'Player not found' end

    local info = {}
    if reward.rarity then
        info.rarity = reward.rarity
    end

    local added = Player.Functions.AddItem(reward.item, reward.amount or 1, false, info, 'prp-crates reward')
    if added then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[reward.item], 'add', reward.amount or 1)
        return true
    end

    return false, 'Inventory full'
end

QBCore.Functions.CreateUseableItem(Config.CrateItem, function(source, item)
    local src = source
    local Player = getPlayer(src)
    if not Player or not item then return end
    if ActiveRolls[src] then return end

    local pool, totalWeight = buildPool()
    if #pool == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No crate items configured', 'error')
        return
    end

    local removed = Player.Functions.RemoveItem(Config.CrateItem, 1, item.slot, 'prp-crates opened')
    if not removed then return end

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[Config.CrateItem], 'remove', 1)

    local winner = weightedPick(pool, totalWeight)
    if not winner then
        TriggerClientEvent('QBCore:Notify', src, 'Crate failed to roll', 'error')
        return
    end

    local spinItems, winningIndex = buildSpinItems(pool, totalWeight, winner, Config.RollItemCount)
    ActiveRolls[src] = {
        winner = winner,
        claimed = false
    }

    TriggerClientEvent('prp-crates:client:startRoll', src, {
        items = spinItems,
        winner = winner,
        winningIndex = winningIndex,
        duration = Config.RollDuration,
        cardWidth = Config.CardWidth,
        cardGap = Config.CardGap,
        showExactPercent = Config.ShowExactPercent,
        rarityColors = Config.RarityColors
    })
end)

RegisterNetEvent('prp-crates:server:finishRoll', function()
    local src = source
    local active = ActiveRolls[src]
    if not active or active.claimed then return end

    active.claimed = true

    local ok, reason = giveReward(src, active.winner)
    clearActive(src)

    if not ok then
        TriggerClientEvent('QBCore:Notify', src, reason or 'Could not give reward', 'error')
        return
    end
end)

AddEventHandler('playerDropped', function()
    clearActive(source)
end)
