local QBCore = exports['qb-core']:GetCoreObject()

local currentTableId = nil
local currentTableEntity = nil
local currentState = nil
local sitting = false
local selectedBet = Config.MinBet
local betDeadline = 0
local phase = 'idle'
local actionCooldown = 0
local playerAnimUntil = 0
local syncQueue = {}
local syncWorkerActive = false
local resultToken = 0

local function notify(msg, msgType)
    QBCore.Functions.Notify(msg, msgType or 'primary')
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000

    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasAnimDictLoaded(dict)
end

local function getSeatData(tableId)
    local tableData = tableId and Config.Tables[tableId]
    if not tableData then
        return nil, nil
    end

    local seatData = tableData.seats[Config.Player.seatIndex or 1]
    return tableData, seatData
end

local function ensureSeatScenario()
    if not sitting or not currentTableId then
        return
    end

    if GetGameTimer() < playerAnimUntil then
        return
    end

    local ped = PlayerPedId()
    local _, seatData = getSeatData(currentTableId)
    if not seatData then
        return
    end

    if IsPedUsingAnyScenario(ped) then
        return
    end

    local seat = seatData.coords
    TaskStartScenarioAtPosition(
        ped,
        Config.Player.seatScenario or 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER',
        seat.x,
        seat.y,
        seat.z,
        seat.w,
        -1,
        true,
        true
    )
end

local function playPlayerSeatClip(clip, duration)
    if not sitting or not currentTableId or not clip then
        return false
    end

    local ped = PlayerPedId()
    local _, seatData = getSeatData(currentTableId)
    if not seatData or not loadAnimDict(Config.Anims.blackjackPlayer) then
        return false
    end

    local seat = seatData.coords
    duration = duration or 1000
    playerAnimUntil = GetGameTimer() + duration + 250

    ClearPedTasks(ped)
    TaskPlayAnimAdvanced(
        ped,
        Config.Anims.blackjackPlayer,
        clip,
        seat.x,
        seat.y,
        seat.z,
        0.0,
        0.0,
        seat.w,
        4.0,
        -4.0,
        duration,
        0,
        0.0,
        2,
        0
    )

    CreateThread(function()
        Wait(math.max(duration - 120, 250))
        if sitting and currentTableId then
            ensureSeatScenario()
        end
    end)

    return true
end

local function playOutcomeClip(status)
    local clip = Config.Player.pushClip
    local lower = string.lower(status or '')

    if lower:find('blackjack', 1, true) or lower:find('you win', 1, true) or lower:find('dealer bust', 1, true) then
        clip = Config.Player.winClip
    elseif lower:find('push', 1, true) then
        clip = Config.Player.pushClip
    else
        clip = Config.Player.loseClip
    end

    playPlayerSeatClip(clip, (Config.Timing and Config.Timing.resultAnimMs) or 1600)
end

local function getConfiguredTableFromEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil, nil
    end

    local model = GetEntityModel(entity)
    for tableId, data in pairs(Config.Tables) do
        if model == data.tableHash then
            return tableId, data
        end
    end

    return nil, nil
end

local function getClosestTableEntity(tableData)
    local obj = GetClosestObjectOfType(
        tableData.tableCoords.x,
        tableData.tableCoords.y,
        tableData.tableCoords.z,
        3.0,
        tableData.tableHash,
        false,
        false,
        false
    )

    if obj ~= 0 and DoesEntityExist(obj) then
        return obj
    end

    return nil
end

local function drawText2d(x, y, scale, text, r, g, b, a, centred)
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, a)
    SetTextCentre(centred == true)
    SetTextOutline()
    SetTextDropShadow()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawBox(x, y, width, height, r, g, b, a)
    DrawRect(x, y, width, height, r, g, b, a)
end

local function drawPanel(x, y, width, height)
    drawBox(x, y, width + 0.004, height + 0.008, 0, 0, 0, 85)
    drawBox(x, y, width, height, 12, 20, 20, 210)
end

local function wasControlPressed(control)
    return IsControlJustPressed(0, control)
        or IsDisabledControlJustPressed(0, control)
        or IsControlJustPressed(2, control)
        or IsDisabledControlJustPressed(2, control)
end

