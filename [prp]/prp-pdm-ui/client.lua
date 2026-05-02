local Open = false
local LastMessage = nil

local function Send(message)
    LastMessage = message
    SendNUIMessage(message)
end

local function OpenUI(message)
    Open = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    Send(message)
end

local function CloseUI()
    Open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('prp-pdm-ui:client:sendMessage', function(message)
    if not message or not message.action then return end

    if message.action == 'close' then
        CloseUI()
        return
    end

    if message.action == 'open' or message.action == 'openFinanceShell' or message.action == 'openManagementShell' or message.action == 'debugOpen' then
        OpenUI(message)
        return
    end

    Send(message)
end)

RegisterNetEvent('prp-pdm-ui:client:close', function()
    CloseUI()
end)

RegisterNUICallback('ready', function(_, cb)
    TriggerEvent('qb-vehicleshop:client:uiReady')
    if Open and LastMessage then Send(LastMessage) end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseUI()
    TriggerEvent('qb-vehicleshop:client:uiClose')
    cb('ok')
end)

RegisterNUICallback('previewVehicle', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiPreviewVehicle', data or {})
    cb('ok')
end)

RegisterNUICallback('setColor', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiSetColor', data or {})
    cb('ok')
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiPurchaseVehicle', data or {})
    cb('ok')
end)

RegisterNUICallback('testDrive', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiTestDrive', data or {})
    cb('ok')
end)

RegisterNUICallback('openManagement', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiOpenManagement', data or {})
    cb('ok')
end)

RegisterNUICallback('saveStock', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiSaveStock', data or {})
    cb('ok')
end)

RegisterNUICallback('makeFinancePayment', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiMakeFinancePayment', data or {})
    cb('ok')
end)

RegisterNUICallback('payFinanceFull', function(data, cb)
    TriggerEvent('qb-vehicleshop:client:uiPayFinanceFull', data or {})
    cb('ok')
end)

RegisterCommand('prppdmtestui', function()
    OpenUI({ action = 'debugOpen' })
end, false)

RegisterCommand('closepdmui', function()
    CloseUI()
end, false)
