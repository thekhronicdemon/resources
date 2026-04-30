local QBCore = exports[Config.CoreName]:GetCoreObject()
local isFueling = false

local function DebugPrint(msg)
    if Config.Debug then print(('[prp-fuel] %s'):format(msg)) end
end

local function Notify(msg, msgType)
    QBCore.Functions.Notify(msg, msgType or 'primary')
end

local function ClampFuel(fuel)
    fuel = tonumber(fuel) or Config.DefaultFuel
    if fuel < 0.0 then return 0.0 end
    if fuel > Config.MaxFuel then return Config.MaxFuel end
    return fuel + 0.0
end

local function GetNetId(vehicle)
    if not DoesEntityExist(vehicle) then return 0 end
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
        Wait(50)
    end
    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function GetVehicleFuel(vehicle)
    if not DoesEntityExist(vehicle) then return 0.0 end

    local stateFuel = Entity(vehicle).state[Config.FuelStateName]
    if stateFuel ~= nil then return ClampFuel(stateFuel) end

    local nativeFuel = GetVehicleFuelLevel(vehicle)
    if nativeFuel == nil or nativeFuel <= 0.0 then nativeFuel = Config.DefaultFuel end
    return ClampFuel(nativeFuel)
end

local function SetVehicleFuel(vehicle, fuel, replicate)
    if not DoesEntityExist(vehicle) then return end

    fuel = ClampFuel(fuel)
    SetVehicleFuelLevel(vehicle, fuel)

    if replicate ~= false then
        local netId = GetNetId(vehicle)
        if netId and netId ~= 0 then
            TriggerServerEvent('prp-fuel:server:setFuelState', netId, fuel)
        end
    end
end

local function ExportSetFuel(vehicle, fuel)
    SetVehicleFuel(vehicle, fuel, true)
end

local function RegisterCompatExport(resourceName, funcName, func)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, funcName), function(setCB)
        setCB(func)
    end)
end

exports('GetFuel', GetVehicleFuel)
exports('SetFuel', ExportSetFuel)

for _, resourceName in ipairs({ 'prp_fuel', 'LegacyFuel', 'qb-fuel' }) do
    RegisterCompatExport(resourceName, 'GetFuel', GetVehicleFuel)
    RegisterCompatExport(resourceName, 'SetFuel', ExportSetFuel)
end

AddStateBagChangeHandler(Config.FuelStateName, nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetVehicleFuelLevel(entity, ClampFuel(value))
    end
end)

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

local function GetClosestVehicleToCoords(coords, radius)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = 0
    local closestDistance = radius or 5.0

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local distance = #(GetEntityCoords(vehicle) - coords)
            if distance < closestDistance then
                closestDistance = distance
                closestVehicle = vehicle
            end
        end
    end

    return closestVehicle, closestDistance
end

local function CanFuelVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    if GetVehicleEngineHealth(vehicle) <= 0.0 then return false end
    return true
end

local function FaceEntity(entity)
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local eCoords = GetEntityCoords(entity)
    local heading = GetHeadingFromVector_2d(eCoords.x - pCoords.x, eCoords.y - pCoords.y)
    SetEntityHeading(ped, heading)
end

