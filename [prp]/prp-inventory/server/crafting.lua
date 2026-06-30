local QBCore = exports['qb-core']:GetCoreObject()

local function GetItemLabel(itemName)
    local item = itemName and QBCore.Shared.Items[itemName:lower()]
    return item and item.label or itemName
end

local function GetItemImage(itemName)
    local item = itemName and QBCore.Shared.Items[itemName:lower()]
    return item and item.image or (itemName and (itemName .. '.png') or 'default.png')
end

local function GetRecipe(recipeId)
    for _, recipe in ipairs((Config.Crafting or {}).Recipes or {}) do
        if recipe.id == recipeId and recipe.enabled ~= false then
            return recipe
        end
    end
    return nil
end

local function NormalizeItemName(itemName)
    if type(itemName) ~= 'string' then return nil end
    itemName = itemName:lower():gsub('%s+', '')
    if itemName == '' then return nil end
    return itemName
end

local function GetGridItemName(gridItem)
    if type(gridItem) == 'table' then
        return NormalizeItemName(gridItem.name or gridItem.item)
    end

    return NormalizeItemName(gridItem)
end

local function GetGridItemAmount(gridItem)
    if type(gridItem) ~= 'table' then return 1 end

    local amount = math.floor(tonumber(gridItem.amount) or 1)
    if amount < 1 then return 1 end
    return amount
end

local function BuildCountMap(items)
    local counts = {}
    for _, gridItem in ipairs(items or {}) do
        local itemName = GetGridItemName(gridItem)
        if itemName then
            counts[itemName] = (counts[itemName] or 0) + GetGridItemAmount(gridItem)
        end
    end
    return counts
end

local function CountRecipeGridItems(recipe)
    local required = {}
    if (recipe.method or Config.Crafting.DefaultMethod or 'shapeless') == 'shaped' and type(recipe.pattern) == 'table' then
        for _, itemName in ipairs(recipe.pattern) do
            itemName = NormalizeItemName(itemName)
            if itemName then required[itemName] = (required[itemName] or 0) + 1 end
        end
    else
        for _, ingredient in ipairs(recipe.ingredients or {}) do
            local itemName = NormalizeItemName(ingredient.item)
            if itemName then required[itemName] = (required[itemName] or 0) + 1 end
        end
    end
    return required
end

local function CountKeys(tbl)
    local total = 0
    for _ in pairs(tbl or {}) do total = total + 1 end
    return total
end

local function ShapelessGridMatches(recipe, gridItems)
    local expected = CountRecipeGridItems(recipe)
    local actual = BuildCountMap(gridItems)
    if CountKeys(expected) ~= CountKeys(actual) then return false end

    for itemName, count in pairs(expected) do
        if actual[itemName] ~= count then return false end
    end
    return true
end

local function ShapedGridMatches(recipe, gridItems)
    if type(recipe.pattern) ~= 'table' then return false end
    local gridSize = tonumber((Config.Crafting or {}).GridSize) or 9

    for i = 1, gridSize do
        local expected = NormalizeItemName(recipe.pattern[i])
        local actual = GetGridItemName(gridItems and gridItems[i])
        if expected ~= actual then return false end
    end
    return true
end

local function GridMatchesRecipe(recipe, gridItems)
    if not recipe then return false end
    if (recipe.method or Config.Crafting.DefaultMethod or 'shapeless') == 'shaped' then
        return ShapedGridMatches(recipe, gridItems)
    end
    return ShapelessGridMatches(recipe, gridItems)
end

local function GetPlayerItemAmount(Player, itemName)
    itemName = NormalizeItemName(itemName)
    if not Player or not itemName then return 0 end

    local total = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name and item.name:lower() == itemName then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function HasMaterials(Player, recipe)
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local itemName = NormalizeItemName(ingredient.item)
        local amount = tonumber(ingredient.amount) or 1
        if GetPlayerItemAmount(Player, itemName) < amount then
            return false, itemName, amount
        end
    end
    return true
end

