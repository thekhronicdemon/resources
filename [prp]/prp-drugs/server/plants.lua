local QBCore = exports['qb-core']:GetCoreObject()
local Plants = {}

local function notify(src, message, kind)
    exports['prp-drugs']:Notify(src, message, kind)
end

local function serialisePlant(row)
    return {
        id = tonumber(row.id),
        owner = row.owner,
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        heading = tonumber(row.heading),
        stage = row.stage,
        dirt_grade = row.dirt_grade,
        dirt_quality = tonumber(row.dirt_quality) or 0,
        seed_quality = tonumber(row.seed_quality) or 0,
        strain = row.strain,
        water_count = tonumber(row.water_count) or 0,
        last_watered = tonumber(row.last_watered) or 0,
        fertilized = row.fertilized == 1 or row.fertilized == true,
        planted_at = tonumber(row.planted_at) or 0,
        ready_at = tonumber(row.ready_at) or 0,
        yield_quality = tonumber(row.yield_quality) or 0,
        created_at = tonumber(row.created_at) or os.time(),
    }
end

local function savePlant(plant)
    MySQL.update.await([[
        UPDATE prp_drug_plants SET
            stage = ?, dirt_grade = ?, dirt_quality = ?, seed_quality = ?, strain = ?,
            water_count = ?, last_watered = ?, fertilized = ?, planted_at = ?,
            ready_at = ?, yield_quality = ?
        WHERE id = ?
    ]], {
        plant.stage, plant.dirt_grade, plant.dirt_quality, plant.seed_quality, plant.strain,
        plant.water_count, plant.last_watered, plant.fertilized and 1 or 0, plant.planted_at,
        plant.ready_at, plant.yield_quality, plant.id
    })
end

local function broadcastPlant(plant)
    TriggerClientEvent('prp-drugs:client:updatePlant', -1, plant)
end

local function validDistance(src, plant)
    if not plant then return false end
    local coords = GetEntityCoords(GetPlayerPed(src))
    return #(coords - vector3(plant.x, plant.y, plant.z)) <= Config.ServerPlantDistance
end

local function calculateYieldQuality(plant)
    local dirt = Config.DirtGrades[plant.dirt_grade] or Config.DirtGrades.D
    local quality = (plant.seed_quality * 0.65) + (plant.dirt_quality * 0.35)

    if plant.fertilized then quality = quality + Config.Harvest.FertilizerQualityBonus end

    local missing = math.max(0, Config.MinimumWaters - plant.water_count)
    quality = quality * (1.0 - (missing * Config.Harvest.UnderWaterPenaltyPerMissingWater))

    if plant.water_count >= Config.IdealWaters then quality = quality + 1.5 end
    return PRPDrugs.Round(PRPDrugs.Clamp(quality, 1, 100), 1)
end

local function calculateBudAmount(plant)
    local dirt = Config.DirtGrades[plant.dirt_grade] or Config.DirtGrades.D
    local qualityRatio = PRPDrugs.Clamp(plant.yield_quality, 1, 100) / 100
    local waterRatio = PRPDrugs.Clamp(plant.water_count / Config.IdealWaters, 0.25, 1.0)
    local multiplier = dirt.yieldMultiplier * waterRatio
    if plant.fertilized then multiplier = multiplier + Config.Harvest.FertilizerYieldBonus end
    if plant.water_count >= Config.IdealWaters then multiplier = multiplier + Config.Harvest.PerfectWaterBonus end

    local range = Config.Harvest.MaximumBuds - Config.Harvest.MinimumBuds
    local amount = Config.Harvest.MinimumBuds + math.floor(range * qualityRatio * multiplier)
    return math.floor(PRPDrugs.Clamp(amount, Config.Harvest.MinimumBuds, Config.Harvest.MaximumBuds))
end

