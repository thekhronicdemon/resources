local QBCore = exports['qb-core']:GetCoreObject()
local SpawnedBenches = {}
local CurrentBenchType = nil
local LastMode = 'dashboard'

local function Notify(msg, msgType)
    QBCore.Functions.Notify(msg, msgType or 'primary')
end

local function GetBenchConfig(benchType)
    return Config.Benches and Config.Benches[benchType]
end

local function GetCurrentXP(xpType, skillData)
    if skillData and skillData.progress and skillData.progress[xpType] then
        return tonumber(skillData.progress[xpType].xp) or 0
    end
    local PlayerData = QBCore.Functions.GetPlayerData()
    return (PlayerData.metadata and tonumber(PlayerData.metadata[xpType])) or 0
end

local function GetLevelFromXP(xp)
    local perLevel = tonumber(Config.XPPerLevel) or 100
    if perLevel <= 0 then perLevel = 100 end
    return math.floor((tonumber(xp) or 0) / perLevel) + 1
end

local function GetItemAmount(inventory, itemName)
    for _, invItem in pairs(inventory or {}) do
        if invItem and invItem.name == itemName then
            return invItem.amount or invItem.count or 0
        end
    end
    return 0
end

local function HasItems(inventory, requiredItems)
    for _, reqItem in pairs(requiredItems or {}) do
        if GetItemAmount(inventory, reqItem.item) < reqItem.amount then
            return false
        end
    end
    return true
end

local function HasAccess(location)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not location then return true end

    if location.jobs then
        local job = PlayerData.job
        local grade = job and (job.grade.level or job.grade) or 0
        if not job or location.jobs[job.name] == nil or grade < location.jobs[job.name] then
            return false
        end
    end

    if location.gangs then
        local gang = PlayerData.gang
        local grade = gang and (gang.grade.level or gang.grade) or 0
        if not gang or location.gangs[gang.name] == nil or grade < location.gangs[gang.name] then
            return false
        end
    end

    return true
end

local function GetItemData(itemName)
    local shared = QBCore.Shared.Items[itemName]
    return {
        name = itemName,
        label = shared and shared.label or itemName,
        image = Config.ImageBasePath .. (shared and shared.image or 'default.png')
    }
end

local function GetBenchProgress(bench, skillData)
    local progress = skillData and skillData.progress and skillData.progress[bench.xpType]
    local xp = progress and tonumber(progress.xp) or GetCurrentXP(bench.xpType, skillData)
    local level = progress and tonumber(progress.level) or GetLevelFromXP(xp)
    local totalPoints = progress and tonumber(progress.totalPoints) or (level * (tonumber(Config.PointsPerLevel) or 1))
    local spentPoints = progress and tonumber(progress.spentPoints) or 0
    local availablePoints = progress and tonumber(progress.availablePoints) or math.max(0, totalPoints - spentPoints)
    local unlocks = progress and progress.unlocks or {}
    return xp, level, totalPoints, spentPoints, availablePoints, unlocks
end

local function IsUnlocked(recipe, unlocks)
    if recipe.defaultUnlocked then return true end
    return type(unlocks) == 'table' and unlocks[recipe.item] == true
end

local function GetUnlockCost(recipe)
    return tonumber(recipe.unlockCost) or 1
end

