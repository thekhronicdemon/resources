local QBCore = exports['qb-core']:GetCoreObject()
local Sessions = {}

math.randomseed(os.time())

local suits = { 'S', 'H', 'D', 'C' }
local ranks = {
    { label = 'A', value = 11 },
    { label = '2', value = 2 },
    { label = '3', value = 3 },
    { label = '4', value = 4 },
    { label = '5', value = 5 },
    { label = '6', value = 6 },
    { label = '7', value = 7 },
    { label = '8', value = 8 },
    { label = '9', value = 9 },
    { label = '10', value = 10 },
    { label = 'J', value = 10 },
    { label = 'Q', value = 10 },
    { label = 'K', value = 10 },
}

local function makeDeck()
    local deck = {}

    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            deck[#deck + 1] = {
                rank = rank.label,
                suit = suit,
                value = rank.value,
                hidden = false
            }
        end
    end

    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end

    return deck
end

local function scoreHand(cards)
    local total = 0
    local aces = 0

    for _, card in ipairs(cards or {}) do
        if not card.hidden then
            total = total + card.value
            if card.rank == 'A' then aces = aces + 1 end
        end
    end

    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end

    return total
end

local function publicState(session, revealDealer)
    local dealerCards = {}

    for i, card in ipairs(session.dealerCards) do
        dealerCards[i] = {
            rank = card.rank,
            suit = card.suit,
            value = card.value,
            hidden = (i == 2 and not revealDealer)
        }
    end

    return {
        bet = session.bet,
        playerCards = session.playerCards,
        dealerCards = dealerCards,
        playerScore = scoreHand(session.playerCards),
        dealerScore = revealDealer and scoreHand(session.dealerCards) or scoreHand({ session.dealerCards[1] }),
        status = session.status or 'playing',
        finished = session.finished or false
    }
end

local function removeBet(Player, amount)
    if Config.UseCasinoChips then
        local item = Player.Functions.GetItemByName(Config.ChipItem)
        if not item or item.amount < amount then return false end

        Player.Functions.RemoveItem(Config.ChipItem, amount)
        if QBCore.Shared.Items[Config.ChipItem] then
            TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items[Config.ChipItem], 'remove', amount)
        end
        return true
    end

    if Player.PlayerData.money.cash < amount then return false end
    Player.Functions.RemoveMoney('cash', amount, 'blackjack-bet')
    return true
end

local function addWinnings(Player, amount)
    if amount <= 0 then return end

    if Config.UseCasinoChips then
        Player.Functions.AddItem(Config.ChipItem, amount)
        if QBCore.Shared.Items[Config.ChipItem] then
            TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items[Config.ChipItem], 'add', amount)
        end
    else
        Player.Functions.AddMoney('cash', amount, 'blackjack-win')
    end
end

local function endGame(src, session, message, payout)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    session.status = message
    session.finished = true

    addWinnings(Player, payout)

    TriggerClientEvent('prp-casino:client:updateBlackjack', src, publicState(session, true))
    TriggerClientEvent('prp-casino:client:blackjackMessage', src, message, payout > 0 and 'success' or 'error')

    Sessions[src] = nil
end

RegisterNetEvent('prp-casino:server:startBlackjack', function(tableId, bet)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Sessions[src] then
        TriggerClientEvent('prp-casino:client:blackjackMessage', src, 'Finish the current hand first.', 'error')
        return
    end

    bet = tonumber(bet) or 0

    if bet < Config.MinBet or bet > Config.MaxBet then
        TriggerClientEvent('prp-casino:client:blackjackMessage', src, ('Bet must be between $%s and $%s.'):format(Config.MinBet, Config.MaxBet), 'error')
        return
    end

    if not Config.Tables[tableId] then
        TriggerClientEvent('prp-casino:client:blackjackMessage', src, 'Invalid blackjack table.', 'error')
        return
    end

    if not removeBet(Player, bet) then
        TriggerClientEvent('prp-casino:client:blackjackMessage', src, 'You do not have enough money/chips.', 'error')
        return
    end

    local deck = makeDeck()

    local session = {
        src = src,
        tableId = tableId,
        bet = bet,
        deck = deck,
        playerCards = {},
        dealerCards = {},
        status = 'playing',
        finished = false
    }

    session.playerCards[#session.playerCards + 1] = table.remove(deck)
    session.dealerCards[#session.dealerCards + 1] = table.remove(deck)
    session.playerCards[#session.playerCards + 1] = table.remove(deck)
    session.dealerCards[#session.dealerCards + 1] = table.remove(deck)

    Sessions[src] = session

    if scoreHand(session.playerCards) == 21 then
        endGame(src, session, 'Blackjack! You win.', math.floor(bet * 2.5))
        return
    end

    TriggerClientEvent('prp-casino:client:updateBlackjack', src, publicState(session, false))
end)

RegisterNetEvent('prp-casino:server:leaveBlackjack', function()
    Sessions[source] = nil
end)

RegisterNetEvent('prp-casino:server:hit', function(tableId)
    local src = source
    local session = Sessions[src]
    if not session or session.tableId ~= tableId then return end

    session.playerCards[#session.playerCards + 1] = table.remove(session.deck)

    if scoreHand(session.playerCards) > 21 then
        endGame(src, session, 'Bust! You lose.', 0)
        return
    end

    TriggerClientEvent('prp-casino:client:updateBlackjack', src, publicState(session, false))
end)

RegisterNetEvent('prp-casino:server:stand', function(tableId)
    local src = source
    local session = Sessions[src]
    if not session or session.tableId ~= tableId then return end

    while scoreHand(session.dealerCards) < 17 do
        session.dealerCards[#session.dealerCards + 1] = table.remove(session.deck)
    end

    local playerScore = scoreHand(session.playerCards)
    local dealerScore = scoreHand(session.dealerCards)

    if dealerScore > 21 then
        endGame(src, session, 'Dealer busts! You win.', session.bet * 2)
    elseif playerScore > dealerScore then
        endGame(src, session, 'You win.', session.bet * 2)
    elseif playerScore == dealerScore then
        endGame(src, session, 'Push. Bet returned.', session.bet)
    else
        endGame(src, session, 'Dealer wins.', 0)
    end
end)

AddEventHandler('playerDropped', function()
    Sessions[source] = nil
end)
