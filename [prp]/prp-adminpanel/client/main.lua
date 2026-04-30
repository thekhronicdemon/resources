local QBCore = exports['qb-core']:GetCoreObject()
local open = false
local wasDead = false

local function closePanel(sendMessage)
    open = false
    SetNuiFocus(false, false)
    if sendMessage then
        SendNUIMessage({ action = 'close' })
    end
end

RegisterNetEvent('prp-adminpanel:client:requestOpen', function()
    TriggerServerEvent('prp-adminpanel:server:open')
end)

RegisterNetEvent('prp-adminpanel:client:open', function(data)
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNUICallback('close', function(_, cb)
    closePanel(false)
    cb(true)
end)

RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:getDashboard', function(data) cb(data or false) end)
end)
RegisterNUICallback('searchPlayer', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:searchPlayer', function(results) cb(results or {}) end, data.query)
end)
RegisterNUICallback('getProfile', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:getProfile', function(result) cb(result or {}) end, data)
end)
RegisterNUICallback('getLogs', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:getLogs', function(result) cb(result or {}) end, data or {})
end)
RegisterNUICallback('getAudit', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:getAudit', function(result) cb(result or {}) end)
end)
RegisterNUICallback('kickPlayer', function(data, cb) TriggerServerEvent('prp-adminpanel:server:kick', data.id, data.reason); cb(true) end)
RegisterNUICallback('banPlayer', function(data, cb) TriggerServerEvent('prp-adminpanel:server:ban', data.id, data.reason, data.hours); cb(true) end)
RegisterNUICallback('addNote', function(data, cb) TriggerServerEvent('prp-adminpanel:server:addNote', data); cb(true) end)
RegisterNUICallback('addFlag', function(data, cb) TriggerServerEvent('prp-adminpanel:server:addFlag', data); cb(true) end)
	RegisterNUICallback("editNote", function(data, cb) TriggerServerEvent("prp-adminpanel:server:editNote", data); cb(true) end)
	RegisterNUICallback("deleteNote", function(data, cb) TriggerServerEvent("prp-adminpanel:server:deleteNote", data); cb(true) end)
	RegisterNUICallback("editFlag", function(data, cb) TriggerServerEvent("prp-adminpanel:server:editFlag", data); cb(true) end)
	RegisterNUICallback("deleteFlag", function(data, cb) TriggerServerEvent("prp-adminpanel:server:deleteFlag", data); cb(true) end)
	RegisterNUICallback("setMoney", function(data, cb) TriggerServerEvent("prp-adminpanel:server:setMoney", data); cb(true) end)
	RegisterNUICallback("addItem", function(data, cb) TriggerServerEvent("prp-adminpanel:server:addItem", data); cb(true) end)
	RegisterNUICallback("removeItem", function(data, cb) TriggerServerEvent("prp-adminpanel:server:removeItem", data); cb(true) end)
	RegisterNUICallback("revokeLicense", function(data, cb) TriggerServerEvent("prp-adminpanel:server:revokeLicense", data); cb(true) end)
	RegisterNUICallback("spawnOwnedVehicle", function(data, cb) TriggerServerEvent("prp-adminpanel:server:spawnOwnedVehicle", data); cb(true) end)
	RegisterNUICallback("deleteOwnedVehicle", function(data, cb) TriggerServerEvent("prp-adminpanel:server:deleteOwnedVehicle", data); cb(true) end)
RegisterNUICallback('devAction', function(data, cb)
    if data and data.action == 'spawnObject' then
        closePanel(true)
    end
    TriggerEvent('prp-adminpanel:client:devAction', data)
    cb(true)
end)
RegisterNUICallback('playerAction', function(data, cb) TriggerServerEvent('prp-adminpanel:server:playerAction', data); cb(true) end)
RegisterNUICallback('adminMassAction', function(data, cb) TriggerServerEvent('prp-adminpanel:server:adminMassAction', data); cb(true) end)

CreateThread(function()
    while true do
        if open and IsControlJustPressed(0, 322) then
            closePanel(true)
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped)
        if dead and not wasDead then
            local coords = GetEntityCoords(ped)
            TriggerServerEvent('prp-adminpanel:server:deathLog', ('Death at %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z))
        end
        wasDead = dead
        Wait(1500)
    end
end)


local frozenByAdmin = false
local spectating = false

RegisterNetEvent('prp-adminpanel:client:teleportToCoords', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
end)

RegisterNetEvent('prp-adminpanel:client:spawnOwnedVehicle', function(data)
    local model = data.vehicle and data.vehicle ~= '' and data.vehicle or tonumber(data.hash)
    if not model then
        QBCore.Functions.Notify('This vehicle has no valid model saved.', 'error')
        return
    end

    local ped = PlayerPedId()
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local heading = GetEntityHeading(ped)
    QBCore.Functions.SpawnVehicle(model, function(vehicle)
        if not vehicle or vehicle == 0 then
            QBCore.Functions.Notify('Could not spawn vehicle.', 'error')
            return
        end

        local props = {}
        if type(data.mods) == 'string' and data.mods ~= '' then
            local ok, decoded = pcall(json.decode, data.mods)
            if ok and type(decoded) == 'table' then props = decoded end
        elseif type(data.mods) == 'table' then
            props = data.mods
        end
        if next(props) and QBCore.Functions.SetVehicleProperties then
            QBCore.Functions.SetVehicleProperties(vehicle, props)
        end

        local plate = tostring(data.plate or 'ADMIN')
        SetVehicleNumberPlateText(vehicle, plate)
        SetEntityHeading(vehicle, heading)
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleFuelLevel(vehicle, tonumber(data.fuel) or 100.0)
        SetVehicleEngineHealth(vehicle, tonumber(data.engine) or 1000.0)
        SetVehicleBodyHealth(vehicle, tonumber(data.body) or 1000.0)
        QBCore.Functions.Notify(('Spawned owned vehicle %s.'):format(plate), 'success')
    end, { x = spawnCoords.x, y = spawnCoords.y, z = spawnCoords.z, w = heading }, true, false)
end)

RegisterNetEvent('prp-adminpanel:client:toggleFreezeSelf', function()
    frozenByAdmin = not frozenByAdmin
    FreezeEntityPosition(PlayerPedId(), frozenByAdmin)
    QBCore.Functions.Notify(frozenByAdmin and 'You have been frozen by staff.' or 'You have been unfrozen by staff.', frozenByAdmin and 'error' or 'success')
end)

RegisterNetEvent('prp-adminpanel:client:killSelf', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('prp-adminpanel:client:healSelf', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('prp-adminpanel:client:reviveSelf', function()
    local ped = PlayerPedId()
    TriggerEvent('hospital:client:Revive')
    TriggerEvent('qb-ambulancejob:client:revive')
    Wait(500)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end)

RegisterNetEvent('prp-adminpanel:client:spectatePlayer', function(targetServerId)
    local target = GetPlayerFromServerId(tonumber(targetServerId))
    if target == -1 then
        QBCore.Functions.Notify('Player is not in scope. Spawn-to them first or get closer.', 'error')
        return
    end

    local targetPed = GetPlayerPed(target)
    if not DoesEntityExist(targetPed) then return end

    spectating = not spectating
    if spectating then
        SetNuiFocus(false, false)
        NetworkSetInSpectatorMode(true, targetPed)
        QBCore.Functions.Notify('Spectating. Use the admin panel Spectate button again to stop.', 'primary')
    else
        NetworkSetInSpectatorMode(false, PlayerPedId())
        QBCore.Functions.Notify('Stopped spectating.', 'success')
    end
end)
