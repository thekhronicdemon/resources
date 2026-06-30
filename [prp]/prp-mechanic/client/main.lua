local QBCore = exports[Config.Core]:GetCoreObject()
local tabletOpen = false
local activeTow = nil
local spawnedTowVehicle = nil
local rentedTruck = nil
local lastSpeed = 0.0
local lastVeh = 0
local lastWear = 0
local attachedEntity = nil
local spawnedTowPed = nil
local towPickupBlip = nil
local towDropoffBlip = nil
local cleanupTowPickup
local cleanupTowDropoff

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function isMechanicJob(job)
    if not job then return false end
    if Config.AllowJobType ~= false and Config.JobType and job.type == Config.JobType then return true end
    if Config.JobName and job.name == Config.JobName then return true end

    for _, jobName in ipairs(Config.JobNames or {}) do
        if job.name == jobName then return true end
    end

    return false
end

local function isMechanic()
    local pd = QBCore.Functions.GetPlayerData()
    return pd and isMechanicJob(pd.job)
end

local function getTargetJob()
    local jobNames = Config.JobNames or {}
    if #jobNames == 0 then return Config.JobName end
    if #jobNames == 1 then return jobNames[1] end

    local jobs = {}
    for _, jobName in ipairs(jobNames) do
        jobs[jobName] = 0
    end
    return jobs
end

local function mechanicTargetOption(option)
    option.canInteract = option.canInteract or function()
        return isMechanic()
    end

    if Config.AllowJobType ~= false and Config.JobType then
        option.jobType = Config.JobType
    else
        option.job = getTargetJob()
    end

    return option
end

local function getPlate(veh)
    return string.upper((GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''))
end

