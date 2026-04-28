Config = {}

Config.UseMPH = true
Config.ShowMinimapOnFoot = false
Config.ShowCompassOnFoot = false
Config.PlayerUpdateInterval = 250
Config.VehicleUpdateInterval = 100
Config.LowFuelAlert = true
Config.LowFuelThreshold = 20

Config.DisableStress = false
Config.NotifyStress = true
Config.StressChance = 1.0
Config.MinimumStress = 50
Config.MinimumSpeedUnbuckled = 60
Config.MinimumSpeed = 80
Config.SpeedStressInterval = 5000
Config.ShootingStressInterval = 1500
Config.EnableStressWhitelist = false

Config.WhitelistedJobs = {
    ['leo'] = true,
    ['ambulance'] = true,
}

Config.WhitelistedWeaponArmed = {
    [`weapon_petrolcan`] = true,
    [`weapon_hazardcan`] = true,
    [`weapon_fireextinguisher`] = true,
    [`weapon_dagger`] = true,
    [`weapon_bat`] = true,
    [`weapon_bottle`] = true,
    [`weapon_crowbar`] = true,
    [`weapon_flashlight`] = true,
    [`weapon_golfclub`] = true,
    [`weapon_hammer`] = true,
    [`weapon_hatchet`] = true,
    [`weapon_knuckle`] = true,
    [`weapon_knife`] = true,
    [`weapon_machete`] = true,
    [`weapon_switchblade`] = true,
    [`weapon_nightstick`] = true,
    [`weapon_wrench`] = true,
    [`weapon_battleaxe`] = true,
    [`weapon_poolcue`] = true,
    [`weapon_briefcase`] = true,
    [`weapon_briefcase_02`] = true,
    [`weapon_garbagebag`] = true,
    [`weapon_handcuffs`] = true,
    [`weapon_bread`] = true,
    [`weapon_stone_hatchet`] = true,
    [`weapon_grenade`] = true,
    [`weapon_bzgas`] = true,
    [`weapon_molotov`] = true,
    [`weapon_stickybomb`] = true,
    [`weapon_proxmine`] = true,
    [`weapon_snowball`] = true,
    [`weapon_pipebomb`] = true,
    [`weapon_ball`] = true,
    [`weapon_smokegrenade`] = true,
    [`weapon_flare`] = true,
}

Config.WhitelistedWeaponStress = {
    [`weapon_petrolcan`] = true,
    [`weapon_hazardcan`] = true,
    [`weapon_fireextinguisher`] = true,
}

Config.VehClassStress = {
    ['0'] = true,
    ['1'] = true,
    ['2'] = true,
    ['3'] = true,
    ['4'] = true,
    ['5'] = true,
    ['6'] = true,
    ['7'] = true,
    ['8'] = true,
    ['9'] = true,
    ['10'] = true,
    ['11'] = true,
    ['12'] = true,
    ['13'] = false,
    ['14'] = false,
    ['15'] = false,
    ['16'] = false,
    ['18'] = false,
    ['19'] = false,
    ['20'] = false,
    ['21'] = false,
}

Config.WhitelistedVehicles = {
    -- [`adder`] = true,
}

Config.Intensity = {
    ['blur'] = {
        [1] = { min = 50, max = 60, intensity = 1500 },
        [2] = { min = 60, max = 70, intensity = 2000 },
        [3] = { min = 70, max = 80, intensity = 2500 },
        [4] = { min = 80, max = 90, intensity = 2700 },
        [5] = { min = 90, max = 100, intensity = 3000 },
    },
}

Config.EffectInterval = {
    [1] = { min = 50, max = 60, timeout = math.random(50000, 60000) },
    [2] = { min = 60, max = 70, timeout = math.random(40000, 50000) },
    [3] = { min = 70, max = 80, timeout = math.random(30000, 40000) },
    [4] = { min = 80, max = 90, timeout = math.random(20000, 30000) },
    [5] = { min = 90, max = 100, timeout = math.random(15000, 20000) },
}
