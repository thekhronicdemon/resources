Config = {}
Config.DefaultSpawn = vector3(-1035.71, -2731.87, 12.86)              -- Default spawn coords if you have start apartments disabled
Config.EnableDeleteButton = true                                      -- Define if the player can delete the character or not
Config.customNationality = true                                      -- Defines if Nationality input is custom of blocked to the list of Countries
Config.SkipSelection = false                                          -- Skip the spawn selection and spawns the player at the last location
Config.SelectionScenePreset = 'custom'                                -- Use 'custom' for your tuned scene, or 'portable' when sharing without your exact Tequi-la-la MLO.

Config.SelectionScene = {
    Debug = false, -- Set true while tuning seats/cameras. It draws markers at every configured seat.
    Interior = vector3(-556.47, 285.15, 82.18),
    HiddenCoords = vector4(-556.47, 285.15, 82.18, 260.8),
    OverviewCam = vector4(-548.80, 285.40, 84.20, 92.0),
    OverviewPoint = vector3(-555.45, 286.25, 83.65),
    OverviewFov = 31.0,
    FocusFov = 31.0,
    EmptyScenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    FallbackScenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    Seats = {
        {
            coords = vector4(-557.51, 291.96, 82.18, 172.4),
            cam = vector4(-557.55, 289.19, 82.97, -9.0),
            scenario = 'WORLD_HUMAN_SMOKING',
        },
        {
            coords = vector4(-551.13, 287.03, 82.98, 87.1),
            cam = vector4(-554.49, 287.04, 83.49, -97.1),
            scenario = 'WORLD_HUMAN_SMOKING',
        },
        {
            coords = vector4(-551.79, 284.24, 82.98, 83.0),
            cam = vector4(-555.15, 284.25, 83.44, -97.1),
            scenario = 'WORLD_HUMAN_SMOKING',
        },
        {
            coords = vector4(-551.30, 281.94, 82.98, 79.0),
             cam = vector4(-554.13, 281.96, 83.66, -100.9),
            scenario = 'WORLD_HUMAN_SMOKING',
        },
        {
            coords = vector4(-561.82, 285.94, 82.18, 266.6),
            cam = vector4(-551.17, 281.76, 83.73, 75.3),
            scenario = 'WORLD_HUMAN_SMOKING',
        },
    },
}

Config.SelectionScenePresets = {
    portable = {
        Debug = false,
        Interior = vector3(-1037.35, -2737.55, 20.17),
        HiddenCoords = vector4(-1034.60, -2731.70, 20.17, 240.0),
        OverviewCam = vector4(-1041.20, -2732.95, 22.10, -142.0),
        OverviewPoint = vector3(-1037.15, -2738.25, 21.05),
        OverviewFov = 45.0,
        FocusFov = 32.0,
        EmptyScenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        FallbackScenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        Seats = {
            {
                coords = vector4(-1039.20, -2739.45, 20.17, 320.0),
                cam = vector4(-1041.50, -2736.35, 21.65, -142.0),
                scenario = 'WORLD_HUMAN_SMOKING',
            },
            {
                coords = vector4(-1038.20, -2738.60, 20.17, 320.0),
                cam = vector4(-1040.55, -2735.50, 21.65, -142.0),
                scenario = 'WORLD_HUMAN_SMOKING',
            },
            {
                coords = vector4(-1037.20, -2737.75, 20.17, 320.0),
                cam = vector4(-1039.55, -2734.70, 21.65, -142.0),
                scenario = 'WORLD_HUMAN_SMOKING',
            },
            {
                coords = vector4(-1036.20, -2736.90, 20.17, 320.0),
                cam = vector4(-1038.55, -2733.85, 21.65, -142.0),
                scenario = 'WORLD_HUMAN_SMOKING',
            },
            {
                coords = vector4(-1035.20, -2736.05, 20.17, 320.0),
                cam = vector4(-1037.55, -2733.00, 21.65, -142.0),
                scenario = 'WORLD_HUMAN_SMOKING',
            },
        },
    },
}

Config.ActiveSelectionScene = Config.SelectionScene
if Config.SelectionScenePreset ~= 'custom' and Config.SelectionScenePresets[Config.SelectionScenePreset] then
    Config.ActiveSelectionScene = Config.SelectionScenePresets[Config.SelectionScenePreset]
end

-- Backward-compatible aliases for any local edits that still read the old config keys.
Config.Interior = Config.ActiveSelectionScene.Interior
Config.HiddenCoords = Config.ActiveSelectionScene.HiddenCoords
Config.CamCoords = Config.ActiveSelectionScene.OverviewCam
Config.PedCoords = Config.ActiveSelectionScene.Seats[1].coords

Config.DefaultNumberOfCharacters = 4                                  -- Define maximum amount of default characters (maximum 5 characters defined by default)
Config.PlayersNumberOfCharacters = {                                  -- Define maximum amount of player characters by rockstar license (you can find this license in your server's database in the player table)
    { license = 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', numberOfChars = 2 },
}
