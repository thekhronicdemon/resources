local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local speedMultiplier = Config.UseMPH and 2.23694 or 3.6
local speedUnit = Config.UseMPH and 'MPH' or 'KMH'

local seatbeltOn = false
local cruiseOn = false
local showSeatbelt = true
local nos = 0
local stress = 0
local hunger = 100
local thirst = 100
local nitroActive = false
local harness = false
local harnessHp = 0
local dev = false
local radioActive = false
local lastFuelUpdate = 0
local lastFuelCheck = 100
local lowFuelWarned = false
local lastCrossroadUpdate = 0
local lastCrossroadCheck = { '', '' }
local staminaNativeReturnsRemaining = nil
local showCustomAmmo = false
local lastSpeedStressAt = 0
local lastShootingStressAt = 0

DisplayRadar(false)

local function clamp(value, min, max)
    value = tonumber(value) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function refreshMetadata()
    local metadata = PlayerData.metadata or {}
    hunger = clamp(metadata.hunger or hunger, 0, 100)
    thirst = clamp(metadata.thirst or thirst, 0, 100)
    stress = clamp(metadata.stress or stress, 0, 100)
end

local function isLoggedIn()
    local loggedIn = LocalPlayer.state.isLoggedIn
    if loggedIn ~= nil then return loggedIn end
    return PlayerData.citizenid ~= nil
end

local function isUsableVehicle(vehicle)
    if vehicle == 0 then return false end
    return not IsThisModelABicycle(GetEntityModel(vehicle))
end

local function shouldShowSeatbelt(vehicle)
    local class = GetVehicleClass(vehicle)
    return showSeatbelt and class ~= 8 and class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16
end

local function getFuelLevel(vehicle)
    local updateTick = GetGameTimer()
    if updateTick - lastFuelUpdate > 1000 then
        lastFuelUpdate = updateTick
        local ok, fuel = pcall(function()
            return exports['LegacyFuel']:GetFuel(vehicle)
        end)
        if ok and fuel then
            lastFuelCheck = fuel
        else
            lastFuelCheck = GetVehicleFuelLevel(vehicle)
        end
    end
    return clamp(round(lastFuelCheck), 0, 100)
end

local function getVehicleGear(vehicle, speed)
    local gear = GetVehicleCurrentGear(vehicle)
    if gear == 0 then
        local forwardSpeed = GetEntitySpeedVector(vehicle, true).y
        return forwardSpeed < -0.1 and 'R' or 'N'
    end
    if speed <= 1 then return 'N' end
    return tostring(gear)
end

local function getDirection(heading)
    local directions = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }
    local index = math.floor(((heading + 22.5) % 360) / 45) + 1
    return directions[index]
end

local function getCrossroads(ped)
    local updateTick = GetGameTimer()
    if updateTick - lastCrossroadUpdate > 1000 then
        local pos = GetEntityCoords(ped)
        local street1, street2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        local zone = GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z))

        lastCrossroadUpdate = updateTick
        lastCrossroadCheck = {
            GetStreetNameFromHashKey(street1),
            zone ~= 'NULL' and zone or GetStreetNameFromHashKey(street2),
        }
    end
    return lastCrossroadCheck
end

local function getOxygen(ped, playerId)
    if IsEntityInWater(ped) then
        return clamp(GetPlayerUnderwaterTimeRemaining(playerId) * 10, 0, 100)
    end
    return 100
end

local function getAmmoData(ped, weapon, isDead)
    if isDead or weapon == `WEAPON_UNARMED` or not IsPedArmed(ped, 4) or Config.WhitelistedWeaponArmed[weapon] then
        return false, 0, 0
    end

    local totalAmmo = tonumber(GetAmmoInPedWeapon(ped, weapon)) or 0
    local _, ammoInClip = GetAmmoInClip(ped, weapon)
    ammoInClip = tonumber(ammoInClip) or totalAmmo
    if ammoInClip > totalAmmo then
        ammoInClip = totalAmmo
    end

    return true, math.max(ammoInClip, 0), math.max(totalAmmo - ammoInClip, 0)
end

