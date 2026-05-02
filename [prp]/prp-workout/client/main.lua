local QBCore = exports[Config.Core]:GetCoreObject()

local isOpen = false
local isWorkingOut = false
local punchingBag = nil
local bagCoords = nil
local bagHeading = nil
local effectsStarted = false

local latestStats = {
    strength = 0,
    stamina = 0,
    endurance = 0,
    activity_count = 0,
    max_activities = Config.MaxActivitiesPerHour,
    reset_in = 0
}

local function ClampStat(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > Config.StatMax then return Config.StatMax end
    return value
end

local function StatPercent(stat)
    return ClampStat(latestStats[stat]) / (Config.StatMax or 100)
end

local function RequestStats()
    TriggerServerEvent('prp-workout:server:getStats')
end

local function ApplyEnduranceEffect()
    local endurance = Config.Effects and Config.Effects.Endurance
    if not Config.Effects or not Config.Effects.Enabled or not endurance or not endurance.Enabled then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    local baseHealth = tonumber(endurance.BaseMaxHealth) or 200
    local bonusHealth = math.floor(((tonumber(endurance.MaxBonusHealth) or 0) * StatPercent('endurance')) + 0.5)
    local targetMaxHealth = baseHealth + bonusHealth
    local currentMaxHealth = GetEntityMaxHealth(ped)

    if currentMaxHealth <= 0 then currentMaxHealth = baseHealth end
    if currentMaxHealth == targetMaxHealth then return end

    local currentHealth = GetEntityHealth(ped)
    local healthPercent = currentHealth / currentMaxHealth

    SetEntityMaxHealth(ped, targetMaxHealth)
    if currentHealth > 0 then
        SetEntityHealth(ped, math.max(1, math.min(targetMaxHealth, math.floor((targetMaxHealth * healthPercent) + 0.5))))
    end
end

local function ApplyStaminaEffect()
    local stamina = Config.Effects and Config.Effects.Stamina
    if not Config.Effects or not Config.Effects.Enabled or not stamina or not stamina.Enabled then return end

    local percent = StatPercent('stamina')
    if percent <= 0 then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end
    if not IsPedRunning(ped) and not IsPedSprinting(ped) then return end

    local restoreAmount = (tonumber(stamina.RestoreAtMax) or 0.0) * percent
    if restoreAmount > 0 then
        RestorePlayerStamina(PlayerId(), restoreAmount)
    end
end

local function ApplyStrengthEffect()
    local strength = Config.Effects and Config.Effects.Strength
    if not Config.Effects or not Config.Effects.Enabled or not strength or not strength.Enabled then return end

    local modifier = (tonumber(strength.BaseMeleeModifier) or 1.0) + ((tonumber(strength.MaxBonusMeleeModifier) or 0.0) * StatPercent('strength'))
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), modifier, true)
end

local function ResetGameplayEffects()
    local ped = PlayerPedId()
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), 1.0, true)

    if ped and ped ~= 0 and not IsEntityDead(ped) and Config.Effects and Config.Effects.Endurance then
        local baseHealth = tonumber(Config.Effects.Endurance.BaseMaxHealth) or 200
        local currentMaxHealth = GetEntityMaxHealth(ped)
        local currentHealth = GetEntityHealth(ped)
        local healthPercent = currentMaxHealth > 0 and (currentHealth / currentMaxHealth) or 1.0
        SetEntityMaxHealth(ped, baseHealth)
        SetEntityHealth(ped, math.max(1, math.min(baseHealth, math.floor((baseHealth * healthPercent) + 0.5))))
    end
end

local function StartGameplayEffects()
    if effectsStarted then return end
    effectsStarted = true

    CreateThread(function()
        while true do
            if Config.Effects and Config.Effects.Enabled then
                ApplyEnduranceEffect()
                ApplyStaminaEffect()
                ApplyStrengthEffect()
            end

            Wait((Config.Effects and Config.Effects.TickMs) or 500)
        end
    end)
end

local function LoadModel(model)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

local function LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function GetBagSpawnCoords()
    local activity = Config.Activities.boxing
    return vector3(
        activity.coords.x,
        activity.coords.y,
        activity.coords.z + (Config.PunchingBag.ZOffset or 0.0)
    )
end

local function DeletePunchingBag()
    if punchingBag and DoesEntityExist(punchingBag) then
        DeleteEntity(punchingBag)
    end

    punchingBag = nil
end

local function SpawnPunchingBag()
    if not Config.PunchingBag.Enabled then return end

    local activity = Config.Activities.boxing
    if not activity then return end

    if punchingBag and DoesEntityExist(punchingBag) then return end

    local model = Config.PunchingBag.Model
    if not LoadModel(model) then
        print('[prp-workout] Failed to load punching bag model.')
        return
    end

    bagCoords = GetBagSpawnCoords()
    bagHeading = activity.heading or 0.0

    punchingBag = CreateObject(model, bagCoords.x, bagCoords.y, bagCoords.z, false, false, false)
    SetEntityHeading(punchingBag, bagHeading)
    SetEntityAsMissionEntity(punchingBag, true, true)
    SetEntityInvincible(punchingBag, true)
    SetEntityCollision(punchingBag, true, true)
    FreezeEntityPosition(punchingBag, true)

    SetModelAsNoLongerNeeded(model)