local function requestModel(model, timeoutMs)
    if not model or not IsModelValid(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + (timeoutMs or 8000)
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasModelLoaded(model)
end

local function requestAnimDict(dict, timeoutMs)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function setVehicleFuel(veh, fuel)
    if not veh or veh == 0 then return end
    fuel = fuel or 100.0
    SetVehicleFuelLevel(veh, fuel)

    if GetResourceState('prp-fuel') == 'started' then
        pcall(function()
            exports['prp-fuel']:SetFuel(veh, fuel)
        end)
    end
end

local function isActiveTow(jobId)
    return activeTow and activeTow.id == jobId
end

local function getRandomWorkshopDropoff()
    local shops = Config.Locations.Workshops or {}
    if #shops == 0 then return Config.Locations.TowDepot.coords, 'Mechanic Shop' end

    local shop = shops[math.random(#shops)]
    return shop.coords, shop.blipName or shop.label or 'Mechanic Shop'
end

local function playCustomerWave(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if requestAnimDict('gestures@m@standing@casual') then
        TaskPlayAnim(ped, 'gestures@m@standing@casual', 'gesture_hello', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CAR_PARK_ATTENDANT', 0, true)
    end
end

local function seatCustomerInTowTruck()
    if not spawnedTowPed or not DoesEntityExist(spawnedTowPed) then return false end
    if not rentedTruck or not DoesEntityExist(rentedTruck) then return false end

    local seat = 0
    if not IsVehicleSeatFree(rentedTruck, seat) then seat = 1 end
    if not IsVehicleSeatFree(rentedTruck, seat) then
        notify('The customer needs an empty passenger seat in the tow truck.', 'error')
        return false
    end

    FreezeEntityPosition(spawnedTowPed, false)
    ClearPedTasks(spawnedTowPed)
    SetBlockingOfNonTemporaryEvents(spawnedTowPed, true)
    TaskEnterVehicle(spawnedTowPed, rentedTruck, 12000, seat, 1.0, 1, 0)

    CreateThread(function()
        local deadline = GetGameTimer() + 9000
        while spawnedTowPed and DoesEntityExist(spawnedTowPed) and GetGameTimer() < deadline do
            if IsPedInVehicle(spawnedTowPed, rentedTruck, false) then return end
            Wait(250)
        end

        if spawnedTowPed and DoesEntityExist(spawnedTowPed) and rentedTruck and DoesEntityExist(rentedTruck) and not IsPedInVehicle(spawnedTowPed, rentedTruck, false) then
            TaskWarpPedIntoVehicle(spawnedTowPed, rentedTruck, seat)
        end
    end)

    return true
end

local function sendCustomerAwayFromVehicle(vehicle, ped)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not ped or ped == 0 or not DoesEntityExist(ped) then return end

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    SetVehicleDoorsLocked(vehicle, 1)
    TaskEnterVehicle(ped, vehicle, 12000, -1, 1.0, 1, 0)

    CreateThread(function()
        local deadline = GetGameTimer() + 9000
        while DoesEntityExist(ped) and DoesEntityExist(vehicle) and GetGameTimer() < deadline do
            if IsPedInVehicle(ped, vehicle, false) then break end
            Wait(250)
        end

        if DoesEntityExist(ped) and DoesEntityExist(vehicle) and not IsPedInVehicle(ped, vehicle, false) then
            TaskWarpPedIntoVehicle(ped, vehicle, -1)
        end

        if DoesEntityExist(ped) and DoesEntityExist(vehicle) then
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleUndriveable(vehicle, false)
            TaskVehicleDriveWander(ped, vehicle, 18.0, 786603)
            SetEntityAsNoLongerNeeded(ped)
            SetEntityAsNoLongerNeeded(vehicle)
        end
    end)
end

local function releaseAccidentCustomer()
    if not spawnedTowPed or not DoesEntityExist(spawnedTowPed) then return end

    local ped = spawnedTowPed
    spawnedTowPed = nil
    ClearPedTasks(ped)
    TaskLeaveVehicle(ped, rentedTruck or 0, 0)

    CreateThread(function()
        Wait(2500)
        if DoesEntityExist(ped) then
            TaskWanderStandard(ped, 10.0, 10)
            SetEntityAsNoLongerNeeded(ped)
        end
    end)
end

local function getClosestVehicle(radius)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = QBCore.Functions.GetClosestVehicle(coords)
    if veh and veh ~= 0 then
        local dist = #(coords - GetEntityCoords(veh))
        if dist <= (radius or 6.0) then return veh, dist end
    end
    return 0, 999.0
end


local function createBlip(coords, sprite, color, scale, name, shortRange)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale or 0.75)
    SetBlipColour(blip, color or 0)
    SetBlipAsShortRange(blip, shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function setupBlips()
    if not Config.Blips or not Config.Blips.Enabled then return end

    if Config.Blips.MechanicShops and Config.Blips.MechanicShops.Enabled then
        for _, loc in ipairs(Config.Locations.Workshops) do
            createBlip(
                loc.coords,
                Config.Blips.MechanicShops.Sprite,
                Config.Blips.MechanicShops.Color,
                Config.Blips.MechanicShops.Scale,
                (loc.blipName or loc.label or 'Mechanic Shop') .. (Config.Blips.MechanicShops.NameSuffix or ''),
                Config.Blips.MechanicShops.ShortRange
            )
        end
    end

    if Config.Blips.TowDepot and Config.Blips.TowDepot.Enabled then
        local d = Config.Locations.TowDepot
        createBlip(
            d.coords,
            Config.Blips.TowDepot.Sprite,
            Config.Blips.TowDepot.Color,
            Config.Blips.TowDepot.Scale,
            Config.Blips.TowDepot.Name or d.label or 'Tow Depot',
            Config.Blips.TowDepot.ShortRange
        )
    end
end

local function repairTime()
    local p = LocalPlayer.state.mechanicProfile
    local level = p and p.level or 1
    local t = Config.Progress.BaseRepairTime - ((level - 1) * Config.Progress.TimeReductionPerLevel)
    return math.max(Config.Progress.MinimumRepairTime, t)
end

local function openTablet()
    if not isMechanic() then notify(Config.Messages.NoJob, 'error') return end
    QBCore.Functions.TriggerCallback('prp-mechanic:server:getDashboard', function(res)
        if not res or not res.ok then notify(res and res.message or 'Unable to open tablet.', 'error') return end
        tabletOpen = true
        activeTow = res.activeTow
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = res })
    end)
end

RegisterCommand(Config.Command, openTablet)
RegisterNetEvent('prp-mechanic:client:openTablet', openTablet)

RegisterNetEvent('prp-mechanic:client:profileUpdated', function(profile, nextLevelXp, leveled)
    LocalPlayer.state:set('mechanicProfile', profile, true)
    SendNUIMessage({ action = 'profile', profile = profile, nextLevelXp = nextLevelXp })
    if leveled then notify('Mechanic level up! You are now level '..profile.level, 'success') end
end)

CreateThread(function()
    Wait(1000)
    setupBlips()

    for _, loc in ipairs(Config.Locations.Workshops) do
        exports[Config.Target]:AddBoxZone('prp_mech_tablet_'..loc.id, loc.coords, loc.length, loc.width, {
            name = 'prp_mech_tablet_'..loc.id,
            heading = loc.heading,
            debugPoly = Config.Debug,
            minZ = loc.minZ,
            maxZ = loc.maxZ,
        }, {
            options = {
                mechanicTargetOption({
                    icon = 'fas fa-tablet-screen-button',
                    label = loc.label,
                    action = openTablet
                })
            },
            distance = 2.0
        })
    end

    local d = Config.Locations.TowDepot
    exports[Config.Target]:AddBoxZone('prp_tow_depot', d.coords, d.length, d.width, {
        name = 'prp_tow_depot', heading = d.heading, debugPoly = Config.Debug, minZ = d.minZ, maxZ = d.maxZ,
    }, {
        options = {
            mechanicTargetOption({ icon = 'fas fa-truck-pickup', label = 'Retrieve Tow Truck', action = function() TriggerEvent('prp-mechanic:client:rentTowTruck') end }),
            mechanicTargetOption({ icon = 'fas fa-rotate-left', label = 'Return Tow Truck', action = function() TriggerEvent('prp-mechanic:client:returnTowTruck') end }),
        },
        distance = 3.0
    })
end)

RegisterNUICallback('close', function(_, cb)
    tabletOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-mechanic:server:getDashboard', function(res)
        if res and res.ok then activeTow = res.activeTow end
        cb(res or {})
    end)
end)

RegisterNUICallback('inspect', function(_, cb)
    local veh = getClosestVehicle(6.0)
    if veh == 0 then cb({ ok = false, message = Config.Messages.NoVehicle }) return end
    local plate = getPlate(veh)
    QBCore.Functions.TriggerCallback('prp-mechanic:server:inspectVehicle', function(res)
        cb(res or {})
    end, { plate = plate })
end)

RegisterNUICallback('repairIssue', function(data, cb)
    local veh = getClosestVehicle(6.0)
    if veh == 0 then cb({ ok = false, message = Config.Messages.NoVehicle }) return end
    local issue = data.issue
    local plate = getPlate(veh)
    SetNuiFocus(false, false)
    QBCore.Functions.Progressbar('prp_mech_repair_'..issue, 'Repairing '..issue..'...', repairTime(), false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
    }, { animDict = 'mini@repair', anim = 'fixing_a_ped', flags = 49 }, {}, {}, function()
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.TriggerCallback('prp-mechanic:server:repairIssue', function(res)
            SetNuiFocus(true, true)
            if res and res.ok then
                if issue == 'tyres' then
                    for i=0, 7 do SetVehicleTyreFixed(veh, i) end
                end
                if issue == 'radiator' or issue == 'fuelpump' or issue == 'ecu' or issue == 'transmission' then SetVehicleEngineHealth(veh, 1000.0) end
                if issue == 'axle' or issue == 'suspension' or issue == 'brakes' then SetVehicleBodyHealth(veh, 1000.0) end
                notify(res.message or 'Repair complete.', 'success')
            else
                notify(res and res.message or 'Repair failed.', 'error')
            end
            cb(res or {})
        end, { plate = plate, issue = issue })
    end, function()
        ClearPedTasks(PlayerPedId())
        SetNuiFocus(true, true)
        cb({ ok = false, message = 'Cancelled.' })
    end)
end)

RegisterNUICallback('basicRepair', function(data, cb)
    local veh = getClosestVehicle(6.0)
    if veh == 0 then cb({ ok = false, message = Config.Messages.NoVehicle }) return end
    local kind = data.kind or 'engine'
    SetNuiFocus(false, false)
    QBCore.Functions.Progressbar('prp_basic_repair', 'Working on vehicle...', repairTime(), false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
    }, { animDict = 'mini@repair', anim = 'fixing_a_ped', flags = 49 }, {}, {}, function()
        if kind == 'engine' then SetVehicleEngineHealth(veh, 1000.0) SetVehicleUndriveable(veh, false) end
        if kind == 'body' then SetVehicleBodyHealth(veh, 1000.0) end
        if kind == 'clean' then SetVehicleDirtLevel(veh, 0.0) end
        TriggerServerEvent('prp-mechanic:server:basicRepairReward', kind == 'clean' and 'small' or 'medium')
        ClearPedTasks(PlayerPedId())
        SetNuiFocus(true, true)
        cb({ ok = true, message = 'Vehicle work completed.' })
    end, function()
        ClearPedTasks(PlayerPedId())
        SetNuiFocus(true, true)
        cb({ ok = false, message = 'Cancelled.' })
    end)
end)

