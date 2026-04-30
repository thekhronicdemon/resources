Config = {}

--[[
    prp-npcLoading

    Main goal:
    - Slightly reduce traffic so roads feel less crowded
    - Reduce random/aggressive driver behavior
    - Reduce ambient civilians walking around armed

    Recommended values:
    1.00 = default GTA population
    0.85 = slight reduction
    0.70 = noticeable reduction
    0.50 = heavy reduction
]]

Config.Debug = false

Config.Density = {
    parkedVehicles = 0.65,  -- parked cars
    vehicles       = 0.60,  -- general road traffic
    peds           = 0.25,  -- walking peds
    scenarioPeds   = 0.25,  -- scenario peds (standing/sitting/etc)
    randomVehicles = 0.25,  -- random extra vehicles
}

-- Makes nearby ambient drivers less erratic / less "psycho GTA".
Config.CalmDrivers = {
    enabled = true,
    scanRadius = 120.0,
    scanInterval = 1500, -- milliseconds

    -- 0.0 to 1.0
    ability = 1.0,
    aggressiveness = 0.0,
    drivingStyle = 786603,
}

-- Removes weapons from ambient non-player, non-cop civilians near the player.
-- This is the most reliable way to stop random spawned civilians from carrying guns.
Config.DisarmAmbientPeds = {
    enabled = true,
    scanRadius = 120.0,
    scanInterval = 1500, -- milliseconds

    -- Keep police / security type peds armed?
    keepPoliceArmed = true,
    keepSecurityArmed = true,

    -- If true, only strips from non-mission ambient peds.
    onlyAmbientPeds = true,
}

-- Extra pass to stop random civilians from boxing / shooting / chasing players.
Config.CalmAmbientPeds = {
    enabled = true,
    scanRadius = 120.0,
    scanInterval = 1500, -- milliseconds
    onlyAmbientPeds = true,
    clearHostileTasks = true,
    relationshipLevel = 1,
    relationshipGroups = {
        'AMBIENT_GANG_HILLBILLY',
        'AMBIENT_GANG_BALLAS',
        'AMBIENT_GANG_MEXICAN',
        'AMBIENT_GANG_FAMILY',
        'AMBIENT_GANG_MARABUNTE',
        'AMBIENT_GANG_SALVA',
        'AMBIENT_GANG_LOST',
        'GANG_1',
        'GANG_2',
        'GANG_9',
        'GANG_10',
        'FIREMAN',
        'MEDIC',
        'PRISONER',
        'SECURITY_GUARD',
        'PRIVATE_SECURITY',
        'DEALER',
        'MISSION2',
    }
}

-- Dispatch / ambient world settings
Config.World = {
    disableRandomCops = true,
    disableRandomBoats = true,
    disableRandomTrains = false,
    disableRandomEvents = true,

    -- Lowers the chance of random emergency/hostile events messing with traffic.
    disableDispatchServices = true,
}
