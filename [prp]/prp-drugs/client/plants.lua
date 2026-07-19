local QBCore = exports['qb-core']:GetCoreObject()
local spawnedPlants = {}
local plantData = {}

local function modelForPlant(plant)
    if plant.stage == 'ready' then return Config.Models.Ready end
    if plant.stage == 'growing' then return Config.Models.Growing end
    return Config.Models.EmptyPot
end

local function deletePlantObject(id)
    local entity = spawnedPlants[id]
    if entity and DoesEntityExist(entity) then
        exports[Config.Target]:RemoveTargetEntity(entity)
        DeleteEntity(entity)
    end
    spawnedPlants[id] = nil
end

local function statusLabel(plant)
    if plant.stage == 'pot' then return 'Empty pot: add dirt' end
    if plant.stage == 'dirt' then return ('%s dirt: plant a seed'):format(plant.dirt_grade or '?') end
    if plant.stage == 'growing' then
        local remaining = math.max(0, (plant.ready_at or 0) - os.time())
        return ('Growing | Water %s/%s | %ss remaining'):format(
            plant.water_count or 0, Config.IdealWaters, remaining
        )
    end
    if plant.stage == 'ready' then
        return ('Harvest %s | %.1f%% yield'):format(plant.strain or 'Weed', plant.yield_quality or 0)
    end
    return 'Weed plant'
end

local function spawnPlant(plant)
    deletePlantObject(plant.id)
    plantData[plant.id] = plant

    local model = modelForPlant(plant)
    if not exports['prp-drugs']:LoadModel(model) then return end

    local entity = CreateObject(model, plant.x + 0.0, plant.y + 0.0, plant.z + 0.0, false, false, false)
    SetEntityHeading(entity, plant.heading + 0.0)
    FreezeEntityPosition(entity, true)
    PlaceObjectOnGroundProperly(entity)
    spawnedPlants[plant.id] = entity

    exports[Config.Target]:AddTargetEntity(entity, {
        options = {
            {
                icon = 'fas fa-circle-info',
                label = statusLabel(plant),
                action = function()
                    TriggerServerEvent('prp-drugs:server:requestPlantStatus', plant.id)
                end,
            },
            {
                icon = 'fas fa-mound',
                label = 'Add graded dirt',
                canInteract = function() return plantData[plant.id] and plantData[plant.id].stage == 'pot' end,
                action = function()
                    TriggerServerEvent('prp-drugs:server:addDirt', plant.id)
                end,
            },
            {
                icon = 'fas fa-seedling',
                label = 'Plant seed',
                canInteract = function() return plantData[plant.id] and plantData[plant.id].stage == 'dirt' end,
                action = function()
                    TriggerServerEvent('prp-drugs:server:addSeed', plant.id)
                end,
            },
            {
                icon = 'fas fa-droplet',
                label = 'Water plant',
                canInteract = function() return plantData[plant.id] and plantData[plant.id].stage == 'growing' end,
                action = function()
                    TriggerServerEvent('prp-drugs:server:waterPlant', plant.id)
                end,
            },
            {
                icon = 'fas fa-flask',
                label = 'Add fertilizer',
                canInteract = function()
                    local p = plantData[plant.id]
                    return p and p.stage == 'growing' and not p.fertilized
                end,
                action = function()
                    TriggerServerEvent('prp-drugs:server:fertilizePlant', plant.id)
                end,
            },
            {
                icon = 'fas fa-scissors',
                label = 'Harvest plant',
                canInteract = function() return plantData[plant.id] and plantData[plant.id].stage == 'ready' end,
                action = function()
                    TriggerServerEvent('prp-drugs:server:harvestPlant', plant.id)
                end,
            },
            {
                icon = 'fas fa-trash',
                label = 'Remove plant',
                action = function()
                    TriggerServerEvent('prp-drugs:server:removePlant', plant.id)
                end,
            },
        },
        distance = Config.PlantInteractionDistance,
    })
end

RegisterNetEvent('prp-drugs:client:syncPlants', function(plants)
    local seen = {}
    for _, plant in ipairs(plants) do
        seen[plant.id] = true
        local old = plantData[plant.id]
        if not old or old.stage ~= plant.stage
            or old.water_count ~= plant.water_count
            or old.fertilized ~= plant.fertilized
            or old.ready_at ~= plant.ready_at then
            spawnPlant(plant)
        else
            plantData[plant.id] = plant
        end
    end

    for id in pairs(spawnedPlants) do
        if not seen[id] then
            deletePlantObject(id)
            plantData[id] = nil
        end
    end
end)

RegisterNetEvent('prp-drugs:client:updatePlant', function(plant)
    spawnPlant(plant)
end)

RegisterNetEvent('prp-drugs:client:deletePlant', function(id)
    deletePlantObject(id)
    plantData[id] = nil
end)

RegisterNetEvent('prp-drugs:client:showPlantStatus', function(plant)
    local message
    if plant.stage == 'growing' then
        local remaining = math.max(0, (plant.ready_at or 0) - os.time())
        message = ('%s seed | %.1f%% genetics | Dirt %s | Water %s/%s | %ss left'):format(
            plant.strain or 'Unknown', plant.seed_quality or 0, plant.dirt_grade or '?',
            plant.water_count or 0, Config.IdealWaters, remaining
        )
    elseif plant.stage == 'ready' then
        message = ('%s is ready | %.1f%% final yield quality | watered %s times'):format(
            plant.strain or 'Unknown', plant.yield_quality or 0, plant.water_count or 0
        )
    else
        message = statusLabel(plant)
    end
    QBCore.Functions.Notify(message, 'primary', 8000)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('prp-drugs:server:requestPlants')
end)

CreateThread(function()
    Wait(2500)
    TriggerServerEvent('prp-drugs:server:requestPlants')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(spawnedPlants) do deletePlantObject(id) end
end)
