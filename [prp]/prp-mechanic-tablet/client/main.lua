local QBCore = exports['qb-core']:GetCoreObject()
local vehicleCache = {}
local tabletVehicle = 0
local previewOriginal = nil
local previewStance = nil
local hydraulicsEnabled = false
local lastHydraulicUse = 0
local airbagsEnabled = Config.Airbags.enabledByDefault ~= false
local airbagStopSince = 0
local airbagAnimations = {}
local airbagAnimationSerials = {}
local airbagVisualStates = {}
local hydraulicLock = {
    vehicle = 0,
    waitingForAir = false,
    startedAt = 0,
    groundedAt = 0,
}
local factoryWheelData = {}

local function trimPlate(plate)
    return string.upper((plate or ''):gsub('^%s*(.-)%s*$', '%1'))
end

local function clamp(value, min, max)
    value = tonumber(value) or 0.0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function copyTable(source)
    local target = {}
    for k, v in pairs(source or {}) do target[k] = v end
    return target
end

local function isMechanic()
    local job = QBCore.Functions.GetPlayerData().job
    local minGrade = job and Config.MechanicJobs[job.name]
    local grade = job and job.grade
    local level = type(grade) == 'table' and (grade.level or grade.grade or 0) or tonumber(grade) or 0
    return minGrade ~= nil and level >= minGrade
end

local function getClosestVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end
    local coords = GetEntityCoords(ped)
    vehicle = QBCore.Functions.GetClosestVehicle(coords)
    if vehicle == 0 or #(coords - GetEntityCoords(vehicle)) > Config.MaxVehicleDistance then return 0 end
    return vehicle
end

local function requestControl(entity)
    if not DoesEntityExist(entity) then return false end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 750
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function normaliseStance(data)
    data = data or {}
    local output = {}
    for key, default in pairs(Config.Defaults) do
        local limits = Config.Limits[key]
        output[key] = limits and clamp(data[key] or default, limits.min, limits.max) or (tonumber(data[key]) or default)
    end
    return output
end

local function wheelIsFront(index, count)
    if count <= 2 then return index == 0 end
    return index == 0 or index == 1
end

