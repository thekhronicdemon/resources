Config = {}

Config.DriverOnly = true

-- Base commands
Config.RightIndicatorCommand = 'prpels_right_indicator'
Config.LeftIndicatorCommand = 'prpels_left_indicator'
Config.HazardsCommand = 'prpels_hazards'
Config.LightsToggleCommand = 'prpels_lights'
Config.SirenToggleCommand = 'prpels_siren'
Config.AirhornCommand = 'prpels_airhorn'
Config.ManualSirenCommand = 'prpels_manual_siren'
Config.AuxSirenCommand = 'prpels_aux_siren'

-- Default binds
Config.DefaultRightIndicatorKey = 'RBRACKET'
Config.DefaultLeftIndicatorKey = 'LBRACKET'
Config.DefaultHazardsKey = 'BACK'
Config.DefaultLightsToggleKey = 'Y'
Config.DefaultAirhornKey = 'E'
Config.DefaultSirenToggleKey = 'COMMA'
Config.DefaultManualSirenKey = 'N'
Config.DefaultAuxSirenKey = 'DOWN'

-- GTA controls to suppress while driving any vehicle, so these keys do indicators only.
Config.DisableIndicatorControls = {
    hazards = 177 -- Phone Cancel
}

-- GTA controls to suppress while driving an ELS vehicle, so these keys do ELS only.
Config.DisableControls = {
    lights = 246,        -- Text Chat Team
    airhorn = 86,        -- Horn
    sirenToggle = 82,    -- Previous Radio Station
    manualSiren = 81,    -- Next Radio Station
    auxSiren = 172       -- Phone Up
}

Config.SirenTones = {
    { name = 'VEHICLES_HORNS_SIREN_1', label = 'Wail' },
    { name = 'VEHICLES_HORNS_SIREN_2', label = 'Yelp' },
    { name = 'VEHICLES_HORNS_POLICE_WARNING', label = 'Priority' }
}

Config.AirhornSound = 'SIRENS_AIRHORN'
Config.AuxSirenSound = 'VEHICLES_HORNS_AMBULANCE_WARNING'
Config.SoundSet = 0

-- Vehicle model whitelist.
Config.AllowedModels = {
    ['police']          = true,
    ['police2']         = true,
    ['police3']         = true,
    ['police4']         = true,
    ['policeb']         = true,
    ['policet']         = true,
    ['fbi']             = true,
    ['fbi2']            = true,
    ['sheriff']         = true,
    ['sheriff2']        = true,
    ['ambulance']       = true,
    ['firetruk']        = true,
    ['npolvic']         = true,
    ['npolstang']       = true,
    ['npolvette']       = true,
    ['npolchal']        = true
}

Config.Notify = false

Config.Messages = {
    notAllowed = '^1ELS:^7 This vehicle is not configured for prp-ELS.',
    lightsOn = '^2ELS:^7 Lights enabled.',
    lightsOff = '^3ELS:^7 Lights disabled.',
    sirenOn = '^2ELS:^7 Siren enabled.',
    sirenOff = '^3ELS:^7 Siren disabled.',
    needLights = '^3ELS:^7 Turn lights on first.',
    toneChanged = '^2ELS:^7 Siren tone changed.'
}
