Config = {}

Config.Debug = false

Config.Core = 'qb-core'
Config.Target = 'qb-target'
Config.JobName = 'mechanic'
Config.JobNames = { 'mechanic', 'mechanic2', 'mechanic3', 'mechanic4', 'mechanic5' }
Config.JobType = 'mechanic'
Config.AllowJobType = true

Config.Command = 'mechanic'
Config.TabletItem = nil -- example: 'mechanic_tablet'. nil disables item registration.

Config.UseCash = true
Config.MoneyType = 'cash'

Config.Progress = {
    BaseRepairTime = 9000,
    MinimumRepairTime = 3500,
    TimeReductionPerLevel = 180,
    LevelXpBase = 250,
    LevelXpMultiplier = 1.25,
    MaxLevel = 50,
    SkillPointsPerLevel = 1,
}

Config.XP = {
    Inspect = 8,
    RepairSmall = 20,
    RepairMedium = 35,
    RepairLarge = 55,
    TowComplete = 85,
    Roadside = 45,
}

Config.Reputation = {
    Repair = 1,
    Tow = 3,
}

Config.Locations = {
    Workshops = {
        {
            id = 'hayes',
            label = 'Hayes Autos Mechanic Tablet',
            coords = vector3(-1426.84, -458.07, 35.91),
            length = 1.5,
            width = 1.5,
            heading = 31.0,
            minZ = 34.9,
            maxZ = 37.2,
        },
        {
            id = 'bennys',
            label = 'Bennys Mechanic Tablet',
            coords = vector3(-205.77, -1327.48, 30.89),
            length = 1.5,
            width = 1.5,
            heading = 0.0,
            minZ = 29.8,
            maxZ = 32.1,
        },
    },

    TowDepot = {
        id = 'tow_depot',
        label = 'Tow Depot',
        coords = vector3(408.88, -1622.84, 29.29),
        length = 2.0,
        width = 2.0,
        heading = 50.0,
        minZ = 28.2,
        maxZ = 31.2,
        spawn = vector4(409.31, -1643.28, 29.29, 228.0),
        returnRadius = 15.0,
    },

    TowDropoffs = {
        vector3(400.34, -1631.21, 29.29),
        vector3(-370.52, -112.73, 38.69),
        vector3(-211.24, -1323.38, 30.89),
        vector3(-1421.24, -449.52, 35.91),
    }
}



Config.Blips = {
    Enabled = true,
    MechanicShops = {
        Enabled = true,
        Sprite = 446, -- wrench
        Color = 5,
        Scale = 0.75,
        ShortRange = true,
        NameSuffix = ''
    },
    TowDepot = {
        Enabled = true,
        Sprite = 477, -- tow/vehicle service style blip
        Color = 17,
        Scale = 0.8,
        ShortRange = true,
        Name = 'Tow Depot'
    }
}

Config.Tow = {
    Enabled = true,
    Deposit = 250,
    TruckModel = 'flatbed',
    AttachDistance = 9.0,
    CompleteDistance = 8.0,

    -- Every tow contract picks a random model from here.
    TowVehicleModels = {
        'sultan', 'asterope', 'stratum', 'ingot', 'premier', 'buffalo', 'asea', 'tailgater', 'oracle',
        'blista', 'stanier', 'intruder', 'washington', 'primo', 'futo', 'felon', 'zion'
    },

    -- A stranded NPC is spawned beside the broken car for RP.
    CustomerPedModels = {
        'a_m_y_business_02', 'a_m_m_business_01', 'a_f_y_business_01', 'a_m_y_genstreet_01',
        'a_f_y_hipster_01', 'a_m_m_farmer_01', 'a_m_y_stbla_02'
    },

    -- Random roadside pickup spots. Add as many as you want.
    PickupLocations = {
        vector4(1174.34, 2651.52, 37.79, 92.0),
        vector4(1850.25, 3683.75, 34.27, 210.0),
        vector4(2578.75, 412.41, 108.46, 178.0),
        vector4(-568.42, -1775.64, 22.38, 328.0),
        vector4(-1537.84, -575.91, 33.68, 33.0),
        vector4(-3088.74, 340.79, 7.39, 255.0),
        vector4(1695.86, 6414.07, 32.42, 154.0),
        vector4(2545.51, 2591.32, 37.95, 105.0),
        vector4(897.54, -45.63, 78.76, 58.0),
        vector4(-786.82, 5519.34, 33.48, 82.0),
        vector4(211.67, 6628.94, 31.56, 45.0),
        vector4(-2534.45, 2342.23, 33.06, 213.0),
        vector4(1017.65, -2511.31, 28.48, 354.0),
        vector4(389.64, -767.87, 29.29, 88.0),
        vector4(-1120.29, -2006.11, 13.17, 311.0),
    },

    Jobs = {
        {
            id = 'basic_breakdown',
            label = 'NPC Breakdown Recovery',
            description = 'Repair a stranded civilian vehicle on site. The customer waves you down and drives away after the fix.',
            rewardMin = 750,
            rewardMax = 1050,
            xp = 85,
            reputation = 3,
            difficulty = 'Easy'
        },
        {
            id = 'impound_recovery',
            label = 'Impound Recovery',
            description = 'Recover a random abandoned vehicle and bring it back to the depot.',
            rewardMin = 950,
            rewardMax = 1350,
            xp = 110,
            reputation = 4,
            difficulty = 'Medium'
        },
        {
            id = 'accident_recovery',
            label = 'Accident Recovery',
            description = 'Tow a badly damaged vehicle and bring the customer with you to a mechanic shop.',
            rewardMin = 1200,
            rewardMax = 1700,
            xp = 135,
            reputation = 5,
            difficulty = 'Hard'
        }
    }
}

