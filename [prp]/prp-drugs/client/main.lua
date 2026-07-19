local QBCore = exports['qb-core']:GetCoreObject()
local shopPed, pressObject

local function notify(message, kind)
    QBCore.Functions.Notify(message, kind or 'primary', Config.NotifyLength)
end

local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(25) end
    return HasModelLoaded(model)
end

local function progress(name, label, duration, animation, callback)
    QBCore.Functions.Progressbar(name, label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, animation or {}, {}, {}, function()
        callback(true)
    end, function()
        callback(false)
    end)
end

RegisterNetEvent('prp-drugs:client:notify', function(message, kind)
    notify(message, kind)
end)

RegisterNetEvent('prp-drugs:client:useShovel', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return notify('You cannot dig while inside a vehicle.', 'error')
    end
    progress('prp_drugs_dig', 'Digging for usable dirt...', Config.Digging.ProgressTimeMs, {
        animDict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flags = 1,
    }, function(completed)
        if completed then
            local coords = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('prp-drugs:server:digDirt', {
                x = coords.x, y = coords.y, z = coords.z
            })
        end
    end)
end)

RegisterNetEvent('prp-drugs:client:usePlantPot', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return notify('You cannot place a pot while inside a vehicle.', 'error')
    end

    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local pos = GetEntityCoords(ped) + (forward * 1.0)
    local foundGround, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
    if foundGround then pos = vector3(pos.x, pos.y, groundZ) end

    progress('prp_drugs_place_pot', 'Placing plant pot...', 2500, {
        animDict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flags = 1,
    }, function(completed)
        if completed then
            TriggerServerEvent('prp-drugs:server:createPot', {
                x = pos.x, y = pos.y, z = pos.z,
                heading = GetEntityHeading(ped)
            })
        end
    end)
end)

RegisterNetEvent('prp-drugs:client:bagBud', function()
    progress('prp_drugs_bag', 'Packing weed into a baggy...', Config.Processing.ProgressTimeMs, {
        animDict = 'anim@amb@business@weed@weed_inspecting_high_dry@',
        anim = 'weed_inspecting_high_base_inspector',
        flags = 49,
    }, function(completed)
        if completed then TriggerServerEvent('prp-drugs:server:bagBud') end
    end)
end)

RegisterNetEvent('prp-drugs:client:rollJoint', function()
    progress('prp_drugs_joint', 'Rolling a joint...', Config.Processing.ProgressTimeMs, {
        animDict = 'anim@amb@business@weed@weed_inspecting_high_dry@',
        anim = 'weed_inspecting_high_base_inspector',
        flags = 49,
    }, function(completed)
        if completed then TriggerServerEvent('prp-drugs:server:rollJoint') end
    end)
end)

RegisterNetEvent('prp-drugs:client:unbagWeed', function(slot)
    TriggerServerEvent('prp-drugs:server:unbagWeed', slot)
end)

local function createShop()
    if not Config.Shop.enabled or DoesEntityExist(shopPed) then return end
    if not loadModel(Config.Shop.model) then return end

    shopPed = CreatePed(0, Config.Shop.model, Config.Shop.coords.x, Config.Shop.coords.y,
        Config.Shop.coords.z - 1.0, Config.Shop.coords.w, false, false)
    SetEntityInvincible(shopPed, true)
    FreezeEntityPosition(shopPed, true)
    SetBlockingOfNonTemporaryEvents(shopPed, true)
    TaskStartScenarioInPlace(shopPed, Config.Shop.scenario, 0, true)

    local options = {}
    for index, entry in ipairs(Config.Shop.items) do
        options[#options + 1] = {
            num = index,
            icon = 'fas fa-basket-shopping',
            label = ('Buy %sx %s - $%s'):format(entry.amount, entry.item, entry.price),
            action = function()
                TriggerServerEvent('prp-drugs:server:buyShopItem', index)
            end,
        }
    end

    exports[Config.Target]:AddTargetEntity(shopPed, {
        options = options,
        distance = 2.0,
    })
end

local function createPress()
    if not Config.Press.enabled or DoesEntityExist(pressObject) then return end
    if not loadModel(Config.Press.model) then return end

    pressObject = CreateObject(Config.Press.model, Config.Press.coords.x, Config.Press.coords.y,
        Config.Press.coords.z - 1.0, false, false, false)
    SetEntityHeading(pressObject, Config.Press.coords.w)
    FreezeEntityPosition(pressObject, true)

    exports[Config.Target]:AddTargetEntity(pressObject, {
        options = {{
            icon = 'fas fa-compress',
            label = ('Press %s buds into a brick'):format(Config.Press.BudsRequired),
            action = function()
                progress('prp_drugs_press', 'Pressing weed brick...', Config.Press.ProgressTimeMs, {
                    animDict = 'mini@repair',
                    anim = 'fixing_a_ped',
                    flags = 1,
                }, function(completed)
                    if completed then TriggerServerEvent('prp-drugs:server:pressBrick') end
                end)
            end,
        }},
        distance = 2.0,
    })
end

CreateThread(function()
    Wait(1500)
    createShop()
    createPress()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if DoesEntityExist(shopPed) then DeleteEntity(shopPed) end
    if DoesEntityExist(pressObject) then DeleteEntity(pressObject) end
end)

exports('Progress', progress)
exports('Notify', notify)
exports('LoadModel', loadModel)
