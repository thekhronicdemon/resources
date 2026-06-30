local vehicleStates = {}
local activeSounds = {}
local lastVehicle = 0

local function notify()
    -- ELS controls should stay quiet on screen.
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

local function getDrivenVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return 0 end

    if Config.DriverOnly and GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return 0
    end

    return vehicle
end

local function normalizeTone(index)
    local tones = Config.SirenTones or {}
    local count = #tones
    if count < 1 then return 1 end

    index = math.floor(tonumber(index) or 1)
    if index < 1 or index > count then
        return 1
    end

    return index
end

local function normalizeState(state)
    state = type(state) == 'table' and state or {}

    return {
        lights = state.lights == true,
        siren = state.siren == true,
        sirenTone = normalizeTone(state.sirenTone),
        right = state.right == true,
        left = state.left == true,
        hazards = state.hazards == true,
        airhorn = state.airhorn == true,
        manual = state.manual == true,
        aux = state.aux == true
    }
end

local function getTone(index)
    local tones = Config.SirenTones or {}
    return tones[normalizeTone(index)] or tones[1]
end

local function getToneSound(index)
    local tone = getTone(index)
    return tone and tone.name or 'VEHICLES_HORNS_SIREN_1'
end

local function getToneLabel(index)
    local tone = getTone(index)
    return tone and tone.label or 'Siren'
end

local function getVehicleState(vehicle)
    local netId = VehToNet(vehicle)
    vehicleStates[netId] = normalizeState(vehicleStates[netId])
    return vehicleStates[netId], netId
end

