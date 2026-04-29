local activeHack = false
local activeCallback = nil
math.randomseed(GetGameTimer() + PlayerId())

local function copyTable(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if type(v) == 'table' then out[k] = copyTable(v) else out[k] = v end
    end
    return out
end

local function getRandomGame(pool)
    pool = pool or (Config.RandomHack and Config.RandomHack.games) or { 'tetris', 'flappy', 'crossy', 'memory', 'typing' }
    return tostring(pool[math.random(#pool)] or 'typing'):lower()
end

local function getRandomDifficulty()
    local diffs = (Config.RandomHack and Config.RandomHack.difficulties) or { 'easy', 'medium', 'hard' }
    return tostring(diffs[math.random(#diffs)] or 'medium'):lower()
end

local function mergeOptions(game, options)
    local defaults = copyTable(Config.Defaults[game] or {})
    local merged = defaults
    if options then for k, v in pairs(options) do merged[k] = v end end

    if game == 'memory' then
        local diff = tostring(merged.difficulty or 'easy'):lower()
        if diff == 'random' then diff = getRandomDifficulty() end
        local mem = Config.Memory[diff] or Config.Memory.easy
        merged.difficulty = diff
        merged.targetScore = tonumber(merged.targetScore or mem.tiles) or mem.tiles
        merged.timeLimit = tonumber(merged.timeLimit or mem.timeLimit) or mem.timeLimit
    elseif game == 'typing' then
        local diff = tostring(merged.difficulty or 'medium'):lower()
        if diff == 'random' then diff = getRandomDifficulty() end
        local typ = Config.Typing[diff] or Config.Typing.medium
        merged.difficulty = diff
        merged.typing = typ
        merged.timeLimit = tonumber(merged.timeLimit or typ.timeLimit) or typ.timeLimit
    end

    merged.game = game
    merged.successText = merged.successText or Config.Banners.success
    merged.failedText = merged.failedText or Config.Banners.failed
    return merged
end

local function validGame(game)
    return game == 'tetris' or game == 'flappy' or game == 'crossy' or game == 'memory' or game == 'typing'
end

local function startHack(game, options, cb)
    game = tostring(game or 'tetris'):lower()
    if not validGame(game) then
        print('[prp-hacks] Invalid hack game: ' .. tostring(game))
        if cb then cb(false, { reason = 'invalid_game' }) end
        return false
    end
    if activeHack then
        if cb then cb(false, { reason = 'busy' }) end
        return false
    end
    activeHack = true
    activeCallback = cb
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'start', data = mergeOptions(game, options or {}) })
    return true
end

exports('StartHack', function(game, options, cb) return startHack(game, options, cb) end)
exports('StartTetris', function(options, cb) return startHack('tetris', options, cb) end)
exports('StartFlappy', function(options, cb) return startHack('flappy', options, cb) end)
exports('StartCrossy', function(options, cb) return startHack('crossy', options, cb) end)
exports('StartMemory', function(options, cb) return startHack('memory', options, cb) end)
exports('StartTyping', function(options, cb) return startHack('typing', options, cb) end)

exports('StartRandomHack', function(options, cb)
    if type(options) == 'function' then
        cb = options
        options = {}
    end

    options = options or {}
    local game = getRandomGame(options.games or options.pool)

    if (game == 'memory' or game == 'typing') and options.difficulty == nil then
        if options.randomDifficulty ~= false and (not Config.RandomHack or Config.RandomHack.randomDifficulty ~= false) then
            options.difficulty = 'random'
        end
    end

    return startHack(game, options, cb)
end)

RegisterNetEvent('prp-hacks:client:startRandom', function(options)
    exports['prp-hacks']:StartRandomHack(options or {}, function(success, data)
        TriggerEvent('prp-hacks:client:result', success, data)
    end)
end)

RegisterNetEvent('prp-hacks:client:start', function(game, options)
    startHack(game, options, function(success, data)
        TriggerEvent('prp-hacks:client:result', success, data)
    end)
end)

RegisterNetEvent('prp-hacks:client:open', function(game, options, cb)
    startHack(game, options, cb)
end)

RegisterNUICallback('hackResult', function(data, cb)
    SetNuiFocus(false, false)
    activeHack = false
    local success = data and data.success == true
    if activeCallback then activeCallback(success, data or {}); activeCallback = nil end
    TriggerEvent('prp-hacks:client:finished', success, data or {})
    cb({ ok = true })
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    activeHack = false
    local result = data or { success = false, reason = 'closed' }
    result.success = false
    if activeCallback then activeCallback(false, result); activeCallback = nil end
    TriggerEvent('prp-hacks:client:finished', false, result)
    cb({ ok = true })
end)
