Config = {}
Config.DefaultSpawn = vector3(-1035.71, -2731.87, 12.86)              -- Default spawn coords if you have start apartments disabled
Config.EnableDeleteButton = true                                      -- Define if the player can delete the character or not
Config.customNationality = false                                      -- Defines if Nationality input is custom of blocked to the list of Countries
Config.SkipSelection = false                                          -- Skip the spawn selection and spawns the player at the last location

Config.SelectionScene = {
    Interior = vector3(-558.10, 284.60, 83.05),
    HiddenCoords = vector4(-565.92, 278.98, 83.05, 88.0),
    OverviewCam = vector4(-558.35, 279.65, 84.15, 0.0),
    OverviewPoint = vector3(-556.55, 284.55, 83.85),
    OverviewFov = 46.0,
    FocusFov = 31.0,
    EmptyScenario = 'PROP_HUMAN_SEAT_CHAIR',
    FallbackScenario = 'PROP_HUMAN_SEAT_CHAIR',
    Seats = {
        {
            coords = vector4(-558.75, 284.65, 83.05, 180.0),
            cam = vector4(-558.75, 281.15, 84.00, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-557.55, 284.65, 83.05, 180.0),
            cam = vector4(-557.55, 281.15, 84.00, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-556.35, 284.65, 83.05, 180.0),
            cam = vector4(-556.35, 281.15, 84.00, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-555.15, 284.65, 83.05, 180.0),
            cam = vector4(-555.15, 281.15, 84.00, 0.0),
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        },
        {
            coords = vector4(-553.95, 284.65, 83.05, 180.0),
            cam = vector4(-553.95, 281.15, 84.00, 0.0),
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
