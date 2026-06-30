local QBCore = nil
local spawnedLifts = {}
local spawnedControls = {}
local liftStates = {}
local localHeights = {}

local function notify(msg, msgType)
    Config.Notify(msg, msgType)
end

RegisterNetEvent('modular_carlift_prp:client:notify', function(msg, msgType)
    notify(msg, msgType)
end)

local function getCore()
    if QBCore then return QBCore end
    if GetResourceState(Config.CoreName) == 'started' then
        QBCore = exports[Config.CoreName]:GetCoreObject()
    end
    return QBCore
end

local function hasJobAccess()
    if not Config.UseQBCoreJobCheck then return true end
    local core = getCore()
    if not core then return true end
    local data = core.Functions.GetPlayerData()
    local jobName = data and data.job and data.job.name
    return jobName and Config.AllowedJobs[jobName] == true
end

local function loadModel(model)
    if not IsModelInCdimage(model) then
        print('[modular_carlift_prp] Missing model: ' .. tostring(model))
        return false
    end
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() > timeout then
            print('[modular_carlift_prp] Failed loading model: ' .. tostring(model))
            return false
        end
    end
    return true
end

local function getLiftById(liftId)
    for _, lift in ipairs(Config.Lifts) do
        if lift.id == liftId then return lift end
    end
    return nil
end

local function setLiftHeight(liftId, height)
    local lift = getLiftById(liftId)
    local obj = spawnedLifts[liftId]
    if not lift or not obj or not DoesEntityExist(obj) then return end

    local maxHeight = lift.maxHeight or Config.MaxHeight
    height = math.max(0.0, math.min(height, maxHeight))
    localHeights[liftId] = height

    SetEntityCoordsNoOffset(obj, lift.coords.x, lift.coords.y, lift.coords.z + height, true, true, true)
    SetEntityHeading(obj, lift.coords.w)
    SetEntityCollision(obj, true, true)
    FreezeEntityPosition(obj, true)
end

local function startLift(liftId, direction)
    if not hasJobAccess() then notify('You are not a mechanic.', 'error') return end
    local currentHeight = localHeights[liftId] or 0.0
    TriggerServerEvent('modular_carlift_prp:server:setDirection', liftId, direction, currentHeight)

    if direction == 'up' then
        notify('Lift going up.', 'primary')
    elseif direction == 'down' then
        notify('Lift going down.', 'primary')
    else
        notify('Lift stopped.', 'primary')
    end
end

local function toggleLock(liftId)
    if not hasJobAccess() then notify('You are not a mechanic.', 'error') return end
    TriggerServerEvent('modular_carlift_prp:server:toggleLock', liftId)
    notify('Lift lock toggled.', 'primary')
end

local function addTarget(entity, liftId, label)
    exports[Config.TargetName]:AddTargetEntity(entity, {
        options = {
            {
                icon = 'fas fa-arrow-up',
                label = 'Raise ' .. label,
                action = function() startLift(liftId, 'up') end,
                canInteract = function() return hasJobAccess() end,
            },
            {
                icon = 'fas fa-hand',
                label = 'Stop ' .. label,
                action = function() startLift(liftId, 'stop') end,
                canInteract = function() return hasJobAccess() end,
            },
            {
                icon = 'fas fa-arrow-down',
                label = 'Lower ' .. label,
                action = function() startLift(liftId, 'down') end,
                canInteract = function() return hasJobAccess() end,
            },
            {
                icon = 'fas fa-lock',
                label = 'Toggle Lift Lock',
                action = function() toggleLock(liftId) end,
                canInteract = function() return hasJobAccess() end,
            },
        },
        distance = Config.TargetDistance,
    })
end