local function vehicleIsBike(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local class = GetVehicleClass(vehicle)
    return class == 8 or class == 13
end

local function setVehicleSuspension(vehicle, height)
    SetVehicleSuspensionHeight(vehicle, height)
end

local function resetUnsupportedBike(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not vehicleIsBike(vehicle) then return end
    SetVehicleSuspensionHeight(vehicle, 0.0)
    pcall(function()
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionRaise', 0.0)
    end)
end

local function getFactoryWheelData(vehicle)
    local model = GetEntityModel(vehicle)
    if factoryWheelData[model] then return factoryWheelData[model] end

    -- Read the unmodified values from a hidden local clone. This also repairs vehicles
    -- that were already distorted by older versions before this resource restarted.
    local sample = CreateVehicle(model, 0.0, 0.0, -100.0, 0.0, false, false)
    local sourceVehicle = sample ~= 0 and sample or vehicle
    if sample ~= 0 then
        SetEntityVisible(sample, false, false)
        SetEntityCollision(sample, false, false)
        FreezeEntityPosition(sample, true)
    end

    local wheelCount = GetVehicleNumberOfWheels(sourceVehicle)
    local data = {
        wheelCount = wheelCount,
        xOffsets = {},
        width = nil,
    }

    for wheel = 0, wheelCount - 1 do
        data.xOffsets[wheel] = GetVehicleWheelXOffset(sourceVehicle, wheel)
    end

    local ok, width = pcall(function()
        return GetVehicleWheelWidth(sourceVehicle)
    end)
    if ok and type(width) == 'number' and width > 0.01 then
        data.width = width
    end

    if sample ~= 0 then DeleteEntity(sample) end
    factoryWheelData[model] = data
    return data
end

local function getEffectiveSuspension(data, vehicleData)
    local height = data.suspension
    local minHeight = Config.Limits.suspension.min
    local maxHeight = Config.Limits.suspension.max
    if vehicleData and vehicleData.airbags and vehicleData.airbags_down then
        local offset = tonumber(Config.Airbags.loweredOffset) or 0.0
        height = height + offset
        if offset < 0.0 then
            minHeight = minHeight + offset
        elseif offset > 0.0 then
            maxHeight = maxHeight + offset
        end
    end
    return clamp(height, minHeight, maxHeight)
end

local function applyStance(vehicle, rawData, vehicleData, suspensionHeight)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        return
    end

    local data = normaliseStance(rawData)
    if not requestControl(vehicle) then return end

    setVehicleSuspension(vehicle, suspensionHeight or getEffectiveSuspension(data, vehicleData))

    local factory = getFactoryWheelData(vehicle)
    for wheel = 0, factory.wheelCount - 1 do
        local front = wheelIsFront(wheel, factory.wheelCount)
        local leftSide = (wheel % 2 == 0)
        local sideSign = leftSide and -1.0 or 1.0
        local trackAdjustment = front and data.frontTrack or data.rearTrack
        local camber = front and data.frontCamber or data.rearCamber
        local factoryX = factory.xOffsets[wheel] or 0.0

        -- X offset is an absolute wheel coordinate, so preserve the vehicle's factory value.
        SetVehicleWheelXOffset(vehicle, wheel, factoryX + (trackAdjustment * sideSign))
        SetVehicleWheelYRotation(vehicle, wheel, camber * sideSign)
    end

    -- Wheel width is also absolute. The saved value is only an adjustment from factory width.
    if factory.width then
        pcall(function()
            SetVehicleWheelWidth(vehicle, math.max(0.05, factory.width + data.wheelWidth))
        end)
    end
end


local function maintainWheelStance(vehicle, rawData)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if vehicleIsBike(vehicle) then return end

    local data = normaliseStance(rawData)
    local factory = getFactoryWheelData(vehicle)

    -- GTA resets wheel Y rotation as wheel physics update, so these visual values
    -- must be maintained while the vehicle is streamed on this client.
    for wheel = 0, factory.wheelCount - 1 do
        local front = wheelIsFront(wheel, factory.wheelCount)
        local leftSide = (wheel % 2 == 0)
        local sideSign = leftSide and -1.0 or 1.0
        local trackAdjustment = front and data.frontTrack or data.rearTrack
        local camber = front and data.frontCamber or data.rearCamber
        local factoryX = factory.xOffsets[wheel] or 0.0

        SetVehicleWheelXOffset(vehicle, wheel, factoryX + (trackAdjustment * sideSign))
        SetVehicleWheelYRotation(vehicle, wheel, camber * sideSign)
    end

    if factory.width then
        pcall(function()
            SetVehicleWheelWidth(vehicle, math.max(0.05, factory.width + data.wheelWidth))
        end)
    end
end

local function resetStance(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        return
    end
    if not requestControl(vehicle) then return end
    setVehicleSuspension(vehicle, 0.0)

    local factory = getFactoryWheelData(vehicle)
    for wheel = 0, factory.wheelCount - 1 do
        SetVehicleWheelXOffset(vehicle, wheel, factory.xOffsets[wheel] or 0.0)
        SetVehicleWheelYRotation(vehicle, wheel, 0.0)
    end
    if factory.width then
        pcall(function() SetVehicleWheelWidth(vehicle, factory.width) end)
    end
end

local function getVehicleAnimationKey(vehicle)
    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    if plate ~= '' then return plate end
    return tostring(vehicle)
end

local function getCurrentSuspensionHeight(vehicle)
    local ok, height = pcall(function()
        return GetVehicleSuspensionHeight(vehicle)
    end)
    if ok and type(height) == 'number' then return height end
    return nil
end

local function easeInOut(progress)
    return progress * progress * (3.0 - (2.0 * progress))
end

local function playAirbagSound()
    SendNUIMessage({
        action = 'playAirbagSound',
        volume = Config.Airbags.soundVolume or 0.65
    })
end

local function animateAirbagSuspension(vehicle, startHeight, targetHeight, lowering)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local key = getVehicleAnimationKey(vehicle)
    local token = (airbagAnimationSerials[key] or 0) + 1
    airbagAnimationSerials[key] = token
    local duration = lowering and Config.Airbags.lowerDurationMs or Config.Airbags.raiseDurationMs
    duration = math.max(0, tonumber(duration) or 0)
    airbagAnimations[key] = token

    local liveHeight = getCurrentSuspensionHeight(vehicle)
    if liveHeight then startHeight = liveHeight end
    if lowering then playAirbagSound() end

    CreateThread(function()
        if not requestControl(vehicle) then
            if airbagAnimations[key] == token then airbagAnimations[key] = nil end
            return
        end
        local startedAt = GetGameTimer()

        while airbagAnimations[key] == token and DoesEntityExist(vehicle) do
            local progress = duration <= 0 and 1.0 or clamp((GetGameTimer() - startedAt) / duration, 0.0, 1.0)
            local eased = easeInOut(progress)
            setVehicleSuspension(vehicle, startHeight + ((targetHeight - startHeight) * eased))

            if progress >= 1.0 then break end
            Wait(0)
        end

        if airbagAnimations[key] == token and DoesEntityExist(vehicle) then
            setVehicleSuspension(vehicle, targetHeight)
            airbagAnimations[key] = nil
        end
    end)
end

local function getActiveStance(vehicle, data)
    if tabletVehicle ~= 0 and tabletVehicle == vehicle and previewStance then
        return previewStance
    end
    if data and data.stancer then return data.stance_data end
    return Config.Defaults
end

local function applyVehicleUpgrades(vehicle, data, animateAirbags, previousAirbagsDown)
    if not data or not (data.stancer or data.airbags) then
        resetStance(vehicle)
        return
    end

    local stance = getActiveStance(vehicle, data)
    local shouldAnimate = animateAirbags
        and data.airbags
        and previousAirbagsDown ~= nil
        and previousAirbagsDown ~= data.airbags_down

    if shouldAnimate then
        local stanceData = normaliseStance(stance)
        local startData = copyTable(data)
        startData.airbags_down = previousAirbagsDown

        local startHeight = getEffectiveSuspension(stanceData, startData)
        local targetHeight = getEffectiveSuspension(stanceData, data)
        startHeight = getCurrentSuspensionHeight(vehicle) or startHeight
        applyStance(vehicle, stance, data, startHeight)
        animateAirbagSuspension(vehicle, startHeight, targetHeight, data.airbags_down == true)
        return
    end

    applyStance(vehicle, stance, data)
end

local function setLocalAirbagState(vehicle, data, down, syncServer)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not data or not data.airbags then return end
    down = down == true
    if data.airbags_down == down then return end

    local previousDown = data.airbags_down == true
    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    data.airbags_down = down
    airbagVisualStates[plate] = down
    applyVehicleUpgrades(vehicle, data, true, previousDown)

    if tabletVehicle ~= 0 and tabletVehicle == vehicle then
        SendNUIMessage({ action = 'airbagsState', down = down })
    end
    if syncServer then
        TriggerServerEvent('prp-mechanic-tablet:server:setAirbagsState', plate, down)
    end
end

local function currentAirbagVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return 0, nil end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        return 0, nil
    end

    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    local data = vehicleCache[plate]
    if not data or not data.airbags then return 0, nil end
    return vehicle, data
end

local function updateAutomaticAirbags(vehicle, data)
    if not Config.Airbags.autoLower then return end
    if vehicle == 0 or not DoesEntityExist(vehicle) or not data or not data.airbags then
        airbagStopSince = 0
        return
    end
    if vehicleIsBike(vehicle) then
        airbagStopSince = 0
        resetUnsupportedBike(vehicle)
        return
    end
    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        airbagStopSince = 0
        return
    end

    if not airbagsEnabled then
        airbagStopSince = 0
        setLocalAirbagState(vehicle, data, false, true)
        return
    end

    local now = GetGameTimer()
    local speed = GetEntitySpeed(vehicle)

    if speed >= Config.Airbags.raiseSpeed then
        airbagStopSince = 0
        setLocalAirbagState(vehicle, data, false, true)
        return
    end

    if speed <= Config.Airbags.lowerSpeed and IsVehicleOnAllWheels(vehicle) then
        if airbagStopSince == 0 then airbagStopSince = now end
        if now - airbagStopSince >= Config.Airbags.stopDelayMs then
            setLocalAirbagState(vehicle, data, true, true)
        end
    else
        airbagStopSince = 0
    end
end

local function cacheVehicle(vehicle, data)
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        return
    end
    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    vehicleCache[plate] = data
    airbagVisualStates[plate] = data and data.airbags_down == true
    airbagAnimations[plate] = nil
    applyVehicleUpgrades(vehicle, data)
end

local function loadVehicleData(vehicle, cb)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        return
    end
    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    QBCore.Functions.TriggerCallback('prp-mechanic-tablet:server:getVehicleData', function(data)
        if not data then
            QBCore.Functions.Notify('Vehicle upgrade data could not be loaded.', 'error')
            return
        end
        cacheVehicle(vehicle, data)
        if cb then cb(data) end
    end, plate)
end

local function runInstall(itemName, upgrade)
    if Config.RequireMechanicForInstall and not isMechanic() then
        QBCore.Functions.Notify('You must be a mechanic to install this upgrade.', 'error')
        return
    end
    local vehicle = getClosestVehicle()
    if vehicle == 0 then QBCore.Functions.Notify('No vehicle nearby.', 'error') return end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        QBCore.Functions.Notify('Bikes are not supported by the mechanic tablet.', 'error')
        return
    end
    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    QBCore.Functions.TriggerCallback('prp-mechanic-tablet:server:getVehicleData', function(data)
        local installed = data and data[upgrade]
        if installed then
            QBCore.Functions.Notify('This upgrade is already installed on this vehicle.', 'error')
            return
        end
        local label = 'Installing upgrade...'
        local duration = Config.InstallTime
        local function complete()
            ClearPedTasks(PlayerPedId())
            QBCore.Functions.TriggerCallback('prp-mechanic-tablet:server:installUpgrade', function(result)
                if not result or not result.ok then
                    QBCore.Functions.Notify((result and result.message) or 'Installation failed.', 'error')
                    return
                end

                if result.data then
                    cacheVehicle(vehicle, result.data)
                    if tabletVehicle ~= 0 and trimPlate(GetVehicleNumberPlateText(tabletVehicle)) == plate then
                        SendNUIMessage({
                            action = 'refreshData',
                            data = result.data,
                            airbagsDown = result.data.airbags_down == true
                        })
                    end
                else
                    loadVehicleData(vehicle)
                end
                QBCore.Functions.Notify(result.message or 'Upgrade installed successfully.', 'success')
            end, plate, upgrade, itemName)
        end
        local function cancel()
            ClearPedTasks(PlayerPedId())
            QBCore.Functions.Notify('Installation cancelled.', 'error')
        end

        if GetResourceState('progressbar') == 'started' then
            exports['progressbar']:Progress({
                name = 'prp_install_' .. upgrade,
                duration = duration,
                label = label,
                useWhileDead = false,
                canCancel = true,
                controlDisables = {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                },
                animation = {
                    animDict = 'mini@repair',
                    anim = 'fixing_a_ped',
                    flags = 49,
                },
            }, function(cancelled)
                if cancelled then cancel() else complete() end
            end)
        elseif QBCore.Functions.Progressbar then
            QBCore.Functions.Progressbar('prp_install_' .. upgrade, label, duration, false, true,
                { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
                { animDict = 'mini@repair', anim = 'fixing_a_ped', flags = 49 }, {}, {}, complete, cancel)
        else
            QBCore.Functions.Notify('No QBCore progressbar resource is running.', 'error')
        end
    end, plate)
end

local function closeTablet(restorePreview)
    if restorePreview and tabletVehicle ~= 0 and previewOriginal then
        local plate = trimPlate(GetVehicleNumberPlateText(tabletVehicle))
        applyStance(tabletVehicle, previewOriginal, vehicleCache[plate])
    end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    tabletVehicle = 0
    previewOriginal = nil
    previewStance = nil
end

local function openTablet()
    if Config.RequireMechanicForTablet and not isMechanic() then
        QBCore.Functions.Notify('Only mechanics can use this tablet.', 'error')
        return
    end
    local vehicle = getClosestVehicle()
    if vehicle == 0 then QBCore.Functions.Notify('No vehicle nearby.', 'error') return end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        QBCore.Functions.Notify('Bikes are not supported by the mechanic tablet.', 'error')
        return
    end
    loadVehicleData(vehicle, function(data)
        tabletVehicle = vehicle
        previewOriginal = copyTable(data.stance_data or Config.Defaults)
        previewStance = nil
        local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            plate = plate,
            label = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
            data = data,
            limits = Config.Limits,
            defaults = Config.Defaults,
            airbagsDown = data.airbags_down == true
        })
    end)
end

RegisterCommand('mechanictablet', function()
    openTablet()
end, false)

RegisterCommand('installairbags', function()
    runInstall(Config.Items.Airbags, 'airbags')
end, false)

RegisterCommand('installstancer', function()
    runInstall(Config.Items.Stancer, 'stancer')
end, false)

RegisterCommand('installhydraulics', function()
    runInstall(Config.Items.Hydraulics, 'hydraulics')
end, false)

RegisterCommand('fixvehiclewheels', function()
    local vehicle = getClosestVehicle()
    if vehicle == 0 then QBCore.Functions.Notify('No vehicle nearby.', 'error') return end
    resetStance(vehicle)
    loadVehicleData(vehicle)
    QBCore.Functions.Notify('Factory wheel positions restored and saved setup reapplied.', 'success')
end, false)

RegisterCommand('checkvehicleupgrades', function()
    local vehicle = getClosestVehicle()
    if vehicle == 0 then QBCore.Functions.Notify('No vehicle nearby.', 'error') return end
    TriggerServerEvent('prp-mechanic-tablet:server:debugVehicle', trimPlate(GetVehicleNumberPlateText(vehicle)))
end, false)

RegisterCommand(Config.Airbags.toggleCommand, function()
    airbagsEnabled = not airbagsEnabled
    airbagStopSince = 0

    local vehicle, data = currentAirbagVehicle()
    if not airbagsEnabled and vehicle ~= 0 then
        setLocalAirbagState(vehicle, data, false, true)
    end

    QBCore.Functions.Notify(airbagsEnabled and 'Automatic airbags enabled.' or 'Automatic airbags disabled.', 'success')
end, false)

RegisterNetEvent('prp-mechanic-tablet:client:debugVehicleResult', function(data)
    if not data then
        QBCore.Functions.Notify('No database record was returned. Check the server console.', 'error')
        return
    end
    local message = ('Plate %s | Stancer: %s | Airbags: %s | Hydraulics: %s'):format(
        tostring(data.plate), tostring(data.stancer), tostring(data.airbags), tostring(data.hydraulics)
    )
    QBCore.Functions.Notify(message, 'primary', 10000)
    print('[prp-mechanic-tablet] ' .. message .. ' | full=' .. json.encode(data))
end)

RegisterNUICallback('close', function(_, cb) closeTablet(true) cb('ok') end)
RegisterNUICallback('previewStance', function(data, cb)
    if tabletVehicle ~= 0 and DoesEntityExist(tabletVehicle) then
        local plate = trimPlate(GetVehicleNumberPlateText(tabletVehicle))
        local installed = vehicleCache[plate]
        if installed and installed.stancer then
            previewStance = normaliseStance(data.stance)
            applyStance(tabletVehicle, previewStance, installed)
        end
    end
    cb('ok')
end)
RegisterNUICallback('saveStance', function(data, cb)
    if tabletVehicle ~= 0 and DoesEntityExist(tabletVehicle) then
        local plate = trimPlate(GetVehicleNumberPlateText(tabletVehicle))
        local savedStance = normaliseStance(data.stance)
        previewOriginal = savedStance
        previewStance = savedStance
        if vehicleCache[plate] then
            vehicleCache[plate].stance_data = savedStance
            applyVehicleUpgrades(tabletVehicle, vehicleCache[plate])
        end
        TriggerServerEvent('prp-mechanic-tablet:server:saveStance', plate, savedStance)
        QBCore.Functions.Notify('Stance setup saved permanently.', 'success')
    end
    cb('ok')
end)
RegisterNUICallback('airbagSoundFailed', function(data, cb)
    print(('[prp-mechanic-tablet] Airbag sound failed: %s (%s)'):format(
        tostring(data and data.message or 'unknown error'),
        tostring(data and data.src or 'unknown source')
    ))
    cb('ok')
end)

RegisterNetEvent('prp-mechanic-tablet:client:useItem', function(itemName)
    if itemName == Config.Items.Tablet then openTablet()
    elseif itemName == Config.Items.Airbags then runInstall(itemName, 'airbags')
    elseif itemName == Config.Items.Stancer then runInstall(itemName, 'stancer')
    elseif itemName == Config.Items.Hydraulics then runInstall(itemName, 'hydraulics') end
end)

RegisterNetEvent('prp-mechanic-tablet:client:applyVehicleData', function(plate, data)
    plate = trimPlate(plate)
    local previousDown = airbagVisualStates[plate]
    if previousDown == nil and vehicleCache[plate] then
        previousDown = vehicleCache[plate].airbags_down == true
    end
    local newDown = data and data.airbags_down == true
    local stateChanged = previousDown ~= nil and previousDown ~= newDown

    vehicleCache[plate] = data
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if trimPlate(GetVehicleNumberPlateText(vehicle)) == plate then
            if vehicleIsBike(vehicle) then
                resetUnsupportedBike(vehicle)
            elseif stateChanged then
                applyVehicleUpgrades(vehicle, data, true, previousDown)
            elseif not airbagAnimations[plate] then
                applyVehicleUpgrades(vehicle, data)
            end
        end
    end
    airbagVisualStates[plate] = newDown
    if tabletVehicle ~= 0 and trimPlate(GetVehicleNumberPlateText(tabletVehicle)) == plate then
        previewOriginal = copyTable(data.stance_data or Config.Defaults)
        SendNUIMessage({
            action = 'refreshData',
            data = data,
            airbagsDown = data.airbags_down == true
        })
    end
end)

local function clearHydraulicLock()
    hydraulicLock.vehicle = 0
    hydraulicLock.waitingForAir = false
    hydraulicLock.startedAt = 0
    hydraulicLock.groundedAt = 0
end

local function startHydraulicLock(vehicle)
    hydraulicLock.vehicle = vehicle
    hydraulicLock.waitingForAir = true
    hydraulicLock.startedAt = GetGameTimer()
    hydraulicLock.groundedAt = 0
end

local function hydraulicsLocked()
    return hydraulicLock.vehicle ~= 0
end

local function currentHydraulicVehicle(requireEnabled)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return 0 end
    if vehicleIsBike(vehicle) then
        resetUnsupportedBike(vehicle)
        return 0
    end
    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    local data = vehicleCache[plate]
    if not data or not data.hydraulics then return 0 end
    if requireEnabled and not hydraulicsEnabled then return 0 end
    return vehicle
end

local function hydraulicPulse(mode)
    local now = GetGameTimer()
    if hydraulicsLocked() then return end
    if now - lastHydraulicUse < Config.Hydraulics.cooldownMs then return end
    local vehicle = currentHydraulicVehicle(true)
    if vehicle == 0 then return end
    lastHydraulicUse = now
    startHydraulicLock(vehicle)
    requestControl(vehicle)

    local up = Config.Hydraulics.verticalForce
    local side = Config.Hydraulics.directionalForce
    if mode == 'all' then
        ApplyForceToEntityCenterOfMass(vehicle, 1, 0.0, 0.0, up, true, true, true, true)
    elseif mode == 'front' then
        ApplyForceToEntity(vehicle, 1, 0.0, 0.0, up, 0.0, 1.4, 0.0, 0, true, true, true, false, true)
    elseif mode == 'rear' then
        ApplyForceToEntity(vehicle, 1, 0.0, 0.0, up, 0.0, -1.4, 0.0, 0, true, true, true, false, true)
    elseif mode == 'left' then
        ApplyForceToEntity(vehicle, 1, 0.0, 0.0, up * 0.8, -side, 0.0, 0.0, 0, true, true, true, false, true)
    elseif mode == 'right' then
        ApplyForceToEntity(vehicle, 1, 0.0, 0.0, up * 0.8, side, 0.0, 0.0, 0, true, true, true, false, true)
    end
end

RegisterCommand(Config.Hydraulics.toggleCommand, function()
    local vehicle = currentHydraulicVehicle(false)
    if vehicle == 0 then return end
    hydraulicsEnabled = not hydraulicsEnabled
    QBCore.Functions.Notify(hydraulicsEnabled and 'Hydraulics controls enabled.' or 'Hydraulics controls disabled.', 'success')
end, false)
RegisterCommand(Config.Hydraulics.frontCommand, function() hydraulicPulse('front') end, false)
RegisterCommand(Config.Hydraulics.rearCommand, function() hydraulicPulse('rear') end, false)
RegisterCommand(Config.Hydraulics.leftCommand, function() hydraulicPulse('left') end, false)
RegisterCommand(Config.Hydraulics.rightCommand, function() hydraulicPulse('right') end, false)
RegisterCommand(Config.Hydraulics.allCommand, function() hydraulicPulse('all') end, false)

RegisterKeyMapping(Config.Airbags.toggleCommand, 'PRP Airbags: toggle automatic ride height', 'keyboard', Config.Airbags.defaultKey)
RegisterKeyMapping(Config.Hydraulics.toggleCommand, 'PRP Hydraulics: toggle controls', 'keyboard', Config.Hydraulics.defaultKeys.toggle)
RegisterKeyMapping(Config.Hydraulics.frontCommand, 'PRP Hydraulics: bounce front', 'keyboard', Config.Hydraulics.defaultKeys.front)
RegisterKeyMapping(Config.Hydraulics.rearCommand, 'PRP Hydraulics: bounce rear', 'keyboard', Config.Hydraulics.defaultKeys.rear)
RegisterKeyMapping(Config.Hydraulics.leftCommand, 'PRP Hydraulics: bounce left', 'keyboard', Config.Hydraulics.defaultKeys.left)
RegisterKeyMapping(Config.Hydraulics.rightCommand, 'PRP Hydraulics: bounce right', 'keyboard', Config.Hydraulics.defaultKeys.right)
RegisterKeyMapping(Config.Hydraulics.allCommand, 'PRP Hydraulics: full bounce', 'keyboard', Config.Hydraulics.defaultKeys.all)

CreateThread(function()
    local lastVehicle = 0
    while true do
        Wait(1200)
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 and vehicle ~= lastVehicle then
            lastVehicle = vehicle
            hydraulicsEnabled = false
            airbagStopSince = 0
            loadVehicleData(vehicle)
        elseif vehicle == 0 then
            lastVehicle = 0
            hydraulicsEnabled = false
            airbagStopSince = 0
            clearHydraulicLock()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(150)
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 then
            local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
            updateAutomaticAirbags(vehicle, vehicleCache[plate])
        else
            airbagStopSince = 0
        end
    end
end)

CreateThread(function()
    while true do
        if hydraulicLock.vehicle == 0 then
            Wait(250)
        else
            Wait(Config.Hydraulics.groundCheckMs)

            local vehicle = hydraulicLock.vehicle
            local now = GetGameTimer()
            if not DoesEntityExist(vehicle) or now - hydraulicLock.startedAt >= Config.Hydraulics.maxLockMs then
                clearHydraulicLock()
            else
                local grounded = IsVehicleOnAllWheels(vehicle)
                if hydraulicLock.waitingForAir then
                    if not grounded then
                        hydraulicLock.waitingForAir = false
                    elseif now - hydraulicLock.startedAt >= Config.Hydraulics.takeoffGraceMs then
                        clearHydraulicLock()
                    end
                elseif grounded then
                    if hydraulicLock.groundedAt == 0 then
                        hydraulicLock.groundedAt = now
                    elseif now - hydraulicLock.groundedAt >= Config.Hydraulics.groundSettleMs then
                        clearHydraulicLock()
                    end
                else
                    hydraulicLock.groundedAt = 0
                end
            end
        end
    end
end)


-- Wheel camber is a visual wheel-physics value and GTA restores it while driving.
-- Reapply only the wheel visuals every frame for streamed vehicles with a stancer kit.
CreateThread(function()
    while true do
        local maintained = false
        local pedCoords = GetEntityCoords(PlayerPedId())

        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(vehicle) and #(pedCoords - GetEntityCoords(vehicle)) < 160.0 then
                local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
                local data = vehicleCache[plate]
                if data and data.stancer and data.stance_data and not vehicleIsBike(vehicle) then
                    maintainWheelStance(vehicle, getActiveStance(vehicle, data))
                    maintained = true
                end
            end
        end

        Wait(maintained and 0 or 500)
    end
end)
