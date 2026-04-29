math.randomseed(os.time())

local function IsAllowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, 'prp-hacks.admin') or IsPlayerAceAllowed(src, 'command')
end

local function copyTable(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if type(v) == 'table' then out[k] = copyTable(v) else out[k] = v end
    end
    return out
end

local function getRandomGame()
    local pool = (Config.RandomHack and Config.RandomHack.games) or { 'tetris', 'flappy', 'crossy', 'memory', 'typing' }
    return tostring(pool[math.random(#pool)] or 'typing'):lower()
end

local function getRandomDifficulty()
    local diffs = (Config.RandomHack and Config.RandomHack.difficulties) or { 'easy', 'medium', 'hard' }
    return tostring(diffs[math.random(#diffs)] or 'medium'):lower()
end

local function buildOptions(game, difficulty)
    local options = copyTable(Config.Defaults[game] or {})
    difficulty = tostring(difficulty or options.difficulty or ''):lower()

    if game == 'memory' then
        if difficulty == '' then difficulty = 'easy' end
        if difficulty == 'random' then difficulty = getRandomDifficulty() end
        local mem = Config.Memory[difficulty] or Config.Memory.easy
        options.difficulty = difficulty
        options.targetScore = mem.tiles
        options.timeLimit = mem.timeLimit
    elseif game == 'typing' then
        if difficulty == '' then difficulty = 'medium' end
        if difficulty == 'random' then difficulty = getRandomDifficulty() end
        local typ = Config.Typing[difficulty] or Config.Typing.medium
        options.difficulty = difficulty
        options.typing = typ
        options.timeLimit = typ.timeLimit
    end

    return options
end

local function validGame(game)
    return game == 'tetris' or game == 'flappy' or game == 'crossy' or game == 'memory' or game == 'typing'
end

local function runTest(source, game, difficulty)
    if not Config.AdminCommands.enabled then return end
    if not IsAllowed(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1PRP Hacks', 'Access denied.' } })
        return
    end
    TriggerClientEvent('prp-hacks:client:start', source, game, buildOptions(game, difficulty))
end

RegisterCommand(Config.AdminCommands.tetris, function(source) runTest(source, 'tetris') end, false)
RegisterCommand(Config.AdminCommands.flappy, function(source) runTest(source, 'flappy') end, false)
RegisterCommand(Config.AdminCommands.crossy, function(source) runTest(source, 'crossy') end, false)
RegisterCommand(Config.AdminCommands.memory, function(source, args) runTest(source, 'memory', args[1]) end, false)
RegisterCommand(Config.AdminCommands.typing, function(source, args) runTest(source, 'typing', args[1]) end, false)
RegisterCommand(Config.AdminCommands.random, function(source)
    local game = getRandomGame()
    local difficulty = (game == 'memory' or game == 'typing') and 'random' or nil
    runTest(source, game, difficulty)
end, false)

RegisterCommand(Config.AdminCommands.any, function(source, args)
    if not Config.AdminCommands.enabled then return end
    if not IsAllowed(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1PRP Hacks', 'Access denied.' } })
        return
    end

    local game = tostring(args[1] or 'tetris'):lower()
    local difficulty = args[2]
    if game == 'random' then
        game = getRandomGame()
        difficulty = (game == 'memory' or game == 'typing') and 'random' or nil
    end
    if not validGame(game) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1PRP Hacks', 'Use /testhack tetris, flappy, crossy, memory, typing, or random' } })
        return
    end

    TriggerClientEvent('prp-hacks:client:start', source, game, buildOptions(game, difficulty))
end, false)