local function RemoveMaterialFromPlayer(src, Player, itemName, amount)
    itemName = NormalizeItemName(itemName)
    amount = tonumber(amount) or 1
    if not itemName or amount <= 0 then return true end

    local remaining = amount
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name and item.name:lower() == itemName and remaining > 0 then
            local take = math.min(remaining, tonumber(item.amount) or 0)
            if take > 0 then
                if not RemoveItem(src, item.name, take, item.slot, 'inventory crafting') then
                    return false
                end
                remaining = remaining - take
            end
        end
    end

    return remaining <= 0
end

local function AddCraftingXP(src, Player, recipe)
    local xpType = recipe.xpType
    local xpGain = tonumber(recipe.xpGain) or 0
    if not xpType or xpGain <= 0 then return end

    if Player.Functions.AddRep then
        Player.Functions.AddRep(xpType, xpGain)
    else
        local current = tonumber((Player.PlayerData.metadata or {})[xpType]) or 0
        Player.Functions.SetMetaData(xpType, current + xpGain)
    end

    TriggerClientEvent('QBCore:Notify', src, ('Gained %s crafting XP.'):format(xpGain), 'success')
end


local function GetCraftingBlueprints(Player)
    local metadata = Player and Player.PlayerData and Player.PlayerData.metadata or {}
    local blueprints = metadata.crafting_blueprints or metadata.craftingBlueprints or {}
    if type(blueprints) ~= 'table' then blueprints = {} end
    return blueprints
end

local function IsRecipeKnown(Player, recipe)
    if not recipe or not recipe.id then return false end

    local defaultKnown = Config.Crafting.DefaultKnownRecipes or {}
    if defaultKnown[recipe.id] == true then
        return true
    end

    -- Only allow recipe.known/defaultKnown for recipes that are NOT blueprint locked.
    if not recipe.blueprint and (recipe.known == true or recipe.defaultKnown == true) then
        return true
    end

    local blueprints = GetCraftingBlueprints(Player)
    return blueprints[recipe.id] == true
end

local function LearnCraftingRecipe(src, Player, recipeId, removeItemName, removeSlot)
    recipeId = NormalizeItemName(recipeId)
    if not recipeId then return false, 'Invalid blueprint.' end

    local recipe = GetRecipe(recipeId)
    if not recipe then return false, 'This blueprint does not match any recipe.' end

    local blueprints = GetCraftingBlueprints(Player)
    if IsRecipeKnown(Player, recipe) or blueprints[recipeId] == true then
        return false, 'You already know this recipe.'
    end

    if removeItemName then
        local removed = false
        if RemoveItem then
            removed = RemoveItem(src, removeItemName, 1, removeSlot or false, 'learned crafting blueprint')
        else
            removed = Player.Functions.RemoveItem(removeItemName, 1, removeSlot or false)
        end
        if not removed then return false, 'Could not use blueprint.' end
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[removeItemName], 'remove', 1)
    end

    blueprints[recipeId] = true
    Player.Functions.SetMetaData('crafting_blueprints', blueprints)
    return true, ('Learned recipe: %s'):format(GetItemLabel((recipe.output and recipe.output.item) or recipe.id))
end

local function BuildRecipePayload(recipe)
    local outputItem = recipe.output or {}
    local outputName = outputItem.item or recipe.item or recipe.id
    local ingredients = {}

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local itemName = NormalizeItemName(ingredient.item)
        ingredients[#ingredients + 1] = {
            item = itemName,
            label = GetItemLabel(itemName),
            image = GetItemImage(itemName),
            amount = tonumber(ingredient.amount) or 1,
        }
    end

    return {
        id = recipe.id,
        category = recipe.category or 'General',
        description = recipe.description or 'Recipe learned',
        blueprint = recipe.blueprint or false,
        ingredientsHidden = recipe.hideIngredients ~= false,
        method = recipe.method or Config.Crafting.DefaultMethod or 'shapeless',
        pattern = recipe.pattern,
        output = {
            item = outputName,
            label = GetItemLabel(outputName),
            image = GetItemImage(outputName),
            amount = tonumber(outputItem.amount) or tonumber(recipe.amount) or 1,
        },
        ingredients = ingredients,
        known = true,
    }
end

