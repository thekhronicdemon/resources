Config = {}

Config.Debug = false
Config.CoreName = 'qb-core'
Config.Target = 'qb-target'
Config.FuelStateName = 'prp_fuel'
Config.DefaultFuel = 65.0
Config.MaxFuel = 100.0

Config.Refuel = {
    VehicleSearchRadius = 5.0,
    StopDistanceFromPump = 8.0,
    FuelPerTick = 1.0,
    TickTime = 650,
    PricePerFuel = 2,
    PaymentType = 'cash',
}

Config.Consumption = {
    Enabled = true,
    TickTime = 5000,
    Divider = 90000.0,
    ClassMultiplier = {
        [0] = 0.85, [1] = 0.90, [2] = 1.10, [3] = 0.95, [4] = 1.05,
        [5] = 1.00, [6] = 1.10, [7] = 1.25, [8] = 0.65, [9] = 1.25,
        [10] = 1.40, [11] = 1.35, [12] = 1.25, [13] = 0.0, [14] = 1.20,
        [15] = 1.60, [16] = 1.75, [17] = 1.10, [18] = 1.15, [19] = 1.40,
        [20] = 1.45, [21] = 0.0,
    }
}

Config.Text = {
    TargetLabel = 'Refuel Vehicle',
    NoVehicle = 'No vehicle close enough to this pump.',
    VehicleFull = 'This vehicle is already full.',
    TooFar = 'You moved too far away from the pump.',
    NoMoney = 'You do not have enough money.',
    Refuelled = 'Vehicle refuelled.',
    Cancelled = 'Refuelling cancelled.',
}

Config.PumpModels = {
    -2007231801, 1339433404, 1694452750, 1933174915,
    -462817101, -469694731, -164877493,
}

Config.GasStations = {
    vector3(49.4187, 2778.793, 58.043), vector3(263.894, 2606.463, 44.983),
    vector3(1039.958, 2671.134, 39.550), vector3(1207.260, 2660.175, 37.899),
    vector3(2539.685, 2594.192, 37.944), vector3(2679.858, 3263.946, 55.240),
    vector3(2005.055, 3773.887, 32.403), vector3(1687.156, 4929.392, 42.078),
    vector3(1701.314, 6416.028, 32.763), vector3(179.857, 6602.839, 31.868),
    vector3(-94.4619, 6419.594, 31.489), vector3(-2554.996, 2334.40, 33.078),
    vector3(-1800.375, 803.661, 138.651), vector3(-1437.622, -276.747, 46.207),
    vector3(-2096.243, -320.286, 13.168), vector3(-724.619, -935.1631, 19.213),
    vector3(-526.019, -1211.003, 18.184), vector3(-70.2148, -1761.792, 29.534),
    vector3(265.648, -1261.309, 29.292), vector3(819.653, -1028.846, 26.403),
    vector3(1208.951, -1402.567, 35.224), vector3(1181.381, -330.847, 69.316),
    vector3(620.843, 269.100, 103.089), vector3(2581.321, 362.039, 108.468),
    vector3(176.631, -1562.025, 29.263), vector3(-319.292, -1471.715, 30.549),
    vector3(1784.324, 3330.55, 41.253),
}
