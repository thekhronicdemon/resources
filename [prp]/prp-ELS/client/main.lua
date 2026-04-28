local vehicleStates = {}
local lastVehicle = 0

local function notify(msg)
    if Config.Notify == 'chat' and msg and msg ~= '' then
        TriggerEvent('chat:addMessage', {
            color = {255, 255, 255},
            multiline = false,
            args = {msg}
        })
    end
end

local function isModelAllowed(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    if Config.DriverOnly and GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        return false
    end

    local model = GetEntityModel(vehicle)
    for name, enabled in pairs(Config.AllowedModels) do
        if enabled and model == joaat(name) then
            return true
        end
    end
    return false
end

local function getVehicleState(vehicle)
    local netId = VehToNet(vehicle)
    if not vehicleStates[netId] then
        vehicleStates[netId] = {
            lights = false,
            siren = false
        }
    end
    return vehicleStates[netId], netId
end

local function applyState(vehicle, state)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if state.lights then
        SetVehicleSiren(vehicle, true)
        SetVehicleHasMutedSirens(vehicle, not state.siren)
    else
        SetVehicleHasMutedSirens(vehicle, false)
        SetVehicleSiren(vehicle, false)
    end
end

local function syncState(vehicle)
    local state, netId = getVehicleState(vehicle)
    TriggerServerEvent('prp-els:server:setState', netId, state)
end

local function getControlledVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return 0 end
    if not isModelAllowed(vehicle) then return 0 end
    return vehicle
end

local function toggleLights()
    local vehicle = getControlledVehicle()
    if vehicle == 0 then
        notify(Config.Messages.notAllowed)
        return
    end

    local state = getVehicleState(vehicle)
    state.lights = not state.lights
    if not state.lights then
        state.siren = false
    end

    applyState(vehicle, state)
    syncState(vehicle)
    notify(state.lights and Config.Messages.lightsOn or Config.Messages.lightsOff)
end

local function toggleSiren()
    local vehicle = getControlledVehicle()
    if vehicle == 0 then
        notify(Config.Messages.notAllowed)
        return
    end

    local state = getVehicleState(vehicle)
    if not state.lights then
        notify(Config.Messages.needLights)
        return
    end

    state.siren = not state.siren
    applyState(vehicle, state)
    syncState(vehicle)
    notify(state.siren and Config.Messages.sirenOn or Config.Messages.sirenOff)
end

RegisterCommand(Config.LightsToggleCommand, function() toggleLights() end, false)
RegisterCommand(Config.LightsToggleAliasCommand, function() toggleLights() end, false)
RegisterCommand(Config.SirenToggleCommand, function() toggleSiren() end, false)
RegisterCommand(Config.SirenToggleAliasCommand1, function() toggleSiren() end, false)
RegisterCommand(Config.SirenToggleAliasCommand2, function() toggleSiren() end, false)

RegisterKeyMapping(Config.LightsToggleCommand, 'prp-ELS: Toggle lights (-)', 'keyboard', Config.DefaultLightsToggleKey)
RegisterKeyMapping(Config.LightsToggleAliasCommand, 'prp-ELS: Toggle lights (numpad -)', 'keyboard', Config.DefaultLightsToggleAliasKey)
RegisterKeyMapping(Config.SirenToggleCommand, 'prp-ELS: Toggle siren (+)', 'keyboard', Config.DefaultSirenToggleKey1)
RegisterKeyMapping(Config.SirenToggleAliasCommand2, 'prp-ELS: Toggle siren (numpad +)', 'keyboard', Config.DefaultSirenToggleKey2)

RegisterNetEvent('prp-els:client:applyState', function(netId, state)
    local vehicle = NetToVeh(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    vehicleStates[netId] = state
    applyState(vehicle, state)
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local currentVehicle = 0

        if IsPedInAnyVehicle(ped, false) then
            currentVehicle = GetVehiclePedIsIn(ped, false)
        end

        if lastVehicle ~= 0 and currentVehicle == 0 and DoesEntityExist(lastVehicle) then
            local netId = VehToNet(lastVehicle)
            local state = vehicleStates[netId]
            if state and state.lights and state.siren then
                state.siren = false
                applyState(lastVehicle, state)
                TriggerServerEvent('prp-els:server:setState', netId, state)
            end
        end

        lastVehicle = currentVehicle
        Wait(100)
    end
end)
