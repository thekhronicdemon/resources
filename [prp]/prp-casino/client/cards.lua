PRPCasinoCards = PRPCasinoCards or {}

local rendered = {
    tableId = nil,
    playerCards = {},
    dealerCards = {},
    previewChips = {},
    liveChips = {},
    state = nil,
    cleanupInProgress = false
}

local SUIT_VARIANTS = {
    C = { 'club', 'clubs', 'clb' },
    D = { 'dia', 'diamond', 'diamonds' },
    H = { 'hrt', 'heart', 'hearts' },
    S = { 'spd', 'spade', 'spades' }
}

local RANK_VARIANTS = {
    A = { 'ace', 'a', '01', '1' },
    ['2'] = { '2', '02' },
    ['3'] = { '3', '03' },
    ['4'] = { '4', '04' },
    ['5'] = { '5', '05' },
    ['6'] = { '6', '06' },
    ['7'] = { '7', '07' },
    ['8'] = { '8', '08' },
    ['9'] = { '9', '09' },
    ['10'] = { '10' },
    J = { 'jack', 'j' },
    Q = { 'queen', 'q' },
    K = { 'king', 'k' }
}

local function resolveModel(model)
    if type(model) == 'string' then
        return joaat(model)
    end

    return model
end

local function loadModel(model)
    model = resolveModel(model)

    if not IsModelInCdimage(model) then
        print(('[PRP Casino] Prop model missing: %s'):format(tostring(model)))
        return false, model
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    return true, model
end

local function clearEntryList(list)
    for index, entry in pairs(list) do
        local obj = entry
        if type(entry) == 'table' then
            obj = entry.obj
        end

        if obj and DoesEntityExist(obj) then
            DeleteEntity(obj)
        end

        list[index] = nil
    end
end

local function cloneCard(card)
    return {
        rank = card.rank,
        suit = card.suit,
        value = card.value,
        hidden = card.hidden == true
    }
end

local function cloneState(state)
    local copy = {
        bet = state.bet or 0,
        playerCards = {},
        dealerCards = {},
        playerScore = state.playerScore or 0,
        dealerScore = state.dealerScore or 0,
        status = state.status,
        finished = state.finished == true
    }

    for i, card in ipairs(state.playerCards or {}) do
        copy.playerCards[i] = cloneCard(card)
    end

    for i, card in ipairs(state.dealerCards or {}) do
        copy.dealerCards[i] = cloneCard(card)
    end

    return copy
end

local function getSeatCardModel(card)
    if not card or card.hidden then
        return Config.Props.hiddenCard
    end

    local suits = SUIT_VARIANTS[card.suit]
    local ranks = RANK_VARIANTS[tostring(card.rank)]
    if not suits or not ranks then
        return Config.Props.hiddenCard
    end

    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            local candidate = ('vw_prop_cas_card_%s_%s'):format(suit, rank)
            if IsModelInCdimage(joaat(candidate)) then
                return candidate
            end
        end
    end

    return Config.Props.fallbackCard
end

local function createProp(model, coords, heading)
    local ok, hash = loadModel(model)
    if not ok then
        if model ~= Config.Props.fallbackCard then
            ok, hash = loadModel(Config.Props.fallbackCard)
        end
        if not ok then
            return nil
        end
    end

    local obj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityRotation(obj, Config.Props.cardPitch or 0.0, Config.Props.cardRoll or 0.0, heading, 2, true)

    return obj
end

local function createChipProp(model, coords, heading)
    local ok, hash = loadModel(model)
    if not ok then
        return nil
    end

    local obj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, heading)

    return obj
end

local function normalize2d(vec)
    local length = math.sqrt((vec.x * vec.x) + (vec.y * vec.y))
    if length <= 0.0001 then
        return vector3(0.0, 1.0, 0.0), 0.0
    end

    return vector3(vec.x / length, vec.y / length, 0.0), length
end

local function getLayout(tableData)
    return tableData.layout or {}
end

local function getWorldAnchor(entity, zOffset)
    local pos = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, zOffset)
    return vector3(pos.x, pos.y, pos.z)
end

local function getActorLane(tableEntity, actorCoords, factor, zOffset)
    local tablePos = GetEntityCoords(tableEntity)
    local actorPos = vector3(actorCoords.x, actorCoords.y, 0.0)
    local centerPos = vector3(tablePos.x, tablePos.y, 0.0)
    local forward, distance = normalize2d(centerPos - actorPos)
    local right = vector3(-forward.y, forward.x, 0.0)
    local feltAnchor = getWorldAnchor(tableEntity, zOffset)
    local scaledDistance = distance * factor

    return vector3(
        actorCoords.x + (forward.x * scaledDistance),
        actorCoords.y + (forward.y * scaledDistance),
        feltAnchor.z
    ), forward, right
