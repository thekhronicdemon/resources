local QBCore = exports['qb-core']:GetCoreObject()

local function GetBenchConfig(benchType)
    return Config.Benches and Config.Benches[benchType]
end

local function GetLevelFromXP(xp)
    local perLevel = tonumber(Config.XPPerLevel) or 100
    if perLevel <= 0 then perLevel = 100 end
    return math.floor((tonumber(xp) or 0) / perLevel) + 1
end

local function GetUnlockCost(recipe)
    return tonumber(recipe.unlockCost) or 1
end

local function GetMetaTable(Player, key)
    local value = Player.PlayerData.metadata and Player.PlayerData.metadata[key]
    if type(value) ~= 'table' then value = {} end
    return value
end

local function GetProgress(Player, xpType)
    local xp = tonumber(Player.PlayerData.metadata[xpType]) or 0
    local level = GetLevelFromXP(xp)
    local totalPoints = level * (tonumber(Config.PointsPerLevel) or 1)
    local spentMeta = GetMetaTable(Player, Config.SkillTreeSpentMetadata or 'prp_crafting_spent')
    local spent = tonumber(spentMeta[xpType]) or 0
    local available = math.max(0, totalPoints - spent)
    return xp, level, totalPoints, spent, available
end

local function IsRecipeUnlocked(Player, bench, recipe)
    if recipe.defaultUnlocked then return true end
    local unlocks = GetMetaTable(Player, Config.SkillTreeMetadata or 'prp_crafting_unlocks')
    local byType = unlocks[bench.xpType]
    return type(byType) == 'table' and byType[recipe.item] == true
end

local function FindRecipe(benchType, itemName)
    local bench = GetBenchConfig(benchType)
    if not bench then return nil, nil end
    for _, recipe in pairs(bench.recipes or {}) do
        if recipe.item == itemName then
            return bench, recipe
        end
    end
    return bench, nil
end