local function spawnLifts()
    if not loadModel(Config.LiftModel) then return end
    loadModel(Config.ControlModel)

    for _, lift in ipairs(Config.Lifts) do
        local c = lift.coords

        local obj = CreateObject(Config.LiftModel, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(obj, c.w)
        SetEntityLodDist(obj, 0xFFFF)
        SetEntityCollision(obj, true, true)
        FreezeEntityPosition(obj, true)
        SetEntityAsMissionEntity(obj, true, true)
        spawnedLifts[lift.id] = obj
        localHeights[lift.id] = 0.0

        local cc = lift.control or vector4(c.x + 2.0, c.y, c.z, c.w)
        local control = CreateObject(Config.ControlModel, cc.x, cc.y, cc.z - 1.0, false, false, false)
        SetEntityHeading(control, cc.w)
        SetEntityCollision(control, true, true)
        FreezeEntityPosition(control, true)
        SetEntityAsMissionEntity(control, true, true)
        spawnedControls[lift.id] = control

        if GetResourceState(Config.TargetName) == 'started' then
            addTarget(control, lift.id, lift.label or lift.id)
            addTarget(obj, lift.id, lift.label or lift.id)
        else
            print('[modular_carlift_prp] qb-target is not started.')
        end
    end
end

RegisterNetEvent('modular_carlift_prp:client:syncStates', function(states)
    liftStates = states or {}
    for liftId, state in pairs(liftStates) do
        if state.height then setLiftHeight(liftId, state.height) end
    end
end)

RegisterNetEvent('modular_carlift_prp:client:syncState', function(liftId, state)
    liftStates[liftId] = state or {}
end)

CreateThread(function()
    Wait(1000)
    getCore()
    spawnLifts()
    TriggerServerEvent('modular_carlift_prp:server:requestStates')
end)

-- Realistic collision lift loop.
-- No AttachEntityToEntity. No vehicle freezing. No vehicle coords.
-- Car is moved only if GTA physics/collision carries it on the platform.
CreateThread(function()
    while true do
        local sleep = 250

        for liftId, state in pairs(liftStates) do
            local lift = getLiftById(liftId)
            local obj = spawnedLifts[liftId]
            if lift and obj and DoesEntityExist(obj) then
                local direction = state.direction or 'stop'
                if direction ~= 'stop' then
                    sleep = Config.MoveDelay or 0

                    local maxHeight = lift.maxHeight or Config.MaxHeight
                    local height = localHeights[liftId] or 0.0
                    local speed = Config.MoveSpeed

                    if direction == 'up' and (maxHeight - height) <= Config.SlowDownNearTop then
                        speed = Config.MoveSpeedSlow
                    elseif direction == 'down' and height <= Config.SlowDownNearBottom then
                        speed = Config.MoveSpeedSlow
                    end

                    if direction == 'up' then
                        height = height + speed
                        if height >= maxHeight then
                            height = maxHeight
                            TriggerServerEvent('modular_carlift_prp:server:setDirection', liftId, 'stop', height)
                        end
                    elseif direction == 'down' then
                        height = height - speed
                        if height <= 0.0 then
                            height = 0.0
                            TriggerServerEvent('modular_carlift_prp:server:setDirection', liftId, 'stop', height)
                        end
                    end

                    setLiftHeight(liftId, height)

                    -- Update server height occasionally so late joiners get the right position.
                    if math.random(1, 25) == 1 then
                        TriggerServerEvent('modular_carlift_prp:server:updateHeight', liftId, height)
                    end
                else
                    if state.height and math.abs((localHeights[liftId] or 0.0) - state.height) > 0.05 then
                        setLiftHeight(liftId, state.height)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterCommand('liftcoords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    print(('LIFT COORDS: coords = vector4(%.2f, %.2f, %.2f, %.2f),'):format(coords.x, coords.y, coords.z, heading))
    notify('Lift coords printed to F8.', 'primary')
end, false)

RegisterCommand('liftmodels', function()
    print('LiftModel nacelle loaded: ' .. tostring(IsModelInCdimage(Config.LiftModel)))
    notify('Model check printed to F8.', 'primary')
end, false)

RegisterCommand('liftstop', function()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local bestLift, bestDist = nil, 9999.0

    for _, lift in ipairs(Config.Lifts) do
        local lc = vector3(lift.coords.x, lift.coords.y, lift.coords.z)
        local d = #(pc - lc)
        if d < bestDist then bestLift = lift bestDist = d end
    end

    if bestLift then startLift(bestLift.id, 'stop') end
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, obj in pairs(spawnedLifts) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    for _, obj in pairs(spawnedControls) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
end)