RegisterNUICallback('unlockSkill', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-mechanic:server:unlockSkill', function(res) cb(res or {}) end, data.skill)
end)

RegisterNUICallback('acceptTow', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-mechanic:server:acceptTow', function(res)
        if res and res.ok then
            activeTow = res.tow
            SetNewWaypoint(res.tow.pickup.x, res.tow.pickup.y)
            notify(res.message, 'success')
            TriggerEvent('prp-mechanic:client:spawnTowTarget', res.tow)
        end
        cb(res or {})
    end, data.jobId)
end)

RegisterNUICallback('cancelTow', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-mechanic:server:cancelTow', function(res)
        if res and res.ok then
            activeTow = nil
            if attachedEntity and DoesEntityExist(attachedEntity) then DetachEntity(attachedEntity, true, true) DeleteEntity(attachedEntity) end
            attachedEntity = nil
            cleanupTowPickup()
            if spawnedTowVehicle and DoesEntityExist(spawnedTowVehicle) then DeleteEntity(spawnedTowVehicle) end
            spawnedTowVehicle = nil
            cleanupTowDropoff()
            notify(res.message, 'success')
        end
        cb(res or {})
    end)
end)

RegisterNetEvent('prp-mechanic:client:rentTowTruck', function()
    QBCore.Functions.TriggerCallback('prp-mechanic:server:rentTowTruck', function(res)
        if not res or not res.ok then notify(res and res.message or 'Could not rent tow truck.', 'error') return end
        local model = joaat(res.model)
        if not requestModel(model) then
            QBCore.Functions.TriggerCallback('prp-mechanic:server:returnTowTruck', function() end)
            notify('Tow truck model could not be loaded.', 'error')
            return
        end
        local s = res.spawn
        local veh = CreateVehicle(model, s.x, s.y, s.z, s.w, true, true)
        if veh == 0 then
            QBCore.Functions.TriggerCallback('prp-mechanic:server:returnTowTruck', function() end)
            SetModelAsNoLongerNeeded(model)
            notify('Tow truck could not be spawned.', 'error')
            return
        end
        SetVehicleNumberPlateText(veh, 'PRPTOW'..math.random(10,99))
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        SetVehicleEngineOn(veh, true, true, false)
        setVehicleFuel(veh, 100.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', getPlate(veh))
        rentedTruck = veh
        SetModelAsNoLongerNeeded(model)
        notify(res.message, 'success')
    end)
end)

RegisterNetEvent('prp-mechanic:client:returnTowTruck', function()
    if not rentedTruck or not DoesEntityExist(rentedTruck) then notify('Your rented tow truck is not nearby or does not exist.', 'error') return end
    local pedDist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(rentedTruck))
    if pedDist > 12.0 then notify('Tow truck must be nearby.', 'error') return end
    local depotDist = #(Config.Locations.TowDepot.coords - GetEntityCoords(rentedTruck))
    if depotDist > Config.Locations.TowDepot.returnRadius then notify('Tow truck must be near the depot.', 'error') return end
    QBCore.Functions.TriggerCallback('prp-mechanic:server:returnTowTruck', function(res)
        if res and res.ok then
            SetEntityAsMissionEntity(rentedTruck, true, true)
            DeleteVehicle(rentedTruck)
            rentedTruck = nil
            notify(res.message, 'success')
        else
            notify(res and res.message or 'Unable to return truck.', 'error')
        end
    end)
end)

