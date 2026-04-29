local QBCore = exports['qb-core']:GetCoreObject()
local open = false
local wasDead = false

RegisterNetEvent('prp-adminpanel:client:requestOpen', function()
    TriggerServerEvent('prp-adminpanel:server:open')
end)

RegisterNetEvent('prp-adminpanel:client:open', function(data)
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
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
RegisterNUICallback('devAction', function(data, cb) TriggerEvent('prp-adminpanel:client:devAction', data); cb(true) end)
RegisterNUICallback('playerAction', function(data, cb) TriggerServerEvent('prp-adminpanel:server:playerAction', data); cb(true) end)
RegisterNUICallback('adminMassAction', function(data, cb) TriggerServerEvent('prp-adminpanel:server:adminMassAction', data); cb(true) end)

CreateThread(function()
    while true do
        if open and IsControlJustPressed(0, 322) then
            open = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
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
