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
RegisterNUICallback('addNote', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:addNote', function(result)
        cb(result or { ok = false })
    end, data or {})
end)
RegisterNUICallback('getNotes', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-adminpanel:server:getNotes', function(result) cb(result or {}) end, data and data.citizenid or '')
end)
RegisterNUICallback('setMoney', function(data, cb) TriggerServerEvent('prp-adminpanel:server:setMoney', data); cb(true) end)
RegisterNUICallback('addItem', function(data, cb) QBCore.Functions.TriggerCallback('prp-adminpanel:server:addItem', function(result) cb(result or { ok = false }) end, data or {}) end)
RegisterNUICallback('removeItem', function(data, cb) QBCore.Functions.TriggerCallback('prp-adminpanel:server:removeItem', function(result) cb(result or { ok = false }) end, data or {}) end)
RegisterNUICallback('addFlag', function(data, cb) TriggerServerEvent('prp-adminpanel:server:addFlag', data); cb(true) end)
RegisterNUICallback('devAction', function(data, cb) TriggerEvent('prp-adminpanel:client:devAction', data); cb(true) end)

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