cleanupTowPickup = function(keepPed)
    if towPickupBlip and DoesBlipExist(towPickupBlip) then RemoveBlip(towPickupBlip) towPickupBlip = nil end
    if spawnedTowPed and DoesEntityExist(spawnedTowPed) and not keepPed then DeleteEntity(spawnedTowPed) spawnedTowPed = nil end
    if spawnedTowVehicle and DoesEntityExist(spawnedTowVehicle) then
        pcall(function()
            exports[Config.Target]:RemoveTargetEntity(spawnedTowVehicle, { 'Attach Tow Vehicle', 'Repair Vehicle On Site' })
        end)
    end
end

cleanupTowDropoff = function()
    if towDropoffBlip and DoesBlipExist(towDropoffBlip) then RemoveBlip(towDropoffBlip) towDropoffBlip = nil end
    pcall(function()
        exports[Config.Target]:RemoveZone('prp_tow_dropoff_active')
    end)
end

RegisterNetEvent('prp-mechanic:client:spawnTowTarget', function(tow)
    cleanupTowPickup()
    if spawnedTowVehicle and DoesEntityExist(spawnedTowVehicle) then DeleteEntity(spawnedTowVehicle) end
    spawnedTowVehicle = nil
    cleanupTowDropoff()

    local modelName = tow.vehicleModel or Config.Tow.TowVehicleModels[math.random(#Config.Tow.TowVehicleModels)]
    local model = joaat(modelName)
    if not requestModel(model) then
        QBCore.Functions.TriggerCallback('prp-mechanic:server:cancelTow', function() end)
        activeTow = nil
        SendNUIMessage({ action = 'towCancelled' })
        notify('Tow vehicle model could not be loaded. Contract cancelled.', 'error')
        return
    end

    local p = tow.pickup
    spawnedTowVehicle = CreateVehicle(model, p.x, p.y, p.z, p.w, true, true)
    if spawnedTowVehicle == 0 then
        QBCore.Functions.TriggerCallback('prp-mechanic:server:cancelTow', function() end)
        SetModelAsNoLongerNeeded(model)
        activeTow = nil
        SendNUIMessage({ action = 'towCancelled' })
        notify('Tow vehicle could not be spawned. Contract cancelled.', 'error')
        return
    end
    SetEntityAsMissionEntity(spawnedTowVehicle, true, true)
    SetVehicleOnGroundProperly(spawnedTowVehicle)
    SetVehicleEngineHealth(spawnedTowVehicle, 80.0)
    SetVehicleBodyHealth(spawnedTowVehicle, 360.0)
    SetVehiclePetrolTankHealth(spawnedTowVehicle, 450.0)
    SetVehicleUndriveable(spawnedTowVehicle, true)
    setVehicleFuel(spawnedTowVehicle, 18.0)
    SetVehicleDirtLevel(spawnedTowVehicle, 12.0)
    SetVehicleDoorOpen(spawnedTowVehicle, 4, false, false)
    SmashVehicleWindow(spawnedTowVehicle, 0)
    if math.random(100) <= 45 then SetVehicleTyreBurst(spawnedTowVehicle, math.random(0, 5), true, 1000.0) end

    local plate = getPlate(spawnedTowVehicle)
    QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, 'axle', math.random(25, 55))
    QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, 'fuelpump', math.random(20, 50))
    QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, 'radiator', math.random(25, 65))
    QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, 'transmission', math.random(15, 45))

    local netId = NetworkGetNetworkIdFromEntity(spawnedTowVehicle)
    TriggerServerEvent('prp-mechanic:server:setTowNetId', netId)

    local pedModel
    if tow.id ~= 'impound_recovery' then
        local pedModelName = tow.pedModel or 'a_m_y_business_02'
        pedModel = joaat(pedModelName)
        if not requestModel(pedModel) then
            pedModel = joaat('a_m_y_business_02')
            requestModel(pedModel)
        end
        local forward = GetEntityForwardVector(spawnedTowVehicle)
        local pedCoords = vector3(p.x + (forward.x * -2.0), p.y + (forward.y * -2.0), p.z)
        if HasModelLoaded(pedModel) then
            spawnedTowPed = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z, p.w, true, true)
            SetEntityAsMissionEntity(spawnedTowPed, true, true)
            playCustomerWave(spawnedTowPed)
        end
    end

    towPickupBlip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(towPickupBlip, 225)
    SetBlipColour(towPickupBlip, 5)
    SetBlipScale(towPickupBlip, 0.9)
    SetBlipRoute(towPickupBlip, true)
    SetBlipRouteColour(towPickupBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Broken Down Vehicle')
    EndTextCommandSetBlipName(towPickupBlip)

    SetNewWaypoint(p.x, p.y)
    if tow.id == 'basic_breakdown' then
        notify(('Roadside repair GPS set. The customer is waving beside the %s.'):format(modelName), 'primary')
    elseif tow.id == 'accident_recovery' then
        notify(('Accident recovery GPS set. Recover the %s and bring the customer back with you.'):format(modelName), 'primary')
    else
        notify(('Tow GPS set. Find the broken down %s.'):format(modelName), 'primary')
    end

    local targetOptions = {}
    if tow.id == 'basic_breakdown' then
        targetOptions[#targetOptions + 1] = mechanicTargetOption({ icon = 'fas fa-wrench', label = 'Repair Vehicle On Site', action = function() TriggerEvent('prp-mechanic:client:repairBreakdownOnSite') end })
    else
        targetOptions[#targetOptions + 1] = mechanicTargetOption({ icon = 'fas fa-link', label = 'Attach Tow Vehicle', action = function() TriggerEvent('prp-mechanic:client:attachTowVehicle') end })
    end

    exports[Config.Target]:AddTargetEntity(spawnedTowVehicle, {
        options = targetOptions,
        distance = 3.0
    })
    SetModelAsNoLongerNeeded(model)
    if pedModel then SetModelAsNoLongerNeeded(pedModel) end
end)

RegisterNetEvent('prp-mechanic:client:repairBreakdownOnSite', function()
    if not isActiveTow('basic_breakdown') then notify('This contract requires vehicle recovery.', 'error') return end
    if not spawnedTowVehicle or not DoesEntityExist(spawnedTowVehicle) then notify('Breakdown vehicle not found.', 'error') return end
    if not spawnedTowPed or not DoesEntityExist(spawnedTowPed) then notify('The customer is not nearby.', 'error') return end

    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - GetEntityCoords(spawnedTowVehicle)) > 6.0 then notify('Move closer to the breakdown vehicle.', 'error') return end

    QBCore.Functions.Progressbar('prp_roadside_repair', 'Repairing roadside vehicle...', repairTime(), false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
    }, { animDict = 'mini@repair', anim = 'fixing_a_ped', flags = 49 }, {}, {}, function()
        ClearPedTasks(ped)

        local vehicle = spawnedTowVehicle
        local customer = spawnedTowPed
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 900.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
        SetVehicleUndriveable(vehicle, false)
        setVehicleFuel(vehicle, 45.0)
        for i = 0, 7 do SetVehicleTyreFixed(vehicle, i) end

        QBCore.Functions.TriggerCallback('prp-mechanic:server:completeTow', function(res)
            if res and res.ok then
                cleanupTowPickup(true)
                activeTow = nil
                spawnedTowVehicle = nil
                spawnedTowPed = nil
                SendNUIMessage({ action = 'towCancelled' })
                sendCustomerAwayFromVehicle(vehicle, customer)
                notify((res.message or 'Roadside repair complete.')..' Paid $'..(res.reward or 0), 'success')
            else
                notify(res and res.message or 'Could not complete roadside repair.', 'error')
            end
        end)
    end, function()
        ClearPedTasks(ped)
        notify('Roadside repair cancelled.', 'error')
    end)
end)

