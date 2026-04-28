local pendingChartRequests = {}
local requestCounter = 0

local function OpenBandHero(mode)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = mode
    })
end

RegisterCommand("bandhero", function()
    OpenBandHero("openPlayer")
end, false)

RegisterCommand("bandheroedit", function()
    OpenBandHero("openEditor")
end, false)

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback("notify", function(data, cb)
    local msg = data.message or "Band Hero"
    TriggerEvent("chat:addMessage", {
        color = { 120, 200, 255 },
        args = { "Band Hero", msg }
    })
    cb({ ok = true })
end)

RegisterNUICallback("saveChart", function(data, cb)
    TriggerServerEvent("prp-bandhero:server:saveChart", data)

    local count = 0
    if data and data.notes then
        count = #data.notes
    end

    TriggerEvent("chat:addMessage", {
        color = { 120, 255, 160 },
        args = { "Band Hero", ("Chart save requested. Notes: %s"):format(count) }
    })

    cb({ ok = true })
end)

RegisterNUICallback("loadChart", function(data, cb)
    requestCounter = requestCounter + 1
    local requestId = tostring(GetGameTimer()) .. "_" .. tostring(requestCounter)

    pendingChartRequests[requestId] = cb

    TriggerServerEvent("prp-bandhero:server:loadChart", requestId, data)

    SetTimeout(5000, function()
        if pendingChartRequests[requestId] then
            pendingChartRequests[requestId]({
                ok = false,
                notes = {},
                error = "Chart request timed out"
            })
            pendingChartRequests[requestId] = nil
        end
    end)
end)

RegisterNetEvent("prp-bandhero:client:receiveChart", function(requestId, result)
    local cb = pendingChartRequests[requestId]
    if cb then
        cb(result or { ok = false, notes = {} })
        pendingChartRequests[requestId] = nil
    end
end)