local function drawBetOverlay()
    local timeLeft = math.max(0, math.ceil((betDeadline - GetGameTimer()) / 1000))

    drawPanel(0.855, 0.858, 0.09, 0.075)
    drawPanel(0.945, 0.858, 0.10, 0.075)
    drawText2d(0.827, 0.838, 0.26, 'BET', 190, 220, 180, 255, false)
    drawText2d(0.827, 0.866, 0.50, tostring(selectedBet), 255, 255, 255, 255, false)
    drawText2d(0.905, 0.838, 0.26, 'TIME', 190, 220, 180, 255, false)
    drawText2d(0.905, 0.866, 0.50, string.format('00:%02d', timeLeft), 255, 255, 255, 255, false)

    drawPanel(0.87, 0.944, 0.33, 0.055)
    drawText2d(0.712, 0.935, 0.22, 'UP +', 255, 255, 255, 255, false)
    drawText2d(0.762, 0.935, 0.22, 'DOWN -', 255, 255, 255, 255, false)
    drawText2d(0.832, 0.935, 0.22, 'LEFT MIN', 255, 255, 255, 255, false)
    drawText2d(0.915, 0.935, 0.22, 'RIGHT MAX', 255, 255, 255, 255, false)
    drawText2d(0.985, 0.935, 0.22, 'ENTER BET', 255, 255, 255, 255, true)
end

local function drawActionOverlay()
    local playerScore = currentState and currentState.playerScore or 0
    local dealerScore = currentState and currentState.dealerScore or 0

    drawPanel(0.865, 0.875, 0.15, 0.06)
    drawPanel(0.955, 0.875, 0.15, 0.06)
    drawText2d(0.805, 0.855, 0.22, 'DEALER', 180, 200, 180, 255, false)
    drawText2d(0.805, 0.88, 0.48, tostring(dealerScore), 255, 255, 255, 255, false)
    drawText2d(0.905, 0.855, 0.22, 'YOUR HAND', 180, 200, 180, 255, false)
    drawText2d(0.905, 0.88, 0.48, tostring(playerScore), 255, 255, 255, 255, false)

    drawPanel(0.89, 0.945, 0.22, 0.05)
    drawText2d(0.80, 0.936, 0.22, 'E HIT', 255, 255, 255, 255, false)
    drawText2d(0.85, 0.936, 0.22, 'G STAND', 255, 255, 255, 255, false)
    drawText2d(0.925, 0.936, 0.22, 'ESC LEAVE', 255, 255, 255, 255, false)
end

local function drawResultOverlay()
    local status = currentState and currentState.status or 'Hand finished.'
    drawPanel(0.89, 0.915, 0.23, 0.075)
    drawText2d(0.777, 0.895, 0.22, status, 255, 234, 170, 255, false)
    drawText2d(0.80, 0.93, 0.22, 'ENTER NEXT HAND', 255, 255, 255, 255, false)
    drawText2d(0.925, 0.93, 0.22, 'ESC LEAVE', 255, 255, 255, 255, false)
end

local function drawWaitingOverlay()
    drawPanel(0.895, 0.935, 0.18, 0.05)
    drawText2d(0.845, 0.926, 0.22, 'DEALING CARDS...', 255, 255, 255, 255, false)
end

local function clampBet(value)
    return math.max(Config.MinBet, math.min(Config.MaxBet, value))
end

local function setSelectedBet(value)
    selectedBet = clampBet(value)

    if currentTableEntity and currentTableId and Config.Tables[currentTableId] then
        PRPCasinoCards.ShowBetPreview(currentTableEntity, Config.Tables[currentTableId], currentTableId, selectedBet)
    end
end

local function beginBettingRound(resetCards)
    if not currentTableId or not currentTableEntity or not Config.Tables[currentTableId] then
        return
    end

    resultToken = resultToken + 1

    if resetCards then
        PRPCasinoCards.ShowBetPreview(currentTableEntity, Config.Tables[currentTableId], currentTableId, selectedBet)
        currentState = nil
    end

    phase = 'betting'
    betDeadline = GetGameTimer() + (Config.Betting.phaseSeconds * 1000)
    PRPCasinoDealers.FocusPlayer(currentTableId, Config.Tables[currentTableId].seats[Config.Player.seatIndex or 1].seatNumber or 1)
end