local function getStamina(ped, playerId)
    if IsEntityInWater(ped) then return 100 end

    local rawStamina = clamp(tonumber(GetPlayerSprintStaminaRemaining(playerId)) or 0, 0, 100)
    if staminaNativeReturnsRemaining == nil and not IsPedRunning(ped) and not IsPedSprinting(ped) and GetEntitySpeed(ped) < 1.0 then
        if rawStamina <= 5 then
            staminaNativeReturnsRemaining = false
        elseif rawStamina >= 95 then
            staminaNativeReturnsRemaining = true
        end
    end

    if staminaNativeReturnsRemaining == false then
        return clamp(100.0 - rawStamina, 0, 100)
    end

    return rawStamina
end

local function setupMinimap()
    RequestStreamedTextureDict('squaremap', false)
    local timeout = GetGameTimer() + 5000
    while not HasStreamedTextureDictLoaded('squaremap') and GetGameTimer() < timeout do
        Wait(50)
    end

    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0

    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end

    SetMinimapClipType(0)
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')
    SetMinimapComponentPosition('minimap', 'L', 'B', 0.0 + minimapOffset, -0.047, 0.1638, 0.183)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0 + minimapOffset, 0.0, 0.128, 0.20)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + minimapOffset, 0.025, 0.262, 0.300)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetBigmapActive(true, false)
    Wait(50)
    SetBigmapActive(false, false)
end

local function sendHudUpdate()
    if not isLoggedIn() or IsPauseMenuActive() then
        showCustomAmmo = false
        SendNUIMessage({ action = 'setVisible', visible = false })
        DisplayRadar(false)
        return
    end

    local ped = PlayerPedId()
    local playerId = PlayerId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local inVehicle = IsPedInAnyVehicle(ped, false) and isUsableVehicle(vehicle)
    local metadata = PlayerData.metadata or {}
    local isDead = IsEntityDead(ped) or metadata.isdead or false
    local inLaststand = metadata.inlaststand or false
    local health = clamp(GetEntityHealth(ped) - 100, 0, 100)
    if isDead or inLaststand then
        health = 0
    end
    local armor = clamp(GetPedArmour(ped), 0, 100)
    local weapon = GetSelectedPedWeapon(ped)
    local armed = weapon ~= `WEAPON_UNARMED` and not Config.WhitelistedWeaponArmed[weapon]
    local showAmmo, ammoClip, ammoReserve = getAmmoData(ped, weapon, isDead or inLaststand)
    local voiceDistance = 0
    local oxygen = getOxygen(ped, playerId)
    local stamina = IsEntityInWater(ped) and oxygen or getStamina(ped, playerId)
    local usingSprint = IsPedSprinting(ped) or (IsControlPressed(0, 21) and GetEntitySpeed(ped) > 1.2)
    local showStamina = not inVehicle and usingSprint

    if LocalPlayer.state.proximity then
        voiceDistance = tonumber(LocalPlayer.state.proximity.distance) or 0
    end

    local coords = GetEntityCoords(ped)
    local heading = 360.0 - ((GetGameplayCamRot(0).z + 360.0) % 360.0)
    if heading >= 359.5 then heading = 0.0 end

    local speed = 0
    local fuel = 0
    local engine = 0
    local rpm = 0
    local gear = 'N'
    local altitude = 0
    local vehicleClass = -1

    if inVehicle then
        local engineHealth = GetVehicleEngineHealth(vehicle)
        if engineHealth ~= engineHealth then engineHealth = 0 end

        speed = round(GetEntitySpeed(vehicle) * speedMultiplier)
        fuel = getFuelLevel(vehicle)
        engine = clamp(engineHealth / 10, 0, 100)
        rpm = clamp(GetVehicleCurrentRpm(vehicle) * 100, 0, 100)
        gear = getVehicleGear(vehicle, speed)
        altitude = round(coords.z * 0.5)
        vehicleClass = GetVehicleClass(vehicle)
    end

    local crossroads = getCrossroads(ped)
    local showCompass = inVehicle or Config.ShowCompassOnFoot
    local showMap = inVehicle or Config.ShowMinimapOnFoot
    showCustomAmmo = showAmmo
    DisplayRadar(showMap)

    SendNUIMessage({
        action = 'update',
        visible = true,
        inVehicle = inVehicle,
        showCompass = showCompass,
        health = health,
        armor = armor,
        hunger = hunger,
        thirst = thirst,
        stress = stress,
        stamina = stamina,
        showStamina = showStamina,
        oxygen = oxygen,
        talking = NetworkIsPlayerTalking(playerId),
        voice = voiceDistance,
        radio = LocalPlayer.state.radioChannel or 0,
        radioActive = radioActive,
        armed = armed,
        showAmmo = showAmmo,
        ammoClip = ammoClip,
        ammoReserve = ammoReserve,
        dead = isDead or inLaststand,
        street = crossroads[1],
        area = crossroads[2],
        direction = getDirection(heading),
        heading = round(heading),
        speed = speed,
        speedUnit = speedUnit,
        fuel = fuel,
        engine = engine,
        rpm = rpm,
        gear = gear,
        altitude = altitude,
        showAltitude = vehicleClass == 15 or vehicleClass == 16,
        seatbelt = seatbeltOn,
        showSeatbelt = inVehicle and shouldShowSeatbelt(vehicle),
        cruise = cruiseOn,
        nos = nos,
        nitroActive = nitroActive,
        harness = harness,
        harnessHp = harnessHp,
        dev = dev,
    })
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()
    refreshMetadata()
    setupMinimap()
    SendNUIMessage({ action = 'setUnit', unit = speedUnit })
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    showCustomAmmo = false
    SendNUIMessage({ action = 'setVisible', visible = false })
    DisplayRadar(false)
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val or {}
    refreshMetadata()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()
    refreshMetadata()
    setupMinimap()
    SendNUIMessage({ action = 'setUnit', unit = speedUnit })