MySQL.ready(function()
    local rows = MySQL.query.await('SELECT * FROM prp_drug_plants')
    for _, row in ipairs(rows) do
        local plant = serialisePlant(row)
        Plants[plant.id] = plant
    end
    print(('[prp-drugs] Loaded %s persistent plants.'):format(#rows))
end)

RegisterNetEvent('prp-drugs:server:requestPlants', function()
    local list = {}
    for _, plant in pairs(Plants) do list[#list + 1] = plant end
    TriggerClientEvent('prp-drugs:client:syncPlants', source, list)
end)

RegisterNetEvent('prp-drugs:server:requestPlantStatus', function(id)
    local src = source
    local plant = Plants[tonumber(id)]
    if not validDistance(src, plant) then return end
    TriggerClientEvent('prp-drugs:client:showPlantStatus', src, plant)
end)

RegisterNetEvent('prp-drugs:server:createPot', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local proposed = vector3(tonumber(data.x) or 0.0, tonumber(data.y) or 0.0, tonumber(data.z) or 0.0)
    if #(coords - proposed) > 4.0 then return end

    local count = 0
    for _, plant in pairs(Plants) do
        if plant.owner == Player.PlayerData.citizenid then count = count + 1 end
        if #(proposed - vector3(plant.x, plant.y, plant.z)) < 1.0 then
            return notify(src, 'Another plant is too close.', 'error')
        end
    end
    if count >= Config.MaxPlantsPerPlayer then
        return notify(src, ('You can only have %s active plants.'):format(Config.MaxPlantsPerPlayer), 'error')
    end

    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.PlantPot, 1, false, 'prp-drugs-place-pot') then
        return notify(src, 'You need a plant pot.', 'error')
    end

    local now = os.time()
    local id = MySQL.insert.await([[
        INSERT INTO prp_drug_plants
        (owner, x, y, z, heading, stage, water_count, fertilized, created_at)
        VALUES (?, ?, ?, ?, ?, 'pot', 0, 0, ?)
    ]], {
        Player.PlayerData.citizenid, proposed.x, proposed.y, proposed.z,
        tonumber(data.heading) or 0.0, now
    })

    local plant = {
        id = id, owner = Player.PlayerData.citizenid,
        x = proposed.x, y = proposed.y, z = proposed.z,
        heading = tonumber(data.heading) or 0.0,
        stage = 'pot', water_count = 0, fertilized = false, created_at = now
    }
    Plants[id] = plant
    broadcastPlant(plant)
    notify(src, 'Plant pot placed.', 'success')
end)

RegisterNetEvent('prp-drugs:server:addDirt', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plant = Plants[tonumber(id)]
    if not Player or not validDistance(src, plant) or plant.stage ~= 'pot' then return end

    local selectedItem, selectedGrade
    for _, grade in ipairs({'A', 'B', 'C', 'D'}) do
        local item = exports['prp-drugs']:GetItemByName(Player, Config.DirtGrades[grade].item)
        if item then selectedItem, selectedGrade = item, grade break end
    end
    if not selectedItem then return notify(src, 'You need graded dirt.', 'error') end

    local info = PRPDrugs.DecodeInfo(selectedItem)
    local quality = tonumber(info.quality)
    if not quality then
        local gradeConfig = Config.DirtGrades[selectedGrade]
        quality = math.random(gradeConfig.minQuality, gradeConfig.maxQuality)
    end

    if not exports['prp-drugs']:RemoveItem(Player, selectedItem.name, 1, selectedItem.slot, 'prp-drugs-add-dirt') then return end
    plant.stage = 'dirt'
    plant.dirt_grade = selectedGrade
    plant.dirt_quality = PRPDrugs.Clamp(quality, 1, 100)
    savePlant(plant)
    broadcastPlant(plant)
    notify(src, ('Added Class %s dirt (%.1f%%).'):format(selectedGrade, plant.dirt_quality), 'success')
end)

RegisterNetEvent('prp-drugs:server:addSeed', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plant = Plants[tonumber(id)]
    if not Player or not validDistance(src, plant) or plant.stage ~= 'dirt' then return end

    local seed = exports['prp-drugs']:GetItemByName(Player, Config.Items.Seed)
    if not seed then return notify(src, 'You need a weed seed.', 'error') end

    local info = PRPDrugs.DecodeInfo(seed)
    local quality = tonumber(info.quality) or math.random(50, 85)
    quality = PRPDrugs.Clamp(quality, 1, 100)

    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.Seed, 1, seed.slot, 'prp-drugs-plant-seed') then return end

    local now = os.time()
    plant.stage = 'growing'
    plant.seed_quality = quality
    plant.strain = PRPDrugs.GetStrain(quality)
    plant.water_count = 0
    plant.last_watered = 0
    plant.fertilized = false
    plant.planted_at = now
    plant.ready_at = now + Config.GrowTimeSeconds
    plant.yield_quality = 0
    savePlant(plant)
    broadcastPlant(plant)
    notify(src, ('Planted a %s seed with %.1f%% genetics.'):format(plant.strain, quality), 'success')
end)

RegisterNetEvent('prp-drugs:server:waterPlant', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plant = Plants[tonumber(id)]
    if not Player or not validDistance(src, plant) or plant.stage ~= 'growing' then return end

    local now = os.time()
    if now - (plant.last_watered or 0) < Config.WaterCooldownSeconds then
        return notify(src, 'The soil is still wet. Water it again later.', 'error')
    end
    if plant.water_count >= Config.IdealWaters then
        return notify(src, 'This plant already has enough water.', 'error')
    end

    local water = exports['prp-drugs']:GetItemByName(Player, Config.Items.Water)
    if not water then return notify(src, 'You need a water bottle.', 'error') end
    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.Water, 1, water.slot, 'prp-drugs-water') then return end

    plant.water_count = plant.water_count + 1
    plant.last_watered = now
    savePlant(plant)
    broadcastPlant(plant)
    notify(src, ('Plant watered (%s/%s).'):format(plant.water_count, Config.IdealWaters), 'success')
end)

