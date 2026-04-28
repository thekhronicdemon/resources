Config = {}

Config.Debug = false
Config.UseTargetMoney = 'cash' -- cash / bank / crypto (if your framework supports it)
Config.FrameworkNotify = true
Config.InventoryImagePath = 'nui://qb-inventory/html/images/' -- only used in README example

Config.ScratchTicketItem = 'scratch_ticket'
Config.CloseOnEscape = true
Config.ConsumeOnUse = true -- removes the item the instant the ticket is opened
Config.RequireModifierForPayout = false -- if true, a winning set must include STAR or X2 to pay out
Config.RequireAllBoxesScratchedBeforeFinish = true
Config.AllowOnlyOneActiveTicket = true

Config.Animations = {
    OpenDuration = 250,
    RevealDuration = 180,
    GlowWinners = true
}

Config.UI = {
    TicketTitle = 'PRP Scratch Ticket',
    TicketSubtitle = 'Scratch 4 boxes. Match 3 logos to win.',
    PrizePrefix = '$',
    CurrencyFormat = true,
    ShowLegend = true,
    ScratchButtonText = 'SCRATCH',
    EscLabel = 'Press ESC to close',
    BoxCount = 4,
    GridColumns = 2
}

-- Prize logos. Default setup uses 8 jackpot logos worth $5,000 each.
-- Weight = how likely the symbol is to appear in general population.
-- WinWeight = how likely this symbol is chosen when the server intentionally generates a winning card.
Config.Symbols = {
    { key = 'diamond',  label = 'Diamond',  icon = '💎', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'crown',    label = 'Crown',    icon = '👑', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'bell',     label = 'Bell',     icon = '🔔', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'bar',      label = 'Bar',      icon = '🟥', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'horseshoe',label = 'Horseshoe',icon = '🧲', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'clover',   label = 'Clover',   icon = '🍀', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'cherry',   label = 'Cherry',   icon = '🍒', prize = 5000, weight = 100, winWeight = 100 },
    { key = 'seven',    label = 'Seven',    icon = '7️⃣', prize = 5000, weight = 100, winWeight = 100 },
}

Config.Modifiers = {
    None = { key = 'none', label = 'None', icon = '' },
    Star = {
        key = 'star',
        label = 'Star',
        icon = '⭐',
        weight = 10, -- chance to stamp a winning/losing square with a star
        payoutMultiplier = 1.0
    },
    Double = {
        key = 'x2',
        label = 'Double',
        icon = '✖2',
        weight = 3,
        payoutMultiplier = 2.0
    }
}

Config.Rolling = {
    -- Overall chance a ticket is a winning ticket.
    WinChance = 0.0008, -- 0.08% (extremely rare)

    -- Number of boxes that must match for a win.
    MatchCount = 3,

    -- On a winning ticket, how many matched boxes are forced. 3 is ideal for your requested rules.
    ForcedMatchBoxes = 3,

    -- Chance a winning set receives a STAR modifier.
    WinningStarChance = 0.75,

    -- Chance a winning set receives an X2 modifier.
    WinningDoubleChance = 0.10,

    -- Chance a losing square gets a visual modifier anyway.
    LosingModifierChance = 0.02
}

Config.Messages = {
    AlreadyOpen = 'You already have a scratch ticket open.',
    NoActiveTicket = 'No active scratch ticket found.',
    TicketOpened = 'Scratch the ticket and try your luck.',
    TicketConsumed = 'Scratch ticket used.',
    TicketLost = 'Unlucky. Better luck next time.',
    TicketWon = 'You won %s!',
    TicketWonDoubled = 'You won %s with X2!',
    InvalidRequest = 'Invalid scratch ticket request.',
    NotEnoughItem = 'You do not have a scratch ticket.',
    MoneyReceived = 'Prize paid: %s'
}

Config.Command = {
    Enabled = false,
    Name = 'testscratch'
}

function Config.FormatMoney(amount)
    if not Config.UI.CurrencyFormat then
        return (Config.UI.PrizePrefix or '$') .. tostring(amount)
    end

    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end

    return (Config.UI.PrizePrefix or '$') .. formatted
end
