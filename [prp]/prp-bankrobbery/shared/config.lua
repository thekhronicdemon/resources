Config = {}

Config.Debug = false
Config.Target = 'qb-target' -- qb-target only for this starter version

Config.RequiredPolice = 2 -- set higher later, example 2
Config.PoliceJobs = {
    police = true,
    sheriff = true,
}

Config.Items = {
    GateCrack = 'gatecrack',
    Lockpick = 'lockpick',
    Drill = 'drill',
}

Config.Timers = {
    FailedHackCooldown = 60,       -- seconds
    DoorReset = 15 * 60,           -- seconds
    DrillSpotCooldown = 15 * 60,   -- seconds
}

Config.Consume = {
    GateCrackOnUse = true,
    LockpickBreakChance = 30, -- percent chance lockpick breaks on fail
    DrillOnUse = false,
}

Config.Alert = {
    Enabled = true,
    DispatchEvent = 'police:server:policeAlert', -- qb-policejob default style
    HackSuccessMessage = 'Fleeca vault keypad breached at Legion Square bank.',
    HackFailMessage = 'Failed vault keypad tamper at Legion Square bank.',
    LockpickMessage = 'Bank security gate lockpick attempt detected.',
}

Config.Doors = {
    Vault = {
        id = 'legion_fleeca_vault',
        coords = vector3(311.28, -284.51, 54.16),
        model = 2121050683, -- v_ilev_gb_vauldr
        objectName = 'v_ilev_gb_vauldr',
        lockedHeading = 250.0,
        openHeading = 160.0, -- tweak if your map needs it
        interactDistance = 2.0,
    },
    Bar = {
        id = 'legion_fleeca_bar',
        coords = vector3(313.44, -285.42, 54.14),
        model = -1591004109, -- v_ilev_gb_vaubar
        objectName = 'v_ilev_gb_vaubar',
        lockedHeading = 159.87,
        openHeading = 250.0, -- tweak if your map needs it
        interactDistance = 2.0,
    }
}

Config.DrillSpots = {
    -- These are starter positions inside the Fleeca loot room. Tweak in-game if needed.
    { id = 1, coords = vector3(315.29, -287.13, 54.14), heading = 250.0 },
    { id = 2, coords = vector3(314.57, -289.0, 54.14), heading = 250.0 },
    { id = 3, coords = vector3(313.3, -289.34, 54.14), heading = 150.0 },
    { id = 4, coords = vector3(311.2, -288.58, 54.14), heading = 150.0 },
    { id = 5, coords = vector3(310.82, -287.69, 54.14), heading = 64.52 },
    { id = 6, coords = vector3(311.43, -286.12, 54.14), heading = 250.0 },
}

Config.Rewards = {
    -- chance is percent. Rewards roll independently, so players can get more than one thing.
    { item = 'security_card_01', chance = 20, min = 1, max = 1 },
    { item = 'crypto_usb',       chance = 30, min = 1, max = 1 },
    { item = 'markedbills',      chance = 90, min = 1, max = 3, worthMin = 750, worthMax = 2500 },
}

Config.Text = {
    HackDoor = 'Hack Vault Keypad',
    LockpickDoor = 'Lockpick Security Gate',
    DrillBox = 'Drill Deposit Box',
}
