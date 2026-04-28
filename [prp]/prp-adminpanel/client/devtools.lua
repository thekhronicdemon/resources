local spawnedVehicles = {}
local spawnedObjects = {}
local spawnedPeds = {}
local placingObject = nil
local placingFrozen = true

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function getClosestEntityOfType(entityType, radius)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local poolName = entityType == 'object' and 'CObject' or 'CPed'
    local closest, closestDist = 0, radius or 6.0

    for _, entity in ipairs(GetGamePool(poolName)) do
        if entity ~= ped and DoesEntityExist(entity) then
            local dist = #(pcoords - GetEntityCoords(entity))
            if dist < closestDist then
                closest = entity
                closestDist = dist
            end
        end
    end

    return closest, closestDist
end

local function raycastFromCamera(distance)
    local camRot = GetGameplayCamRot(2)
    local camCoord = GetGameplayCamCoord()
    local pitch = math.rad(camRot.x)
    local yaw = math.rad(camRot.z)
    local dir = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local dest = camCoord + (dir * distance)
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, _, entity = GetShapeTestResult(ray)
    return hit == 1, endCoords, entity
end

RegisterNetEvent('prp-adminpanel:client:devAction', function(data)
    local action = data.action

    if action == 'spawnVehicle' then
        local model = data.model
        local hash = loadModel(model)
        if not hash then return end
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local veh = CreateVehicle(hash, coords.x + 2.0, coords.y, coords.z, GetEntityHeading(ped), true, false)
        SetPedIntoVehicle(ped, veh, -1)
        spawnedVehicles[#spawnedVehicles + 1] = veh
        SetModelAsNoLongerNeeded(hash)
    elseif action == 'spawnPed' then
        local hash = loadModel(data.model)
        if not hash then return end
        local hit, coords = raycastFromCamera(15.0)
        if not hit then coords = GetEntityCoords(PlayerPedId()) + vector3(1.0, 0.0, 0.0) end
        local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()), true, false)
        FreezeEntityPosition(ped, data.freeze == true)
        spawnedPeds[#spawnedPeds + 1] = ped
        SetModelAsNoLongerNeeded(hash)
    elseif action == 'spawnObject' then
        local hash = loadModel(data.model)
        if not hash then return end
        local hit, coords = raycastFromCamera(15.0)
        if not hit then coords = GetEntityCoords(PlayerPedId()) + vector3(1.0, 0.0, 0.0) end
        local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, false, false)
        SetEntityAlpha(obj, 150, false)
        SetEntityCollision(obj, false, false)
        placingObject = obj
        placingFrozen = data.freeze == true
        spawnedObjects[#spawnedObjects + 1] = obj
    elseif action == 'closestObject' then
        local entity, dist = getClosestEntityOfType('object', 10.0)
        if entity and entity ~= 0 then
            local model = GetEntityModel(entity)
            local coords = GetEntityCoords(entity)
            print(('[ADMIN PANEL] Closest object entity=%s model=%s distance=%.2f coords=%s'):format(entity, model, dist, coords))
        end
    elseif action == 'closestPed' then
        local entity, dist = getClosestEntityOfType('ped', 10.0)
        if entity and entity ~= 0 and IsEntityAPed(entity) then
            print(('[ADMIN PANEL] Closest ped entity=%s model=%s distance=%.2f'):format(entity, GetEntityModel(entity), dist))
        end
    elseif action == 'deleteClosestObject' then
        local entity, dist = getClosestEntityOfType('object', 8.0)
        if entity and entity ~= 0 then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
            print(('[ADMIN PANEL] Deleted closest object entity=%s distance=%.2f'):format(entity, dist))
        end
    elseif action == 'deleteLookingAt' then
        local _, _, entity = raycastFromCamera(8.0)
        if entity and entity ~= 0 then DeleteEntity(entity) end
    end
end)

CreateThread(function()
    while true do
        if placingObject and DoesEntityExist(placingObject) then
            local hit, coords = raycastFromCamera(20.0)
            if hit then
                SetEntityCoords(placingObject, coords.x, coords.y, coords.z, false, false, false, false)
            end
            if IsControlJustPressed(0, 191) then -- ENTER
                SetEntityAlpha(placingObject, 255, false)
                SetEntityCollision(placingObject, true, true)
                FreezeEntityPosition(placingObject, placingFrozen)
                placingObject = nil
            elseif IsControlJustPressed(0, 194) then -- BACKSPACE
                DeleteEntity(placingObject)
                placingObject = nil
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