RegisterNetEvent('prp-drugs:server:fertilizePlant', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plant = Plants[tonumber(id)]
    if not Player or not validDistance(src, plant) or plant.stage ~= 'growing' or plant.fertilized then return end

    local fertilizer = exports['prp-drugs']:GetItemByName(Player, Config.Items.Fertilizer)
    if not fertilizer then return notify(src, 'You need fertilizer.', 'error') end
    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.Fertilizer, 1, fertilizer.slot, 'prp-drugs-fertilizer') then return end

    plant.fertilized = true
    savePlant(plant)
    broadcastPlant(plant)
    notify(src, 'The plant has been fertilized.', 'success')
end)

RegisterNetEvent('prp-drugs:server:harvestPlant', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plant = Plants[tonumber(id)]
    if not Player or not validDistance(src, plant) or plant.stage ~= 'ready' then return end
    if Config.RequireOwnerToHarvest and plant.owner ~= Player.PlayerData.citizenid then return end

    plant.yield_quality = plant.yield_quality > 0 and plant.yield_quality or calculateYieldQuality(plant)
    local amount = calculateBudAmount(plant)
    local info = PRPDrugs.BuildInfo(plant.yield_quality, {
        yield = plant.yield_quality,
        seedGenetics = plant.seed_quality,
        dirtGrade = plant.dirt_grade,
        waterCount = plant.water_count,
        description = ('%s buds | %.1f%% yield | Class %s dirt'):format(
            PRPDrugs.GetStrain(plant.yield_quality), plant.yield_quality, plant.dirt_grade
        ),
    })

    if not exports['prp-drugs']:AddItem(Player, Config.Items.Bud, amount, info, 'prp-drugs-harvest') then
        return notify(src, 'Your inventory is full.', 'error')
    end

    if math.random(1, 100) <= Config.Harvest.SeedChance then
        local variance = math.random(-50, 30) / 10
        local seedQuality = PRPDrugs.Round(PRPDrugs.Clamp(plant.yield_quality + variance, 1, 100), 1)
        exports['prp-drugs']:AddItem(Player, Config.Items.Seed, 1, PRPDrugs.BuildInfo(seedQuality, {
            genetics = seedQuality,
            description = ('%s seed | %.1f%% genetics'):format(PRPDrugs.GetStrain(seedQuality), seedQuality),
        }), 'prp-drugs-seed-drop')
    end

    MySQL.update.await('DELETE FROM prp_drug_plants WHERE id = ?', { plant.id })
    Plants[plant.id] = nil
    TriggerClientEvent('prp-drugs:client:deletePlant', -1, plant.id)
    notify(src, ('Harvested %sx %s buds at %.1f%% quality.'):format(amount, info.strain, plant.yield_quality), 'success')
end)

RegisterNetEvent('prp-drugs:server:removePlant', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plant = Plants[tonumber(id)]
    if not Player or not validDistance(src, plant) then return end
    if plant.owner ~= Player.PlayerData.citizenid then
        return notify(src, 'Only the owner can remove this plant.', 'error')
    end

    MySQL.update.await('DELETE FROM prp_drug_plants WHERE id = ?', { plant.id })
    Plants[plant.id] = nil
    TriggerClientEvent('prp-drugs:client:deletePlant', -1, plant.id)
    notify(src, 'Plant removed.', 'success')
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, plant in pairs(Plants) do
            if plant.stage == 'growing' and now >= plant.ready_at then
                plant.stage = 'ready'
                plant.yield_quality = calculateYieldQuality(plant)
                savePlant(plant)
                broadcastPlant(plant)
            elseif now - plant.created_at > Config.PlantDecaySeconds and plant.stage ~= 'ready' then
                -- Optional old abandoned pot cleanup. Growing plants are allowed to finish first.
            end
        end
    end
end)
