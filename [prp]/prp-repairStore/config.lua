Config = {}

Config.Debug = false

Config.Core = 'qb-core'
Config.Target = 'qb-target'

Config.Mechanic = {
    Enabled = true,
    JobNames = {
        mechanic = true,
    },
    RequireOnDuty = true,
    BlockMessage = 'A mechanic is currently on duty. Please visit a mechanic.'
}

Config.Payment = {
    Account = 'cash',
    RepairPrice = 750,
    MechanicDiscountPercent = 75 -- on-duty mechanics pay 75% less
}

Config.TargetSettings = {
    Distance = 3.0,
    Icon = 'fas fa-wrench',
    Label = 'Repair Store'
}

Config.Interaction = {
    VehicleSearchRadius = 6.0,
    FreezeVehicleInMenu = true,
    FreezePlayerInMenu = false,
    DisableVehicleControlsInMenu = true
}

Config.Repair = {
    Duration = 8000, -- milliseconds
    EngineHealth = 1000.0,
    BodyHealth = 1000.0,
    DirtLevel = 0.0
}

-- Saves only vehicles owned by the player. Stolen/unowned vehicles can still be modified, but will not persist.
Config.SaveOwnedVehicleMods = true
Config.PlayerVehiclesTable = 'player_vehicles'
Config.PlayerVehiclesPlateColumn = 'plate'
Config.PlayerVehiclesModsColumn = 'mods'

Config.Locations = {
    {
        id = 'route68_lsc',
        label = 'Route 68 Repair Store',
        coords = vector3(1174.83, 2640.21, 37.75),
        radius = 5.0,
    },
    {
        id = 'city_lsc',
        label = 'City Repair Store',
        coords = vector3(-337.45, -136.92, 39.01),
        radius = 5.0,
    },
    {
        id = 'bennys',
        label = 'Bennys Repair Store',
        coords = vector3(-211.55, -1324.55, 30.89),
        radius = 5.0,
    }
}

Config.CosmeticMods = {
    { id = 'spoiler', label = 'Spoilers', modType = 0, price = 350, camera = 'rear' },
    { id = 'front_bumper', label = 'Front Bumper', modType = 1, price = 450, camera = 'front' },
    { id = 'rear_bumper', label = 'Rear Bumper', modType = 2, price = 450, camera = 'rear' },
    { id = 'side_skirt', label = 'Side Skirts', modType = 3, price = 350, camera = 'side' },
    { id = 'exhaust', label = 'Exhaust', modType = 4, price = 350, camera = 'rear' },
    { id = 'frame', label = 'Frame / Roll Cage', modType = 5, price = 500, camera = 'side' },
    { id = 'grille', label = 'Grille', modType = 6, price = 300, camera = 'front' },
    { id = 'hood', label = 'Hood', modType = 7, price = 400, camera = 'frontTop' },
    { id = 'fender', label = 'Left Fender', modType = 8, price = 300, camera = 'side' },
    { id = 'right_fender', label = 'Right Fender', modType = 9, price = 300, camera = 'side' },
    { id = 'roof', label = 'Roof', modType = 10, price = 350, camera = 'top' },
    { id = 'horns', label = 'Horn', modType = 14, price = 250, camera = 'front' }
}

Config.EngineMods = {
    { id = 'engine', label = 'Engine', modType = 11, price = 1500, camera = 'frontTop' },
    { id = 'brakes', label = 'Brakes', modType = 12, price = 1250, camera = 'side' },
    { id = 'transmission', label = 'Transmission', modType = 13, price = 1400, camera = 'frontTop' },
    { id = 'suspension', label = 'Suspension', modType = 15, price = 1000, camera = 'side' },
    { id = 'armor', label = 'Armor', modType = 16, price = 2000, camera = 'diagonal' },
    { id = 'turbo', label = 'Turbo', toggle = 18, price = 2500, camera = 'frontTop' }
}

Config.VisualMods = {
    { id = 'primary_colour', label = 'Primary Colour', kind = 'primaryColour', price = 500, camera = 'diagonal' },
    { id = 'secondary_colour', label = 'Secondary Colour', kind = 'secondaryColour', price = 500, camera = 'diagonal' },
    { id = 'pearlescent', label = 'Pearlescent', kind = 'pearlescent', price = 350, camera = 'diagonal' },
    { id = 'wheel_colour', label = 'Wheel Colour', kind = 'wheelColour', price = 350, camera = 'side' },
    { id = 'window_tint', label = 'Window Tint', kind = 'windowTint', price = 300, camera = 'side' },
    { id = 'plate_index', label = 'Plate Style', kind = 'plateIndex', price = 250, camera = 'rear' },
    { id = 'xenon', label = 'Xenon Headlights', toggle = 22, price = 700, camera = 'front' }
}

Config.WheelPrice = 700

Config.Colours = {
    { label = 'Black', id = 0 },
    { label = 'Graphite', id = 1 },
    { label = 'Silver', id = 4 },
    { label = 'White', id = 111 },
    { label = 'Red', id = 27 },
    { label = 'Torino Red', id = 28 },
    { label = 'Hot Pink', id = 135 },
    { label = 'Blue', id = 64 },
    { label = 'Ultra Blue', id = 70 },
    { label = 'Yellow', id = 88 },
    { label = 'Orange', id = 38 },
    { label = 'Lime Green', id = 92 },
    { label = 'Green', id = 55 },
    { label = 'Purple', id = 145 }
}

Config.WindowTints = {
    { label = 'None', id = 0 },
    { label = 'Pure Black', id = 1 },
    { label = 'Dark Smoke', id = 2 },
    { label = 'Light Smoke', id = 3 },
    { label = 'Stock', id = 4 },
    { label = 'Limo', id = 5 },
    { label = 'Green', id = 6 }
}

Config.PlateIndexes = {
    { label = 'Blue on White 1', id = 0 },
    { label = 'Yellow on Black', id = 1 },
    { label = 'Yellow on Blue', id = 2 },
    { label = 'Blue on White 2', id = 3 },
    { label = 'Blue on White 3', id = 4 },
    { label = 'Yankton', id = 5 }
}

Config.WheelTypes = {
    { label = 'Sport', id = 0 },
    { label = 'Muscle', id = 1 },
    { label = 'Lowrider', id = 2 },
    { label = 'SUV', id = 3 },
    { label = 'Offroad', id = 4 },
    { label = 'Tuner', id = 5 },
    { label = 'Bike', id = 6 },
    { label = 'High End', id = 7 },
    { label = 'Benny Originals', id = 8 },
    { label = 'Benny Bespoke', id = 9 },
    { label = 'Open Wheel', id = 10 },
    { label = 'Street', id = 11 },
    { label = 'Track', id = 12 }
}


-- Extra controls blocked while the NUI is open.
-- Helps stop radio/weapon wheel/phone/camera controls firing while scrolling the UI.
Config.DisableControlsInMenu = {
    12, 13, 14, 15, 16, 17, 37, 44, 45, 80, 81, 82, 83, 84, 85,
    99, 100, 140, 141, 142, 143, 157, 158, 159, 160, 161, 162,
    163, 164, 165, 199, 200, 241, 242, 243, 244, 245, 246, 257
}
