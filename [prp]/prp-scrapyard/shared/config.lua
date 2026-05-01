Config = {}

--[[
    PRP Scrapyard Configuration

    Quick edit guide:
    - StartPed = NPC that gives the scrapyard job
    - DropZone = parking rectangle where the stolen vehicle must be placed
    - PartsPed = final NPC used for BOTH:
        1. checking whether the correct vehicle is parked in the rectangle
        2. taking stripped parts from the player
    - StealLocations = possible spawn locations for the mission vehicle
    - VehicleSets = categories of vehicles + the parts each category can lose
    - Parts = visual/carry settings for each removable part
    - Mail = prp-phone email contents sent when a mission starts
    - Rewards = payout tuning
]]

Config.Debug = false
Config.FrameworkNotify = true
Config.UseQBMail = true

-- Job NPC: talk here to receive a new scrapyard mission
Config.StartPed = {
    model = 's_m_m_dockwork_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    coords = vector4(2403.51, 3127.95, 48.15, 270.0),
    zone = {
        coords = vector3(2403.51, 3127.95, 48.15),
        length = 6.0,
        width = 4.0,
        heading = 270.0,
        minZ = 46.15,
        maxZ = 50.15,
    }
}

-- Vehicle parking rectangle: the stolen vehicle must be parked INSIDE this area
-- This location has NO NPC on it.
Config.DropZone = {
    coords = vector3(2351.5, 3132.96, 48.2),
    length = 5.6,      -- average car length area
    width = 2.8,       -- average car width area
    heading = 170.0,
    minZ = 46.2,
    maxZ = 50.2,

    -- Four-corner ground marker settings
    corners = {
        draw = true,
        drawDistance = 45.0,
        markerType = 28,
        markerSize = vec3(0.22, 0.22, 0.22),
        color = { r = 0, g = 120, b = 255, a = 180 },
        zOffset = 0.03,
    }
}

-- Final NPC: used to confirm the vehicle AND receive stripped parts
Config.PartsPed = {
    model = 's_m_y_construct_01',
    scenario = 'WORLD_HUMAN_HAMMERING',
    coords = vector4(2341.62, 3143.59, 48.21, 270.0),
    zone = {
        coords = vector3(2341.62, 3143.59, 48.21),
        length = 6.0,
        width = 4.0,
        heading = 270.0,
        minZ = 46.21,
        maxZ = 50.21,
    }
}

-- Possible mission vehicle spawn locations
Config.StealLocations = {
    { coords = vector4(1735.44, 3709.28, 34.14, 20.5) },
    { coords = vector4(1223.43, 2728.91, 38.00, 177.44) },
    { coords = vector4(913.99, -170.55, 74.31, 237.41) },
    { coords = vector4(-534.21, -1711.76, 19.17, 330.16) },
    { coords = vector4(-1157.72, -2007.67, 13.18, 313.37) },
    { coords = vector4(2574.86, 466.56, 108.62, 179.55) },
}

-- Vehicle categories
-- models = possible GTA vehicle spawn names
-- parts = removable parts available on that category
Config.VehicleSets = {
    ['4door'] = {
        label = '4 Door',
        models = { 'asea', 'primo', 'stanier', 'tailgater', 'sultan', 'buffalo', 'emperor' },
        parts = {
            'door_fl', 'door_fr', 'door_rl', 'door_rr',
            'wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr',
            'hood', 'trunk', 'engine'
        }
    },
    ['2door'] = {
        label = '2 Door',
        models = { 'zion', 'oracle', 'sentinel', 'jackal', 'f620', 'penumbra' },
        parts = {
            'door_fl', 'door_fr',
            'wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr',
            'hood', 'trunk', 'engine'
        }
    },
    ['motorcycle'] = {
        label = 'Motorcycle',
        models = { 'bati', 'bagger', 'faggio', 'sanchez', 'daemon', 'innovation' },
        parts = {
            'wheel_fl', 'wheel_rr', 'engine'
        }
    }
}

-- Individual part settings
-- doorIndex follows GTA vehicle door indexes
-- wheelIndex follows GTA wheel indexes
Config.Parts = {
    ['door_fl'] = { label = 'Front Left Door', type = 'door', doorIndex = 0, carryProp = 'prop_car_door_01' },
    ['door_fr'] = { label = 'Front Right Door', type = 'door', doorIndex = 1, carryProp = 'prop_car_door_01' },
    ['door_rl'] = { label = 'Rear Left Door', type = 'door', doorIndex = 2, carryProp = 'prop_car_door_01' },
    ['door_rr'] = { label = 'Rear Right Door', type = 'door', doorIndex = 3, carryProp = 'prop_car_door_01' },
    ['hood'] = { label = 'Hood', type = 'panel', doorIndex = 4, carryProp = 'prop_car_bonnet_01' },
    ['trunk'] = { label = 'Trunk', type = 'panel', doorIndex = 5, carryProp = 'prop_car_bonnet_02' },
    ['wheel_fl'] = { label = 'Front Left Wheel', type = 'wheel', wheelIndex = 0, carryProp = 'prop_wheel_tyre' },
    ['wheel_fr'] = { label = 'Front Right Wheel', type = 'wheel', wheelIndex = 1, carryProp = 'prop_wheel_tyre' },
    ['wheel_rl'] = { label = 'Rear Left Wheel', type = 'wheel', wheelIndex = 4, carryProp = 'prop_wheel_tyre' },
    ['wheel_rr'] = { label = 'Rear Right Wheel', type = 'wheel', wheelIndex = 5, carryProp = 'prop_wheel_tyre' },
    ['engine'] = { label = 'Engine', type = 'engine', carryProp = 'prop_car_engine_01' },
}

-- Progressbar timings (milliseconds)
Config.Progress = {
    removePartMs = 5500,
    handInPartMs = 2200,
    confirmVehicleMs = 2500,
}

-- Interaction distances
Config.InteractDistance = 2.0
Config.NpcDistance = 2.0

-- prp-phone mission email
Config.Mail = {
    sender = 'PRP Scrapyard',
    subject = 'Vehicle Contract',
    message = 'Target vehicle details:<br><br><b>Plate:</b> %s<br><b>Color:</b> %s<br><b>Type:</b> %s<br><br>Steal it and bring it back to the yard.'
}

-- Reward tuning
Config.Rewards = {
    guaranteedDrops = 8,
    perPartBonusChance = 25,
    bonusRollsMin = 1,
    bonusRollsMax = 3,
}

-- Possible reward items
Config.Items = {
    'metalscrap',
    'plastic',
    'copper',
    'iron',
    'aluminum',
    'steel',
    'glass',
}
