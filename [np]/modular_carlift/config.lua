Config = {}

Config.CoreName = 'qb-core'
Config.TargetName = 'qb-target'
Config.UseQBCoreJobCheck = true
Config.AllowedJobs = {
    mechanic = true,
    bennys = true,
}

Config.Debug = false
Config.LiftModel = `nacelle`
Config.ControlModel = `prop_toolchest_05`

Config.TargetDistance = 3.0

-- This version DOES NOT attach/freeze/move the vehicle.
-- It only moves the nacelle/lift prop. The vehicle is lifted by GTA collision.
-- If the car is parked badly, it can slip/fall like a real lift.
Config.MoveSpeed = 0.010
Config.MoveSpeedSlow = 0.006
Config.MoveDelay = 0
Config.MaxHeight = 1.95
Config.SlowDownNearTop = 0.25
Config.SlowDownNearBottom = 0.18

-- Original modular_carlift Benny's lift coords.
-- z = lower/floor position of the nacelle prop.
Config.Lifts = {
    {
        id = 'bennys_1',
        label = "Benny's Lift 1",
        coords = vector4(-223.5853, -1327.1580, 29.80, 0.0),
        control = vector4(-219.3204, -1326.4300, 29.89, 90.0),
        maxHeight = 1.95,
    },
    {
        id = 'bennys_2',
        label = "Benny's Lift 2",
        coords = vector4(-213.4600, -1313.1800, 29.80, 270.0),
        control = vector4(-212.7980, -1317.5430, 30.89, 180.0),
        maxHeight = 1.95,
    },
}

Config.Notify = function(msg, msgType)
    if GetResourceState(Config.CoreName) == 'started' then
        local QBCore = exports[Config.CoreName]:GetCoreObject()
        QBCore.Functions.Notify(msg, msgType or 'primary')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end
