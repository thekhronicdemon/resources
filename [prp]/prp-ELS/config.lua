Config = {}

Config.DriverOnly = true

-- Base commands
Config.LightsToggleCommand = 'prpels_lights'
Config.SirenToggleCommand  = 'prpels_siren'

-- Extra alias commands so multiple keyboard layouts/workflows still work.
Config.LightsToggleAliasCommand = 'prpels_lights_np'
Config.SirenToggleAliasCommand1 = 'prpels_siren_eq'
Config.SirenToggleAliasCommand2 = 'prpels_siren_np'

-- Default binds
-- Lights: top-row minus and numpad subtract
Config.DefaultLightsToggleKey = 'SUBTRACT'
Config.DefaultLightsToggleAliasKey = 'RBRACKET'

-- Siren: top-row plus/equals and numpad add
Config.DefaultSirenToggleKey1 = 'ADD'
Config.DefaultSirenToggleKey2 = 'LBRACKET'

-- Vehicle model whitelist.
Config.AllowedModels = {
    ['police'] = true,
    ['police2'] = true,
    ['police3'] = true,
    ['police4'] = true,
    ['policeb'] = true,
    ['policet'] = true,
    ['fbi'] = true,
    ['fbi2'] = true,
    ['sheriff'] = true,
    ['sheriff2'] = true,
    ['ambulance'] = true,
    ['firetruk'] = true,
    ['lspdbuffalosx'] = true,
    ['lspdbuffalosx2'] = true,
    ['lspdbuffalosx3'] = true
}

Config.Notify = 'qb-notify'

Config.Messages = {
    notAllowed = '^1ELS:^7 This vehicle is not configured for prp-ELS.',
    lightsOn = '^2ELS:^7 Lights enabled.',
    lightsOff = '^3ELS:^7 Lights disabled.',
    sirenOn = '^2ELS:^7 Siren enabled.',
    sirenOff = '^3ELS:^7 Siren disabled.',
    needLights = '^3ELS:^7 Turn lights on first.'
}
