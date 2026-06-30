local QBCore = exports[Config.Core]:GetCoreObject()

local Profiles = {}
local VehicleIssues = {}
local ActiveTows = {}
local RentedTrucks = {}

local function dbg(msg)
    if Config.Debug then print('[prp-mechanic] '..msg) end
end

local function defaultIssues()
    local t = {}
    for k,v in pairs(Config.HiddenIssueDefaults) do t[k] = v end
    return t
end

local function sanitizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('%s+', ''):upper()
    if plate == '' then return nil end
    return plate:sub(1, 16)
end

local function safeJsonDecode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
    return fallback
end

local function normalizeIssues(issues)
    issues = type(issues) == 'table' and issues or {}
    for k, v in pairs(Config.HiddenIssueDefaults) do
        local value = tonumber(issues[k])
        if value == nil then
            issues[k] = v
        else
            issues[k] = math.max(0, math.min(100, math.floor(value)))
        end
    end
    return issues
end

local function isConfiguredMechanicJob(job)
    if not job then return false end
    if Config.AllowJobType ~= false and Config.JobType and job.type == Config.JobType then return true end
    if Config.JobName and job.name == Config.JobName then return true end

    for _, jobName in ipairs(Config.JobNames or {}) do
        if job.name == jobName then return true end
    end

    return false
end