Config.Issues = {
    axle = {
        label = 'Axle / Alignment',
        minLevel = 1,
        repairCost = 45,
        xp = 28,
        damageEffects = true,
    },
    fuelpump = {
        label = 'Fuel Pump',
        minLevel = 2,
        repairCost = 60,
        xp = 35,
        damageEffects = true,
    },
    transmission = {
        label = 'Transmission',
        minLevel = 4,
        repairCost = 85,
        xp = 45,
        damageEffects = true,
    },
    radiator = {
        label = 'Radiator / Cooling',
        minLevel = 3,
        repairCost = 55,
        xp = 38,
        damageEffects = true,
    },
    ecu = {
        label = 'ECU / Electrical',
        minLevel = 6,
        repairCost = 95,
        xp = 55,
        damageEffects = true,
    },
    brakes = {
        label = 'Brakes',
        minLevel = 2,
        repairCost = 50,
        xp = 30,
        damageEffects = true,
    },
    suspension = {
        label = 'Suspension',
        minLevel = 3,
        repairCost = 70,
        xp = 40,
        damageEffects = true,
    },
    tyres = {
        label = 'Tyres',
        minLevel = 1,
        repairCost = 35,
        xp = 24,
        damageEffects = false,
    }
}

Config.Skills = {
    engine_specialist = {
        label = 'Engine Specialist',
        description = 'Reduces engine and radiator repair time.',
        cost = 1,
        minLevel = 2,
    },
    tow_operator = {
        label = 'Tow Operator',
        description = 'Unlocks tow dispatch jobs and higher tow payouts.',
        cost = 1,
        minLevel = 3,
    },
    diagnostics = {
        label = 'Advanced Diagnostics',
        description = 'Shows deeper hidden vehicle issue detail.',
        cost = 1,
        minLevel = 4,
    },
    electrical = {
        label = 'Electrical Expert',
        description = 'Unlocks ECU and fuel pump specialist repairs.',
        cost = 2,
        minLevel = 6,
    },
    fabrication = {
        label = 'Fabricator',
        description = 'Unlocks high-tier suspension and chassis repair RP.',
        cost = 2,
        minLevel = 8,
    },
}

Config.HiddenIssueDefaults = {
    axle = 100,
    fuelpump = 100,
    transmission = 100,
    radiator = 100,
    ecu = 100,
    brakes = 100,
    suspension = 100,
    tyres = 100,
}

Config.DamageDetection = {
    Enabled = true,
    TickMs = 1500,
    HardCrashSpeedKmh = 70.0,
    SevereCrashSpeedKmh = 120.0,
    MinCrashDeltaKmh = 35.0,
    WearTickMs = 45000,
    WearChance = 18,
}

Config.Messages = {
    NoJob = 'You are not a mechanic.',
    NoVehicle = 'No vehicle nearby.',
    NoActiveTow = 'You do not have an active tow contract.',
    TowAccepted = 'Tow contract accepted. GPS has been set.',
    TowCompleted = 'Tow contract completed.',
    TruckRented = 'Tow truck rented. Deposit paid.',
    TruckReturned = 'Tow truck returned. Deposit refunded.',
}