local function getVehicleFromNetId(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return 0 end

    if NetworkDoesEntityExistWithNetworkId then
        if not NetworkDoesEntityExistWithNetworkId(netId) then return 0 end
    elseif NetworkDoesNetworkIdExist and not NetworkDoesNetworkIdExist(netId) then
        return 0
    end

    local vehicle = NetToVeh(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end

    return vehicle
end

local function getSoundKey(netId, key)
    return ('%s:%s'):format(netId, key)
end

local function stopLoopSound(netId, key)
    local cacheKey = getSoundKey(netId, key)
    local sound = activeSounds[cacheKey]
    if not sound then return end

    StopSound(sound.soundId)
    ReleaseSoundId(sound.soundId)
    activeSounds[cacheKey] = nil
end

local function startLoopSound(netId, vehicle, key, soundName)
    if not soundName or soundName == '' then return end

    local cacheKey = getSoundKey(netId, key)
    local existing = activeSounds[cacheKey]
    if existing and existing.soundName == soundName then
        return
    end

    if existing then
        stopLoopSound(netId, key)
    end

    local soundId = GetSoundId()
    PlaySoundFromEntity(soundId, soundName, vehicle, Config.SoundSet or 0, false, 0)
    activeSounds[cacheKey] = {
        soundId = soundId,
        netId = netId,
        key = key,
        soundName = soundName
    }
end

local function syncSound(vehicle, netId, key, enabled, soundName)
    if enabled then
        startLoopSound(netId, vehicle, key, soundName)
    else
        stopLoopSound(netId, key)
    end
end

local function stopVehicleSounds(netId)
    stopLoopSound(netId, 'siren')
    stopLoopSound(netId, 'manual')
    stopLoopSound(netId, 'aux')
    stopLoopSound(netId, 'airhorn')
end

local function applyState(vehicle, state)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local netId = VehToNet(vehicle)
    state = normalizeState(state)

    if not state.lights then
        state.siren = false
        state.manual = false
        state.aux = false
    end

    vehicleStates[netId] = state

    SetVehicleIndicatorLights(vehicle, 0, state.right or state.hazards)
    SetVehicleIndicatorLights(vehicle, 1, state.left or state.hazards)

    if state.lights then
        SetVehicleSiren(vehicle, true)
        SetVehicleHasMutedSirens(vehicle, true)
    else
        SetVehicleHasMutedSirens(vehicle, false)
        SetVehicleSiren(vehicle, false)
    end

    syncSound(vehicle, netId, 'siren', state.lights and state.siren, getToneSound(state.sirenTone))
    syncSound(vehicle, netId, 'manual', state.lights and state.manual, getToneSound(state.sirenTone))
    syncSound(vehicle, netId, 'aux', state.lights and state.aux, Config.AuxSirenSound)
    syncSound(vehicle, netId, 'airhorn', state.airhorn, Config.AirhornSound)
end

local function syncState(vehicle)
    local state, netId = getVehicleState(vehicle)
    TriggerServerEvent('prp-els:server:setState', netId, state)
end

local function getControlledVehicle()
    local vehicle = getDrivenVehicle()
    if vehicle == 0 or not isModelAllowed(vehicle) then
        return 0
    end

    return vehicle
end

local function withVehicle(callback, elsOnly)
    local vehicle = elsOnly and getControlledVehicle() or getDrivenVehicle()
    if vehicle == 0 then
        notify(Config.Messages.notAllowed, 'error')
        return
    end

    local state = getVehicleState(vehicle)
    local changed = callback(vehicle, state)
    if changed == false then return end

    applyState(vehicle, state)
    syncState(vehicle)
end

local function withControlledVehicle(callback)
    withVehicle(callback, true)
end

local function toggleIndicator(side)
    withVehicle(function(_, state)
        local enabled = not state[side]
        state.right = false
        state.left = false
        state.hazards = false
        state[side] = enabled
    end, false)
end

local function toggleHazards()
    withVehicle(function(_, state)
        state.hazards = not state.hazards
        if state.hazards then
            state.right = false
            state.left = false
        end
    end, false)
end

local function toggleLights()
    withControlledVehicle(function(_, state)
        state.lights = not state.lights
        if not state.lights then
            state.siren = false
            state.manual = false
            state.aux = false
        end

        notify(state.lights and Config.Messages.lightsOn or Config.Messages.lightsOff, state.lights and 'success' or 'error')
    end)
end

local function toggleSiren()
    withControlledVehicle(function(_, state)
        if not state.lights then
            notify(Config.Messages.needLights, 'error')
            return false
        end

        state.siren = not state.siren
        if state.siren then
            state.manual = false
            state.aux = false
        end

        notify(state.siren and Config.Messages.sirenOn or Config.Messages.sirenOff, state.siren and 'success' or 'error')
    end)
end

local function cycleSirenTone(state)
    local tones = Config.SirenTones or {}
    if #tones < 1 then return end

    state.sirenTone = normalizeTone(state.sirenTone) + 1
    if state.sirenTone > #tones then state.sirenTone = 1 end

    notify(('%s %s'):format(Config.Messages.toneChanged, getToneLabel(state.sirenTone)), 'primary')
end

local function setAirhorn(enabled)
    withControlledVehicle(function(_, state)
        if state.airhorn == enabled then
            return false
        end

        state.airhorn = enabled
    end)
end

local function setManualSiren(enabled)
    withControlledVehicle(function(_, state)
        if not state.lights then
            if enabled then
                notify(Config.Messages.needLights, 'error')
            end
            return false
        end

        if enabled and state.siren then
            cycleSirenTone(state)
            return
        end

        if state.manual == enabled then
            return false
        end

        state.manual = enabled
    end)
end

local function setAuxSiren(enabled)
    withControlledVehicle(function(_, state)
        if not state.lights then
            if enabled then
                notify(Config.Messages.needLights, 'error')
            end
            return false
        end

        if state.aux == enabled then
            return false
        end

        state.aux = enabled
    end)
end

RegisterCommand(Config.RightIndicatorCommand, function() toggleIndicator('right') end, false)
RegisterCommand(Config.LeftIndicatorCommand, function() toggleIndicator('left') end, false)
RegisterCommand(Config.HazardsCommand, function() toggleHazards() end, false)
RegisterCommand(Config.LightsToggleCommand, function() toggleLights() end, false)
RegisterCommand(Config.SirenToggleCommand, function() toggleSiren() end, false)

RegisterCommand('+' .. Config.AirhornCommand, function() setAirhorn(true) end, false)
RegisterCommand('-' .. Config.AirhornCommand, function() setAirhorn(false) end, false)
RegisterCommand('+' .. Config.ManualSirenCommand, function() setManualSiren(true) end, false)
RegisterCommand('-' .. Config.ManualSirenCommand, function() setManualSiren(false) end, false)
RegisterCommand('+' .. Config.AuxSirenCommand, function() setAuxSiren(true) end, false)
RegisterCommand('-' .. Config.AuxSirenCommand, function() setAuxSiren(false) end, false)

RegisterCommand('prpels_lights_np', function() toggleLights() end, false)
RegisterCommand('prpels_siren_np', function() toggleSiren() end, false)
RegisterCommand('prpels_siren_add', function() toggleSiren() end, false)

RegisterKeyMapping(Config.RightIndicatorCommand, 'prp-ELS: Right indicator (])', 'keyboard', Config.DefaultRightIndicatorKey)
RegisterKeyMapping(Config.LeftIndicatorCommand, 'prp-ELS: Left indicator ([)', 'keyboard', Config.DefaultLeftIndicatorKey)
RegisterKeyMapping(Config.HazardsCommand, 'prp-ELS: Hazard lights (Backspace)', 'keyboard', Config.DefaultHazardsKey)
RegisterKeyMapping(Config.LightsToggleCommand, 'prp-ELS: Toggle emergency lights (Y)', 'keyboard', Config.DefaultLightsToggleKey)
RegisterKeyMapping(Config.SirenToggleCommand, 'prp-ELS: Toggle siren (,)', 'keyboard', Config.DefaultSirenToggleKey)
RegisterKeyMapping('+' .. Config.AirhornCommand, 'prp-ELS: Airhorn (E)', 'keyboard', Config.DefaultAirhornKey)
RegisterKeyMapping('+' .. Config.ManualSirenCommand, 'prp-ELS: Manual siren/change tone (N)', 'keyboard', Config.DefaultManualSirenKey)
RegisterKeyMapping('+' .. Config.AuxSirenCommand, 'prp-ELS: Auxiliary siren (Down Arrow)', 'keyboard', Config.DefaultAuxSirenKey)

RegisterNetEvent('prp-els:client:applyState', function(netId, state)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return end

    vehicleStates[netId] = normalizeState(state)

    local vehicle = getVehicleFromNetId(netId)
    if vehicle == 0 then
        stopVehicleSounds(netId)
        return
    end

    applyState(vehicle, vehicleStates[netId])
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, sound in pairs(activeSounds) do
        StopSound(sound.soundId)
        ReleaseSoundId(sound.soundId)
    end
end)

CreateThread(function()
    while true do
        local vehicle = getDrivenVehicle()
        if vehicle ~= 0 then
            for _, control in pairs(Config.DisableIndicatorControls or {}) do
                DisableControlAction(0, control, true)
            end

            if isModelAllowed(vehicle) then
                for _, control in pairs(Config.DisableControls or {}) do
                    DisableControlAction(0, control, true)
                end
            end

            Wait(0)
        else
            Wait(250)
        end
    end
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
            if state and (state.siren or state.manual or state.aux or state.airhorn) then
                state.siren = false
                state.manual = false
                state.aux = false
                state.airhorn = false
                applyState(lastVehicle, state)
                TriggerServerEvent('prp-els:server:setState', netId, state)
            end
        end

        lastVehicle = currentVehicle
        Wait(100)
    end
end)

CreateThread(function()
    while true do
        local staleSounds = {}

        for cacheKey, sound in pairs(activeSounds) do
            local vehicle = getVehicleFromNetId(sound.netId)
            if vehicle == 0 then
                staleSounds[#staleSounds + 1] = cacheKey
            end
        end

        for _, cacheKey in ipairs(staleSounds) do
            local sound = activeSounds[cacheKey]
            if sound then
                StopSound(sound.soundId)
                ReleaseSoundId(sound.soundId)
                activeSounds[cacheKey] = nil
            end
        end

        Wait(5000)
    end
end)

CreateThread(function()
    while true do
        for netId, state in pairs(vehicleStates) do
            local vehicle = getVehicleFromNetId(netId)
            if vehicle ~= 0 then
                applyState(vehicle, state)
            else
                stopVehicleSounds(netId)
            end
        end

        Wait(1000)
    end
end)