local function BuildRecipeData(benchType, inventory, skillData)
    local bench = GetBenchConfig(benchType)
    if not bench then return nil end

    local xp, level, totalPoints, spentPoints, availablePoints, unlocks = GetBenchProgress(bench, skillData)
    local recipes = {}
    local unlockedCount = 0
    local totalRecipes = 0
    local nextUnlock = nil

    for _, recipe in pairs(bench.recipes or {}) do
        totalRecipes = totalRecipes + 1

        local item = GetItemData(recipe.item)
        local unlocked = IsUnlocked(recipe, unlocks)
        local canBuy = not unlocked and xp >= (recipe.xpRequired or 0) and availablePoints >= GetUnlockCost(recipe)
        local canCraft = unlocked and HasItems(inventory, recipe.requiredItems)
        local required = {}

        if unlocked then unlockedCount = unlockedCount + 1 end
        if not unlocked and (not nextUnlock or (recipe.xpRequired or 0) < (nextUnlock.xpRequired or 0)) then
            nextUnlock = { label = item.label, xpRequired = recipe.xpRequired or 0, unlockCost = GetUnlockCost(recipe) }
        end

        for _, req in pairs(recipe.requiredItems or {}) do
            local reqItem = GetItemData(req.item)
            local playerAmount = GetItemAmount(inventory, req.item)
            required[#required + 1] = {
                name = req.item,
                label = reqItem.label,
                image = reqItem.image,
                amount = req.amount,
                playerAmount = playerAmount,
                hasEnough = playerAmount >= req.amount
            }
        end

        recipes[#recipes + 1] = {
            item = recipe.item,
            label = item.label,
            image = item.image,
            xpRequired = recipe.xpRequired or 0,
            unlockCost = GetUnlockCost(recipe),
            xpGain = recipe.xpGain or 0,
            unlocked = unlocked,
            canBuy = canBuy,
            canCraft = canCraft,
            requiredItems = required
        }
    end

    table.sort(recipes, function(a, b)
        if a.unlocked ~= b.unlocked then return a.unlocked end
        if a.canBuy ~= b.canBuy then return a.canBuy end
        if a.xpRequired ~= b.xpRequired then return a.xpRequired < b.xpRequired end
        return a.unlockCost < b.unlockCost
    end)

    return {
        benchType = benchType,
        label = bench.label or benchType,
        xpType = bench.xpType,
        xp = xp,
        level = level,
        xpPerLevel = tonumber(Config.XPPerLevel) or 100,
        totalPoints = totalPoints,
        spentPoints = spentPoints,
        availablePoints = availablePoints,
        unlockedCount = unlockedCount,
        totalRecipes = totalRecipes,
        nextUnlock = nextUnlock,
        recipes = recipes
    }
end