end

local function ResetPunchingBag()
    if not Config.PunchingBag.Enabled then return end

    if not punchingBag or not DoesEntityExist(punchingBag) then
        SpawnPunchingBag()
        return
    end

    bagCoords = GetBagSpawnCoords()

    FreezeEntityPosition(punchingBag, true)
    SetEntityCoordsNoOffset(punchingBag, bagCoords.x, bagCoords.y, bagCoords.z, false, false, false)
    SetEntityHeading(punchingBag, bagHeading or Config.Activities.boxing.heading or 0.0)
end

local function SwingPunchingBag()
    if not punchingBag or not DoesEntityExist(punchingBag) then return end

    local baseHeading = bagHeading or Config.Activities.boxing.heading or 0.0
    local coords = bagCoords or GetBagSpawnCoords()
    local swing = Config.PunchingBag.SwingAmount or 12.0
    local speed = Config.PunchingBag.SwingSpeed or 75

    CreateThread(function()
        local steps = {
            swing,
            -swing * 0.85,
            swing * 0.65,
            -swing * 0.45,
            swing * 0.25,
            -swing * 0.12,
            0.0
        }

        for _, offset in ipairs(steps) do
            if not punchingBag or not DoesEntityExist(punchingBag) then return end
            SetEntityCoordsNoOffset(punchingBag, coords.x, coords.y, coords.z, false, false, false)
            SetEntityHeading(punchingBag, baseHeading + offset)
            Wait(speed)
        end

        ResetPunchingBag()
    end)
end

local function OpenStats()
    isOpen = true
    SetNuiFocus(true, true)

    RequestStats()

    SendNUIMessage({
        action = 'open',
        stats = latestStats
    })
end

local function CloseStats()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Command, function()
    OpenStats()
end)

RegisterNUICallback('close', function(_, cb)
    CloseStats()
    cb('ok')
end)

RegisterNetEvent('prp-workout:client:setStats', function(stats)
    latestStats = stats
    ApplyEnduranceEffect()
    ApplyStrengthEffect()

    SendNUIMessage({
        action = isOpen and 'update' or 'cache',
        stats = latestStats
    })
end)

local function PlayActivity(activityName)
    if isWorkingOut then
        QBCore.Functions.Notify('You are already working out.', 'error')
        return
    end

    local activity = Config.Activities[activityName]
    if not activity then return end

    isWorkingOut = true

    local ped = PlayerPedId()

    if activityName == 'boxing' then
        ResetPunchingBag()

        if activity.playerCoords then
            SetEntityCoords(
                ped,
                activity.playerCoords.x,
                activity.playerCoords.y,
                activity.playerCoords.z - 1.0,
                false,
                false,
                false,
                false
            )

            SetEntityHeading(ped, activity.playerCoords.w)
        end
    end

    if activity.scenario then
        TaskStartScenarioInPlace(ped, activity.scenario, 0, true)
    elseif activity.animDict and activity.animName then
        LoadAnim(activity.animDict)

        CreateThread(function()
            while isWorkingOut do
                TaskPlayAnim(ped, activity.animDict, activity.animName, 8.0, -8.0, 750, 48, 0.0, false, false, false)

                if activityName == 'boxing' then
                    Wait(250)
                    PlaySoundFrontend(-1, 'FIGHT_PUNCH', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    SwingPunchingBag()
                end

                Wait(650)
            end
        end)
    end

    QBCore.Functions.Progressbar('prp_workout_' .. activityName, activity.label, Config.WorkoutDuration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(ped)

        if activityName == 'boxing' then
            ResetPunchingBag()
        end

        TriggerServerEvent('prp-workout:server:completeActivity', activityName)
        isWorkingOut = false
    end, function()
        ClearPedTasks(ped)

        if activityName == 'boxing' then
            ResetPunchingBag()
        end

        QBCore.Functions.Notify('Workout cancelled.', 'error')
        isWorkingOut = false
    end)
end

CreateThread(function()
    Wait(1000)

    SendNUIMessage({ action = 'close' })
    StartGameplayEffects()
    RequestStats()
    SpawnPunchingBag()

    for activityName, activity in pairs(Config.Activities) do
        exports[Config.Target]:AddCircleZone('prp_workout_' .. activityName, activity.coords, activity.radius, {
            name = 'prp_workout_' .. activityName,
            debugPoly = false
        }, {
            options = {
                {
                    icon = activity.icon,
                    label = activity.label,
                    action = function()
                        PlayActivity(activityName)
                    end
                }
            },
            distance = 2.0
        })
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    RequestStats()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    latestStats = {
        strength = 0,
        stamina = 0,
        endurance = 0,
        activity_count = 0,
        max_activities = Config.MaxActivitiesPerHour,
        reset_in = 0
    }
    ResetGameplayEffects()
end)

CreateThread(function()
    while true do
        Wait((Config.PunchingBag.ResetEverySeconds or 30) * 1000)
        ResetPunchingBag()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ResetGameplayEffects()
    DeletePunchingBag()
end)
