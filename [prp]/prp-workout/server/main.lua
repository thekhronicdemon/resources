local QBCore = exports[Config.Core]:GetCoreObject()

local function Clamp(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > Config.StatMax then return Config.StatMax end
    return value
end

local function GetCitizenId(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return Player.PlayerData.citizenid
end

local function EnsureStats(citizenid)
    MySQL.insert.await([[
        INSERT IGNORE INTO prp_workout_stats
        (citizenid, strength, stamina, endurance, activity_count, activity_reset, last_decay)
        VALUES (?, 0, 0, 0, 0, ?, ?)
    ]], { citizenid, os.time(), os.time() })
end

local function GetStats(citizenid)
    EnsureStats(citizenid)
    return MySQL.single.await('SELECT * FROM prp_workout_stats WHERE citizenid = ?', { citizenid })
end

local function ApplyDecay(row)
    local now = os.time()
    local lastDecay = tonumber(row.last_decay) or now
    local decaySeconds = Config.DecayEveryMinutes * 60

    if now - lastDecay < decaySeconds then
        return row
    end

    local ticks = math.floor((now - lastDecay) / decaySeconds)
    local amount = ticks * Config.DecayAmount

    row.strength = Clamp((tonumber(row.strength) or 0) - amount)
    row.stamina = Clamp((tonumber(row.stamina) or 0) - amount)
    row.endurance = Clamp((tonumber(row.endurance) or 0) - amount)
    row.last_decay = lastDecay + (ticks * decaySeconds)

    MySQL.update.await([[
        UPDATE prp_workout_stats
        SET strength = ?, stamina = ?, endurance = ?, last_decay = ?
        WHERE citizenid = ?
    ]], {
        row.strength,
        row.stamina,
        row.endurance,
        row.last_decay,
        row.citizenid
    })

    return row
end

local function SendStats(src)
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    local row = ApplyDecay(GetStats(citizenid))
    local now = os.time()

    local resetAt = tonumber(row.activity_reset) or now
    local activityCount = tonumber(row.activity_count) or 0

    if now >= resetAt then
        activityCount = 0
        resetAt = now + Config.ActivityWindowSeconds

        MySQL.update.await([[
            UPDATE prp_workout_stats
            SET activity_count = ?, activity_reset = ?
            WHERE citizenid = ?
        ]], { activityCount, resetAt, citizenid })
    end

    TriggerClientEvent('prp-workout:client:setStats', src, {
        strength = tonumber(row.strength) or 0,
        stamina = tonumber(row.stamina) or 0,
        endurance = tonumber(row.endurance) or 0,
        activity_count = activityCount,
        max_activities = Config.MaxActivitiesPerHour,
        reset_in = math.max(resetAt - now, 0)
    })
end

RegisterNetEvent('prp-workout:server:getStats', function()
    SendStats(source)
end)

RegisterNetEvent('prp-workout:server:completeActivity', function(activityName)
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    local activity = Config.Activities[activityName]
    if not activity then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid workout activity.', 'error')
        return
    end

    local row = ApplyDecay(GetStats(citizenid))
    local now = os.time()

    local resetAt = tonumber(row.activity_reset) or now
    local count = tonumber(row.activity_count) or 0

    if now >= resetAt then
        count = 0
        resetAt = now + Config.ActivityWindowSeconds
    end

    if count >= Config.MaxActivitiesPerHour then
        local mins = math.ceil((resetAt - now) / 60)
        TriggerClientEvent('QBCore:Notify', src, ('Workout limit reached. Try again in %s min.'):format(mins), 'error')
        SendStats(src)
        return
    end

    row[activity.stat] = Clamp((tonumber(row[activity.stat]) or 0) + activity.gain)
    count = count + 1

    MySQL.update.await([[
        UPDATE prp_workout_stats
        SET strength = ?, stamina = ?, endurance = ?, activity_count = ?, activity_reset = ?
        WHERE citizenid = ?
    ]], {
        row.strength,
        row.stamina,
        row.endurance,
        count,
        resetAt,
        citizenid
    })

    TriggerClientEvent('QBCore:Notify', src, ('%s complete. +%s %s'):format(activity.label, activity.gain, activity.stat), 'success')
    SendStats(src)
end)
