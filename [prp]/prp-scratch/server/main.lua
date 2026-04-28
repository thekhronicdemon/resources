local QBCore = exports['qb-core']:GetCoreObject()
local ActiveTickets = {}

local function debugPrint(...)
    if Config.Debug then
        print('[prp-scratch]', ...)
    end
end

local function weightedRandom(list, weightKey)
    local total = 0
    for i = 1, #list do
        total = total + (list[i][weightKey] or 0)
    end

    if total <= 0 then
        return list[math.random(1, #list)]
    end

    local roll = math.random() * total
    local cumulative = 0

    for i = 1, #list do
        cumulative = cumulative + (list[i][weightKey] or 0)
        if roll <= cumulative then
            return list[i]
        end
    end

    return list[#list]
end

local function copyTable(tbl)
    local newTable = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            newTable[k] = copyTable(v)
        else
            newTable[k] = v
        end
    end
    return newTable
end

local function randomModifier(isWinningSet)
    local modifier = Config.Modifiers.None

    if isWinningSet then
        if math.random() <= Config.Rolling.WinningDoubleChance then
            return Config.Modifiers.Double
        end

        if math.random() <= Config.Rolling.WinningStarChance then
            return Config.Modifiers.Star
        end

        return Config.Modifiers.None
    end

    if math.random() > Config.Rolling.LosingModifierChance then
        return Config.Modifiers.None
    end

    local candidates = {
        { ref = Config.Modifiers.Star, weight = Config.Modifiers.Star.weight or 1 },
        { ref = Config.Modifiers.Double, weight = Config.Modifiers.Double.weight or 1 },
    }

    local total = 0
    for i = 1, #candidates do total = total + candidates[i].weight end
    local roll = math.random() * total
    local cumulative = 0
    for i = 1, #candidates do
        cumulative = cumulative + candidates[i].weight
        if roll <= cumulative then
            modifier = candidates[i].ref
            break
        end
    end

    return modifier
end

local function buildSquare(symbol, modifier)
    return {
        symbol = symbol.key,
        label = symbol.label,
        icon = symbol.icon,
        prize = symbol.prize,
        modifier = modifier.key,
        modifierLabel = modifier.label,
        modifierIcon = modifier.icon,
    }
end

local function getDifferentSymbol(excludedKey)
    local pool = {}
    for i = 1, #Config.Symbols do
        if Config.Symbols[i].key ~= excludedKey then
            pool[#pool + 1] = Config.Symbols[i]
        end
    end
    return weightedRandom(pool, 'weight')
end

local function shuffle(list)
    local arr = copyTable(list)
    for i = #arr, 2, -1 do
        local j = math.random(i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return arr
end

local function generateWinningBoard()
    local boxes = {}
    local winningSymbol = weightedRandom(Config.Symbols, 'winWeight')
    local winningIndices = {}
    local count = math.min(Config.Rolling.ForcedMatchBoxes, Config.UI.BoxCount)

    while #winningIndices < count do
        local index = math.random(1, Config.UI.BoxCount)
        local exists = false
        for i = 1, #winningIndices do
            if winningIndices[i] == index then
                exists = true
                break
            end
        end
        if not exists then
            winningIndices[#winningIndices + 1] = index
        end
    end

    local hasModifier = false
    for i = 1, Config.UI.BoxCount do
        local isMatch = false
        for j = 1, #winningIndices do
            if winningIndices[j] == i then
                isMatch = true
                break
            end
        end

        if isMatch then
            local modifier = randomModifier(true)
            if modifier.key ~= 'none' then hasModifier = true end
            boxes[i] = buildSquare(winningSymbol, modifier)
        else
            local alt = getDifferentSymbol(winningSymbol.key)
            boxes[i] = buildSquare(alt, randomModifier(false))
        end
    end

    if Config.RequireModifierForPayout and not hasModifier then
        boxes[winningIndices[1]].modifier = Config.Modifiers.Star.key
        boxes[winningIndices[1]].modifierLabel = Config.Modifiers.Star.label
        boxes[winningIndices[1]].modifierIcon = Config.Modifiers.Star.icon
    end

    return {
        boxes = boxes,
        isWinningTicket = true,
    }
end

local function generateLosingBoard()
    local attempts = 0
    while attempts < 50 do
        attempts = attempts + 1
        local boxes = {}
        for i = 1, Config.UI.BoxCount do
            local symbol = weightedRandom(Config.Symbols, 'weight')
            boxes[i] = buildSquare(symbol, randomModifier(false))
        end

        local counts = {}
        for i = 1, #boxes do
            counts[boxes[i].symbol] = (counts[boxes[i].symbol] or 0) + 1
        end

        local accidentalWin = false
        for _, amount in pairs(counts) do
            if amount >= Config.Rolling.MatchCount then
                accidentalWin = true
                break
            end
        end

        if not accidentalWin then
            return {
                boxes = boxes,
                isWinningTicket = false,
            }
        end
    end

    local forced = {}
    local used = {}
    for i = 1, Config.UI.BoxCount do
        local symbol
        repeat
            symbol = weightedRandom(Config.Symbols, 'weight')
        until not used[symbol.key]
        used[symbol.key] = true
        forced[i] = buildSquare(symbol, randomModifier(false))
    end

    return {
        boxes = forced,
        isWinningTicket = false,
    }
end

local function generateBoard()
    if math.random() <= Config.Rolling.WinChance then
        return generateWinningBoard()
    end
    return generateLosingBoard()
end

local function resolveTicket(ticket)
    local counts = {}
    local grouped = {}

    for i = 1, #ticket.boxes do
        local box = ticket.boxes[i]
        counts[box.symbol] = (counts[box.symbol] or 0) + 1
        grouped[box.symbol] = grouped[box.symbol] or {}
        grouped[box.symbol][#grouped[box.symbol] + 1] = box
    end

    local winningSymbolKey = nil
    for symbol, amount in pairs(counts) do
        if amount >= Config.Rolling.MatchCount then
            winningSymbolKey = symbol
            break
        end
    end

    if not winningSymbolKey then
        return {
            won = false,
            amount = 0,
            formattedPrize = Config.FormatMoney(0),
            matchedSymbol = nil,
            multiplier = 0,
        }
    end

    local matchedBoxes = grouped[winningSymbolKey]
    local basePrize = matchedBoxes[1].prize or 0
    local multiplier = 1.0
    local hasStar = false
    local hasDouble = false

    for i = 1, #matchedBoxes do
        if matchedBoxes[i].modifier == Config.Modifiers.Double.key then
            hasDouble = true
            multiplier = math.max(multiplier, Config.Modifiers.Double.payoutMultiplier or 2.0)
        elseif matchedBoxes[i].modifier == Config.Modifiers.Star.key then
            hasStar = true
        end
    end

    if Config.RequireModifierForPayout and not hasStar and not hasDouble then
        return {
            won = false,
            amount = 0,
            formattedPrize = Config.FormatMoney(0),
            matchedSymbol = winningSymbolKey,
            multiplier = 0,
        }
    end

    local payout = math.floor(basePrize * multiplier)
    return {
        won = payout > 0,
        amount = payout,
        formattedPrize = Config.FormatMoney(payout),
        matchedSymbol = winningSymbolKey,
        multiplier = multiplier,
        doubled = hasDouble,
        starred = hasStar,
    }
end

local function givePrize(source, amount)
    if amount <= 0 then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    Player.Functions.AddMoney(Config.UseTargetMoney, amount, 'prp-scratch-win')
    return true
end

local function consumeTicketItem(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    if not Config.ConsumeOnUse then return true end

    local removed = Player.Functions.RemoveItem(Config.ScratchTicketItem, 1)
    if removed then
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[Config.ScratchTicketItem], 'remove', 1)
    end
    return removed
end

local function openScratchTicket(source, bypassItemCheck)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    if Config.AllowOnlyOneActiveTicket and ActiveTickets[source] then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages.AlreadyOpen, 'error')
        return
    end

    if not bypassItemCheck then
        local item = Player.Functions.GetItemByName(Config.ScratchTicketItem)
        if not item or item.amount < 1 then
            TriggerClientEvent('QBCore:Notify', source, Config.Messages.NotEnoughItem, 'error')
            return
        end
    end

    if Config.ConsumeOnUse and not bypassItemCheck then
        local removed = consumeTicketItem(source)
        if not removed then
            TriggerClientEvent('QBCore:Notify', source, Config.Messages.NotEnoughItem, 'error')
            return
        end
    end

    local board = generateBoard()
    ActiveTickets[source] = {
        boxes = board.boxes,
        isWinningTicket = board.isWinningTicket,
        finished = false,
        openedAt = os.time(),
    }

    debugPrint(('Opened ticket for %s | winning=%s'):format(source, tostring(board.isWinningTicket)))
    TriggerClientEvent('prp-scratch:client:openTicket', source, { boxes = board.boxes })
end

QBCore.Functions.CreateUseableItem(Config.ScratchTicketItem, function(source)
    openScratchTicket(source, false)
end)

RegisterNetEvent('prp-scratch:server:finishTicket', function()
    local source = source
    local ticket = ActiveTickets[source]
    if not ticket or ticket.finished then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages.NoActiveTicket, 'error')
        return
    end

    ticket.finished = true

    local result = resolveTicket(ticket)
    if result.won then
        givePrize(source, result.amount)
        TriggerClientEvent('QBCore:Notify', source, string.format(Config.Messages.MoneyReceived, result.formattedPrize), 'success')
    end

    TriggerClientEvent('prp-scratch:client:ticketResult', source, result)
end)

RegisterNetEvent('prp-scratch:server:closeTicket', function()
    local source = source
    ActiveTickets[source] = nil
    TriggerClientEvent('prp-scratch:client:forceClose', source)
end)

RegisterNetEvent('prp-scratch:server:testOpen', function()
    local source = source
    if not Config.Command.Enabled then return end
    openScratchTicket(source, true)
end)

AddEventHandler('playerDropped', function()
    ActiveTickets[source] = nil
end)