end

local function getSpreadOffset(index, step)
    if index <= 1 then
        return -step * 0.5
    end

    if index == 2 then
        return step * 0.5
    end

    return step * (index - 1.5)
end

local function getCardTarget(tableEntity, tableData, side, index)
    local layout = getLayout(tableData)

    if side == 'player' then
        local seatData = tableData.seats[Config.Player.seatIndex or 1]
        if not seatData then
            return nil, nil
        end

        local playerLayout = layout.playerCards or {}
        local basePos, forward, right = getActorLane(
            tableEntity,
            vector3(seatData.coords.x, seatData.coords.y, seatData.coords.z),
            playerLayout.factor or 0.56,
            playerLayout.z or 0.964
        )
        local lateral = getSpreadOffset(index, playerLayout.spreadStep or 0.042) + (playerLayout.sideOffset or 0.0)
        local coords = basePos + (right * lateral)
        local heading = GetHeadingFromVector_2d(-forward.x, -forward.y)

        return vector3(coords.x, coords.y, coords.z + 0.006), heading
    end

    local dealerData = tableData.dealer
    if not dealerData then
        return nil, nil
    end

    local dealerLayout = layout.dealerCards or {}
    local basePos, forward, right = getActorLane(
        tableEntity,
        vector3(dealerData.coords.x, dealerData.coords.y, dealerData.coords.z),
        dealerLayout.factor or 0.44,
        dealerLayout.z or 0.964
    )
    local lateral = getSpreadOffset(index, dealerLayout.spreadStep or 0.048)
    local coords = basePos + (right * lateral)
    local heading = GetHeadingFromVector_2d(-forward.x, -forward.y)

    return vector3(coords.x, coords.y, coords.z + 0.006), heading
end

local function getChipPosition(tableEntity, tableData, stackIndex)
    local seatData = tableData.seats[Config.Player.seatIndex or 1]
    if not seatData then
        return nil, 0.0
    end

    local chipsLayout = (getLayout(tableData)).chips or {}
    local basePos, forward, right = getActorLane(
        tableEntity,
        vector3(seatData.coords.x, seatData.coords.y, seatData.coords.z),
        chipsLayout.factor or 0.37,
        chipsLayout.z or 0.958
    )
    local perRow = chipsLayout.perRow or 3
    local row = math.floor((stackIndex - 1) / perRow)
    local col = (stackIndex - 1) % perRow
    local centeredCol = col - ((perRow - 1) * 0.5)
    local lateral = centeredCol * (chipsLayout.stepSide or 0.032)
    local forwardOffset = row * (chipsLayout.stepForward or 0.026)
    local vertical = (stackIndex - 1) * (chipsLayout.stackLift or 0.011)
    local pos = basePos + (right * lateral) + (forward * forwardOffset)

    return vector3(pos.x, pos.y, pos.z + vertical), GetHeadingFromVector_2d(-forward.x, -forward.y)
end

local function animateToTarget(obj, fromCoords, toCoords, heading, duration)
    local startAt = GetGameTimer()
    local finishAt = startAt + duration

    FreezeEntityPosition(obj, false)

    while GetGameTimer() < finishAt do
        local now = GetGameTimer()
        local t = (now - startAt) / duration
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local x = fromCoords.x + ((toCoords.x - fromCoords.x) * eased)
        local y = fromCoords.y + ((toCoords.y - fromCoords.y) * eased)
        local z = fromCoords.z + ((toCoords.z - fromCoords.z) * eased) + (math.sin(t * math.pi) * 0.045)

        SetEntityCoordsNoOffset(obj, x, y, z, false, false, false)
        SetEntityRotation(obj, Config.Props.cardPitch or 0.0, Config.Props.cardRoll or 0.0, heading, 2, true)
        Wait(0)
    end

    SetEntityCoordsNoOffset(obj, toCoords.x, toCoords.y, toCoords.z, false, false, false)
    SetEntityRotation(obj, Config.Props.cardPitch or 0.0, Config.Props.cardRoll or 0.0, heading, 2, true)
    FreezeEntityPosition(obj, true)
end

local function collectCardToDealer(tableId, entry, heading, duration)
    if not entry or not entry.obj or not DoesEntityExist(entry.obj) then
        return
    end

    local handCoords = PRPCasinoDealers.GetHandPosition(tableId)
    if not handCoords then
        DeleteEntity(entry.obj)
        entry.obj = nil
        return
    end

    local startCoords = GetEntityCoords(entry.obj)
    animateToTarget(
        entry.obj,
        vector3(startCoords.x, startCoords.y, startCoords.z),
        vector3(handCoords.x, handCoords.y, handCoords.z),
        heading,
        duration
    )

    if DoesEntityExist(entry.obj) then
        DeleteEntity(entry.obj)
    end

    entry.obj = nil
