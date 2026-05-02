Config = {}

Config.Debug = false
Config.JobName = 'garbage'
Config.Command = 'jobmenu'

Config.RequireGarbageTruck = true
Config.RequirePlayerInTruckToStart = true

Config.Depot = {
    label = 'Garbage Depot',
    coords = vector4(892.27, -2172.26, 32.29, 170.5),
    ped = {
        enabled = true,
        model = 's_m_y_garbage',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    spawn = vector4(882.87, -2181.24, 30.52, 174.0),
    vehicle = 'trash',
    platePrefix = 'GARB',
    deposit = 250,
    returnDistance = 18.0,
    blip = { enabled = true, sprite = 318, colour = 2, scale = 0.8 },
}

Config.GarbageTruckModels = {
    [`trash`] = true,
    [`trash2`] = true,
}

-- Custom tray/trey bed vehicles can show loaded hard rubbish in exact slots.
-- Add your custom vehicle model here and tune each offset/rotation until the
-- prop sits perfectly in the tray. Vehicles without this config still work,
-- they just do not show item block placement.
Config.TrayVehicles = {
    -- [`your_tray_vehicle`] = {
    --     slots = {
    --         { offset = vector3(-0.55, -1.65, 0.62), rotation = vector3(0.0, 0.0, 0.0) },
    --         { offset = vector3(0.00, -1.65, 0.62), rotation = vector3(0.0, 0.0, 0.0) },
    --         { offset = vector3(0.55, -1.65, 0.62), rotation = vector3(0.0, 0.0, 0.0) },
    --         { offset = vector3(-0.55, -2.15, 0.62), rotation = vector3(0.0, 0.0, 0.0) },
    --         { offset = vector3(0.00, -2.15, 0.62), rotation = vector3(0.0, 0.0, 0.0) },
    --         { offset = vector3(0.55, -2.15, 0.62), rotation = vector3(0.0, 0.0, 0.0) },
    --     }
    -- }
}

Config.DrawDistance = 35.0
Config.TruckDistance = 12.0
Config.TargetDistance = 2.2
Config.TruckRearDistance = 3.0
Config.TruckRearOffset = vector3(0.0, -3.2, 0.0)
Config.BinSpawnDistance = 95.0
Config.RouteBlipSprite = 318
Config.RouteBlipColour = 3
Config.ScrapBlipSprite = 365
Config.ScrapBlipColour = 5
Config.ScrapyardBlipSprite = 467
Config.ScrapyardBlipColour = 47

Config.Animations = {
    BinCollect = {
        dict = 'anim@heists@narcotics@trash',
        anim = 'pickup',
        time = 3500,
        flag = 49,
    },
    ScrapCollect = {
        dict = 'amb@medic@standing@kneel@base',
        anim = 'base',
        time = 2500,
        flag = 1,
    },
    CarryScrap = {
        dict = 'anim@heists@box_carry@',
        anim = 'idle',
        flag = 49,
    },
    PlaceInTruck = {
        dict = 'anim@heists@narcotics@trash',
        anim = 'throw_b',
        time = 1800,
        flag = 49,
    },
    Breakdown = {
        dict = 'amb@world_human_hammering@male@base',
        anim = 'base',
        time = 6500,
        flag = 49,
    }
}

Config.Props = {
    ClosedBin = 'prop_bin_08a',
    OpenBin = 'prop_bin_08open',
    BinBag = 'hei_prop_heist_binbag'
}

Config.BinBagAttach = {
    bone = 57005,
    pos = vector3(0.12, 0.0, -0.03),
    rot = vector3(-90.0, 0.0, 0.0)
}

Config.Pay = {
    MirrorPark = {
        min = 900,
        max = 1450,
        account = 'cash'
    }
}

Config.Areas = {
    mirrorpark = {
        label = 'Mirror Park',
        description = 'Residential bin run around Mirror Park.',
        payKey = 'MirrorPark',
        bins = {
            vector4(1251.35, -396.64, 69.12, 141.36),
            vector4(1272.33, -422.68, 69.12, 112.56),
            vector4(1276.28, -432.7, 69.12, 109.83),
            vector4(1278.35, -470.44, 69.11, 76.87),
            vector4(1276.11, -479.24, 69.12, 70.69),
            vector4(1266.21, -504.56, 69.13, 71.98),
            vector4(1261.64, -519.22, 69.13, 76.94),
            vector4(1304.39, -559.94, 71.37, 161.76), --Mirror Court
            vector4(1328.21, -568.16, 73.28, 153.46), 
            vector4(1353.23, -585.58, 74.37, 129.94),            
            vector4(1366.66, -593.32, 74.39, 182.2),
            vector4(1377.92, -586.54, 74.37, 234.91),
            vector4(1377.42, -571.35, 74.37, 305.9),
            vector4(1366.99, -565.48, 74.4, 15.33),
            vector4(1342.92, -558.85, 73.96, 327.98),
            vector4(1325.92, -551.55, 72.64, 337.51),
            vector4(1300.29, -543.45, 70.72, 349.68), -- Mirror Court
            vector4(1206.64, -510.56, 65.61, 331.59),
            vector4(1015.83, -525.74, 60.61, 27.63),
            vector4(993.41, -538.35, 59.98, 40.82),
            vector4(976.98, -549.83, 59.37, 37.41),
            vector4(921.38, -578.29, 57.38, 23.09),
            vector4(877.12, -540.71, 57.36, 257.09),
            vector4(919.19, -512.37, 58.78, 195.14),
            vector4(936.74, -504.65, 59.75, 209.83),
            vector4(963.56, -489.51, 61.48, 204.25),
            vector4(1007.85, -458.36, 63.89, 224.11),
            vector4(1031.08, -440.41, 65.28, 217.81),
            vector4(1097.29, -387.14, 67.15, 227.11),
            vector4(1165.02, -369.37, 67.76, 159.26),
            vector4(1180.08, -439.42, 66.94, 86.31),
            vector4(1173.22, -468.81, 66.12, 79.54),
            vector4(1079.92, -483.76, 63.89, 254.59),
            vector4(1083.28, -463.98, 64.96, 257.41),
            vector4(1089.05, -433.77, 66.63, 255.53),
            vector4(1091.51, -413.27, 67.18, 268.38),
            vector4(1068.82, -390.79, 67.18, 51.38),
            vector4(1034.88, -419.53, 65.98, 35.06),
        }
    }
}

Config.HardRubbish = {
    label = 'Collect Scrap Metal',
    description = 'Drive to hard rubbish clusters, pick up each visible item, carry it to the back of the truck, then break it down at the scrapyard.',
    MaxCarry = 12,
    CarryAttach = {
        bone = 28422,
        pos = vector3(0.0, -0.08, -0.18),
        rot = vector3(0.0, 0.0, 0.0),
    },
    Scrapyard = vector4(2409.16, 3127.82, 48.15, 65.0),
    BreakdownObject = {
        enabled = true,
        model = 'prop_tool_bench02',
        offset = vector3(0.0, 0.0, -1.0),
        heading = 65.0,
    },
    Clusters = {
        {
            label = 'Mirror Park Hard Rubbish 1',
            center = vector4(1140.91, -466.06, 66.49, 255.0),
            items = {
                { prop = 'old_tv', offset = vector3(0.0, 0.0, 0.0), heading = 255.0 },
                { prop = 'old_chair', offset = vector3(0.85, -0.25, 0.0), heading = 215.0 },
                { prop = 'tyre_pile', offset = vector3(-0.75, 0.25, 0.0), heading = 15.0 },
            }
        },
        {
            label = 'Mirror Park Hard Rubbish 2',
            center = vector4(1115.62, -476.07, 65.65, 344.0),
            items = {
                { prop = 'microwave', offset = vector3(0.0, 0.0, 0.0), heading = 344.0 },
                { prop = 'scrap_metal', offset = vector3(0.75, 0.15, 0.0), heading = 80.0 },
                { prop = 'old_tv', offset = vector3(-0.75, -0.2, 0.0), heading = 210.0 },
            }
        },
        {
            label = 'Mirror Park Hard Rubbish 3',
            center = vector4(1087.96, -486.18, 64.93, 344.0),
            items = {
                { prop = 'scrap_metal', offset = vector3(0.0, 0.0, 0.0), heading = 344.0 },
                { prop = 'tyre_pile', offset = vector3(0.85, 0.20, 0.0), heading = 25.0 },
                { prop = 'old_chair', offset = vector3(-0.75, -0.15, 0.0), heading = 180.0 },
                { prop = 'microwave', offset = vector3(0.20, -0.85, 0.0), heading = 120.0 },
            }
        },
        {
            label = 'Mirror Park Hard Rubbish 4',
            center = vector4(1057.42, -474.67, 63.89, 75.0),
            items = {
                { prop = 'old_tv', offset = vector3(0.0, 0.0, 0.0), heading = 75.0 },
                { prop = 'scrap_metal', offset = vector3(0.80, -0.25, 0.0), heading = 250.0 },
                { prop = 'tyre_pile', offset = vector3(-0.70, 0.35, 0.0), heading = 0.0 },
            }
        },
        {
            label = 'Mirror Park Hard Rubbish 5',
            center = vector4(1031.58, -452.32, 64.13, 215.0),
            items = {
                { prop = 'microwave', offset = vector3(0.0, 0.0, 0.0), heading = 215.0 },
                { prop = 'old_chair', offset = vector3(-0.70, 0.20, 0.0), heading = 275.0 },
                { prop = 'old_tv', offset = vector3(0.75, -0.25, 0.0), heading = 95.0 },
                { prop = 'scrap_metal', offset = vector3(0.25, 0.80, 0.0), heading = 20.0 },
            }
        },
    },
    Props = {
        old_tv = {
            label = 'Old TV',
            model = 'prop_tv_06',
            rewards = {
                plastic = { min = 2, max = 5 },
                glass = { min = 2, max = 4 },
                steel = { min = 1, max = 2 },
            }
        },
        microwave = {
            label = 'Broken Microwave',
            model = 'prop_micro_01',
            rewards = {
                plastic = { min = 1, max = 3 },
                steel = { min = 2, max = 5 },
                glass = { min = 1, max = 2 },
            }
        },
        old_chair = {
            label = 'Old Chair',
            model = 'prop_chair_05',
            rewards = {
                plastic = { min = 1, max = 2 },
                steel = { min = 1, max = 3 },
            }
        },
        tyre_pile = {
            label = 'Tyre Pile',
            model = 'prop_rub_tyre_01',
            rewards = {
                rubber = { min = 3, max = 7 },
            }
        },
        scrap_metal = {
            label = 'Scrap Metal',
            model = 'prop_rub_carpart_05',
            rewards = {
                steel = { min = 4, max = 8 },
                rubber = { min = 1, max = 2 },
            }
        },
    }
}

Config.Notifications = {
    NeedJob = 'You need to be employed as garbage to use this.',
    NeedTruck = 'You need to be near a garbage truck.',
    NeedTruckToStart = 'You must be inside a Trashmaster before starting a garbage job.',
    DepotTruckSpawned = 'Trashmaster collected. Get in and open /jobmenu to start work.',
    DepotTruckBlocked = 'The depot spawn point is blocked.',
    DepotReturnTruck = 'Trashmaster returned. Deposit refunded.',
    AlreadyRented = 'You already have a rented Trashmaster. Return it before renting another one.',
    NoDeposit = 'You need $250 cash for the truck deposit.',
    NoRentedTruck = 'You do not have a rented Trashmaster.',
    WrongTruck = 'This is not your rented Trashmaster.',
    BringTruckCloser = 'Bring your rented Trashmaster closer to the depot NPC.',
    StartedRoute = 'Mirror Park route started. Follow the blue GPS.',
    AlreadyRunning = 'You already have a job active.',
    RouteComplete = 'Route complete. You have been paid.',
    ScrapStarted = 'Hard rubbish collection started. Follow the blue GPS.',
    ScrapStopped = 'Hard rubbish collection stopped.',
    CarryFull = 'Your truck is full of hard rubbish. Go to the scrapyard.',
    NothingCarried = 'You have no hard rubbish to break down.',
    ScrapItemBroken = 'One hard rubbish item broken down.',
    ScrapComplete = 'Scrap job complete.',
    PutItemInTruck = 'Take it to the back of the Trashmaster and place it in.',
    TruckLoaded = 'Loaded into truck.',
}
