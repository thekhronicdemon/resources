local QBCore = exports[Config.CoreName]:GetCoreObject()
local activeMining = {}

local function GetItemBySlot(Player, slot)
    slot = tonumber(slot)
    if not slot then return nil end
    return Player.PlayerData.items[slot]
end

local function GetDurability(item)
    local info = item.info or item.metadata or {}
    local durability = tonumber(info.durability or info.health or info.uses)
    if not durability then durability = Config.DefaultPickaxeHealth end
    return durability
end

local function SetDurability(Player, slot, durability)
    local item = Player.PlayerData.items[slot]
    if not item then return false end

    item.info = item.info or {}
    item.info.durability = durability
    item.info.health = durability
    item.info.description = ('Health: %s/%s'):format(durability, Config.DefaultPickaxeHealth)

    Player.Functions.SetInventory(Player.PlayerData.items)
    return true
end

local function PickReward()
    local total = 0
    for _, reward in ipairs(Config.Rewards) do
        total = total + reward.chance
    end

    local roll = math.random(1, total)
    local current = 0

    for _, reward in ipairs(Config.Rewards) do
        current = current + reward.chance
        if roll <= current then
            return reward.item, math.random(reward.min, reward.max)
        end
    end

    local fallback = Config.Rewards[1]
    return fallback.item, math.random(fallback.min, fallback.max)
end

local function IsNearMiningSpot(src, index)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local spot = Config.MiningSpots[index]
    if not spot then return false end

    local coords = GetEntityCoords(ped)
    return #(coords - spot) <= 4.0
end

QBCore.Functions.CreateUseableItem(Config.PickaxeItem, function(source, item)
    local src = source
    if not item or not item.slot then
        Config.Notify(src, 'This pickaxe has invalid item data.', 'error')
        return
    end

    local durability = GetDurability(item)
    if durability <= 0 then
        Config.Notify(src, 'This pickaxe is broken.', 'error')
        return
    end

    TriggerClientEvent('prp-mining:client:TogglePickaxe', src, item.slot)
end)

RegisterNetEvent('prp-mining:server:StartMining', function(index, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    index = tonumber(index)
    slot = tonumber(slot)

    if not IsNearMiningSpot(src, index) then
        TriggerClientEvent('prp-mining:client:MiningRejected', src, 'You are too far from the mining spot.')
        return
    end

    local item = GetItemBySlot(Player, slot)
    if not item or item.name ~= Config.PickaxeItem then
        TriggerClientEvent('prp-mining:client:ForceUnequipPickaxe', src)
        TriggerClientEvent('prp-mining:client:MiningRejected', src, 'You need a pickaxe equipped.')
        return
    end

    local durability = GetDurability(item)
    if durability <= 0 then
        TriggerClientEvent('prp-mining:client:ForceUnequipPickaxe', src)
        TriggerClientEvent('prp-mining:client:MiningRejected', src, 'Your pickaxe is broken.')
        return
    end

    local token = ('%s:%s:%s'):format(src, os.time(), math.random(100000, 999999))
    activeMining[src] = {
        token = token,
        slot = slot,
        index = index,
        started = os.time()
    }

    TriggerClientEvent('prp-mining:client:StartMiningAnim', src, index, token)
end)

RegisterNetEvent('prp-mining:server:FinishMining', function(token, completed)
    local src = source
    local miningData = activeMining[src]
    activeMining[src] = nil

    if not miningData or miningData.token ~= token then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not completed then return end

    if os.time() - miningData.started < 8 then
        -- Basic anti-spam check. Client mining time is 10 seconds.
        return
    end

    if not IsNearMiningSpot(src, miningData.index) then
        Config.Notify(src, 'You moved too far away.', 'error')
        return
    end

    local item = GetItemBySlot(Player, miningData.slot)
    if not item or item.name ~= Config.PickaxeItem then
        TriggerClientEvent('prp-mining:client:ForceUnequipPickaxe', src)
        Config.Notify(src, 'Your pickaxe is missing.', 'error')
        return
    end

    local durability = GetDurability(item)
    local damage = math.random(Config.PickaxeDamage.min, Config.PickaxeDamage.max)
    local newDurability = math.max(0, durability - damage)

    local rewardItem, amount = PickReward()
    Player.Functions.AddItem(rewardItem, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[rewardItem], 'add', amount)

    if newDurability <= 0 and Config.DestroyPickaxeAtZero then
        Player.Functions.RemoveItem(Config.PickaxeItem, 1, miningData.slot)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.PickaxeItem], 'remove', 1)
        TriggerClientEvent('prp-mining:client:ForceUnequipPickaxe', src)
        Config.Notify(src, ('You mined %sx %s. Your pickaxe broke.'):format(amount, rewardItem), 'success')
    else
        SetDurability(Player, miningData.slot, newDurability)
        Config.Notify(src, ('You mined %sx %s. Pickaxe health: %s/%s'):format(amount, rewardItem, newDurability, Config.DefaultPickaxeHealth), 'success')
    end
end)

AddEventHandler('playerDropped', function()
    activeMining[source] = nil
end)
