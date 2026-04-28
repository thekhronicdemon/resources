local isOpen = false

RegisterNetEvent('prp-crates:client:startRoll', function(data)
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        payload = data
    })
end)

RegisterNUICallback('rollFinished', function(_, cb)
    TriggerServerEvent('prp-crates:server:finishRoll')
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    isOpen = false
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    isOpen = false
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
