local QBCore = exports['qb-core']:GetCoreObject()

local Mission = {
    active = false,
    stage = 'idle',
    vehicleNet = nil,
    vehiclePlate = nil,
    vehicleModel = nil,
    vehicleSet = nil,
    carrying = nil,
    carryEntity = nil,
    stripped = {},
    delivered = {},
    dismantleUnlocked = false,
}

local SpawnedPeds = {}
local VehicleTargetApplied = false
local MissionBlip = nil

local function Notify(msg, typ)
    if Config.FrameworkNotify then
        QBCore.Functions.Notify(msg, typ or 'primary')
    end
end

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end
    end
    return hash
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function ClearMissionWaypoint()
    if MissionBlip and DoesBlipExist(MissionBlip) then
        SetBlipRoute(MissionBlip, false)
        RemoveBlip(MissionBlip)
        MissionBlip = nil
    end
end

local function SetMissionWaypoint(vec, label)
    ClearMissionWaypoint()
    MissionBlip = AddBlipForCoord(vec.x + 0.0, vec.y + 0.0, (vec.z or 0.0) + 0.0)
    SetBlipSprite(MissionBlip, 1)
    SetBlipDisplay(MissionBlip, 4)
    SetBlipScale(MissionBlip, 0.9)
    SetBlipColour(MissionBlip, 3)
    SetBlipAsShortRange(MissionBlip, false)
    SetBlipRoute(MissionBlip, true)
    SetBlipRouteColour(MissionBlip, 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Mission Route')
    EndTextCommandSetBlipName(MissionBlip)
end

local function NormalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function GetVehicleEntity()
    if not Mission.vehicleNet then return 0 end
    local veh = NetToVeh(Mission.vehicleNet)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return 0
end

local function RotatedBoxContains(point, zone)
    local relX = point.x - zone.coords.x
    local relY = point.y - zone.coords.y
    local heading = math.rad(-(zone.heading or 0.0))
    local rotX = relX * math.cos(heading) - relY * math.sin(heading)
    local rotY = relX * math.sin(heading) + relY * math.cos(heading)
    return math.abs(rotX) <= (zone.length / 2.0) and math.abs(rotY) <= (zone.width / 2.0)
end

local function VehicleInZone(vehicle, zone)
    local coords = GetEntityCoords(vehicle)
    if zone.minZ and coords.z < zone.minZ then return false end
    if zone.maxZ and coords.z > zone.maxZ then return false end
    return RotatedBoxContains(coords, zone)
end

local function MakePed(data)
    local hash = LoadModel(data.model)
    local ped = CreatePed(0, hash, data.coords.x, data.coords.y, data.coords.z - 1.0, data.coords.w, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    if data.scenario then
        TaskStartScenarioInPlace(ped, data.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function GetVehicleColorName(vehicle)
    local primary, secondary = GetVehicleColours(vehicle)
    local names = {
        [0] = 'Black', [1] = 'Black', [2] = 'Black', [3] = 'Silver', [4] = 'Silver', [5] = 'Silver',
        [27] = 'Red', [28] = 'Red', [29] = 'Red', [30] = 'Orange', [31] = 'Gold', [32] = 'Orange',
        [38] = 'Blue', [61] = 'Blue', [62] = 'Blue', [63] = 'Blue', [64] = 'Blue', [65] = 'Blue',
        [71] = 'Green', [72] = 'Green', [73] = 'Green', [74] = 'Green',
        [88] = 'Yellow', [89] = 'Yellow', [90] = 'Bronze', [91] = 'Yellow',
        [111] = 'White', [112] = 'White', [121] = 'White', [135] = 'Pink', [136] = 'Pink', [137] = 'Pink',
    }
    return names[primary] or names[secondary] or ('Color #' .. tostring(primary))
end

local function GetVehicleTypeLabel(setKey)
    local set = Config.VehicleSets[setKey]
    return set and set.label or tostring(setKey)
end

local function SendMissionMail(plate, color, typeLabel)
    if not Config.UseQBMail then return end
    TriggerServerEvent('qb-phone:server:sendNewMail', {
        sender = Config.Mail.sender,
        subject = Config.Mail.subject,
        message = Config.Mail.message:format(plate, color, typeLabel),
        button = {}
    })
end

local function CleanupCarry()
    ClearPedTasks(PlayerPedId())
    if Mission.carryEntity and DoesEntityExist(Mission.carryEntity) then
        DeleteEntity(Mission.carryEntity)
    end
    Mission.carryEntity = nil
    Mission.carrying = nil
end

local function ResetMission()
    ClearMissionWaypoint()
    CleanupCarry()
    Mission.active = false
    Mission.stage = 'idle'
    Mission.vehicleNet = nil
    Mission.vehiclePlate = nil
    Mission.vehicleModel = nil
    Mission.vehicleSet = nil
    Mission.stripped = {}
    Mission.delivered = {}
    Mission.dismantleUnlocked = false
    VehicleTargetApplied = false
end

local function CreateMissionVehicle(modelName, spawnCoords)
    local hash = LoadModel(modelName)
    local vehicle = CreateVehicle(hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    local plate = ('PRP%03d'):format(math.random(100, 999))
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleColours(vehicle, math.random(0, 159), math.random(0, 159))
    SetModelAsNoLongerNeeded(hash)
    return vehicle
end

local function ApplyPartVisual(vehicle, partKey)
    local part = Config.Parts[partKey]
    if not part then return end

    if part.type == 'door' or part.type == 'panel' then
        SetVehicleDoorOpen(vehicle, part.doorIndex, false, false)
        Wait(200)
        SetVehicleDoorBroken(vehicle, part.doorIndex, true)
    elseif part.type == 'wheel' then
        if BreakOffVehicleWheel then
            BreakOffVehicleWheel(vehicle, part.wheelIndex, false, true, false, false)
        else
            SetVehicleTyreBurst(vehicle, part.wheelIndex, true, 1000.0)
        end
    elseif part.type == 'engine' then
        SetVehicleDoorOpen(vehicle, 4, false, false)
        SetVehicleEngineHealth(vehicle, -4000.0)
    end
end

local function StartCarryPart(partKey)
    local ped = PlayerPedId()
    local part = Config.Parts[partKey]
    if not part then return end
    CleanupCarry()

    local propHash = LoadModel(part.carryProp)
    local pcoords = GetEntityCoords(ped)
    local prop = CreateObject(propHash, pcoords.x, pcoords.y, pcoords.z + 0.2, true, true, false)
    SetEntityAsMissionEntity(prop, true, true)

    LoadAnimDict('anim@heists@box_carry@')
    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 3.0, 3.0, -1, 49, 0.0, false, false, false)

    local bone = GetPedBoneIndex(ped, 60309)
    local off = vec3(0.12, 0.0, 0.0)
    local rot = vec3(0.0, 90.0, 180.0)

    if part.type == 'wheel' then
        off = vec3(0.2, 0.02, 0.0)
        rot = vec3(0.0, 90.0, 90.0)
    elseif part.type == 'engine' then
        off = vec3(0.18, 0.03, 0.0)
        rot = vec3(0.0, 85.0, 180.0)
    elseif partKey == 'hood' or partKey == 'trunk' then
        off = vec3(0.12, 0.04, 0.0)
        rot = vec3(0.0, 90.0, 180.0)
    end

    AttachEntityToEntity(prop, ped, bone, off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    Mission.carryEntity = prop
    Mission.carrying = partKey
end

local function RemainingPartsCount()
    local delivered = 0
    for _ in pairs(Mission.delivered) do delivered = delivered + 1 end
    local set = Config.VehicleSets[Mission.vehicleSet]
    return (set and #set.parts or 0) - delivered
end

local function BuildVehicleTargetOptions()
    local opts = {}
    local set = Config.VehicleSets[Mission.vehicleSet]
    if not set then return opts end

    for _, partKey in ipairs(set.parts) do
        local partData = Config.Parts[partKey]
        opts[#opts+1] = {
            icon = 'fas fa-screwdriver-wrench',
            label = 'Take ' .. partData.label,
            canInteract = function(entity, distance)
                if distance > Config.InteractDistance then return false end
                if not Mission.active or not Mission.dismantleUnlocked then return false end
                if Mission.carrying then return false end
                if Mission.stripped[partKey] then return false end
                return NormalizePlate(GetVehicleNumberPlateText(entity)) == Mission.vehiclePlate
            end,
            action = function()
                TriggerEvent('prp-scrapyard:client:removePart', partKey)
            end
        }
    end

    return opts
end

local function RefreshVehicleTarget()
    local vehicle = GetVehicleEntity()
    if vehicle == 0 or VehicleTargetApplied then return end
    exports['qb-target']:AddTargetEntity(vehicle, {
        options = BuildVehicleTargetOptions(),
        distance = 2.5,
    })
    VehicleTargetApplied = true
end

local function GetDropZoneCorners(zone)
    local halfL = zone.length / 2.0
    local halfW = zone.width / 2.0
    local heading = math.rad(zone.heading or 0.0)
    local cosH, sinH = math.cos(heading), math.sin(heading)

    local function rotateOffset(x, y)
        return vec3(
            zone.coords.x + (x * cosH - y * sinH),
            zone.coords.y + (x * sinH + y * cosH),
            zone.coords.z + ((zone.corners and zone.corners.zOffset) or 0.03)
        )
    end

    return {
        rotateOffset(halfL, halfW),
        rotateOffset(halfL, -halfW),
        rotateOffset(-halfL, halfW),
        rotateOffset(-halfL, -halfW),
    }
end

local function DrawDropMarkerLoop()
    CreateThread(function()
        while Mission.active do
            Wait(0)
            local cornersCfg = Config.DropZone.corners
            if cornersCfg and cornersCfg.draw and (Mission.stage == 'return' or Mission.stage == 'dismantle') then
                local pedCoords = GetEntityCoords(PlayerPedId())
                if #(pedCoords - Config.DropZone.coords) <= (cornersCfg.drawDistance or 45.0) then
                    local corners = GetDropZoneCorners(Config.DropZone)
                    local size = cornersCfg.markerSize or vec3(0.22, 0.22, 0.22)
                    for _, corner in ipairs(corners) do
                        DrawMarker(
                            cornersCfg.markerType or 28,
                            corner.x, corner.y, corner.z,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            size.x, size.y, size.z,
                            cornersCfg.color.r, cornersCfg.color.g, cornersCfg.color.b, cornersCfg.color.a,
                            false, false, 2, false, nil, nil, false
                        )
                    end
                end
            end
        end
    end)
end

local function StartMission(data)
    ResetMission()
    local vehicle = CreateMissionVehicle(data.model, data.location.coords)
    Mission.active = true
    Mission.stage = 'steal'
    Mission.vehicleNet = NetworkGetNetworkIdFromEntity(vehicle)
    Mission.vehiclePlate = NormalizePlate(GetVehicleNumberPlateText(vehicle))
    Mission.vehicleModel = data.model
    Mission.vehicleSet = data.vehicleSet
    SetNetworkIdCanMigrate(Mission.vehicleNet, true)

    SetMissionWaypoint(data.location.coords, 'Steal Vehicle')
    Notify('New scrapyard job received. Check your phone mail.', 'success')
    Notify('Vehicle location marked on your route.', 'primary')

    SendMissionMail(Mission.vehiclePlate, GetVehicleColorName(vehicle), GetVehicleTypeLabel(data.vehicleSet))
    DrawDropMarkerLoop()

    CreateThread(function()
        local sentReturnRoute = false
        while Mission.active and Mission.stage == 'steal' do
            Wait(300)
            local veh = GetVehicleEntity()
            if veh ~= 0 and GetVehiclePedIsIn(PlayerPedId(), false) == veh then
                if not sentReturnRoute then
                    Mission.stage = 'return'
                    SetMissionWaypoint(Config.DropZone.coords, 'Scrapyard Drop Off')
                    Notify('Bring the vehicle back to the scrapyard drop zone.', 'primary')
                    sentReturnRoute = true
                end
                break
            end
        end
    end)

    CreateThread(function()
        while Mission.active do
            Wait(400)
            local veh = GetVehicleEntity()
            if Mission.stage == 'return' and veh ~= 0 and VehicleInZone(veh, Config.DropZone) then
                ClearMissionWaypoint()
                Notify('Park inside the marked zone and confirm the vehicle.', 'success')
                break
            end
        end
    end)
end

RegisterNetEvent('prp-scrapyard:client:startMission', function(data)
    StartMission(data)
end)

RegisterNetEvent('prp-scrapyard:client:removePart', function(partKey)
    if not Mission.active then return Notify('You are not on a scrapyard run.', 'error') end
    if Mission.carrying then return Notify('You are already carrying a part.', 'error') end
    if not Mission.dismantleUnlocked then return Notify('You need to confirm the correct vehicle first.', 'error') end
    if Mission.stripped[partKey] then return end

    local vehicle = GetVehicleEntity()
    if vehicle == 0 or NormalizePlate(GetVehicleNumberPlateText(vehicle)) ~= Mission.vehiclePlate then
        return Notify('You can only dismantle the active mission vehicle.', 'error')
    end

    QBCore.Functions.Progressbar('prp_scrapyard_remove_' .. partKey, 'Removing ' .. Config.Parts[partKey].label, Config.Progress.removePartMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mini@repair',
        anim = 'fixing_a_player',
        flags = 49,
    }, {}, {}, function()
        Mission.stripped[partKey] = true
        ApplyPartVisual(vehicle, partKey)
        StartCarryPart(partKey)
        Notify('Part removed. Take it to the final NPC.', 'success')
    end, function()
        Notify('Cancelled', 'error')
    end)
end)

RegisterNetEvent('prp-scrapyard:client:checkVehicle', function()
    if not Mission.active then return Notify('You are not on a scrapyard run.', 'error') end
    if Mission.dismantleUnlocked then return Notify('Vehicle already confirmed. Start taking parts off it.', 'success') end

    local vehicle = GetVehicleEntity()
    if vehicle == 0 then return Notify('The target vehicle is not parked in the drop zone.', 'error') end
    if NormalizePlate(GetVehicleNumberPlateText(vehicle)) ~= Mission.vehiclePlate then
        return Notify('This is not the requested vehicle.', 'error')
    end
    if not VehicleInZone(vehicle, Config.DropZone) then
        return Notify('The target vehicle is not parked inside the marked zone.', 'error')
    end

    QBCore.Functions.Progressbar('prp_scrapyard_confirm_vehicle', 'Checking vehicle...', Config.Progress.confirmVehicleMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'amb@prop_human_bum_bin@idle_b',
        anim = 'idle_d',
        flags = 49,
    }, {}, {}, function()
        Mission.stage = 'dismantle'
        Mission.dismantleUnlocked = true
        ClearMissionWaypoint()
        RefreshVehicleTarget()
        Notify('Correct vehicle confirmed. Start taking parts off it.', 'success')
    end, function()
        Notify('Cancelled', 'error')
    end)
end)

RegisterNetEvent('prp-scrapyard:client:handInPart', function()
    if not Mission.active then return Notify('You are not on a scrapyard run.', 'error') end
    if not Mission.carrying then return Notify('You are not carrying anything.', 'error') end

    local partKey = Mission.carrying
    QBCore.Functions.Progressbar('prp_scrapyard_handin_' .. partKey, 'Handing over ' .. Config.Parts[partKey].label, Config.Progress.handInPartMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mp_common',
        anim = 'givetake1_a',
        flags = 49,
    }, {}, {}, function()
        Mission.delivered[partKey] = true
        CleanupCarry()
        Notify('Part handed in.', 'success')
        if RemainingPartsCount() <= 0 then
            TriggerServerEvent('prp-scrapyard:server:completeJob', Mission.vehicleSet)
            local vehicle = GetVehicleEntity()
            if vehicle ~= 0 then DeleteEntity(vehicle) end
            ResetMission()
            Notify('Vehicle fully stripped. Rewards paid.', 'success')
        end
    end, function()
        Notify('Cancelled', 'error')
    end)
end)

CreateThread(function()
    local startPed = MakePed(Config.StartPed)
    local partsPed = MakePed(Config.PartsPed)
    SpawnedPeds = { startPed, partsPed }

    exports['qb-target']:AddTargetEntity(startPed, {
        options = {
            {
                icon = 'fas fa-car-burst',
                label = 'Ask for a scrapyard job',
                canInteract = function()
                    return not Mission.active
                end,
                action = function()
                    TriggerServerEvent('prp-scrapyard:server:requestMission')
                end,
            }
        },
        distance = 2.0,
    })

    exports['qb-target']:AddTargetEntity(partsPed, {
        options = {
            {
                icon = 'fas fa-circle-question',
                label = 'Is this the car?',
                canInteract = function()
                    return Mission.active and not Mission.dismantleUnlocked and Mission.stage == 'return'
                end,
                action = function()
                    TriggerEvent('prp-scrapyard:client:checkVehicle')
                end,
            },
            {
                icon = 'fas fa-hand',
                label = 'Take item',
                canInteract = function()
                    return Mission.active and Mission.dismantleUnlocked and Mission.carrying ~= nil
                end,
                action = function()
                    TriggerEvent('prp-scrapyard:client:handInPart')
                end,
            }
        },
        distance = Config.NpcDistance,
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CleanupCarry()
    ClearMissionWaypoint()
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
