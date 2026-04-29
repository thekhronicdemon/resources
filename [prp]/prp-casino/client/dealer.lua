PRPCasinoDealers = PRPCasinoDealers or {}
PRPCasinoDealers.Spawned = {}

local DEAL_RELEASE_EVENT = 585557868
local REVEAL_ATTACH_EVENT = -1345695206

local function loadModel(model)
    if not IsModelInCdimage(model) then
        print(('[PRP Casino] Dealer model not found: %s'):format(model))
        return false
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    return true
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000

    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasAnimDictLoaded(dict)
end

local function getDealerPrefix(ped)
    if not ped or not DoesEntityExist(ped) then
        return ''
    end

    local model = GetEntityModel(ped)
    if model == joaat('s_f_y_casino_01') then
        return 'female_'
    end

    return ''
end

local function playDealerClip(tableId, dict, clip, duration, flags)
    local ped = PRPCasinoDealers.Spawned[tableId]
    if not ped or not DoesEntityExist(ped) then
        return false
    end

    if not loadAnimDict(dict) then
        return false
    end

    TaskPlayAnim(ped, dict, clip, 4.0, -4.0, duration or -1, flags or 0, 0.0, false, false, false)
    return true
end

local function waitForAnimEvent(ped, eventHash, timeoutMs)
    local timeoutAt = GetGameTimer() + timeoutMs

    while GetGameTimer() < timeoutAt do
        if HasAnimEventFired(ped, eventHash) then
            return true
        end
        Wait(0)
    end

    return false
end