QBCore.Functions.CreateCallback('prp-inventory:server:getCraftingData', function(source, cb)
    if not (Config.Crafting and Config.Crafting.Enabled) then
        cb({ success = false, message = 'Crafting is disabled.', recipes = {} })
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.', recipes = {} })
        return
    end

    local recipes = {}
    for _, recipe in ipairs(Config.Crafting.Recipes or {}) do
        if recipe.enabled ~= false and IsRecipeKnown(Player, recipe) then
            recipes[#recipes + 1] = BuildRecipePayload(recipe)
        end
    end

    cb({
        success = true,
        gridSize = tonumber(Config.Crafting.GridSize) or 9,
        recipes = recipes,
    })
end)

QBCore.Functions.CreateCallback('prp-inventory:server:craftGridRecipe', function(source, cb, data)
    local src = source
    if not (Config.Crafting and Config.Crafting.Enabled) then
        cb({ success = false, message = 'Crafting is disabled.' })
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    local recipe = GetRecipe(data and data.recipeId)
    if not recipe then
        cb({ success = false, message = 'Unknown recipe.' })
        return
    end

    if not IsRecipeKnown(Player, recipe) then
        cb({ success = false, message = 'You have not learned this blueprint.' })
        return
    end

    local gridItems = data and data.grid or {}
    if not GridMatchesRecipe(recipe, gridItems) then
        cb({ success = false, message = 'Those items do not match the recipe.' })
        return
    end

    local output = recipe.output or {}
    local outputName = NormalizeItemName(output.item or recipe.item or recipe.id)
    local outputAmount = tonumber(output.amount) or tonumber(recipe.amount) or 1
    if not outputName or not QBCore.Shared.Items[outputName] then
        cb({ success = false, message = 'Crafting output is invalid.' })
        return
    end

    local hasMaterials, missingItem, missingAmount = HasMaterials(Player, recipe)
    if not hasMaterials then
        cb({ success = false, message = ('Need %sx %s.'):format(missingAmount, GetItemLabel(missingItem)) })
        return
    end

    if CanAddItem and not CanAddItem(src, outputName, outputAmount) then
        cb({ success = false, message = 'You do not have room for the crafted item.' })
        return
    end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if not RemoveMaterialFromPlayer(src, Player, ingredient.item, ingredient.amount) then
            cb({ success = false, message = 'Could not remove crafting materials.' })
            return
        end
    end

    if not AddItem(src, outputName, outputAmount, false, output.info or {}, 'inventory crafting') then
        cb({ success = false, message = 'Could not add crafted item.' })
        return
    end

    AddCraftingXP(src, Player, recipe)

    local itemInfo = QBCore.Shared.Items[outputName]
    TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'add', outputAmount)
    TriggerClientEvent('QBCore:Notify', src, ('Crafted %sx %s.'):format(outputAmount, itemInfo.label), 'success')

    cb({
        success = true,
        message = ('Crafted %sx %s.'):format(outputAmount, itemInfo.label),
        inventory = Player.PlayerData.items,
    })
end)


CreateThread(function()
    local blueprintItems = Config.Crafting and Config.Crafting.BlueprintItems or {}
    for itemName, recipeId in pairs(blueprintItems) do
        local normalizedItem = NormalizeItemName(itemName)
        local normalizedRecipe = NormalizeItemName(recipeId)
        if normalizedItem and normalizedRecipe and QBCore.Shared.Items[normalizedItem] then
            QBCore.Functions.CreateUseableItem(normalizedItem, function(source, item)
                local Player = QBCore.Functions.GetPlayer(source)
                if not Player then return end

                local ok, msg = LearnCraftingRecipe(source, Player, normalizedRecipe, normalizedItem, item and item.slot)
                TriggerClientEvent('QBCore:Notify', source, msg, ok and 'success' or 'error')
            end)
        end
    end
end)

RegisterNetEvent('prp-inventory:server:learnBlueprint', function(recipeId, itemName, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, msg = LearnCraftingRecipe(src, Player, recipeId, itemName and NormalizeItemName(itemName), slot)
    TriggerClientEvent('QBCore:Notify', src, msg, ok and 'success' or 'error')
end)
