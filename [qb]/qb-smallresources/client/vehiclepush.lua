local QBCore = exports['qb-core']:GetCoreObject()
local isInFront = false
local isFlippingVehicle = false

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function requestControl(entity)
    if not DoesEntityExist(entity) then return false end

    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(10)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function isPushableVehicleClass(vehicle)
    local vehClass = GetVehicleClass(vehicle)
    return vehClass ~= 13 and vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16
end

local function isVehicleFlipped(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return IsEntityUpsidedown(vehicle) or math.abs(GetEntityRoll(vehicle)) >= 75.0
end

local function flipVehicle(vehicle)
    if isFlippingVehicle or not isVehicleFlipped(vehicle) then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    if not requestControl(vehicle) then
        QBCore.Functions.Notify('Could not get control of this vehicle.', 'error')
        return
    end

    isFlippingVehicle = true
    local ped = PlayerPedId()
    local heading = GetEntityHeading(vehicle)

    TaskTurnPedToFaceEntity(ped, vehicle, 1000)
    QBCore.Functions.Progressbar('flip_vehicle', 'Flipping vehicle...', 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'missfinale_c2ig_11',
        anim = 'pushcar_offcliff_m',
        flags = 35,
    }, {}, {}, function()
        if DoesEntityExist(vehicle) then
            requestControl(vehicle)
            SetEntityRotation(vehicle, 0.0, 0.0, heading, 2, true)
            SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
            SetVehicleOnGroundProperly(vehicle)
        end
        ClearPedTasks(ped)
        isFlippingVehicle = false
    end, function()
        ClearPedTasks(ped)
        isFlippingVehicle = false
    end)
end

RegisterNetEvent('vehiclepush:client:push', function(veh)
    if veh then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehPos = GetEntityCoords(veh)
        local dimension = GetModelDimensions(GetEntityModel(veh))
        if not IsEntityAttachedToEntity(ped, veh) and IsVehicleSeatFree(veh, -1) and GetVehicleEngineHealth(veh) <= Config.DamageNeeded and GetVehicleEngineHealth(veh) >= 0 then
            if isPushableVehicleClass(veh) then
                NetworkRequestControlOfEntity(veh)
                if #(pos - vehPos) < 3.0 and not IsPedInAnyVehicle(ped, false) then
                    if #(vehPos + GetEntityForwardVector(veh) - pos) > #(vehPos + GetEntityForwardVector(veh) * -1 - pos) then
                        isInFront = false
                        AttachEntityToEntity(ped, veh, GetPedBoneIndex(ped, 6286), 0.0, dimension.y - 0.3, dimension.z + 1.0, 0.0, 0.0, 0.0, false, false, false, true, 0, true)
                    else
                        isInFront = true
                        AttachEntityToEntity(ped, veh, GetPedBoneIndex(ped, 6286), 0.0, dimension.y * -1 + 0.1, dimension.z + 1.0, 0.0, 0.0, 180.0, false, false, false, true, 0, true)
                    end
                    loadAnimDict('missfinale_c2ig_11')
                    TaskPlayAnim(ped, 'missfinale_c2ig_11', 'pushcar_offcliff_m', 2.0, -8.0, -1, 35, 0, false, false, false)
                    exports['qb-core']:DrawText(Lang:t('pushcar.stop_push'),'left')
                    while true do
                        Wait(0)
                        SetVehicleForwardSpeed(veh, isInFront and -1.0 or 1.0)

                        if IsControlJustPressed(0, 38) then
                            exports['qb-core']:HideText()
                            DetachEntity(ped, false, false)
                            StopAnimTask(ped, 'missfinale_c2ig_11', 'pushcar_offcliff_m', 2.0)
                            FreezeEntityPosition(ped, false)
                            break
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and isPushableVehicleClass(veh) then
                if IsEntityInAir(veh) or IsEntityUpsidedown(veh) or not IsVehicleOnAllWheels(veh) then
                    sleep = 0
                    DisableControlAction(0, 59, true) -- INPUT_VEH_MOVE_LR
                    DisableControlAction(0, 60, true) -- INPUT_VEH_MOVE_UD
                    DisableControlAction(0, 61, true) -- INPUT_VEH_MOVE_UP_ONLY
                    DisableControlAction(0, 62, true) -- INPUT_VEH_MOVE_DOWN_ONLY
                    DisableControlAction(0, 63, true) -- INPUT_VEH_MOVE_LEFT_ONLY
                    DisableControlAction(0, 64, true) -- INPUT_VEH_MOVE_RIGHT_ONLY
                    DisableControlAction(0, 107, true) -- INPUT_VEH_FLY_ROLL_LR
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    exports['qb-target']:AddTargetBone({'bonnet', 'boot'}, {
        options = {
            {
                icon = 'fas fa-wrench',
                label = 'Push Vehicle',
                action = function(entity)
                    if GetEntityHealth(entity) > Config.DamageNeeded then
                        QBCore.Functions.Notify(Lang:t('pushcar.notDamaged'), 'error')
                        return
                    end
                    TriggerEvent('vehiclepush:client:push', entity)
                end,
                distance = 1.3
            }
        }
    })

    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                icon = 'fas fa-car-crash',
                label = 'Flip Vehicle',
                action = function(entity)
                    flipVehicle(entity)
                end,
                canInteract = function(entity, distance)
                    return distance <= 2.5 and not isFlippingVehicle and not IsPedInAnyVehicle(PlayerPedId(), false) and isVehicleFlipped(entity)
                end,
            }
        },
        distance = 2.5
    })
end)