local function leaveTable()
    if not sitting then
        return
    end

    local tableId = currentTableId
    local ped = PlayerPedId()

    phase = 'idle'
    sitting = false
    TriggerServerEvent('prp-casino:server:leaveBlackjack')

    PRPCasinoCards.Clear()

    if tableId then
        PRPCasinoDealers.ClearFocus(tableId, Config.Tables[tableId].seats[Config.Player.seatIndex or 1].seatNumber or 1)
    end

    ClearPedTasks(ped)
    StopAudioScene('DLC_VW_Casino_General')

    currentTableId = nil
    currentTableEntity = nil
    currentState = nil
    selectedBet = Config.MinBet
    betDeadline = 0
    actionCooldown = 0
    playerAnimUntil = 0
    syncQueue = {}
    syncWorkerActive = false
    resultToken = resultToken + 1
end

local function sitAtTable(tableId, tableData, entity)
    if sitting then
        notify('You are already at a blackjack table.', 'error')
        return
    end

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        notify('Could not find the blackjack table entity.', 'error')
        return
    end

    local seatData = tableData.seats[Config.Player.seatIndex or 1]
    if not seatData then
        notify('This table has no configured seat.', 'error')
        return
    end

    local ped = PlayerPedId()
    local seat = seatData.coords

    currentTableId = tableId
    currentTableEntity = entity
    currentState = nil
    selectedBet = Config.MinBet
    sitting = true
    phase = 'betting'
    actionCooldown = 0

    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    SetEntityCoordsNoOffset(ped, seat.x, seat.y, seat.z, false, false, false)
    SetEntityHeading(ped, seat.w)
    StartAudioScene('DLC_VW_Casino_General')
    ClearPedTasksImmediately(ped)
    ensureSeatScenario()
    Wait(300)
    ensureSeatScenario()

    PRPCasinoCards.ShowBetPreview(currentTableEntity, tableData, tableId, selectedBet)
    PRPCasinoDealers.FocusPlayer(tableId, seatData.seatNumber or 1)
    betDeadline = GetGameTimer() + (Config.Betting.phaseSeconds * 1000)
end

