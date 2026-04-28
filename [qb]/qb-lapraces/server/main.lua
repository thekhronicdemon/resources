local QBCore = exports['qb-core']:GetCoreObject()
local Races = {}
local AvailableRaces = {}
local LastRaces = {}
local NotFinished = {}
local RaceTablesReady = false

local function Trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function SecondsToClock(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        return '00:00:00'
    end

    local hours = string.format('%02.f', math.floor(seconds / 3600))
    local mins = string.format('%02.f', math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format('%02.f', math.floor(seconds - hours * 3600 - mins * 60))
    return hours .. ':' .. mins .. ':' .. secs
end

local function CountEntries(data)
    local amount = 0
    for _ in pairs(data or {}) do
        amount = amount + 1
    end
    return amount
end

local function Slice(list, limit)
    local output = {}
    local max = math.max(1, math.floor(tonumber(limit) or #list))
    for index = 1, math.min(#list, max) do
        output[#output + 1] = list[index]
    end
    return output
end

local function HasAdminAccess(source)
    return QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')
end

local function EnsureRaceTables()
    if RaceTablesReady then return end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_race_profiles (
            citizenid VARCHAR(50) NOT NULL,
            nickname VARCHAR(40) NOT NULL,
            rating INT NOT NULL DEFAULT 0,
            total_races INT NOT NULL DEFAULT 0,
            last_race_name VARCHAR(80) NULL DEFAULT NULL,
            last_race_position INT NULL DEFAULT NULL,
            last_race_time VARCHAR(32) NULL DEFAULT NULL,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_race_daily (
            citizenid VARCHAR(50) NOT NULL,
            race_date DATE NOT NULL,
            race_count INT NOT NULL DEFAULT 0,
            claimed_2 TINYINT(1) NOT NULL DEFAULT 0,
            claimed_5 TINYINT(1) NOT NULL DEFAULT 0,
            claimed_7 TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (citizenid, race_date)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_race_track_stats (
            raceid VARCHAR(50) NOT NULL,
            name VARCHAR(80) NOT NULL,
            uses INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            last_used_at TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (raceid)
        )
    ]])

    RaceTablesReady = true
end

local function GetCharacterNameByCitizenId(citizenId)
    citizenId = Trim(citizenId)
    if citizenId == '' then
        return 'Unknown Racer'
    end

    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
    if Player and Player.PlayerData and Player.PlayerData.charinfo then
        local charinfo = Player.PlayerData.charinfo
        return ((charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')):gsub('%s+$', '')
    end

    local result = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenId })
    if result and result.charinfo then
        local ok, charinfo = pcall(json.decode, result.charinfo)
        if ok and type(charinfo) == 'table' then
            return ((charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')):gsub('%s+$', '')
        end
    end

    return 'Unknown Racer'
end

local function EnsureRaceProfile(citizenId)
    EnsureRaceTables()
    local fallbackName = GetCharacterNameByCitizenId(citizenId)

    MySQL.insert.await(
        'INSERT INTO prp_race_profiles (citizenid, nickname) VALUES (?, ?) ON DUPLICATE KEY UPDATE citizenid = citizenid',
        { citizenId, fallbackName }
    )

    local row = MySQL.single.await([[
        SELECT
            citizenid,
            nickname,
            rating,
            total_races,
            last_race_name AS lastRaceName,
            last_race_position AS lastRacePosition,
            last_race_time AS lastRaceTime
        FROM prp_race_profiles
        WHERE citizenid = ?
    ]], { citizenId })

    if row and Trim(row.nickname) == '' then
        MySQL.update.await('UPDATE prp_race_profiles SET nickname = ? WHERE citizenid = ?', { fallbackName, citizenId })
        row.nickname = fallbackName
    end

    if not row then
        row = {
            citizenid = citizenId,
            nickname = fallbackName,
            rating = 0,
            total_races = 0,
            lastRaceName = nil,
            lastRacePosition = nil,
            lastRaceTime = nil,
        }
    end

    return row
end

local function EnsureDailyRow(citizenId)
    EnsureRaceTables()
    MySQL.insert.await([[
        INSERT INTO prp_race_daily (citizenid, race_date)
        VALUES (?, CURDATE())
        ON DUPLICATE KEY UPDATE citizenid = citizenid
    ]], { citizenId })

    return MySQL.single.await([[
        SELECT race_count, claimed_2, claimed_5, claimed_7
        FROM prp_race_daily
        WHERE citizenid = ? AND race_date = CURDATE()
    ]], { citizenId }) or {
        race_count = 0,
        claimed_2 = 0,
        claimed_5 = 0,
        claimed_7 = 0,
    }
end

local function IsClaimedRewardFlag(value)
    if value == true then
        return true
    end

    if value == false or value == nil then
        return false
    end

    local numeric = tonumber(value)
    if numeric ~= nil then
        return numeric == 1
    end

    local text = tostring(value):lower()
    return text == 'true' or text == '1'
end

local function EnsureTrackStat(raceId, name)
    EnsureRaceTables()
    MySQL.insert.await([[
        INSERT INTO prp_race_track_stats (raceid, name)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], { raceId, Trim(name) ~= '' and name or raceId })
end

local function MarkTrackUsage(raceId, name)
    EnsureTrackStat(raceId, name)
    MySQL.update.await([[
        UPDATE prp_race_track_stats
        SET uses = uses + 1, name = ?, last_used_at = CURRENT_TIMESTAMP
        WHERE raceid = ?
    ]], { name, raceId })
end

local function FetchTrackStats()
    EnsureRaceTables()
    local rows = MySQL.query.await('SELECT raceid, name, uses, created_at, last_used_at FROM prp_race_track_stats', {}) or {}
    local map = {}
    for _, row in ipairs(rows) do
        map[row.raceid] = row
    end
    return map
end

local function BuildDailyReward(citizenId)
    local daily = EnsureDailyRow(citizenId)
    local count = tonumber(daily.race_count) or 0
    local claimed2 = IsClaimedRewardFlag(daily.claimed_2)
    local claimed5 = IsClaimedRewardFlag(daily.claimed_5)
    local claimed7 = IsClaimedRewardFlag(daily.claimed_7)
    local now = os.time()
    local resetClock = os.date('*t', now)
    resetClock.hour = 23
    resetClock.min = 59
    resetClock.sec = 59
    local secondsUntilReset = math.max(os.time(resetClock) - now, 0)
    local progressPercent = math.min(math.floor((count / 7) * 100), 100)
    local hours = math.floor(secondsUntilReset / 3600)
    local minutes = math.floor((secondsUntilReset % 3600) / 60)
    local seconds = math.floor(secondsUntilReset % 60)

    return {
        count = count,
        rewardItem = 'briefcrate',
        progressPercent = progressPercent,
        secondsUntilReset = secondsUntilReset,
        resetLabel = string.format('%02d:%02d:%02d', hours, minutes, seconds),
        goals = {
            {
                races = 2,
                claimed = claimed2,
                claimable = count >= 2 and not claimed2,
            },
            {
                races = 5,
                claimed = claimed5,
                claimable = count >= 5 and not claimed5,
            },
            {
                races = 7,
                claimed = claimed7,
                claimable = count >= 7 and not claimed7,
            },
        }
    }
end

local function GetRaceRating(position, totalPlayers, maxRating)
    position = math.max(tonumber(position) or 1, 1)
    totalPlayers = math.max(tonumber(totalPlayers) or 1, 1)
    maxRating = math.max(tonumber(maxRating) or (totalPlayers * 10), 10)

    local base = maxRating * ((totalPlayers - position + 1) / totalPlayers)
    if position == 1 then base = base * 1.5 end
    if position == 2 then base = base * 1.2 end
    if position == 3 then base = base * 1.1 end

    return math.floor(base)
end

local function RecordRaceCompletion(citizenId, raceName, position, totalPlayers, totalTime)
    local profile = EnsureRaceProfile(citizenId)
    local ratingGain = GetRaceRating(position, totalPlayers, math.max(totalPlayers, 1) * 10)
    MySQL.update.await([[
        UPDATE prp_race_profiles
        SET
            nickname = ?,
            rating = rating + ?,
            total_races = total_races + 1,
            last_race_name = ?,
            last_race_position = ?,
            last_race_time = ?
        WHERE citizenid = ?
    ]], {
        profile.nickname,
        ratingGain,
        raceName,
        position,
        SecondsToClock(totalTime),
        citizenId
    })

    MySQL.insert.await([[
        INSERT INTO prp_race_daily (citizenid, race_date, race_count)
        VALUES (?, CURDATE(), 1)
        ON DUPLICATE KEY UPDATE race_count = race_count + 1
    ]], { citizenId })
end

local function RecordRaceDnf(citizenId, raceName)
    local profile = EnsureRaceProfile(citizenId)
    MySQL.update.await([[
        UPDATE prp_race_profiles
        SET nickname = ?, last_race_name = ?, last_race_position = 0, last_race_time = 'DNF'
        WHERE citizenid = ?
    ]], { profile.nickname, raceName, citizenId })
end

local function ClaimDailyReward(Player, target)
    local citizenId = Player.PlayerData.citizenid
    local daily = EnsureDailyRow(citizenId)
    local count = tonumber(daily.race_count) or 0
    local threshold = tonumber(target)

    if threshold ~= 2 and threshold ~= 5 and threshold ~= 7 then
        return false, 'That reward tier is invalid.'
    end

    if count < threshold then
        return false, 'That reward has not unlocked yet.'
    end

    local column = 'claimed_' .. threshold
    if IsClaimedRewardFlag(daily[column]) then
        return false, 'That reward is already claimed.'
    end

    if threshold == 2 then
        MySQL.update.await([[
            UPDATE prp_race_daily
            SET claimed_2 = 1
            WHERE citizenid = ? AND race_date = CURDATE() AND claimed_2 = 0
        ]], { citizenId })
    elseif threshold == 5 then
        MySQL.update.await([[
            UPDATE prp_race_daily
            SET claimed_5 = 1
            WHERE citizenid = ? AND race_date = CURDATE() AND claimed_5 = 0
        ]], { citizenId })
    elseif threshold == 7 then
        MySQL.update.await([[
            UPDATE prp_race_daily
            SET claimed_7 = 1
            WHERE citizenid = ? AND race_date = CURDATE() AND claimed_7 = 0
        ]], { citizenId })
    end

    local savedDaily = EnsureDailyRow(citizenId)
    if not IsClaimedRewardFlag(savedDaily[column]) then
        return false, 'Could not save claimed reward state.'
    end

    local added = Player.Functions.AddItem('briefcrate', 1, false, {
        source = 'RacePro',
        tier = threshold,
    }, 'racepro-daily-reward')

    if not added then
        if threshold == 2 then
            MySQL.update.await([[
                UPDATE prp_race_daily
                SET claimed_2 = 0
                WHERE citizenid = ? AND race_date = CURDATE()
            ]], { citizenId })
        elseif threshold == 5 then
            MySQL.update.await([[
                UPDATE prp_race_daily
                SET claimed_5 = 0
                WHERE citizenid = ? AND race_date = CURDATE()
            ]], { citizenId })
        elseif threshold == 7 then
            MySQL.update.await([[
                UPDATE prp_race_daily
                SET claimed_7 = 0
                WHERE citizenid = ? AND race_date = CURDATE()
            ]], { citizenId })
        end

        return false, 'Your inventory is full.'
    end

    local rewardItem = QBCore.Shared.Items.briefcrate
    if rewardItem then
        TriggerClientEvent('qb-inventory:client:ItemBox', Player.PlayerData.source, rewardItem, 'add')
    end

    return true, ('Daily %s-race cache claimed.'):format(threshold)
end

local function SerializeRecord(record)
    if type(record) ~= 'table' or next(record) == nil or not record.Time then
        return nil
    end

    local holder = record.Holder or {}
    return {
        time = tonumber(record.Time) or 0,
        label = SecondsToClock(record.Time),
        holder = ((holder[1] or 'Unknown') .. ' ' .. (holder[2] or '')):gsub('%s+$', '')
    }
end

local function IsWhitelisted(CitizenId)
    if Config.AllowAllCreators then
        return true
    end

    local retval = false
    for _, cid in pairs(Config.WhitelistedCreators) do
        if cid == CitizenId then
            retval = true
            break
        end
    end

    local Player = QBCore.Functions.GetPlayerByCitizenId(CitizenId)
    if Player and Player.PlayerData and Player.PlayerData.source and HasAdminAccess(Player.PlayerData.source) then
        retval = true
    end

    return retval
end

local function IsNameAvailable(RaceName, skipRaceId)
    local name = Trim(RaceName):lower()
    if name == '' then return false end

    for RaceId, race in pairs(Races) do
        if RaceId ~= skipRaceId and Trim(race.RaceName):lower() == name then
            return false
        end
    end

    return true
end

local function HasOpenedRace(CitizenId)
    for _, race in pairs(AvailableRaces) do
        if race.SetupCitizenId == CitizenId then
            return true
        end
    end
    return false
end

local function GetOpenedRaceKey(RaceId)
    for index, race in pairs(AvailableRaces) do
        if race.RaceId == RaceId then
            return index
        end
    end
    return nil
end

local function GetCurrentRace(MyCitizenId)
    for RaceId, race in pairs(Races) do
        for cid in pairs(race.Racers or {}) do
            if cid == MyCitizenId then
                return RaceId
            end
        end
    end
    return nil
end

local function GetRaceId(name)
    local lookup = Trim(name):lower()
    for RaceId, race in pairs(Races) do
        if Trim(race.RaceName):lower() == lookup then
            return RaceId
        end
    end
    return nil
end

local function GenerateRaceId()
    local RaceId = 'LR-' .. math.random(1111, 9999)
    while Races[RaceId] ~= nil do
        RaceId = 'LR-' .. math.random(1111, 9999)
    end
    return RaceId
end

local function GetRaceProfileSummary(citizenId)
    local profile = EnsureRaceProfile(citizenId)
    return {
        citizenId = citizenId,
        name = GetCharacterNameByCitizenId(citizenId),
        nickname = profile.nickname or GetCharacterNameByCitizenId(citizenId),
        rating = tonumber(profile.rating) or 0,
        totalRaces = tonumber(profile.total_races) or 0,
    }
end

local function BuildRaceRoster(race, hostCitizenId)
    local roster = {}
    local alreadyAdded = {}

    for citizenId, racer in pairs(race.Racers or {}) do
        local summary = GetRaceProfileSummary(citizenId)
        roster[#roster + 1] = {
            citizenId = citizenId,
            name = summary.name,
            nickname = summary.nickname,
            rating = summary.rating,
            lap = tonumber(racer.Lap) or 1,
            checkpoint = tonumber(racer.Checkpoint) or 0,
            finished = racer.Finished == true,
            isHost = citizenId == hostCitizenId,
        }
        alreadyAdded[citizenId] = true
    end

    if hostCitizenId and not alreadyAdded[hostCitizenId] then
        local summary = GetRaceProfileSummary(hostCitizenId)
        roster[#roster + 1] = {
            citizenId = hostCitizenId,
            name = summary.name,
            nickname = summary.nickname,
            rating = summary.rating,
            lap = 1,
            checkpoint = 0,
            finished = false,
            isHost = true,
        }
    end

    table.sort(roster, function(a, b)
        if a.isHost ~= b.isHost then
            return a.isHost
        end
        if a.finished ~= b.finished then
            return a.finished and not b.finished
        end
        if (a.lap or 0) ~= (b.lap or 0) then
            return (a.lap or 0) > (b.lap or 0)
        end
        if (a.checkpoint or 0) ~= (b.checkpoint or 0) then
            return (a.checkpoint or 0) > (b.checkpoint or 0)
        end
        return (a.nickname or a.name or '') < (b.nickname or b.name or '')
    end)

    return roster
end

local function BuildRaceRacerEntry(citizenId, checkpoint, lap, finished)
    local summary = GetRaceProfileSummary(citizenId)
    return {
        CitizenId = citizenId,
        Name = summary.nickname or summary.name or 'Racer',
        Checkpoint = tonumber(checkpoint) or 0,
        Lap = tonumber(lap) or 1,
        Finished = finished == true,
        TotalTimeMs = 0,
        LapTimeMs = 0,
    }
end

local function BuildPotData(entry)
    local paidInTotal = 0
    for _, amount in pairs(entry.PaidIn or {}) do
        paidInTotal = paidInTotal + (tonumber(amount) or 0)
    end

    local settings = entry.Settings or {}
    local hostJackpot = tonumber(settings.hostJackpot) or 0
    local total = paidInTotal + hostJackpot

    local first = math.floor(total * 0.50)
    local second = math.floor(total * 0.30)
    local third = math.max(total - first - second, 0)

    return {
        buyIn = tonumber(settings.buyIn) or 0,
        hostJackpot = hostJackpot,
        total = total,
        joinedPot = paidInTotal,
        breakdown = {
            first = first,
            second = second,
            third = third,
        }
    }
end

local function SerializeTrack(track, citizenId, statMap)
    local stat = statMap and statMap[track.RaceId] or nil

    return {
        raceId = track.RaceId,
        name = track.RaceName,
        creator = GetCharacterNameByCitizenId(track.Creator),
        creatorCitizenId = track.Creator,
        checkpoints = #(track.Checkpoints or {}),
        distance = math.floor(tonumber(track.Distance) or 0),
        record = SerializeRecord(track.Records),
        uses = tonumber(stat and stat.uses) or 0,
        createdAt = stat and stat.created_at or nil,
        lastUsedAt = stat and stat.last_used_at or nil,
        isOwner = citizenId ~= nil and track.Creator == citizenId,
        canManage = citizenId ~= nil and track.Creator == citizenId,
    }
end

local function SerializeAvailableRace(entry, citizenId)
    if not entry or not entry.RaceData then return nil end

    local race = entry.RaceData
    local hostCitizenId = entry.SetupCitizenId
    local pot = BuildPotData(entry)
    local settings = entry.Settings or {}
    local startPoint = race.Checkpoints and race.Checkpoints[1] and race.Checkpoints[1].coords or nil

    return {
        raceId = race.RaceId,
        name = race.RaceName,
        host = GetCharacterNameByCitizenId(hostCitizenId),
        hostCitizenId = hostCitizenId,
        hostProfile = GetRaceProfileSummary(hostCitizenId),
        creator = GetCharacterNameByCitizenId(race.Creator),
        creatorCitizenId = race.Creator,
        laps = tonumber(entry.Laps) or 0,
        checkpoints = #(race.Checkpoints or {}),
        distance = math.floor(tonumber(race.Distance) or 0),
        racers = CountEntries(race.Racers),
        racersList = BuildRaceRoster(race, hostCitizenId),
        started = race.Started == true,
        waiting = race.Waiting == true,
        isPrivate = Trim(entry.Password) ~= '',
        isHost = citizenId ~= nil and hostCitizenId == citizenId,
        isJoined = citizenId ~= nil and race.Racers[citizenId] ~= nil,
        status = race.Started and 'live' or 'forming',
        record = SerializeRecord(race.Records),
        buyIn = pot.buyIn,
        hostJackpot = pot.hostJackpot,
        jackpotTotal = pot.total,
        buyInPot = pot.joinedPot,
        prizeBreakdown = pot.breakdown,
        countdownSeconds = tonumber(settings.countdownSeconds) or 10,
        maxPlayers = tonumber(settings.maxPlayers) or math.max(CountEntries(race.Racers), 1),
        ghostCars = settings.ghostCars == true,
        collisionMode = settings.ghostCars == true and 'Ghost Cars' or 'Contact On',
        startPoint = startPoint and {
            x = tonumber(startPoint.x) or 0,
            y = tonumber(startPoint.y) or 0,
            z = tonumber(startPoint.z) or 0,
        } or nil,
    }
end

local function BuildTrackCollections(citizenId)
    EnsureRaceTables()
    local statMap = FetchTrackStats()
    local tracks = {}

    for _, race in pairs(Races) do
        EnsureTrackStat(race.RaceId, race.RaceName)
        tracks[#tracks + 1] = SerializeTrack(race, citizenId, statMap)
    end

    table.sort(tracks, function(a, b)
        return (a.name or '') < (b.name or '')
    end)

    local personalTracks = {}
    for _, track in ipairs(tracks) do
        if track.creatorCitizenId == citizenId then
            personalTracks[#personalTracks + 1] = track
        end
    end

    local function cloneList()
        local copy = {}
        for _, track in ipairs(tracks) do
            copy[#copy + 1] = track
        end
        return copy
    end

    local hotTracks = cloneList()
    table.sort(hotTracks, function(a, b)
        local aStamp = a.lastUsedAt or ''
        local bStamp = b.lastUsedAt or ''
        if aStamp == bStamp then
            return (a.uses or 0) > (b.uses or 0)
        end
        return aStamp > bStamp
    end)

    local popularTracks = cloneList()
    table.sort(popularTracks, function(a, b)
        if (a.uses or 0) == (b.uses or 0) then
            return (a.name or '') < (b.name or '')
        end
        return (a.uses or 0) > (b.uses or 0)
    end)

    local newTracks = cloneList()
    table.sort(newTracks, function(a, b)
        return (a.createdAt or '') > (b.createdAt or '')
    end)

    return {
        tracks = tracks,
        personalTracks = personalTracks,
        hotTracks = Slice(hotTracks, 8),
        popularTracks = Slice(popularTracks, 8),
        newTracks = Slice(newTracks, 8),
    }
end

local function GetHostedRace(citizenId)
    for _, race in pairs(AvailableRaces) do
        if race.SetupCitizenId == citizenId then
            return race
        end
    end
    return nil
end

local function GetCurrentRaceEntry(citizenId)
    local raceId = GetCurrentRace(citizenId)
    if not raceId or not Races[raceId] then return nil end

    local availableKey = GetOpenedRaceKey(raceId)
    if availableKey and AvailableRaces[availableKey] then
        return AvailableRaces[availableKey]
    end

    return {
        RaceData = Races[raceId],
        RaceId = raceId,
        Laps = 0,
        SetupCitizenId = nil,
        Password = nil,
        Settings = {},
        PaidIn = {},
    }
end

local function BuildPublicRaceList(citizenId)
    local races = {}
    for _, race in pairs(AvailableRaces) do
        if Trim(race.Password) == '' then
            races[#races + 1] = SerializeAvailableRace(race, citizenId)
        end
    end

    table.sort(races, function(a, b)
        if a.started ~= b.started then
            return a.started and not b.started
        end
        if a.jackpotTotal ~= b.jackpotTotal then
            return (a.jackpotTotal or 0) > (b.jackpotTotal or 0)
        end
        if a.racers ~= b.racers then
            return (a.racers or 0) > (b.racers or 0)
        end
        return (a.name or '') < (b.name or '')
    end)

    return races
end

local function FindPrivateRaceByPassword(password)
    local lookup = Trim(password):lower()
    if lookup == '' then return nil end

    for _, race in pairs(AvailableRaces) do
        if Trim(race.Password):lower() == lookup then
            return race
        end
    end

    return nil
end

local function BuildTabletRaceState(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return {
            success = false,
            message = 'Player not found.',
            tracks = {},
            personalTracks = {},
            publicRaces = {},
            hotTracks = {},
            popularTracks = {},
            newTracks = {},
            myHostedRace = nil,
            currentRace = nil,
            canCreateTracks = false,
            raceSetupAllowed = false,
            canManageAllTracks = false,
            profile = {
                nickname = 'Racer',
                rating = 0,
                totalRaces = 0,
            },
            dailyReward = {
                count = 0,
                rewardItem = 'briefcrate',
                goals = {
                    { races = 2, claimed = false, claimable = false },
                    { races = 5, claimed = false, claimable = false },
                    { races = 7, claimed = false, claimable = false },
                }
            },
            lastRace = nil,
        }
    end

    local citizenId = Player.PlayerData.citizenid
    local collections = BuildTrackCollections(citizenId)
    local hostedRace = GetHostedRace(citizenId)
    local currentRace = GetCurrentRaceEntry(citizenId)
    local profile = EnsureRaceProfile(citizenId)
    local dailyReward = BuildDailyReward(citizenId)

    return {
        success = true,
        tracks = collections.tracks,
        personalTracks = collections.personalTracks,
        publicRaces = BuildPublicRaceList(citizenId),
        hotTracks = collections.hotTracks,
        popularTracks = collections.popularTracks,
        newTracks = collections.newTracks,
        myHostedRace = hostedRace and SerializeAvailableRace(hostedRace, citizenId) or nil,
        currentRace = currentRace and SerializeAvailableRace(currentRace, citizenId) or nil,
        canCreateTracks = IsWhitelisted(citizenId),
        raceSetupAllowed = Config.RaceSetupAllowed == true,
        canManageAllTracks = HasAdminAccess(source),
        profile = {
            nickname = profile.nickname or GetCharacterNameByCitizenId(citizenId),
            rating = tonumber(profile.rating) or 0,
            totalRaces = tonumber(profile.total_races) or 0,
        },
        dailyReward = dailyReward,
        lastRace = profile.lastRaceName and {
            name = profile.lastRaceName,
            position = tonumber(profile.lastRacePosition) or 0,
            time = profile.lastRaceTime,
        } or nil,
    }
end

local function TryTakeMoney(Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return true
    end

    local bank = math.floor(tonumber(Player.PlayerData.money.bank) or 0)
    local cash = math.floor(tonumber(Player.PlayerData.money.cash) or 0)
    if (bank + cash) < amount then
        return false
    end

    local remaining = amount
    local bankTake = math.min(bank, remaining)
    if bankTake > 0 then
        Player.Functions.RemoveMoney('bank', bankTake, reason or 'race')
        remaining = remaining - bankTake
    end

    if remaining > 0 then
        Player.Functions.RemoveMoney('cash', remaining, reason or 'race')
    end

    return true
end

local function RefundPlayerMoney(citizenId, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenId)
    if Target then
        Target.Functions.AddMoney('bank', amount, reason or 'race refund')
        if Target.PlayerData.source then
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('$%s returned to your bank.'):format(amount), 'success')
        end
    end
end

local function RefundRaceEntry(entry, citizenId, reason)
    if not entry or not entry.PaidIn or not entry.PaidIn[citizenId] then return end
    RefundPlayerMoney(citizenId, entry.PaidIn[citizenId], reason or 'race refund')
    entry.PaidIn[citizenId] = nil
end

local function RefundHostedRace(entry, reason)
    if not entry then return end

    for citizenId, amount in pairs(entry.PaidIn or {}) do
        RefundPlayerMoney(citizenId, amount, reason or 'host closed')
    end
    entry.PaidIn = {}

    local hostJackpot = tonumber(entry.Settings and entry.Settings.hostJackpot) or 0
    if hostJackpot > 0 and entry.SetupCitizenId then
        RefundPlayerMoney(entry.SetupCitizenId, hostJackpot, reason or 'host closed jackpot')
        entry.Settings.hostJackpot = 0
    end
end

local function GetWinningShares(total, winnerCount)
    total = math.floor(tonumber(total) or 0)
    if total <= 0 or winnerCount <= 0 then
        return {}
    end

    if winnerCount == 1 then
        return { total }
    end

    if winnerCount == 2 then
        local first = math.floor(total * 0.70)
        return { first, total - first }
    end

    local first = math.floor(total * 0.50)
    local second = math.floor(total * 0.30)
    return { first, second, math.max(total - first - second, 0) }
end

local function DistributeRacePot(raceId, entry)
    if not entry then return end

    local pot = BuildPotData(entry)
    if pot.total <= 0 then return end

    local leaderboard = LastRaces[raceId] or {}
    local winners = {}
    for _, result in ipairs(leaderboard) do
        if result.CitizenId and result.TotalTime ~= 'DNF' then
            winners[#winners + 1] = result
        end
        if #winners >= 3 then
            break
        end
    end

    local shares = GetWinningShares(pot.total, #winners)
    for index, amount in ipairs(shares) do
        local winner = winners[index]
        if winner and amount > 0 then
            local Player = QBCore.Functions.GetPlayerByCitizenId(winner.CitizenId)
            if Player then
                Player.Functions.AddMoney('bank', amount, 'racepro jackpot payout')
                if Player.PlayerData.source then
                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, ('RacePro paid out $%s for place %s.'):format(amount, index), 'success')
                end
            end
        end
    end
end

local function KickAllRacers(raceId)
    if not Races[raceId] then return end

    for citizenId in pairs(Races[raceId].Racers or {}) do
        local RacerData = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        if RacerData ~= nil then
            TriggerClientEvent('qb-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[raceId])
        end
    end
end

local function CloseRaceEntry(raceId)
    local AvailableKey = GetOpenedRaceKey(raceId)
    if AvailableKey then
        table.remove(AvailableRaces, AvailableKey)
    end

    if Races[raceId] then
        Races[raceId].LastLeaderboard = LastRaces[raceId] or {}
        Races[raceId].Racers = {}
        Races[raceId].Started = false
        Races[raceId].Waiting = false
        Races[raceId].TabletSettings = {}
    end

    LastRaces[raceId] = nil
    NotFinished[raceId] = nil
end

local function HandleStartedRaceLeave(Player, raceId, availableKey)
    local citizenId = Player.PlayerData.citizenid
    local amountOfRacers = CountEntries(Races[raceId].Racers)

    NotFinished[raceId] = NotFinished[raceId] or {}
    NotFinished[raceId][#NotFinished[raceId] + 1] = {
        CitizenId = citizenId,
        TotalTime = 'DNF',
        BestLap = 'DNF',
        Holder = {
            [1] = Player.PlayerData.charinfo.firstname,
            [2] = Player.PlayerData.charinfo.lastname
        }
    }

    Races[raceId].Racers[citizenId] = nil
    RecordRaceDnf(citizenId, Races[raceId].RaceName)

    if (amountOfRacers - 1) == 0 then
        if NotFinished[raceId] ~= nil and next(NotFinished[raceId]) ~= nil then
            for _, v in pairs(NotFinished[raceId]) do
                LastRaces[raceId] = LastRaces[raceId] or {}
                LastRaces[raceId][#LastRaces[raceId] + 1] = {
                    CitizenId = v.CitizenId,
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = {
                        [1] = v.Holder[1],
                        [2] = v.Holder[2]
                    }
                }
            end
        end

        if availableKey and AvailableRaces[availableKey] then
            DistributeRacePot(raceId, AvailableRaces[availableKey])
        end
        CloseRaceEntry(raceId)
    else
        if availableKey and AvailableRaces[availableKey] then
            AvailableRaces[availableKey].RaceData = Races[raceId]
        end
    end
end

local function HandleWaitingRaceLeave(Player, raceId, availableKey)
    local citizenId = Player.PlayerData.citizenid
    local amountOfRacers = CountEntries(Races[raceId].Racers)

    if availableKey and AvailableRaces[availableKey] then
        RefundRaceEntry(AvailableRaces[availableKey], citizenId, 'race entry refund')
    end

    Races[raceId].Racers[citizenId] = nil

    if (amountOfRacers - 1) == 0 then
        if availableKey and AvailableRaces[availableKey] then
            RefundHostedRace(AvailableRaces[availableKey], 'race lobby closed')
        end
        CloseRaceEntry(raceId)
    elseif availableKey and AvailableRaces[availableKey] then
        AvailableRaces[availableKey].RaceData = Races[raceId]
    end
end

RegisterNetEvent('qb-lapraces:server:FinishPlayer', function(RaceData, TotalTime, TotalLaps, BestLap)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local raceId = RaceData.RaceId
    local AvailableKey = GetOpenedRaceKey(raceId)
    if not Player or not raceId or not Races[raceId] then return end

    local playersFinished = 0
    local amountOfRacers = 0
    for _, racer in pairs(Races[raceId].Racers) do
        if racer.Finished then
            playersFinished = playersFinished + 1
        end
        amountOfRacers = amountOfRacers + 1
    end

    local bestLapValue = TotalLaps < 2 and TotalTime or BestLap
    LastRaces[raceId] = LastRaces[raceId] or {}
    LastRaces[raceId][#LastRaces[raceId] + 1] = {
        CitizenId = Player.PlayerData.citizenid,
        TotalTime = TotalTime,
        BestLap = bestLapValue,
        Holder = {
            [1] = Player.PlayerData.charinfo.firstname,
            [2] = Player.PlayerData.charinfo.lastname
        }
    }

    if Races[raceId].Records ~= nil and next(Races[raceId].Records) ~= nil then
        if bestLapValue < Races[raceId].Records.Time then
            Races[raceId].Records = {
                Time = bestLapValue,
                Holder = {
                    [1] = Player.PlayerData.charinfo.firstname,
                    [2] = Player.PlayerData.charinfo.lastname
                }
            }
            MySQL.update.await('UPDATE lapraces SET records = ? WHERE raceid = ?', {
                json.encode(Races[raceId].Records), raceId
            })
            TriggerClientEvent('qb-phone:client:RaceNotify', src, 'You have won the WR from ' .. RaceData.RaceName .. ' with a time of: ' .. SecondsToClock(bestLapValue) .. '!')
        end
    else
        Races[raceId].Records = {
            Time = bestLapValue,
            Holder = {
                [1] = Player.PlayerData.charinfo.firstname,
                [2] = Player.PlayerData.charinfo.lastname
            }
        }
        MySQL.update.await('UPDATE lapraces SET records = ? WHERE raceid = ?', {
            json.encode(Races[raceId].Records), raceId
        })
        TriggerClientEvent('qb-phone:client:RaceNotify', src, 'You have won the WR from ' .. RaceData.RaceName .. ' with a time of: ' .. SecondsToClock(bestLapValue) .. '!')
    end

    if AvailableKey and AvailableRaces[AvailableKey] then
        AvailableRaces[AvailableKey].RaceData = Races[raceId]
    end

    local finishPosition = playersFinished + 1
    RecordRaceCompletion(Player.PlayerData.citizenid, RaceData.RaceName, finishPosition, amountOfRacers, TotalTime)
    TriggerClientEvent('qb-lapraces:client:PlayerFinishs', -1, raceId, finishPosition, Player)

    if playersFinished == amountOfRacers then
        if NotFinished[raceId] ~= nil and next(NotFinished[raceId]) ~= nil then
            for _, value in pairs(NotFinished[raceId]) do
                LastRaces[raceId][#LastRaces[raceId] + 1] = {
                    CitizenId = value.CitizenId,
                    TotalTime = value.TotalTime,
                    BestLap = value.BestLap,
                    Holder = {
                        [1] = value.Holder[1],
                        [2] = value.Holder[2]
                    }
                }
            end
        end

        if AvailableKey and AvailableRaces[AvailableKey] then
            DistributeRacePot(raceId, AvailableRaces[AvailableKey])
        end
        CloseRaceEntry(raceId)
    end

    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:CreateLapRace', function(RaceName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if IsWhitelisted(Player.PlayerData.citizenid) then
        if IsNameAvailable(RaceName) then
            TriggerClientEvent('qb-lapraces:client:StartRaceEditor', source, RaceName)
        else
            TriggerClientEvent('QBCore:Notify', source, 'There is already a race with this name.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'You have not been authorized to create races.', 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:JoinRace', function(RaceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local raceId = RaceData.RaceId
    local AvailableKey = GetOpenedRaceKey(raceId)
    if not Player or not raceId or not AvailableKey or not Races[raceId] or not AvailableRaces[AvailableKey] then
        TriggerClientEvent('QBCore:Notify', src, 'That race is no longer available.', 'error')
        return
    end

    if Races[raceId].Started then
        TriggerClientEvent('QBCore:Notify', src, 'That race is already live.', 'error')
        return
    end

    local maxPlayers = tonumber(AvailableRaces[AvailableKey].Settings and AvailableRaces[AvailableKey].Settings.maxPlayers) or 0
    if maxPlayers > 0 and not Races[raceId].Racers[Player.PlayerData.citizenid] and CountEntries(Races[raceId].Racers) >= maxPlayers then
        TriggerClientEvent('QBCore:Notify', src, 'That race grid is full.', 'error')
        return
    end

    local expectedPassword = Trim(AvailableRaces[AvailableKey].Password)
    local suppliedPassword = Trim(RaceData.Password or RaceData.password)
    if expectedPassword ~= '' and expectedPassword:lower() ~= suppliedPassword:lower() then
        TriggerClientEvent('QBCore:Notify', src, 'Race password incorrect.', 'error')
        return
    end

    local buyIn = tonumber(AvailableRaces[AvailableKey].Settings and AvailableRaces[AvailableKey].Settings.buyIn) or 0
    if not AvailableRaces[AvailableKey].PaidIn[Player.PlayerData.citizenid] and buyIn > 0 then
        if not TryTakeMoney(Player, buyIn, 'racepro buy-in') then
            TriggerClientEvent('QBCore:Notify', src, 'You do not have enough cash or bank for that buy-in.', 'error')
            return
        end
        AvailableRaces[AvailableKey].PaidIn[Player.PlayerData.citizenid] = buyIn
    end

    local currentRace = GetCurrentRace(Player.PlayerData.citizenid)
    if currentRace ~= nil then
        local previousKey = GetOpenedRaceKey(currentRace)
        if Races[currentRace] and previousKey and AvailableRaces[previousKey] then
            if Races[currentRace].Started then
                HandleStartedRaceLeave(Player, currentRace, previousKey)
            else
                HandleWaitingRaceLeave(Player, currentRace, previousKey)
            end
            TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[currentRace])
        end
    end

    Races[raceId].Waiting = true
    Races[raceId].Racers[Player.PlayerData.citizenid] = BuildRaceRacerEntry(Player.PlayerData.citizenid, 0, 1, false)
    AvailableRaces[AvailableKey].RaceData = Races[raceId]

    TriggerClientEvent('qb-lapraces:client:JoinRace', src, Races[raceId], AvailableRaces[AvailableKey].Laps)
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)

    local Creator = QBCore.Functions.GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId)
    local creatorSource = Creator and Creator.PlayerData and Creator.PlayerData.source
    if creatorSource and creatorSource ~= Player.PlayerData.source then
        TriggerClientEvent('qb-phone:client:RaceNotify', creatorSource,
            string.sub(Player.PlayerData.charinfo.firstname, 1, 1) .. '. ' .. Player.PlayerData.charinfo.lastname .. ' joined your race!')
    end
end)

RegisterNetEvent('qb-lapraces:server:LeaveRace', function(RaceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local raceName = RaceData.RaceData and RaceData.RaceData.RaceName or RaceData.RaceName
    local raceId = RaceData.RaceId or GetRaceId(raceName)
    local AvailableKey = GetOpenedRaceKey(raceId)
    if not raceId or not AvailableKey or not AvailableRaces[AvailableKey] or not Races[raceId] then
        TriggerClientEvent('QBCore:Notify', src, 'That race is no longer available.', 'error')
        return
    end

    local Creator = QBCore.Functions.GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId)
    local creatorSource = Creator and Creator.PlayerData and Creator.PlayerData.source
    if creatorSource and creatorSource ~= Player.PlayerData.source then
        TriggerClientEvent('qb-phone:client:RaceNotify', creatorSource,
            string.sub(Player.PlayerData.charinfo.firstname, 1, 1) .. '. ' .. Player.PlayerData.charinfo.lastname .. ' left the race.')
    end

    if Races[raceId].Started then
        HandleStartedRaceLeave(Player, raceId, AvailableKey)
    else
        HandleWaitingRaceLeave(Player, raceId, AvailableKey)
    end

    TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[raceId])
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:SetupRace', function(RaceId, Laps, options)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Config.RaceSetupAllowed then
        TriggerClientEvent('QBCore:Notify', src, 'Race hosting is closed right now.', 'error')
        return
    end

    if HasOpenedRace(Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'You already have a hosted race open.', 'error')
        return
    end

    if not Races[RaceId] then
        TriggerClientEvent('QBCore:Notify', src, 'This race does not exist.', 'error')
        return
    end

    if Races[RaceId].Waiting or Races[RaceId].Started then
        TriggerClientEvent('QBCore:Notify', src, 'That race is already active.', 'error')
        return
    end

    options = type(options) == 'table' and options or {}
    local laps = math.max(math.floor(tonumber(Laps) or 1), 1)
    local password = Trim(options.password or options.Password)
    if password == '' then
        password = nil
    end

    local buyIn = math.max(0, math.floor(tonumber(options.buyIn) or 0))
    local hostJackpot = math.max(0, math.floor(tonumber(options.hostJackpot or options.jackpot) or 0))
    local countdownSeconds = math.max(5, math.min(math.floor(tonumber(options.countdownSeconds or options.startDelay) or 10), 120))
    local maxPlayers = math.max(2, math.min(math.floor(tonumber(options.maxPlayers) or 10), 64))
    local ghostCars = options.ghostCars == true or options.collisionMode == 'ghost'

    if buyIn > 0 and not TryTakeMoney(Player, buyIn, 'racepro host buy-in') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have enough cash or bank for the buy-in.', 'error')
        return
    end

    if hostJackpot > 0 and not TryTakeMoney(Player, hostJackpot, 'racepro host jackpot') then
        if buyIn > 0 then
            Player.Functions.AddMoney('bank', buyIn, 'racepro host refund')
        end
        TriggerClientEvent('QBCore:Notify', src, 'You do not have enough cash or bank for that jackpot.', 'error')
        return
    end

    local currentRace = GetCurrentRace(Player.PlayerData.citizenid)
    if currentRace ~= nil then
        local previousKey = GetOpenedRaceKey(currentRace)
        if Races[currentRace] and previousKey and AvailableRaces[previousKey] then
            if Races[currentRace].Started then
                HandleStartedRaceLeave(Player, currentRace, previousKey)
            else
                HandleWaitingRaceLeave(Player, currentRace, previousKey)
            end
            TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[currentRace])
        end
    end

    Races[RaceId].Waiting = true
    Races[RaceId].Racers = {}
    Races[RaceId].Racers[Player.PlayerData.citizenid] = BuildRaceRacerEntry(Player.PlayerData.citizenid, 0, 1, false)

    AvailableRaces[#AvailableRaces + 1] = {
        RaceData = Races[RaceId],
        Laps = laps,
        RaceId = RaceId,
        SetupCitizenId = Player.PlayerData.citizenid,
        Password = password,
        PaidIn = {
            [Player.PlayerData.citizenid] = buyIn
        },
        Settings = {
            buyIn = buyIn,
            hostJackpot = hostJackpot,
            countdownSeconds = countdownSeconds,
            maxPlayers = maxPlayers,
            ghostCars = ghostCars,
        }
    }

    Races[RaceId].TabletSettings = AvailableRaces[#AvailableRaces].Settings

    TriggerClientEvent('qb-lapraces:client:JoinRace', src, Races[RaceId], laps)
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)

    SetTimeout(5 * 60 * 1000, function()
        local AvailableKey = GetOpenedRaceKey(RaceId)
        if AvailableKey and Races[RaceId] and Races[RaceId].Waiting and not Races[RaceId].Started then
            RefundHostedRace(AvailableRaces[AvailableKey], 'staged race expired')
            KickAllRacers(RaceId)
            CloseRaceEntry(RaceId)
            TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
        end
    end)
end)

RegisterNetEvent('qb-lapraces:server:CancelRace', function(raceId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(raceId)

    if not Player or not AvailableKey or not AvailableRaces[AvailableKey] or not Races[raceId] then
        TriggerClientEvent('QBCore:Notify', src, 'Race not open: ' .. tostring(raceId), 'error')
        return
    end

    if AvailableRaces[AvailableKey].SetupCitizenId ~= Player.PlayerData.citizenid and not HasAdminAccess(src) then
        TriggerClientEvent('QBCore:Notify', src, 'You are not the host of that race.', 'error')
        return
    end

    if not Races[raceId].Started then
        RefundHostedRace(AvailableRaces[AvailableKey], 'host closed race')
    end

    KickAllRacers(raceId)
    CloseRaceEntry(raceId)
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:UpdateRaceState', function(RaceId, Started, Waiting)
    if Races[RaceId] then
        Races[RaceId].Waiting = Waiting
        Races[RaceId].Started = Started
    end
end)

RegisterNetEvent('qb-lapraces:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished, TotalTimeMs, LapTimeMs)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Races[RaceId] or not Races[RaceId].Racers[Player.PlayerData.citizenid] then return end

    Races[RaceId].Racers[Player.PlayerData.citizenid].Checkpoint = Checkpoint
    Races[RaceId].Racers[Player.PlayerData.citizenid].Lap = Lap
    Races[RaceId].Racers[Player.PlayerData.citizenid].Finished = Finished
    Races[RaceId].Racers[Player.PlayerData.citizenid].TotalTimeMs = math.max(tonumber(TotalTimeMs) or 0, 0)
    Races[RaceId].Racers[Player.PlayerData.citizenid].LapTimeMs = math.max(tonumber(LapTimeMs) or 0, 0)

    TriggerClientEvent('qb-lapraces:client:UpdateRaceRacerData', -1, RaceId, Races[RaceId])
end)

RegisterNetEvent('qb-lapraces:server:StartRace', function(RaceId)
    local src = source
    local MyPlayer = QBCore.Functions.GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(RaceId)

    if not RaceId or not AvailableKey or not AvailableRaces[AvailableKey] or not MyPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a race.', 'error')
        return
    end

    if AvailableRaces[AvailableKey].SetupCitizenId ~= MyPlayer.PlayerData.citizenid and not HasAdminAccess(src) then
        TriggerClientEvent('QBCore:Notify', src, 'You are not the host of the race.', 'error')
        return
    end

    AvailableRaces[AvailableKey].RaceData.Started = true
    AvailableRaces[AvailableKey].RaceData.Waiting = false
    MarkTrackUsage(RaceId, Races[RaceId].RaceName)

    for CitizenId in pairs(Races[RaceId].Racers) do
        local Player = QBCore.Functions.GetPlayerByCitizenId(CitizenId)
        if Player ~= nil then
            TriggerClientEvent('qb-lapraces:client:RaceCountdown', Player.PlayerData.source)
        end
    end

    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:SaveRace', function(RaceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local RaceId = GenerateRaceId()
    local Checkpoints = {}
    for key, value in pairs(RaceData.Checkpoints or {}) do
        Checkpoints[key] = {
            offset = value.offset,
            coords = value.coords
        }
    end

    Races[RaceId] = {
        RaceName = RaceData.RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = Player.PlayerData.citizenid,
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceData.RaceDistance),
        Racers = {},
        LastLeaderboard = {},
        TabletSettings = {}
    }

    MySQL.insert.await('INSERT INTO lapraces (name, checkpoints, creator, distance, raceid) VALUES (?, ?, ?, ?, ?)', {
        RaceData.RaceName,
        json.encode(Checkpoints),
        Player.PlayerData.citizenid,
        RaceData.RaceDistance,
        RaceId
    })

    EnsureTrackStat(RaceId, RaceData.RaceName)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetRacingLeaderboards', function(_, cb)
    cb(Races)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetRaces', function(_, cb)
    cb(AvailableRaces)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetListedRaces', function(_, cb)
    cb(Races)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetRacingData', function(_, cb, RaceId)
    cb(Races[RaceId])
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:HasCreatedRace', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(Player and HasOpenedRace(Player.PlayerData.citizenid) or false)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:IsAuthorizedToCreateRaces', function(source, cb, TrackName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, false)
        return
    end
    cb(IsWhitelisted(Player.PlayerData.citizenid), IsNameAvailable(TrackName))
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:CanRaceSetup', function(_, cb)
    cb(Config.RaceSetupAllowed)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetTrackData', function(_, cb, RaceId)
    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { Races[RaceId].Creator })
    if result[1] ~= nil then
        result[1].charinfo = json.decode(result[1].charinfo)
        cb(Races[RaceId], result[1])
    else
        cb(Races[RaceId], {
            charinfo = {
                firstname = 'Unknown',
                lastname = 'Unknown'
            }
        })
    end
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetTabletState', function(source, cb)
    cb(BuildTabletRaceState(source))
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:GetPrivateRaceByPassword', function(source, cb, password)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    local race = FindPrivateRaceByPassword(password)
    if not race then
        cb({ success = false, message = 'No private race matched that code.' })
        return
    end

    cb({
        success = true,
        race = SerializeAvailableRace(race, Player.PlayerData.citizenid)
    })
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:UpdateRaceProfile', function(source, cb, nickname)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    nickname = Trim(nickname)
    if #nickname < 3 or #nickname > 24 then
        cb({ success = false, message = 'Nickname must be 3-24 characters.' })
        return
    end

    EnsureRaceProfile(Player.PlayerData.citizenid)
    MySQL.update.await('UPDATE prp_race_profiles SET nickname = ? WHERE citizenid = ?', {
        nickname,
        Player.PlayerData.citizenid
    })

    local state = BuildTabletRaceState(source)
    state.message = 'Race nickname updated.'
    cb(state)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:ClaimDailyReward', function(source, cb, tier)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    local success, message = ClaimDailyReward(Player, tier)
    local state = BuildTabletRaceState(source)
    if success and state and state.dailyReward and type(state.dailyReward.goals) == 'table' then
        for _, goal in ipairs(state.dailyReward.goals) do
            if tonumber(goal.races) == tonumber(tier) then
                goal.claimed = true
                goal.claimable = false
            end
        end
    end
    state.success = success
    state.message = message
    cb(state)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:RenameTrack', function(source, cb, raceId, newName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    if not Races[raceId] then
        cb({ success = false, message = 'Track not found.' })
        return
    end

    local isOwner = Races[raceId].Creator == Player.PlayerData.citizenid
    if not isOwner and not HasAdminAccess(source) then
        cb({ success = false, message = 'You do not own that track.' })
        return
    end

    newName = Trim(newName)
    if #newName < 3 or #newName > 40 then
        cb({ success = false, message = 'Track name must be 3-40 characters.' })
        return
    end

    if not IsNameAvailable(newName, raceId) then
        cb({ success = false, message = 'That track name is already taken.' })
        return
    end

    local oldName = Races[raceId].RaceName
    Races[raceId].RaceName = newName

    for _, race in pairs(AvailableRaces) do
        if race.RaceId == raceId then
            race.RaceData.RaceName = newName
        end
    end

    MySQL.update.await('UPDATE lapraces SET name = ? WHERE raceid = ?', { newName, raceId })
    MySQL.update.await('UPDATE prp_race_track_stats SET name = ? WHERE raceid = ?', { newName, raceId })
    MySQL.update.await('UPDATE prp_race_profiles SET last_race_name = ? WHERE last_race_name = ?', { newName, oldName })

    local state = BuildTabletRaceState(source)
    state.message = 'Track renamed.'
    cb(state)
end)

QBCore.Functions.CreateCallback('qb-lapraces:server:DeleteTrack', function(source, cb, raceId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    if not Races[raceId] then
        cb({ success = false, message = 'Track not found.' })
        return
    end

    local isOwner = Races[raceId].Creator == Player.PlayerData.citizenid
    if not isOwner and not HasAdminAccess(source) then
        cb({ success = false, message = 'You do not own that track.' })
        return
    end

    local AvailableKey = GetOpenedRaceKey(raceId)
    if AvailableKey and AvailableRaces[AvailableKey] then
        if not Races[raceId].Started then
            RefundHostedRace(AvailableRaces[AvailableKey], 'track deleted')
        end
        KickAllRacers(raceId)
        CloseRaceEntry(raceId)
    end

    Races[raceId] = nil
    LastRaces[raceId] = nil
    NotFinished[raceId] = nil
    MySQL.query.await('DELETE FROM lapraces WHERE raceid = ?', { raceId })
    MySQL.query.await('DELETE FROM prp_race_track_stats WHERE raceid = ?', { raceId })

    local state = BuildTabletRaceState(source)
    state.message = 'Track deleted.'
    cb(state)
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

QBCore.Commands.Add('cancelrace', 'Cancel going race..', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    if IsWhitelisted(Player.PlayerData.citizenid) then
        local RaceName = table.concat(args, ' ')
        if RaceName ~= nil then
            local RaceId = GetRaceId(RaceName)
            local AvailableKey = RaceId and GetOpenedRaceKey(RaceId) or nil
            if RaceId and Races[RaceId] and AvailableKey then
                if not Races[RaceId].Started then
                    RefundHostedRace(AvailableRaces[AvailableKey], 'race canceled')
                end
                KickAllRacers(RaceId)
                CloseRaceEntry(RaceId)
                TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
            else
                TriggerClientEvent('QBCore:Notify', source, 'That race is not open.', 'error')
            end
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'You have not been authorized to do this.', 'error')
    end
end)

QBCore.Commands.Add('togglesetup', 'Turn on / off racing setup', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    if IsWhitelisted(Player.PlayerData.citizenid) then
        Config.RaceSetupAllowed = not Config.RaceSetupAllowed
        if not Config.RaceSetupAllowed then
            TriggerClientEvent('QBCore:Notify', source, 'No more races can be created!', 'error')
        else
            TriggerClientEvent('QBCore:Notify', source, 'Races can be created again!', 'success')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'You have not been authorized to do this.', 'error')
    end
end)

exports('GetTabletState', BuildTabletRaceState)

CreateThread(function()
    EnsureRaceTables()
    local races = MySQL.query.await('SELECT * FROM lapraces', {})
    if races[1] ~= nil then
        for _, value in pairs(races) do
            local records = {}
            if value.records ~= nil then
                local ok, decoded = pcall(json.decode, value.records)
                if ok and type(decoded) == 'table' then
                    records = decoded
                end
            end

            Races[value.raceid] = {
                RaceName = value.name,
                Checkpoints = json.decode(value.checkpoints),
                Records = records,
                Creator = value.creator,
                RaceId = value.raceid,
                Started = false,
                Waiting = false,
                Distance = value.distance,
                LastLeaderboard = {},
                Racers = {},
                TabletSettings = {}
            }

            EnsureTrackStat(value.raceid, value.name)
        end
    end
end)
