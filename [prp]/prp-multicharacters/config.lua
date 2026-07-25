Config = {}
Config.DefaultSpawn = vector3(-1035.71, -2731.87, 12.86)              -- Default spawn coords if you have start apartments disabled
Config.EnableDeleteButton = true                                      -- Define if the player can delete the character or not
Config.customNationality = false                                      -- Defines if Nationality input is custom of blocked to the list of Countries
Config.SkipSelection = false                                          -- Skip the spawn selection and spawns the player at the last location

Config.SelectionScene = {
    Interior = vector3(-561.55, 286.78, 82.18),
    HiddenCoords = vector4(-565.92, 278.98, 82.18, 88.0),
    OverviewCam = vector4(-560.30, 280.55, 84.10, 0.0),
    OverviewPoint = vector3(-559.25, 286.05, 82.95),
    OverviewFov = 50.0,
    FocusFov = 34.0,
    EmptyScenario = 'PROP_HUMAN_SEAT_CHAIR_DRINK',
    Seats = {
        {
            coords = vector4(-562.15, 286.18, 82.18, 265.0),
            cam = vector4(-562.15, 282.85, 83.30, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-560.95, 286.18, 82.18, 265.0),
            cam = vector4(-560.95, 282.85, 83.30, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-559.75, 286.18, 82.18, 265.0),
            cam = vector4(-559.75, 282.85, 83.30, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-558.55, 286.18, 82.18, 265.0),
            cam = vector4(-558.55, 282.85, 83.30, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-557.35, 286.18, 82.18, 265.0),
            cam = vector4(-557.35, 282.85, 83.30, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
    },
}

-- Backward-compatible aliases for any local edits that still read the old config keys.
Config.Interior = Config.SelectionScene.Interior
Config.HiddenCoords = Config.SelectionScene.HiddenCoords
Config.CamCoords = Config.SelectionScene.OverviewCam
Config.PedCoords = Config.SelectionScene.Seats[1].coords

Config.DefaultNumberOfCharacters = 5                                  -- Define maximum amount of default characters (maximum 5 characters defined by default)
Config.PlayersNumberOfCharacters = {                                  -- Define maximum amount of player characters by rockstar license (you can find this license in your server's database in the player table)
    { license = 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', numberOfChars = 2 },
}