local function IncreasePlayerXP(source, xpGain, xpType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not xpGain or xpGain <= 0 then return end

    if Player.Functions.AddRep then
        Player.Functions.AddRep(xpType, xpGain)
    else
        local current = tonumber(Player.PlayerData.metadata[xpType]) or 0
        Player.Functions.SetMetaData(xpType, current + xpGain)
    end

    TriggerClientEvent('QBCore:Notify', source, Lang:t('notifications.xpGain', { value = xpGain, value2 = xpType }), 'success')
end

local function HasItems(Player, requiredItems)
    for _, req in pairs(requiredItems or {}) do
        local item = Player.Functions.GetItemByName(req.item)
        if not item or (item.amount or 0) < req.amount then
            return false
        end
    end
    return true
end

QBCore.Functions.CreateCallback('prp-crafting:server:getPlayerInventory', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(Player and Player.PlayerData.items or {})
end)

QBCore.Functions.CreateCallback('prp-crafting:server:getSkillData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end

    local unlocks = GetMetaTable(Player, Config.SkillTreeMetadata or 'prp_crafting_unlocks')
    local spent = GetMetaTable(Player, Config.SkillTreeSpentMetadata or 'prp_crafting_spent')
    local progress = {}

    for _, bench in pairs(Config.Benches or {}) do
        local xp, level, totalPoints, spentPoints, availablePoints = GetProgress(Player, bench.xpType)
        progress[bench.xpType] = {
            xp = xp,
            level = level,
            totalPoints = totalPoints,
            spentPoints = spentPoints,
            availablePoints = availablePoints,
            unlocks = type(unlocks[bench.xpType]) == 'table' and unlocks[bench.xpType] or {}
        }
    end

    cb({ progress = progress, spent = spent, unlocks = unlocks })
end)

RegisterNetEvent('prp-crafting:server:unlockRecipe', function(benchType, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bench, recipe = FindRecipe(benchType, itemName)
    if not Player or not bench or not recipe then return end

    if IsRecipeUnlocked(Player, bench, recipe) then
        TriggerClientEvent('QBCore:Notify', src, 'You already unlocked this recipe.', 'error')
        return
    end

    local xp, _, _, spentPoints, availablePoints = GetProgress(Player, bench.xpType)
    local requiredXP = tonumber(recipe.xpRequired) or 0
    local cost = GetUnlockCost(recipe)

    if xp < requiredXP then
        TriggerClientEvent('QBCore:Notify', src, ('You need %s XP before you can unlock this.'):format(requiredXP), 'error')
        return
    end

    if availablePoints < cost then
        TriggerClientEvent('QBCore:Notify', src, ('You need %s crafting point(s).'):format(cost), 'error')
        return
    end

    local unlocks = GetMetaTable(Player, Config.SkillTreeMetadata or 'prp_crafting_unlocks')
    local spent = GetMetaTable(Player, Config.SkillTreeSpentMetadata or 'prp_crafting_spent')

    unlocks[bench.xpType] = unlocks[bench.xpType] or {}
    unlocks[bench.xpType][recipe.item] = true
    spent[bench.xpType] = spentPoints + cost

    Player.Functions.SetMetaData(Config.SkillTreeMetadata or 'prp_crafting_unlocks', unlocks)
    Player.Functions.SetMetaData(Config.SkillTreeSpentMetadata or 'prp_crafting_spent', spent)

    local item = QBCore.Shared.Items[recipe.item]
    TriggerClientEvent('QBCore:Notify', src, ('Unlocked %s.'):format(item and item.label or recipe.item), 'success')
    TriggerClientEvent('prp-crafting:client:refreshSkillTree', src)
end)

RegisterNetEvent('prp-crafting:server:removeMaterials', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Shared.Items[itemName] then return end

    if exports['qb-inventory']:RemoveItem(src, itemName, amount, false, 'prp-crafting:server:removeMaterials') then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    end
end)

RegisterNetEvent('prp-crafting:server:removeCraftingTable', function(benchType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not GetBenchConfig(benchType) then return end

    if exports['qb-inventory']:RemoveItem(src, benchType, 1, false, 'prp-crafting:server:removeCraftingTable') then
        if QBCore.Shared.Items[benchType] then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[benchType], 'remove')
        end
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notifications.tablePlace'), 'success')
    end
end)

RegisterNetEvent('prp-crafting:server:addCraftingTable', function(benchType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not GetBenchConfig(benchType) then return end

    if exports['qb-inventory']:AddItem(src, benchType, 1, false, false, 'prp-crafting:server:addCraftingTable') then
        if QBCore.Shared.Items[benchType] then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[benchType], 'add')
        end
    end
end)

RegisterNetEvent('prp-crafting:server:receiveItem', function(benchType, craftedItem, requiredItems, amountToCraft, xpGain)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bench, recipe = FindRecipe(benchType, craftedItem)
    if not Player or not bench or not recipe or not QBCore.Shared.Items[craftedItem] then return end

    if not IsRecipeUnlocked(Player, bench, recipe) then
        TriggerClientEvent('QBCore:Notify', src, 'You have not unlocked this recipe yet.', 'error')
        return
    end

    if not HasItems(Player, requiredItems) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notifications.notenoughMaterials'), 'error')
        return
    end

    for _, req in ipairs(requiredItems or {}) do
        if exports['qb-inventory']:RemoveItem(src, req.item, req.amount, false, 'prp-crafting:server:receiveItem') then
            if QBCore.Shared.Items[req.item] then
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[req.item], 'remove')
            end
        else
            return
        end
    end

    if exports['qb-inventory']:AddItem(src, craftedItem, amountToCraft, false, false, 'prp-crafting:server:receiveItem') then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[craftedItem], 'add')
        TriggerClientEvent('QBCore:Notify', src, ('You crafted %sx %s'):format(amountToCraft, QBCore.Shared.Items[craftedItem].label), 'success')
        IncreasePlayerXP(src, xpGain, bench.xpType)
    end
end)

CreateThread(function()
    for benchType, _ in pairs(Config.Benches or {}) do
        QBCore.Functions.CreateUseableItem(benchType, function(source)
            TriggerClientEvent('prp-crafting:client:useCraftingTable', source, benchType)
        end)
    end
end)
