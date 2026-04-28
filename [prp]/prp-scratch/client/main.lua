local QBCore = exports['qb-core']:GetCoreObject()

local isOpen = false
local currentTicket = nil
local revealed = {}

local function setNui(state, payload)
    SetNuiFocus(state, state)
    SendNUIMessage(payload)
end

local function resetTicketState()
    isOpen = false
    currentTicket = nil
    revealed = {}
    SetNuiFocus(false, false)
end

RegisterNetEvent('prp-scratch:client:openTicket', function(ticketData)
    if isOpen and Config.AllowOnlyOneActiveTicket then
        QBCore.Functions.Notify(Config.Messages.AlreadyOpen, 'error')
        return
    end

    isOpen = true
    currentTicket = ticketData
    revealed = {}

    setNui(true, {
        action = 'open',
        config = {
            title = Config.UI.TicketTitle,
            subtitle = Config.UI.TicketSubtitle,
            showLegend = Config.UI.ShowLegend,
            scratchText = Config.UI.ScratchButtonText,
            escLabel = Config.UI.EscLabel,
            gridColumns = Config.UI.GridColumns,
            boxCount = Config.UI.BoxCount,
            openDuration = Config.Animations.OpenDuration,
            revealDuration = Config.Animations.RevealDuration,
            glowWinners = Config.Animations.GlowWinners,
        },
        ticket = ticketData,
    })

    if Config.FrameworkNotify then
        QBCore.Functions.Notify(Config.Messages.TicketOpened, 'primary')
    end
end)

RegisterNUICallback('scratchBox', function(data, cb)
    local index = tonumber(data.index)
    if not isOpen or not currentTicket or not index then
        cb({ ok = false })
        return
    end

    if revealed[index] then
        cb({ ok = true, already = true })
        return
    end

    revealed[index] = true
    local square = currentTicket.boxes[index]

    local scratchedCount = 0
    for _ in pairs(revealed) do scratchedCount = scratchedCount + 1 end

    cb({
        ok = true,
        square = square,
        allScratched = (scratchedCount >= #currentTicket.boxes)
    })

    if scratchedCount >= #currentTicket.boxes and Config.RequireAllBoxesScratchedBeforeFinish then
        TriggerServerEvent('prp-scratch:server:finishTicket')
    end
end)

RegisterNUICallback('close', function(_, cb)
    if isOpen then
        TriggerServerEvent('prp-scratch:server:closeTicket')
    end
    resetTicketState()
    cb({ ok = true })
end)

RegisterNetEvent('prp-scratch:client:ticketResult', function(result)
    if not result then return end

    SendNUIMessage({
        action = 'result',
        result = result,
    })

    if result.won then
        local message = result.multiplier and result.multiplier > 1
            and string.format(Config.Messages.TicketWonDoubled, result.formattedPrize)
            or string.format(Config.Messages.TicketWon, result.formattedPrize)
        QBCore.Functions.Notify(message, 'success', 6000)
    else
        QBCore.Functions.Notify(Config.Messages.TicketLost, 'error', 5000)
    end
end)

RegisterNetEvent('prp-scratch:client:forceClose', function()
    if isOpen then
        SendNUIMessage({ action = 'forceClose' })
    end
    resetTicketState()
end)

CreateThread(function()
    if Config.Command.Enabled then
        RegisterCommand(Config.Command.Name, function()
            TriggerServerEvent('prp-scratch:server:testOpen')
        end, false)
    end
end)