local function BuildDashboardData(skillData, inventory)
    local benches = {}

    for benchType, bench in pairs(Config.Benches or {}) do
        local xp, level, totalPoints, spentPoints, availablePoints, unlocks = GetBenchProgress(bench, skillData)
        local unlocked = 0
        local total = 0
        local nextUnlock = nil
        local tree = {}

        for _, recipe in pairs(bench.recipes or {}) do
            total = total + 1
            local item = GetItemData(recipe.item)
            local isUnlocked = IsUnlocked(recipe, unlocks)
            local cost = GetUnlockCost(recipe)
            local required = {}

            for _, req in pairs(recipe.requiredItems or {}) do
                local reqItem = GetItemData(req.item)
                local playerAmount = GetItemAmount(inventory, req.item)
                required[#required + 1] = {
                    name = req.item,
                    label = reqItem.label,
                    image = reqItem.image,
                    amount = req.amount,
                    playerAmount = playerAmount,
                    hasEnough = playerAmount >= req.amount
                }
            end

            local node = {
                item = recipe.item,
                label = item.label,
                image = item.image,
                xpRequired = recipe.xpRequired or 0,
                unlockCost = cost,
                xpGain = recipe.xpGain or 0,
                unlocked = isUnlocked,
                canBuy = (not isUnlocked) and xp >= (recipe.xpRequired or 0) and availablePoints >= cost,
                requiredItems = required
            }
            tree[#tree + 1] = node

            if isUnlocked then
                unlocked = unlocked + 1
            elseif not nextUnlock or (recipe.xpRequired or 0) < nextUnlock.xpRequired then
                nextUnlock = { label = item.label, xpRequired = recipe.xpRequired or 0, unlockCost = cost }
            end
        end

        table.sort(tree, function(a, b)
            if a.unlocked ~= b.unlocked then return a.unlocked end
            if a.canBuy ~= b.canBuy then return a.canBuy end
            if a.xpRequired ~= b.xpRequired then return a.xpRequired < b.xpRequired end
            return a.unlockCost < b.unlockCost
        end)

        benches[#benches + 1] = {
            benchType = benchType,
            label = bench.label or benchType,
            xp = xp,
            level = level,
            xpPerLevel = tonumber(Config.XPPerLevel) or 100,
            totalPoints = totalPoints,
            spentPoints = spentPoints,
            availablePoints = availablePoints,
            unlockedCount = unlocked,
            totalRecipes = total,
            nextUnlock = nextUnlock,
            tree = tree
        }
    end

    table.sort(benches, function(a, b) return a.label < b.label end)
    return benches
end

local function OpenNui(mode, benchType)
    CurrentBenchType = benchType
    LastMode = mode or 'dashboard'

    QBCore.Functions.TriggerCallback('prp-crafting:server:getPlayerInventory', function(inventory)
        QBCore.Functions.TriggerCallback('prp-crafting:server:getSkillData', function(skillData)
            local payload = {
                mode = LastMode,
                dashboard = BuildDashboardData(skillData or {}, inventory or {}),
                bench = benchType and BuildRecipeData(benchType, inventory or {}, skillData or {}) or nil
            }

            SetNuiFocus(true, true)
            Wait(50)
            SendNUIMessage({ action = 'open', data = payload })
            Wait(100)
            SendNUIMessage({ action = 'open', data = payload })
        end)
    end)
end

function OpenCraftingMenu(benchType)
    OpenNui('bench', benchType)
end

local function OpenCraftingStatusMenu()
    OpenNui('dashboard', nil)
end

exports('OpenCraftingMenu', OpenCraftingMenu)
exports('OpenCraftingStatusMenu', OpenCraftingStatusMenu)
RegisterNetEvent('prp-crafting:client:openMenu', OpenCraftingMenu)
RegisterNetEvent('prp-crafting:client:openStatus', OpenCraftingStatusMenu)
RegisterNetEvent('prp-crafting:client:refreshSkillTree', function()
    OpenNui(LastMode or 'dashboard', CurrentBenchType)
end)

RegisterCommand(Config.CraftingCommand or 'crafting', function()
    OpenCraftingStatusMenu()
end, false)

RegisterNUICallback('close', function(_, cb)
    CurrentBenchType = nil
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('openBench', function(data, cb)
    local benchType = data and data.benchType
    if benchType and GetBenchConfig(benchType) then
        OpenNui('bench', benchType)
    end
    cb({ ok = true })
end)

RegisterNUICallback('backDashboard', function(_, cb)
    OpenNui('dashboard', nil)
    cb({ ok = true })
end)

RegisterNUICallback('unlockRecipe', function(data, cb)
    local benchType = data and data.benchType
    local item = data and data.item
    if benchType and item then
        TriggerServerEvent('prp-crafting:server:unlockRecipe', benchType, item)
    end
    cb({ ok = true })
end)

RegisterNUICallback('craft', function(data, cb)
    local benchType = data and data.benchType or CurrentBenchType
    local itemName = data and data.item
    local amount = tonumber(data and data.amount) or 1
    local bench = GetBenchConfig(benchType)

    if not bench or not itemName or amount <= 0 then
        cb({ ok = false })
        return
    end

    local selectedRecipe
    for _, recipe in pairs(bench.recipes or {}) do
        if recipe.item == itemName then
            selectedRecipe = recipe
            break
        end
    end

    if not selectedRecipe then
        cb({ ok = false })
        return
    end

    QBCore.Functions.TriggerCallback('prp-crafting:server:getSkillData', function(skillData)
        local _, _, _, _, _, unlocks = GetBenchProgress(bench, skillData or {})
        if not IsUnlocked(selectedRecipe, unlocks) then
            Notify('You have not unlocked this recipe yet.', 'error')
            cb({ ok = false })
            return
        end

        local multipliedItems = {}
        for _, reqItem in ipairs(selectedRecipe.requiredItems or {}) do
            multipliedItems[#multipliedItems + 1] = { item = reqItem.item, amount = reqItem.amount * amount }
        end

        SendNUIMessage({ action = 'setBusy', busy = true })

        QBCore.Functions.TriggerCallback('prp-crafting:server:getPlayerInventory', function(inventory)
            if not HasItems(inventory, multipliedItems) then
                SendNUIMessage({ action = 'setBusy', busy = false })
                Notify(Lang:t('notifications.notenoughMaterials'), 'error')
                cb({ ok = false })
                return
            end

            local shared = QBCore.Shared.Items[selectedRecipe.item]
            local label = shared and shared.label or selectedRecipe.item

            SetNuiFocus(false, false)

            QBCore.Functions.Progressbar('prp_crafting_item', 'Crafting ' .. label, (math.random(2000, 5000) * amount), false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = 'mini@repair',
                anim = 'fixing_a_player',
                flags = 16,
            }, {}, {}, function()
                TriggerServerEvent('prp-crafting:server:receiveItem', benchType, selectedRecipe.item, multipliedItems, amount, selectedRecipe.xpGain or 0)
                Wait(300)
                SendNUIMessage({ action = 'setBusy', busy = false })
                OpenNui('bench', benchType)
            end, function()
                SendNUIMessage({ action = 'setBusy', busy = false })
                SetNuiFocus(true, true)
                Notify(Lang:t('notifications.craftingCancelled'), 'error')
            end)

            cb({ ok = true })
        end)
    end)
end)

local function PickupBench(benchType)
    local ped = PlayerPedId()
    local bench = GetBenchConfig(benchType)
    if not bench then return end

    local entity = GetClosestObjectOfType(GetEntityCoords(ped), 3.0, bench.object, false, false, false)
    if DoesEntityExist(entity) then
        exports['qb-target']:RemoveTargetEntity(entity)
        DeleteEntity(entity)
        TriggerServerEvent('prp-crafting:server:addCraftingTable', benchType)
        Notify(Lang:t('notifications.pickupBench'), 'success')
    end
end

local function AddBenchTarget(entity, benchType, canPickup, location)
    local bench = GetBenchConfig(benchType)
    if not bench then return end

    local options = {
        {
            icon = 'fas fa-tools',
            label = location and (location.label or bench.label) or (bench.label or Lang:t('menus.header')),
            action = function()
                if not HasAccess(location) then
                    Notify(Lang:t('notifications.noAccess'), 'error')
                    return
                end
                OpenCraftingMenu(benchType)
            end
        }
    }

    if canPickup then
        options[#options + 1] = {
            icon = 'fas fa-hand-rock',
            label = Lang:t('menus.pickupworkBench'),
            action = function()
                PickupBench(benchType)
            end
        }
    end

    exports['qb-target']:AddTargetEntity(entity, { options = options, distance = 2.5 })
end

RegisterNetEvent('prp-crafting:client:useCraftingTable', function(benchType)
    local bench = GetBenchConfig(benchType)
    if not bench then return end

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
    local heading = GetEntityHeading(ped) - 90.0
    if heading < 0 then heading = 360.0 + heading end

    local workbench = CreateObject(bench.object, coords.x, coords.y, coords.z, true, true, true)
    SetEntityHeading(workbench, heading)
    PlaceObjectOnGroundProperly(workbench)
    FreezeEntityPosition(workbench, true)

    TriggerServerEvent('prp-crafting:server:removeCraftingTable', benchType)
    AddBenchTarget(workbench, benchType, true, nil)
end)

CreateThread(function()
    if not Config.UsePermanentBenches then return end

    for _, location in pairs(Config.Locations or {}) do
        local bench = GetBenchConfig(location.benchType)
        if bench then
            local coords = location.coords
            local entity

            if location.spawnObject then
                entity = CreateObject(bench.object, coords.x, coords.y, coords.z - 1.0, false, false, false)
                SetEntityHeading(entity, coords.w or 0.0)
                PlaceObjectOnGroundProperly(entity)
                FreezeEntityPosition(entity, true)
                SpawnedBenches[#SpawnedBenches + 1] = entity
                AddBenchTarget(entity, location.benchType, false, location)
            else
                exports['qb-target']:AddBoxZone(location.id, vector3(coords.x, coords.y, coords.z), location.length or 1.5, location.width or 1.5, {
                    name = location.id,
                    heading = coords.w or 0.0,
                    debugPoly = Config.Debug,
                    minZ = coords.z - 1.0,
                    maxZ = coords.z + 1.0,
                }, {
                    options = {
                        {
                            icon = 'fas fa-tools',
                            label = location.label or bench.label or Lang:t('menus.header'),
                            action = function()
                                if not HasAccess(location) then
                                    Notify(Lang:t('notifications.noAccess'), 'error')
                                    return
                                end
                                OpenCraftingMenu(location.benchType)
                            end
                        }
                    },
                    distance = 2.5
                })
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, entity in pairs(SpawnedBenches) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)
