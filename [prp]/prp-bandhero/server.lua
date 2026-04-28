local function safeName(value)
    value = tostring(value or "")
    value = value:gsub("[^%w_%-]", "")
    return value
end

local function isValidDifficulty(difficulty)
    return difficulty == "easy" or difficulty == "hard" or difficulty == "expert"
end

RegisterNetEvent("prp-bandhero:server:saveChart", function(data)
    local src = source

    local songId = safeName(data and data.songId)
    local difficulty = safeName(data and data.difficulty)
    local notes = data and data.notes or {}

    if songId == "" then
        print("[prp-bandhero] Save failed: missing songId")
        return
    end

    if not isValidDifficulty(difficulty) then
        print("[prp-bandhero] Save failed: invalid difficulty " .. tostring(difficulty))
        return
    end

    local path = ("html/songs/charts/%s_%s.json"):format(songId, difficulty)

    local payload = {
        songId = songId,
        difficulty = difficulty,
        notes = notes,
        savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    SaveResourceFile(GetCurrentResourceName(), path, json.encode(payload, { indent = true }), -1)

    print(("[prp-bandhero] SAVED LIVE CHART: %s | notes: %s | by player: %s"):format(path, tostring(#notes), tostring(src)))
end)

RegisterNetEvent("prp-bandhero:server:loadChart", function(requestId, data)
    local src = source

    local songId = safeName(data and data.songId)
    local difficulty = safeName(data and data.difficulty)

    if songId == "" or not isValidDifficulty(difficulty) then
        TriggerClientEvent("prp-bandhero:client:receiveChart", src, requestId, {
            ok = false,
            notes = {},
            error = "Invalid song or difficulty"
        })
        return
    end

    local path = ("html/songs/charts/%s_%s.json"):format(songId, difficulty)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)

    if not raw or raw == "" then
        TriggerClientEvent("prp-bandhero:client:receiveChart", src, requestId, {
            ok = true,
            notes = {},
            path = path,
            found = false
        })
        return
    end

    local decoded = json.decode(raw)
    local notes = {}

    if decoded then
        notes = decoded.notes or decoded
    end

    print(("[prp-bandhero] LOADED LIVE CHART: %s | notes: %s | for player: %s"):format(path, tostring(#notes), tostring(src)))

    TriggerClientEvent("prp-bandhero:client:receiveChart", src, requestId, {
        ok = true,
        notes = notes,
        path = path,
        found = true
    })
end)