local function StartFuelAnim()
    local ped = PlayerPedId()
    local dict = 'timetable@gardener@filling_can'
    local anim = 'gar_ig_5_filling_can'

    if LoadAnimDict(dict) then
        TaskPlayAnim(ped, dict, anim, 2.0, 2.0, -1, 49, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GARDENER_PLANT', 0, true)
    end
end

local function DrawHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function ServerCanPay(amount)
    local result = nil
    QBCore.Functions.TriggerCallback('prp-fuel:server:canPay', function(canPay)
        result = canPay
    end, amount, Config.Refuel.PaymentType)

    local timeout = GetGameTimer() + 3000
    while result == nil and GetGameTimer() < timeout do Wait(10) end
    return result == true
end

local function StartRefuel(pumpEntity)
    if isFueling then return end

    local pumpCoords = GetEntityCoords(pumpEntity)
    local vehicle = GetClosestVehicleToCoords(pumpCoords, Config.Refuel.VehicleSearchRadius)

    if not CanFuelVehicle(vehicle) then
        Notify(Config.Text.NoVehicle, 'error')
        return
    end

    local currentFuel = GetVehicleFuel(vehicle)
    if currentFuel >= Config.MaxFuel - 0.5 then
        Notify(Config.Text.VehicleFull, 'error')
        return
    end

    isFueling = true
    FaceEntity(vehicle)
    StartFuelAnim()

    local totalCost = 0
    local cancelled = false

    CreateThread(function()
        while isFueling do
            Wait(0)
            DrawHelpText(('Refuelling: %.0f%% | Cost: $%s | Press ~INPUT_FRONTEND_CANCEL~ to stop'):format(GetVehicleFuel(vehicle), totalCost))
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                cancelled = true
                isFueling = false
            end
        end
    end)

    while isFueling do
        Wait(Config.Refuel.TickTime)

        if not DoesEntityExist(vehicle) then
            cancelled = true
            break
        end

        if #(GetEntityCoords(PlayerPedId()) - pumpCoords) > Config.Refuel.StopDistanceFromPump then
            Notify(Config.Text.TooFar, 'error')
            cancelled = true
            break
        end

        currentFuel = GetVehicleFuel(vehicle)
        if currentFuel >= Config.MaxFuel then break end

        local addAmount = math.min(Config.Refuel.FuelPerTick, Config.MaxFuel - currentFuel)
        local tickCost = math.ceil(addAmount * Config.Refuel.PricePerFuel)

        if not ServerCanPay(totalCost + tickCost) then
            Notify(Config.Text.NoMoney, 'error')
            break
        end

        SetVehicleFuel(vehicle, currentFuel + addAmount, true)
        totalCost = totalCost + tickCost
    end

    isFueling = false
    ClearPedTasks(PlayerPedId())

    if totalCost > 0 then
        TriggerServerEvent('prp-fuel:server:payFuel', totalCost, Config.Refuel.PaymentType)
        Notify(('%s Cost: $%s'):format(Config.Text.Refuelled, totalCost), 'success')
    elseif cancelled then
        Notify(Config.Text.Cancelled, 'error')
    end
end

CreateThread(function()
    exports[Config.Target]:AddTargetModel(Config.PumpModels, {
        options = {
            {
                icon = 'fas fa-gas-pump',
                label = Config.Text.TargetLabel,
                action = function(entity)
                    StartRefuel(entity)
                end,
                canInteract = function(_, distance)
                    return not isFueling and distance <= 2.5 and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
            }
        },
        distance = 2.5
    })

    DebugPrint('qb-target pump models registered')
end)

CreateThread(function()
    if not Config.Consumption.Enabled then return end

    while true do
        Wait(Config.Consumption.TickTime)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local class = GetVehicleClass(vehicle)
            local classMult = Config.Consumption.ClassMultiplier[class] or 1.0

            if classMult > 0.0 and GetIsVehicleEngineRunning(vehicle) then
                local fuel = GetVehicleFuel(vehicle)
                local rpm = GetVehicleCurrentRpm(vehicle)
                local speed = GetEntitySpeed(vehicle)
                local drain = ((rpm + 0.2) * (speed + 1.0) * classMult * Config.Consumption.TickTime) / Config.Consumption.Divider
                local newFuel = ClampFuel(fuel - drain)

                if newFuel <= 0.1 then
                    newFuel = 0.0
                    SetVehicleEngineOn(vehicle, false, true, true)
                    SetVehicleUndriveable(vehicle, true)
                else
                    SetVehicleUndriveable(vehicle, false)
                end

                SetVehicleFuel(vehicle, newFuel, true)
            end
        end
    end
end)

RegisterCommand('setfuel', function(_, args)
    if not Config.Debug then return end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then vehicle = GetVehiclePedIsIn(PlayerPedId(), true) end
    if vehicle == 0 then return end

    SetVehicleFuel(vehicle, tonumber(args[1]) or 50.0, true)
end, false)