end)

RegisterNetEvent('pma-voice:radioActive', function(active)
    radioActive = active
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger = clamp(newHunger, 0, 100)
    thirst = clamp(newThirst, 0, 100)
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    stress = clamp(newStress, 0, 100)
    PlayerData.metadata = PlayerData.metadata or {}
    PlayerData.metadata.stress = stress
    sendHudUpdate()
end)

RegisterNetEvent('hud:client:StressNotify', function(message, notifyType, length)
    QBCore.Functions.Notify(message or 'Stress changed', notifyType or 'primary', length or 1500)
end)

RegisterNetEvent('hud:client:ToggleShowSeatbelt', function()
    showSeatbelt = not showSeatbelt
end)

RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function(enabled)
    if type(enabled) == 'boolean' then
        seatbeltOn = enabled
    else
        seatbeltOn = not seatbeltOn
    end
end)

RegisterNetEvent('seatbelt:client:ToggleCruise', function(enabled)
    if type(enabled) == 'boolean' then
        cruiseOn = enabled
    else
        cruiseOn = not cruiseOn
    end
end)

RegisterNetEvent('hud:client:UpdateNitrous', function(nitroLevel, active)
    nos = clamp(nitroLevel, 0, 100)
    nitroActive = active
end)

RegisterNetEvent('hud:client:UpdateHarness', function(newHarnessHp)
    harness = (newHarnessHp or 0) > 0
    harnessHp = clamp(newHarnessHp, 0, 100)
end)

RegisterNetEvent('qb-admin:client:ToggleDevmode', function()
    dev = not dev
end)

RegisterNetEvent('hud:client:ShowAccounts', function(accountType, amount)
    SendNUIMessage({
        action = 'money',
        account = accountType,
        amount = round(amount),
    })
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(accountType, amount, isMinus)
    local money = PlayerData.money or {}
    SendNUIMessage({
        action = 'moneyChange',
        account = accountType,
        amount = round(amount),
        isMinus = isMinus,
        cash = round(money.cash),
        bank = round(money.bank),
    })
end)

RegisterNetEvent('hud:client:LoadMap', setupMinimap)

RegisterCommand('resethud', function()
    SendNUIMessage({ action = 'setVisible', visible = false })
    Wait(250)
    setupMinimap()
    sendHudUpdate()
end, false)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local inVehicle = IsPedInAnyVehicle(ped, false) and isUsableVehicle(vehicle)

        sendHudUpdate()
        Wait(inVehicle and Config.VehicleUpdateInterval or Config.PlayerUpdateInterval)
    end
end)