CreateThread(function()
    Wait(1000)

    for tableId, data in pairs(Config.Tables) do
        local dealer = data.dealer

        if loadModel(dealer.model) then
            local ped = CreatePed(4, dealer.model, dealer.coords.x, dealer.coords.y, dealer.coords.z - 1.0, dealer.coords.w, false, true)

            SetEntityAsMissionEntity(ped, true, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedCanRagdoll(ped, false)

            PRPCasinoDealers.Spawned[tableId] = ped
            PRPCasinoDealers.PlayIdle(tableId)

            if Config.Debug then
                print(('[PRP Casino] Dealer spawned for table %s'):format(tableId))
            end
        end
    end
end)

function PRPCasinoDealers.Get(tableId)
    return PRPCasinoDealers.Spawned[tableId]
end

function PRPCasinoDealers.PlayIdle(tableId)
    local ped = PRPCasinoDealers.Spawned[tableId]
    if not ped or not DoesEntityExist(ped) then
        return
    end

    local prefix = getDealerPrefix(ped)
    local clip = prefix ~= '' and (prefix .. 'idle') or 'idle'
    playDealerClip(tableId, Config.Anims.sharedDealer, clip, -1, 1)
end

function PRPCasinoDealers.FocusPlayer(tableId, seatNumber)
    local ped = PRPCasinoDealers.Spawned[tableId]
    if not ped or not DoesEntityExist(ped) then
        return
    end

    local prefix = getDealerPrefix(ped)
    local intro = ('%sdealer_focus_player_%02d_idle_intro'):format(prefix, seatNumber)
    local loop = ('%sdealer_focus_player_%02d_idle'):format(prefix, seatNumber)

    if playDealerClip(tableId, Config.Anims.blackjackDealer, intro, 900, 0) then
        CreateThread(function()
            Wait(700)
            playDealerClip(tableId, Config.Anims.blackjackDealer, loop, -1, 1)
        end)
    else
        PRPCasinoDealers.PlayIdle(tableId)
    end
end

function PRPCasinoDealers.ClearFocus(tableId, seatNumber)
    local ped = PRPCasinoDealers.Spawned[tableId]
    if not ped or not DoesEntityExist(ped) then
        return
    end

    local prefix = getDealerPrefix(ped)
    local outro = ('%sdealer_focus_player_%02d_idle_outro'):format(prefix, seatNumber)

    if playDealerClip(tableId, Config.Anims.blackjackDealer, outro, 900, 0) then
        CreateThread(function()
            Wait(700)
            PRPCasinoDealers.PlayIdle(tableId)
        end)
    else
        PRPCasinoDealers.PlayIdle(tableId)
    end
end

function PRPCasinoDealers.GetHandPosition(tableId)
    local ped = PRPCasinoDealers.Get(tableId)
    local tableData = Config.Tables[tableId]
    if not ped or not DoesEntityExist(ped) or not tableData or not tableData.dealer then
        return nil
    end

    local dealerData = tableData.dealer
    local handOffset = dealerData.handOffset or vector3(0.0, 0.0, 0.0)
    local pos = GetPedBoneCoords(ped, dealerData.handBone or 28422, handOffset.x, handOffset.y, handOffset.z)

    return vector3(pos.x, pos.y, pos.z)
end

function PRPCasinoDealers.DealToPlayer(tableId, seatNumber, cardObj)
    local ped = PRPCasinoDealers.Get(tableId)
    if not ped or not DoesEntityExist(ped) or not cardObj or not DoesEntityExist(cardObj) then
        return
    end

    local prefix = getDealerPrefix(ped)
    local clip = ('%sdeal_card_player_%02d'):format(prefix, seatNumber)

    AttachEntityToEntity(cardObj, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
    SetEntityVisible(cardObj, false, false)

    playDealerClip(tableId, Config.Anims.blackjackDealer, clip, 1200, 0)
    Wait(260)
    SetEntityVisible(cardObj, true, false)
    waitForAnimEvent(ped, DEAL_RELEASE_EVENT, 900)

    DetachEntity(cardObj, true, true)
    PRPCasinoDealers.PlayIdle(tableId)
end

function PRPCasinoDealers.DealToDealer(tableId, cardIndex, cardObj)
    local ped = PRPCasinoDealers.Get(tableId)
    if not ped or not DoesEntityExist(ped) or not cardObj or not DoesEntityExist(cardObj) then
        return
    end

    local prefix = getDealerPrefix(ped)
    local clip = cardIndex == 2 and (prefix .. 'deal_card_self_second_card') or (prefix .. 'deal_card_self')

    if cardIndex >= 4 then
        clip = prefix .. 'deal_card_self_card_10'
    end

    AttachEntityToEntity(cardObj, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
    SetEntityVisible(cardObj, false, false)

    playDealerClip(tableId, Config.Anims.blackjackDealer, clip, 1200, 0)
    Wait(260)
    SetEntityVisible(cardObj, true, false)
    waitForAnimEvent(ped, DEAL_RELEASE_EVENT, 900)

    DetachEntity(cardObj, true, true)
    PRPCasinoDealers.PlayIdle(tableId)
end

function PRPCasinoDealers.RevealDealerCard(tableId, cardObj)
    local ped = PRPCasinoDealers.Get(tableId)
    if not ped or not DoesEntityExist(ped) or not cardObj or not DoesEntityExist(cardObj) then
        return
    end

    local prefix = getDealerPrefix(ped)
    local clip = prefix .. 'check_and_turn_card'

    SetEntityVisible(cardObj, false, false)
    playDealerClip(tableId, Config.Anims.blackjackDealer, clip, 1700, 0)

    waitForAnimEvent(ped, REVEAL_ATTACH_EVENT, 900)
    AttachEntityToEntity(cardObj, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
    SetEntityVisible(cardObj, true, false)
    waitForAnimEvent(ped, DEAL_RELEASE_EVENT, 900)

    DetachEntity(cardObj, true, true)
    PRPCasinoDealers.PlayIdle(tableId)
end

function PRPCasinoDealers.CollectFromPlayer(tableId, seatNumber)
    local ped = PRPCasinoDealers.Get(tableId)
    if not ped or not DoesEntityExist(ped) then
        return false
    end

    local prefix = getDealerPrefix(ped)
    local clip = ('%sdeal_card_player_%02d'):format(prefix, seatNumber)

    return playDealerClip(tableId, Config.Anims.blackjackDealer, clip, Config.Timing.cleanupStepMs + 420, 0)
end

function PRPCasinoDealers.CollectFromDealer(tableId, cardIndex)
    local ped = PRPCasinoDealers.Get(tableId)
    if not ped or not DoesEntityExist(ped) then
        return false
    end

    local prefix = getDealerPrefix(ped)
    local clip = cardIndex == 2 and (prefix .. 'deal_card_self_second_card') or (prefix .. 'deal_card_self')

    if cardIndex >= 4 then
        clip = prefix .. 'deal_card_self_card_10'
    end

    return playDealerClip(tableId, Config.Anims.blackjackDealer, clip, Config.Timing.cleanupStepMs + 420, 0)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    for _, ped in pairs(PRPCasinoDealers.Spawned) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
end)