local function queueStateUpdate(state)
    syncQueue[#syncQueue + 1] = state
    if syncWorkerActive then
        return
    end

    syncWorkerActive = true

    CreateThread(function()
        while #syncQueue > 0 do
            local queuedState = table.remove(syncQueue, 1)

            if not sitting or not currentTableId or not Config.Tables[currentTableId] then
                break
            end

            local previousPhase = phase

            if currentTableEntity then
                PRPCasinoCards.SyncTableState(
                    currentTableEntity,
                    Config.Tables[currentTableId],
                    currentTableId,
                    queuedState
                )
            end

            if not sitting or not currentTableId then
                break
            end

            currentState = queuedState

            if queuedState and queuedState.finished then
                phase = 'result'
                if previousPhase ~= 'result' then
                    local seatNumber = Config.Tables[currentTableId].seats[Config.Player.seatIndex or 1].seatNumber or 1
                    PRPCasinoDealers.ClearFocus(currentTableId, seatNumber)
                    resultToken = resultToken + 1
                    local thisToken = resultToken

                    CreateThread(function()
                        playOutcomeClip(queuedState.status)
                        Wait((Config.Timing and Config.Timing.resultPauseMs) or 1800)

                        if not sitting or not currentTableId or resultToken ~= thisToken then
                            return
                        end

                        PRPCasinoCards.CollectTable(
                            currentTableEntity,
                            Config.Tables[currentTableId],
                            currentTableId
                        )
                    end)
                end
            else
                phase = 'playing'
                if previousPhase ~= 'playing' then
                    local seatNumber = Config.Tables[currentTableId].seats[Config.Player.seatIndex or 1].seatNumber or 1
                    PRPCasinoDealers.FocusPlayer(currentTableId, seatNumber)
                end
            end
        end

        syncWorkerActive = false
    end)
end

CreateThread(function()
    Wait(1500)

    exports['qb-target']:AddTargetModel(
        { Config.BlackjackTableHash },
        {
            options = {
                {
                    icon = 'fas fa-coins',
                    label = 'Play Blackjack',
                    action = function(entity)
                        local tableId, tableData = getConfiguredTableFromEntity(entity)
                        if not tableId then
                            notify('This blackjack table is not configured.', 'error')
                            return
                        end

                        sitAtTable(tableId, tableData, entity)
                    end
                }
            },
            distance = 2.5
        }
    )

    for tableId, data in pairs(Config.Tables) do
        exports['qb-target']:AddBoxZone(
            'prp_casino_blackjack_' .. tableId,
            data.tableCoords,
            1.8,
            1.8,
            {
                name = 'prp_casino_blackjack_' .. tableId,
                heading = data.tableHeading or 0.0,
                debugPoly = Config.Debug,
                minZ = data.tableCoords.z - 1.0,
                maxZ = data.tableCoords.z + 1.5
            },
            {
                options = {
                    {
                        icon = 'fas fa-coins',
                        label = 'Play Blackjack',
                        action = function()
                            local obj = getClosestTableEntity(data)
                            if not obj then
                                notify('No blackjack table prop found near config coords.', 'error')
                                return
                            end

                            sitAtTable(tableId, data, obj)
                        end
                    }
                },
                distance = 2.5
            }
        )
    end
end)

RegisterNetEvent('prp-casino:client:updateBlackjack', function(state)
    if not sitting or not currentTableId or not Config.Tables[currentTableId] then
        return
    end

    queueStateUpdate(state)
end)

RegisterNetEvent('prp-casino:client:blackjackMessage', function(msg, msgType)
    if phase == 'waiting' and not currentState and msgType == 'error' then
        beginBettingRound(true)
    end

    notify(msg, msgType or 'primary')
end)

CreateThread(function()
    while true do
        if not sitting then
            Wait(500)
        else
            ensureSeatScenario()
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)

            if phase == 'betting' then
                drawBetOverlay()

                if GetGameTimer() >= betDeadline then
                    notify('Blackjack bet timed out.', 'error')
                    leaveTable()
                    Wait(0)
                elseif wasControlPressed(Config.Controls.betUp) then
                    setSelectedBet(selectedBet + Config.Betting.step)
                elseif wasControlPressed(Config.Controls.betDown) then
                    setSelectedBet(selectedBet - Config.Betting.step)
                elseif wasControlPressed(Config.Controls.betMin) then
                    setSelectedBet(Config.MinBet)
                elseif wasControlPressed(Config.Controls.betMax) then
                    setSelectedBet(Config.MaxBet)
                elseif wasControlPressed(Config.Controls.placeBet) then
                    phase = 'waiting'
                    currentState = nil
                    PRPCasinoCards.CommitBet(currentTableEntity, Config.Tables[currentTableId], currentTableId, selectedBet)
                    playPlayerSeatClip(Config.Player.betClip, (Config.Timing and Config.Timing.placeBetAnimMs) or 1200)
                    CreateThread(function()
                        Wait(550)
                        if sitting and currentTableId then
                            TriggerServerEvent('prp-casino:server:startBlackjack', currentTableId, selectedBet)
                        end
                    end)
                elseif wasControlPressed(Config.Controls.leave) then
                    leaveTable()
                end
            elseif phase == 'playing' then
                drawActionOverlay()

                if GetGameTimer() >= actionCooldown then
                    if wasControlPressed(Config.Controls.hit) then
                        actionCooldown = GetGameTimer() + 450
                        phase = 'waiting'
                        playPlayerSeatClip(Config.Player.hitClip, (Config.Timing and Config.Timing.hitAnimMs) or 900)
                        CreateThread(function()
                            Wait(280)
                            if sitting and currentTableId then
                                TriggerServerEvent('prp-casino:server:hit', currentTableId)
                            end
                        end)
                    elseif wasControlPressed(Config.Controls.stand) then
                        actionCooldown = GetGameTimer() + 450
                        phase = 'waiting'
                        playPlayerSeatClip(Config.Player.standClip, (Config.Timing and Config.Timing.standAnimMs) or 950)
                        CreateThread(function()
                            Wait(280)
                            if sitting and currentTableId then
                                TriggerServerEvent('prp-casino:server:stand', currentTableId)
                            end
                        end)
                    elseif wasControlPressed(Config.Controls.leave) then
                        leaveTable()
                    end
                end
            elseif phase == 'result' then
                drawResultOverlay()

                if wasControlPressed(Config.Controls.placeBet) then
                    beginBettingRound(true)
                elseif wasControlPressed(Config.Controls.leave) then
                    leaveTable()
                end
            elseif phase == 'waiting' then
                drawWaitingOverlay()

                if wasControlPressed(Config.Controls.leave) then
                    leaveTable()
                end
            end

            Wait(0)
        end
    end
end)

RegisterCommand('prpcasino_leave', function()
    if sitting then
        leaveTable()
    end
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    if sitting then
        local ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
        PRPCasinoCards.Clear()
        StopAudioScene('DLC_VW_Casino_General')
    end
end)