local function ensureDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `prp_mechanic_profiles` (
            `citizenid` varchar(64) NOT NULL,
            `level` int(11) NOT NULL DEFAULT 1,
            `xp` int(11) NOT NULL DEFAULT 0,
            `skill_points` int(11) NOT NULL DEFAULT 0,
            `reputation` int(11) NOT NULL DEFAULT 0,
            `skills` longtext DEFAULT NULL,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `prp_vehicle_issues` (
            `plate` varchar(16) NOT NULL,
            `issues` longtext DEFAULT NULL,
            `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
end

local function xpForLevel(level)
    return math.floor(Config.Progress.LevelXpBase * (level ^ Config.Progress.LevelXpMultiplier))
end

local function getIdentifier(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return Player.PlayerData.citizenid
end

local function isMechanic(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return isConfiguredMechanicJob(Player.PlayerData.job)
end

local function ensureProfile(src, cb)
    local citizenid = getIdentifier(src)
    if not citizenid then cb(nil) return end
    if Profiles[citizenid] then cb(Profiles[citizenid]) return end

    MySQL.single('SELECT * FROM prp_mechanic_profiles WHERE citizenid = ?', { citizenid }, function(row)
        if not row then
            local profile = { citizenid = citizenid, level = 1, xp = 0, skill_points = 0, reputation = 0, skills = {} }
            Profiles[citizenid] = profile
            MySQL.insert('INSERT INTO prp_mechanic_profiles (citizenid, level, xp, skill_points, reputation, skills) VALUES (?, ?, ?, ?, ?, ?)', {
                citizenid, 1, 0, 0, 0, json.encode({})
            })
            cb(profile)
            return
        end
        local skills = safeJsonDecode(row.skills, {})
        Profiles[citizenid] = {
            citizenid = citizenid,
            level = tonumber(row.level) or 1,
            xp = tonumber(row.xp) or 0,
            skill_points = tonumber(row.skill_points) or 0,
            reputation = tonumber(row.reputation) or 0,
            skills = skills
        }
        cb(Profiles[citizenid])
    end)
end

local function saveProfile(profile)
    if not profile then return end
    MySQL.update('UPDATE prp_mechanic_profiles SET level = ?, xp = ?, skill_points = ?, reputation = ?, skills = ? WHERE citizenid = ?', {
        profile.level, profile.xp, profile.skill_points, profile.reputation, json.encode(profile.skills or {}), profile.citizenid
    })
end

local function addXP(src, amount, rep)
    ensureProfile(src, function(profile)
        if not profile then return end
        profile.xp = profile.xp + (amount or 0)
        profile.reputation = profile.reputation + (rep or 0)
        local leveled = false
        while profile.level < Config.Progress.MaxLevel and profile.xp >= xpForLevel(profile.level) do
            profile.xp = profile.xp - xpForLevel(profile.level)
            profile.level = profile.level + 1
            profile.skill_points = profile.skill_points + Config.Progress.SkillPointsPerLevel
            leveled = true
        end
        saveProfile(profile)
        TriggerClientEvent('prp-mechanic:client:profileUpdated', src, profile, xpForLevel(profile.level), leveled)
    end)
end

CreateThread(function()
    Wait(500)
    ensureDatabase()
end)

local saveVehicleIssues

local function ensureVehicleIssues(plate, cb)
    plate = sanitizePlate(plate)
    if not plate then cb(defaultIssues()) return end
    if VehicleIssues[plate] then cb(VehicleIssues[plate]) return end
    MySQL.single('SELECT issues FROM prp_vehicle_issues WHERE plate = ?', { plate }, function(row)
        if row and row.issues then
            VehicleIssues[plate] = normalizeIssues(safeJsonDecode(row.issues, defaultIssues()))
            saveVehicleIssues(plate)
            cb(VehicleIssues[plate])
        else
            VehicleIssues[plate] = defaultIssues()
            MySQL.insert('INSERT INTO prp_vehicle_issues (plate, issues) VALUES (?, ?)', { plate, json.encode(VehicleIssues[plate]) })
            cb(VehicleIssues[plate])
        end
    end)
end

saveVehicleIssues = function(plate)
    plate = sanitizePlate(plate)
    if not plate then return end
    if not VehicleIssues[plate] then return end
    MySQL.update('INSERT INTO prp_vehicle_issues (plate, issues) VALUES (?, ?) ON DUPLICATE KEY UPDATE issues = VALUES(issues)', {
        plate, json.encode(VehicleIssues[plate])
    })
end

QBCore.Functions.CreateCallback('prp-mechanic:server:getDashboard', function(src, cb)
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    ensureProfile(src, function(profile)
        cb({ ok = true, profile = profile, nextLevelXp = xpForLevel(profile.level), skills = Config.Skills, towJobs = Config.Tow.Jobs, issues = Config.Issues, activeTow = ActiveTows[src] })
    end)
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:inspectVehicle', function(src, cb, data)
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    local plate = data and data.plate
    if not plate then cb({ ok = false, message = 'Missing plate.' }) return end
    ensureVehicleIssues(plate, function(issues)
        addXP(src, Config.XP.Inspect, 0)
        cb({ ok = true, issues = issues, issueConfig = Config.Issues })
    end)
end)


QBCore.Functions.CreateCallback('prp-mechanic:server:getVehicleIssues', function(src, cb, plate)
    if not plate then cb({ ok = false }) return end
    ensureVehicleIssues(plate, function(issues)
        cb({ ok = true, issues = issues })
    end)
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:damageVehicleIssue', function(src, cb, plate, issue, amount)
    if not plate or not issue then cb(false) return end
    ensureVehicleIssues(plate, function(issues)
        if issues[issue] ~= nil then
            issues[issue] = math.max(0, math.min(100, issues[issue] - math.abs(tonumber(amount) or 0)))
            saveVehicleIssues(plate)
            cb(true, issues)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:repairIssue', function(src, cb, data)
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    ensureProfile(src, function(profile)
        local plate = data and data.plate
        local issue = data and data.issue
        local cfg = Config.Issues[issue]
        if not plate or not cfg then cb({ ok = false, message = 'Invalid repair.' }) return end
        if profile.level < cfg.minLevel then cb({ ok = false, message = ('Requires mechanic level %s.'):format(cfg.minLevel) }) return end
        ensureVehicleIssues(plate, function(issues)
            if (issues[issue] or 100) >= 100 then
                cb({ ok = false, message = cfg.label..' does not need repair.', issues = issues })
                return
            end
            issues[issue] = 100
            saveVehicleIssues(plate)
            addXP(src, cfg.xp or Config.XP.RepairMedium, Config.Reputation.Repair)
            cb({ ok = true, issues = issues, message = cfg.label..' repaired.' })
        end)
    end)
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:unlockSkill', function(src, cb, skill)
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    local cfg = Config.Skills[skill]
    if not cfg then cb({ ok = false, message = 'Invalid skill.' }) return end
    ensureProfile(src, function(profile)
        profile.skills = profile.skills or {}
        if profile.skills[skill] then cb({ ok = false, message = 'Already unlocked.' }) return end
        if profile.level < cfg.minLevel then cb({ ok = false, message = 'Level too low.' }) return end
        if profile.skill_points < cfg.cost then cb({ ok = false, message = 'Not enough skill points.' }) return end
        profile.skill_points = profile.skill_points - cfg.cost
        profile.skills[skill] = true
        saveProfile(profile)
        TriggerClientEvent('prp-mechanic:client:profileUpdated', src, profile, xpForLevel(profile.level), false)
        cb({ ok = true, profile = profile, message = cfg.label..' unlocked.' })
    end)
end)

local function randomFrom(list)
    if not list or #list == 0 then return nil end
    return list[math.random(1, #list)]
end

QBCore.Functions.CreateCallback('prp-mechanic:server:acceptTow', function(src, cb, jobId)
    if not Config.Tow.Enabled then cb({ ok = false, message = 'Tow dispatch is disabled.' }) return end
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    ensureProfile(src, function(profile)
        if not (profile.skills and profile.skills.tow_operator) and profile.level < 3 then
            cb({ ok = false, message = 'Unlock Tow Operator or reach level 3 first.' }) return
        end
        if ActiveTows[src] then cb({ ok = false, message = 'You already have an active tow contract.' }) return end
        local job
        for _,j in ipairs(Config.Tow.Jobs) do if j.id == jobId then job = j break end end
        if not job then cb({ ok = false, message = 'Invalid tow job.' }) return end

        local pickup = randomFrom(Config.Tow.PickupLocations)
        if not pickup then cb({ ok = false, message = 'No tow pickup locations configured.' }) return end

        local vehicleModel = randomFrom(Config.Tow.TowVehicleModels) or 'sultan'
        local pedModel = randomFrom(Config.Tow.CustomerPedModels) or 'a_m_y_business_02'
        local rewardMin = tonumber(job.rewardMin) or tonumber(job.reward) or 750
        local rewardMax = tonumber(job.rewardMax) or rewardMin
        if rewardMax < rewardMin then rewardMin, rewardMax = rewardMax, rewardMin end
        local reward = job.reward or math.random(rewardMin, rewardMax)

        ActiveTows[src] = {
            id = job.id,
            label = job.label,
            pickup = pickup,
            vehicleModel = vehicleModel,
            pedModel = pedModel,
            reward = reward,
            xp = job.xp,
            reputation = job.reputation,
            difficulty = job.difficulty,
            stage = 'pickup',
            netId = nil
        }
        cb({ ok = true, tow = ActiveTows[src], message = Config.Messages.TowAccepted })
    end)
end)

RegisterNetEvent('prp-mechanic:server:setTowNetId', function(netId)
    local src = source
    if ActiveTows[src] then ActiveTows[src].netId = netId end
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:cancelTow', function(src, cb)
    if not ActiveTows[src] then cb({ ok = false, message = Config.Messages.NoActiveTow }) return end
    ActiveTows[src] = nil
    cb({ ok = true, message = 'Tow contract cancelled.' })
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:rentTowTruck', function(src, cb)
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    if RentedTrucks[src] then cb({ ok = false, message = 'You already have a rented tow truck.' }) return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ ok = false, message = 'Player not found.' }) return end
    if Config.UseCash and Config.Tow.Deposit > 0 then
        local balance = ((Player.PlayerData.money or {})[Config.MoneyType]) or 0
        local hasMoney = balance >= Config.Tow.Deposit
        if not hasMoney then cb({ ok = false, message = 'You need $'..Config.Tow.Deposit..' deposit.' }) return end
        Player.Functions.RemoveMoney(Config.MoneyType, Config.Tow.Deposit, 'tow-truck-deposit')
    end
    RentedTrucks[src] = true
    cb({ ok = true, spawn = Config.Locations.TowDepot.spawn, model = Config.Tow.TruckModel, message = Config.Messages.TruckRented })
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:returnTowTruck', function(src, cb)
    if not RentedTrucks[src] then cb({ ok = false, message = 'You do not have a rented tow truck.' }) return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ ok = false, message = 'Player not found.' }) return end
    if Config.UseCash and Config.Tow.Deposit > 0 then Player.Functions.AddMoney(Config.MoneyType, Config.Tow.Deposit, 'tow-truck-deposit-refund') end
    RentedTrucks[src] = nil
    cb({ ok = true, message = Config.Messages.TruckReturned })
end)

QBCore.Functions.CreateCallback('prp-mechanic:server:completeTow', function(src, cb)
    if not isMechanic(src) then cb({ ok = false, message = Config.Messages.NoJob }) return end
    local tow = ActiveTows[src]
    if not tow then cb({ ok = false, message = Config.Messages.NoActiveTow }) return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ ok = false, message = 'Player not found.' }) return end
    if Config.UseCash and (tow.reward or 0) > 0 then
        Player.Functions.AddMoney(Config.MoneyType, tow.reward or 0, 'mechanic-tow-contract')
    end
    addXP(src, tow.xp or Config.XP.TowComplete, tow.reputation or Config.Reputation.Tow)
    ActiveTows[src] = nil
    cb({ ok = true, message = Config.Messages.TowCompleted, reward = tow.reward })
end)

RegisterNetEvent('prp-mechanic:server:basicRepairReward', function(kind)
    local src = source
    if not isMechanic(src) then return end
    local xp = Config.XP.RepairSmall
    if kind == 'medium' then xp = Config.XP.RepairMedium end
    if kind == 'large' then xp = Config.XP.RepairLarge end
    addXP(src, xp, Config.Reputation.Repair)
end)

AddEventHandler('playerDropped', function()
    local src = source
    ActiveTows[src] = nil
    RentedTrucks[src] = nil
end)

if Config.TabletItem then
    QBCore.Functions.CreateUseableItem(Config.TabletItem, function(source)
        if isMechanic(source) then TriggerClientEvent('prp-mechanic:client:openTablet', source) end
    end)
end
