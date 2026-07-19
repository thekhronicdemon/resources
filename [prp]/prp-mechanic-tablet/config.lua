Config = {}

Config.Debug = false
Config.MechanicJobs = {
    mechanic = 0,
    tuner = 0,
}

Config.Items = {
    Tablet = 'mechanic_tablet',
    Airbags = 'airbags',
    Stancer = 'stancer',
    Hydraulics = 'hydraulics_kit',
}

Config.InstallTime = 10000
Config.RemoveTime = 7000
Config.RequireMechanicForTablet = true
Config.RequireMechanicForInstall = true
Config.MaxVehicleDistance = 4.0

Config.Defaults = {
    suspension = 0.0,
    -- Adjustment added to the vehicle's factory wheel width (not an absolute width).
    wheelWidth = 0.0,
    frontCamber = 0.0,
    rearCamber = 0.0,
    frontTrack = 0.0,
    rearTrack = 0.0,
}

Config.Limits = {
    suspension = { min = -0.15, max = 0.15, step = 0.005 },
    wheelWidth = { min = -0.10, max = 0.25, step = 0.005 },
    frontCamber = { min = -0.35, max = 0.35, step = 0.005 },
    rearCamber = { min = -0.35, max = 0.35, step = 0.005 },
    frontTrack = { min = -0.30, max = 0.30, step = 0.005 },
    rearTrack = { min = -0.30, max = 0.30, step = 0.005 },
}

Config.Airbags = {
    -- Added to the saved stance suspension while airbags are lowered.
    loweredOffset = 0.10,
    autoLower = true,
    enabledByDefault = true,
    toggleCommand = 'prp_airbags_toggle',
    defaultKey = 'J',
    lowerDurationMs = 1600,
    raiseDurationMs = 1300,
    soundVolume = 0.65,
    lowerSpeed = 0.15,
    raiseSpeed = 0.45,
    stopDelayMs = 500,
}

Config.Hydraulics = {
    toggleCommand = 'prp_hydraulics_toggle',
    frontCommand = 'prp_hydraulics_front',
    rearCommand = 'prp_hydraulics_rear',
    leftCommand = 'prp_hydraulics_left',
    rightCommand = 'prp_hydraulics_right',
    allCommand = 'prp_hydraulics_all',

    defaultKeys = {
        toggle = 'H',
        front = 'NUMPAD8',
        rear = 'NUMPAD2',
        left = 'NUMPAD4',
        right = 'NUMPAD6',
        all = 'NUMPAD5',
    },

    cooldownMs = 220,
    groundCheckMs = 50,
    groundSettleMs = 150,
    takeoffGraceMs = 1000,
    maxLockMs = 3500,
    verticalForce = 2.4,
    directionalForce = 1.35,
}