RegisterNetEvent('prp-mechanic:client:attachTowVehicle', function()
    if not activeTow then notify(Config.Messages.NoActiveTow, 'error') return end
    if not rentedTruck or not DoesEntityExist(rentedTruck) then notify('Retrieve your tow truck first.', 'error') return end
    if not spawnedTowVehicle or not DoesEntityExist(spawnedTowVehicle) then notify('Tow vehicle not found.', 'error') return end
    local truckCoords = GetEntityCoords(rentedTruck)
    local carCoords = GetEntityCoords(spawnedTowVehicle)
    if #(truckCoords - carCoords) > Config.Tow.AttachDistance then notify('Tow truck is too far away.', 'error') return end
    local isAccidentRecovery = isActiveTow('accident_recovery')
    if isAccidentRecovery and (not spawnedTowPed or not DoesEntityExist(spawnedTowPed)) then notify('The accident customer is not nearby.', 'error') return end
    if isAccidentRecovery and not seatCustomerInTowTruck() then return end

    cleanupTowPickup(isAccidentRecovery)
    AttachEntityToEntity(spawnedTowVehicle, rentedTruck, GetEntityBoneIndexByName(rentedTruck, 'bodyshell'), 0.0, -2.2, 0.95, 0.0, 0.0, 0.0, false, false, true, false, 20, true)
    attachedEntity = spawnedTowVehicle
    local drop, dropLabel
    if isAccidentRecovery then
        drop, dropLabel = getRandomWorkshopDropoff()
    else
        drop = Config.Locations.TowDropoffs[math.random(#Config.Locations.TowDropoffs)]
        dropLabel = 'Tow Drop-off'
    end
    activeTow.dropoff = drop
    SetNewWaypoint(drop.x, drop.y)
    if isAccidentRecovery then
        notify('Vehicle attached. The customer is getting in. Take both to the mechanic shop.', 'success')
    else
        notify('Vehicle attached. Take it to the marked drop-off.', 'success')
    end

    cleanupTowDropoff()
    towDropoffBlip = AddBlipForCoord(drop.x, drop.y, drop.z)
    SetBlipSprite(towDropoffBlip, 478)
    SetBlipColour(towDropoffBlip, 2)
    SetBlipScale(towDropoffBlip, 0.85)
    SetBlipRoute(towDropoffBlip, true)
    SetBlipRouteColour(towDropoffBlip, 2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(dropLabel or 'Tow Drop-off')
    EndTextCommandSetBlipName(towDropoffBlip)

    exports[Config.Target]:AddCircleZone('prp_tow_dropoff_active', drop, Config.Tow.CompleteDistance, {
        name = 'prp_tow_dropoff_active', debugPoly = Config.Debug,
    }, {
        options = {
            mechanicTargetOption({ icon = 'fas fa-check', label = 'Complete Tow Contract', action = function() TriggerEvent('prp-mechanic:client:completeTow') end })
        },
        distance = Config.Tow.CompleteDistance
    })
end)

RegisterNetEvent('prp-mechanic:client:completeTow', function()
    if not activeTow then notify(Config.Messages.NoActiveTow, 'error') return end
    if not attachedEntity or not DoesEntityExist(attachedEntity) then notify('No vehicle attached.', 'error') return end
    local wasAccidentRecovery = isActiveTow('accident_recovery')
    if wasAccidentRecovery and spawnedTowPed and DoesEntityExist(spawnedTowPed) and rentedTruck and DoesEntityExist(rentedTruck) and not IsPedInVehicle(spawnedTowPed, rentedTruck, false) then
        notify('Bring the accident customer with you in the tow truck.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('prp-mechanic:server:completeTow', function(res)
        if res and res.ok then
            DetachEntity(attachedEntity, true, true)
            DeleteEntity(attachedEntity)
            attachedEntity = nil
            spawnedTowVehicle = nil
            if wasAccidentRecovery then
                releaseAccidentCustomer()
            else
                cleanupTowPickup()
            end
            activeTow = nil
            cleanupTowDropoff()
            notify((res.message or 'Tow complete.')..' Paid $'..(res.reward or 0), 'success')
        else
            notify(res and res.message or 'Could not complete tow.', 'error')
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    cleanupTowDropoff()
    cleanupTowPickup()
    if spawnedTowVehicle and DoesEntityExist(spawnedTowVehicle) then DeleteEntity(spawnedTowVehicle) end
    if rentedTruck and DoesEntityExist(rentedTruck) then DeleteVehicle(rentedTruck) end
end)

CreateThread(function()
    while true do
        Wait(Config.DamageDetection.TickMs)
        if not Config.DamageDetection.Enabled then goto continue end
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local speed = GetEntitySpeed(veh) * 3.6
            if lastVeh ~= veh then lastSpeed = speed lastVeh = veh end
            local delta = lastSpeed - speed
            local plate = getPlate(veh)
            if delta >= Config.DamageDetection.MinCrashDeltaKmh and lastSpeed >= Config.DamageDetection.HardCrashSpeedKmh then
                local severe = lastSpeed >= Config.DamageDetection.SevereCrashSpeedKmh
                local dmg = severe and math.random(12, 28) or math.random(4, 14)
                local roll = math.random(1, 6)
                local issue = ({'axle','radiator','suspension','brakes','transmission','fuelpump'})[roll]
                QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, issue, dmg)
                if severe then
                    QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, 'ecu', math.random(3, 12))
                end
            end
            if GetGameTimer() - lastWear > Config.DamageDetection.WearTickMs then
                lastWear = GetGameTimer()
                if math.random(100) <= Config.DamageDetection.WearChance then
                    local issue = ({'brakes','fuelpump','transmission','tyres','suspension'})[math.random(5)]
                    QBCore.Functions.TriggerCallback('prp-mechanic:server:damageVehicleIssue', function() end, plate, issue, math.random(1, 4))
                end
            end
            lastSpeed = speed
        else
            lastSpeed = 0.0
            lastVeh = 0
        end
        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(3500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local plate = getPlate(veh)
            QBCore.Functions.TriggerCallback('prp-mechanic:server:getVehicleIssues', function(res)
                if not res or not res.ok or not res.issues then return end
                local issues = res.issues
                if (issues.fuelpump or 100) < 35 and math.random(100) < 12 then
                    SetVehicleEngineOn(veh, false, true, true)
                end
                if (issues.radiator or 100) < 35 then
                    SetVehicleEngineHealth(veh, math.max(100.0, GetVehicleEngineHealth(veh) - 8.0))
                end
                if (issues.transmission or 100) < 35 then
                    SetVehicleCheatPowerIncrease(veh, -25.0)
                else
                    SetVehicleCheatPowerIncrease(veh, 0.0)
                end
                if (issues.axle or 100) < 35 or (issues.suspension or 100) < 35 then
                    SetVehicleReduceGrip(veh, true)
                else
                    SetVehicleReduceGrip(veh, false)
                end
                if (issues.brakes or 100) < 30 then
                    SetVehicleHandbrake(veh, math.random(100) < 2)
                end
            end, plate)
        end
    end
end)