end

local function buildChipStacks(tableEntity, tableData, bet, targetList)
    clearEntryList(targetList)

    local stackIndex = 1
    local remaining = math.max(0, bet or 0)

    if remaining <= 0 then
        return
    end

    for _, chipDef in ipairs(Config.Props.chipModels or {}) do
        while remaining >= chipDef.value and stackIndex <= 8 do
            local pos, heading = getChipPosition(tableEntity, tableData, stackIndex)
            local obj = pos and createChipProp(chipDef.model, pos, heading + (stackIndex * 9.0)) or nil
            if obj then
                targetList[#targetList + 1] = obj
            end

            remaining = remaining - chipDef.value
            stackIndex = stackIndex + 1
        end
    end

    if #targetList == 0 then
        local pos, heading = getChipPosition(tableEntity, tableData, 1)
        local fallback = Config.Props.chipModels[#Config.Props.chipModels]
        local obj = (pos and fallback) and createChipProp(fallback.model, pos, heading) or nil
        if obj then
            targetList[#targetList + 1] = obj
        end
    end
end

local function addCardEntry(side, index, obj, card)
    local targetList = side == 'player' and rendered.playerCards or rendered.dealerCards
    targetList[index] = {
        obj = obj,
        card = cloneCard(card)
    }
end

local function dealCard(tableId, tableEntity, tableData, side, index, card)
    local targetCoords, targetHeading = getCardTarget(tableEntity, tableData, side, index)
    if not targetCoords then
        return
    end

    local handCoords = PRPCasinoDealers.GetHandPosition(tableId)
        or GetOffsetFromEntityInWorldCoords(tableEntity, 0.0, 0.15, 0.92)
    local model = getSeatCardModel(card)
    local obj = createProp(model, handCoords, targetHeading)
    if not obj then
        return
    end

    if side == 'player' then
        local seatData = tableData.seats[Config.Player.seatIndex or 1]
        PRPCasinoDealers.DealToPlayer(tableId, seatData and seatData.seatNumber or 1, obj)
    else
        PRPCasinoDealers.DealToDealer(tableId, index, obj)
    end

    local releaseCoords = GetEntityCoords(obj)
    animateToTarget(obj, vector3(releaseCoords.x, releaseCoords.y, releaseCoords.z), targetCoords, targetHeading, 260)
    addCardEntry(side, index, obj, card)
end

local function revealDealerCard(tableId, tableEntity, tableData, card)
    local existing = rendered.dealerCards[2]
    local targetCoords, targetHeading = getCardTarget(tableEntity, tableData, 'dealer', 2)
    if not existing or not targetCoords then
        return
    end

    local handCoords = PRPCasinoDealers.GetHandPosition(tableId)
        or GetOffsetFromEntityInWorldCoords(tableEntity, 0.0, 0.15, 0.92)
    local obj = createProp(getSeatCardModel(card), handCoords, targetHeading)
    if not obj then
        return
    end

    PRPCasinoDealers.RevealDealerCard(tableId, obj)

    if existing.obj and DoesEntityExist(existing.obj) then
        DeleteEntity(existing.obj)
    end

    local revealCoords = GetEntityCoords(obj)
    animateToTarget(obj, vector3(revealCoords.x, revealCoords.y, revealCoords.z), targetCoords, targetHeading, 180)
    rendered.dealerCards[2] = {
        obj = obj,
        card = cloneCard(card)
    }
end

function PRPCasinoCards.Clear()
    clearEntryList(rendered.playerCards)
    clearEntryList(rendered.dealerCards)
    clearEntryList(rendered.previewChips)
    clearEntryList(rendered.liveChips)

    rendered.tableId = nil
    rendered.state = nil
    rendered.cleanupInProgress = false
end

function PRPCasinoCards.ShowBetPreview(tableEntity, tableData, tableId, bet)
    if rendered.tableId ~= tableId then
        PRPCasinoCards.Clear()
        rendered.tableId = tableId
    end

    rendered.state = nil
    clearEntryList(rendered.playerCards)
    clearEntryList(rendered.dealerCards)
    clearEntryList(rendered.liveChips)

    buildChipStacks(tableEntity, tableData, bet, rendered.previewChips)
end

function PRPCasinoCards.CommitBet(tableEntity, tableData, tableId, bet)
    if rendered.tableId ~= tableId then
        PRPCasinoCards.Clear()
        rendered.tableId = tableId
    end

    rendered.state = nil
    clearEntryList(rendered.playerCards)
    clearEntryList(rendered.dealerCards)
    clearEntryList(rendered.previewChips)

    buildChipStacks(tableEntity, tableData, bet, rendered.liveChips)
end

function PRPCasinoCards.SyncTableState(tableEntity, tableData, tableId, state)
    if not tableEntity or not DoesEntityExist(tableEntity) or not tableData or not state then
        return
    end

    if rendered.tableId ~= tableId then
        PRPCasinoCards.Clear()
        rendered.tableId = tableId
    end

    buildChipStacks(tableEntity, tableData, state.bet or 0, rendered.liveChips)
    clearEntryList(rendered.previewChips)

    local previousState = rendered.state

    local previousPlayerCount = previousState and #previousState.playerCards or 0
    local previousDealerCount = previousState and #previousState.dealerCards or 0
    local currentPlayerCount = #(state.playerCards or {})
    local currentDealerCount = #(state.dealerCards or {})

    if previousPlayerCount == 0 and previousDealerCount == 0 and currentPlayerCount >= 2 and currentDealerCount >= 2 then
        local openingSequence = {
            { side = 'player', index = 1 },
            { side = 'dealer', index = 1 },
            { side = 'player', index = 2 },
            { side = 'dealer', index = 2 }
        }

        for _, step in ipairs(openingSequence) do
            local card = step.side == 'player' and state.playerCards[step.index] or state.dealerCards[step.index]
            if card then
                dealCard(tableId, tableEntity, tableData, step.side, step.index, card)
                Wait(step.side == 'dealer' and 260 or 220)
            end
        end

        for index = 3, currentPlayerCount do
            local card = state.playerCards[index]
            if card then
                dealCard(tableId, tableEntity, tableData, 'player', index, card)
                Wait(220)
            end
        end

        for index = 3, currentDealerCount do
            local card = state.dealerCards[index]
            if card then
                dealCard(tableId, tableEntity, tableData, 'dealer', index, card)
                Wait(260)
            end
        end
    else
        for index = previousPlayerCount + 1, currentPlayerCount do
            local card = state.playerCards[index]
            if card then
                dealCard(tableId, tableEntity, tableData, 'player', index, card)
                Wait(220)
            end
        end

        if previousState
            and previousState.dealerCards[2]
            and previousState.dealerCards[2].hidden
            and state.dealerCards
            and state.dealerCards[2]
            and not state.dealerCards[2].hidden then
            revealDealerCard(tableId, tableEntity, tableData, state.dealerCards[2])
            Wait(180)
        end

        for index = previousDealerCount + 1, currentDealerCount do
            local card = state.dealerCards[index]
            if card then
                dealCard(tableId, tableEntity, tableData, 'dealer', index, card)
                Wait(260)
            end
        end
    end

    for index, card in ipairs(state.playerCards or {}) do
        if rendered.playerCards[index] then
            rendered.playerCards[index].card = cloneCard(card)
        end
    end

    for index, card in ipairs(state.dealerCards or {}) do
        if rendered.dealerCards[index] then
            rendered.dealerCards[index].card = cloneCard(card)
        end
    end

    rendered.state = cloneState(state)
end

function PRPCasinoCards.CollectTable(tableEntity, tableData, tableId)
    if rendered.cleanupInProgress or rendered.tableId ~= tableId then
        return
    end

    rendered.cleanupInProgress = true

    local seatData = tableData.seats[Config.Player.seatIndex or 1]
    local seatNumber = seatData and (seatData.seatNumber or 1) or 1
    local cleanupMs = (Config.Timing and Config.Timing.cleanupStepMs) or 220

    for index, entry in ipairs(rendered.playerCards) do
        if entry and entry.obj and DoesEntityExist(entry.obj) then
            PRPCasinoDealers.CollectFromPlayer(tableId, seatNumber)
            Wait(110)
            collectCardToDealer(tableId, entry, GetEntityHeading(entry.obj), cleanupMs)
            Wait(cleanupMs)
        end
        rendered.playerCards[index] = nil
    end

    for index, entry in ipairs(rendered.dealerCards) do
        if entry and entry.obj and DoesEntityExist(entry.obj) then
            PRPCasinoDealers.CollectFromDealer(tableId, index)
            Wait(110)
            collectCardToDealer(tableId, entry, GetEntityHeading(entry.obj), cleanupMs)
            Wait(cleanupMs)
        end
        rendered.dealerCards[index] = nil
    end

    clearEntryList(rendered.liveChips)
    clearEntryList(rendered.previewChips)
    rendered.state = nil
    rendered.cleanupInProgress = false
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    PRPCasinoCards.Clear()
end)