CreateThread(function()
    while true do
        SetBigmapActive(false, false)
        SetRadarZoom(1000)
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if showCustomAmmo and not IsPauseMenuActive() then
            HideHudComponentThisFrame(2)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        if Config.LowFuelAlert and isLoggedIn() then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if IsPedInAnyVehicle(ped, false) and isUsableVehicle(vehicle) then
                local fuel = getFuelLevel(vehicle)
                if fuel <= Config.LowFuelThreshold and not lowFuelWarned then
                    lowFuelWarned = true
                    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'pager', 0.10)
                    QBCore.Functions.Notify('Low fuel', 'error')
                elseif fuel > Config.LowFuelThreshold + 5 then
                    lowFuelWarned = false
                end
            else
                lowFuelWarned = false
            end
        end
        Wait(10000)
    end
end)

if not Config.DisableStress then
    CreateThread(function()
        while true do
            if isLoggedIn() then
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if isUsableVehicle(veh) then
                        local vehClass = GetVehicleClass(veh)
                        local speed = GetEntitySpeed(veh) * speedMultiplier
                        local vehHash = GetEntityModel(veh)

                        if Config.VehClassStress[tostring(vehClass)] and not Config.WhitelistedVehicles[vehHash] then
                            local stressSpeed = seatbeltOn and Config.MinimumSpeed or Config.MinimumSpeedUnbuckled
                            if vehClass == 8 then stressSpeed = Config.MinimumSpeed end
                            if speed >= stressSpeed then
                                local now = GetGameTimer()
                                if now - lastSpeedStressAt >= Config.SpeedStressInterval then
                                    lastSpeedStressAt = now
                                    TriggerServerEvent('prp-hud:server:GainStress', math.random(1, 3))
                                end
                            else
                                lastSpeedStressAt = 0
                            end
                        else
                            lastSpeedStressAt = 0
                        end
                    else
                        lastSpeedStressAt = 0
                    end
                else
                    lastSpeedStressAt = 0
                end
            else
                lastSpeedStressAt = 0
            end
            Wait(1000)
        end
    end)

    CreateThread(function()
        while true do
            if isLoggedIn() then
                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= `WEAPON_UNARMED` and IsPedArmed(ped, 4) then
                    if IsPedShooting(ped) and not Config.WhitelistedWeaponStress[weapon] then
                        local now = GetGameTimer()
                        if now - lastShootingStressAt >= Config.ShootingStressInterval and math.random() <= Config.StressChance then
                            lastShootingStressAt = now
                            TriggerServerEvent('prp-hud:server:GainStress', math.random(1, 3))
                        end
                    end
                else
                    lastShootingStressAt = 0
                    Wait(1000)
                end
            else
                lastShootingStressAt = 0
                Wait(1000)
            end
            Wait(0)
        end
    end)
end

local function getBlurIntensity(stressLevel)
    for _, data in pairs(Config.Intensity.blur) do
        if stressLevel >= data.min and stressLevel <= data.max then
            return data.intensity
        end
    end
    return 1500
end

local function getEffectInterval(stressLevel)
    for _, data in pairs(Config.EffectInterval) do
        if stressLevel >= data.min and stressLevel <= data.max then
            return data.timeout
        end
    end
    return 60000
end

CreateThread(function()
    while true do
        if isLoggedIn() then
            local ped = PlayerPedId()
            local effectInterval = getEffectInterval(stress)

            if stress >= 100 then
                local blurIntensity = getBlurIntensity(stress)
                local fallRepeat = math.random(2, 4)
                local ragdollTimeout = fallRepeat * 1750

                TriggerScreenblurFadeIn(1000.0)
                Wait(blurIntensity)
                TriggerScreenblurFadeOut(1000.0)

                if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                    SetPedToRagdollWithFall(ped, ragdollTimeout, ragdollTimeout, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                end

                Wait(1000)
                for _ = 1, fallRepeat do
                    Wait(750)
                    DoScreenFadeOut(200)
                    Wait(1000)
                    DoScreenFadeIn(200)
                    TriggerScreenblurFadeIn(1000.0)
                    Wait(blurIntensity)
                    TriggerScreenblurFadeOut(1000.0)
                end
            elseif stress >= Config.MinimumStress then
                local blurIntensity = getBlurIntensity(stress)
                TriggerScreenblurFadeIn(1000.0)
                Wait(blurIntensity)
                TriggerScreenblurFadeOut(1000.0)
            end

            Wait(effectInterval)
        else
            Wait(1000)
        end
    end
end)
