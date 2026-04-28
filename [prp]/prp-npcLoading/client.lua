local function debugPrint(msg)
    if Config.Debug then
        print(('[prp-npcLoading] %s'):format(msg))
    end
end

local function isPedValid(ped)
    return ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped)
end

local function isPlayerPed(ped)
    return isPedValid(ped) and IsPedAPlayer(ped)
end

local function isAmbientPed(ped)
    if not isPedValid(ped) then return false end
    if not IsPedHuman(ped) then return false end
    if IsPedAPlayer(ped) then return false end
    return GetEntityPopulationType(ped) ~= 7
end

local function isPolicePed(ped)
    if not isPedValid(ped) then return false end

    local pedType = GetPedType(ped)
    if pedType == 6 then
        return true
    end

    local relationshipGroup = GetPedRelationshipGroupHash(ped)
    if relationshipGroup == GetHashKey('COP') or relationshipGroup == GetHashKey('MISSION2') then
        return true
    end

    local model = GetEntityModel(ped)
    return model == GetHashKey('s_m_y_cop_01')
        or model == GetHashKey('s_f_y_cop_01')
        or model == GetHashKey('s_m_y_hwaycop_01')
        or model == GetHashKey('s_m_y_sheriff_01')
        or model == GetHashKey('s_f_y_sheriff_01')
        or model == GetHashKey('s_m_y_ranger_01')
        or model == GetHashKey('s_m_y_swat_01')
end

local function isSecurityPed(ped)
    if not isPedValid(ped) then return false end

    local model = GetEntityModel(ped)
    return model == GetHashKey('s_m_m_security_01')
        or model == GetHashKey('s_m_m_armoured_01')
        or model == GetHashKey('s_m_m_armoured_02')
        or model == GetHashKey('mp_s_m_armoured_01')
        or model == GetHashKey('s_m_m_ciasec_01')
end

local function shouldTouchAmbientPed(ped, onlyAmbient)
    if not isPedValid(ped) then return false end
    if isPlayerPed(ped) then return false end
    if onlyAmbient and not isAmbientPed(ped) then return false end
    return true
end

local function applyRelationshipCalm()
    if not Config.CalmAmbientPeds or not Config.CalmAmbientPeds.enabled then return end

    local level = Config.CalmAmbientPeds.relationshipLevel or 1
    for _, groupName in ipairs(Config.CalmAmbientPeds.relationshipGroups or {}) do
        local groupHash = GetHashKey(groupName)
        SetRelationshipBetweenGroups(level, groupHash, `PLAYER`)
        SetRelationshipBetweenGroups(level, `PLAYER`, groupHash)
    end
end

local function disarmAmbientPed(ped)
    if not Config.DisarmAmbientPeds.enabled then return end
    if not shouldTouchAmbientPed(ped, Config.DisarmAmbientPeds.onlyAmbientPeds) then return end
    if Config.DisarmAmbientPeds.keepPoliceArmed and isPolicePed(ped) then return end
    if Config.DisarmAmbientPeds.keepSecurityArmed and isSecurityPed(ped) then return end

    if IsPedArmed(ped, 6) then
        RemoveAllPedWeapons(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        debugPrint(('Disarmed ped %s'):format(ped))
    end

    SetPedDropsWeaponsWhenDead(ped, false)
end

local function calmAmbientPed(ped, playerPed)
    if not Config.CalmAmbientPeds.enabled then return end
    if not shouldTouchAmbientPed(ped, Config.CalmAmbientPeds.onlyAmbientPeds) then return end
    if isPolicePed(ped) or isSecurityPed(ped) then return end

    SetPedAsEnemy(ped, false)
    SetCanAttackFriendly(ped, false, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 3, false)
    SetPedCombatAttributes(ped, 5, false)
    SetPedCombatAttributes(ped, 17, false)
    SetPedCombatAttributes(ped, 46, false)
    SetPedCombatMovement(ped, 0)
    SetPedCombatRange(ped, 0)

    if Config.CalmAmbientPeds.clearHostileTasks then
        local hostileToPlayer = IsPedInCombat(ped, playerPed)
            or IsPedInMeleeCombat(ped)
            or IsPedShooting(ped)

        if hostileToPlayer then
            ClearPedTasksImmediately(ped)
            ClearPedSecondaryTask(ped)
            if not IsPedInAnyVehicle(ped, false) then
                TaskWanderStandard(ped, 10.0, 10)
            end
            debugPrint(('Cleared hostile ambient ped %s'):format(ped))
        end
    end
end

local function calmNearbyAmbientPeds()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local scanRadius = math.max(
        Config.CalmAmbientPeds.enabled and Config.CalmAmbientPeds.scanRadius or 0.0,
        Config.DisarmAmbientPeds.enabled and Config.DisarmAmbientPeds.scanRadius or 0.0
    )

    for _, ped in ipairs(GetGamePool('CPed')) do
        if isPedValid(ped) then
            local pedCoords = GetEntityCoords(ped)
            if #(playerCoords - pedCoords) <= scanRadius then
                calmAmbientPed(ped, playerPed)
                disarmAmbientPed(ped)
            end
        end
    end
end

local function calmDriver(driver)
    if not isPedValid(driver) then return end
    if isPlayerPed(driver) then return end

    SetDriverAbility(driver, Config.CalmDrivers.ability)
    SetDriverAggressiveness(driver, Config.CalmDrivers.aggressiveness)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedFleeAttributes(driver, 0, false)
    SetPedCombatAttributes(driver, 3, false)
    SetPedCombatAttributes(driver, 5, false)
    SetPedCombatAttributes(driver, 17, false)
    SetPedCombatAttributes(driver, 46, false)

    if Config.CalmDrivers.drivingStyle then
        SetDriveTaskDrivingStyle(driver, Config.CalmDrivers.drivingStyle)
    end
end

local function calmNearbyDrivers()
    if not Config.CalmDrivers.enabled then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            if #(playerCoords - vehCoords) <= Config.CalmDrivers.scanRadius then
                local driver = GetPedInVehicleSeat(vehicle, -1)
                calmDriver(driver)
            end
        end
    end
end

CreateThread(function()
    applyRelationshipCalm()

    while true do
        Wait(30000)
        applyRelationshipCalm()
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        SetVehicleDensityMultiplierThisFrame(Config.Density.vehicles)
        SetPedDensityMultiplierThisFrame(Config.Density.peds)
        SetRandomVehicleDensityMultiplierThisFrame(Config.Density.randomVehicles)
        SetParkedVehicleDensityMultiplierThisFrame(Config.Density.parkedVehicles)
        SetScenarioPedDensityMultiplierThisFrame(Config.Density.scenarioPeds, Config.Density.scenarioPeds)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if Config.World.disableRandomCops then
            SetCreateRandomCops(false)
            SetCreateRandomCopsNotOnScenarios(false)
            SetCreateRandomCopsOnScenarios(false)
            DistantCopCarSirens(false)
        end

        if Config.World.disableRandomBoats then
            SetRandomBoats(false)
        end

        if Config.World.disableRandomTrains then
            SetRandomTrains(false)
        end

        if Config.World.disableRandomEvents then
            SetRandomEventFlag(false)
        end

        if Config.World.disableDispatchServices then
            for i = 1, 15 do
                EnableDispatchService(i, false)
            end
        end
    end
end)

CreateThread(function()
    while Config.CalmDrivers.enabled do
        calmNearbyDrivers()
        Wait(Config.CalmDrivers.scanInterval)
    end
end)

CreateThread(function()
    while Config.CalmAmbientPeds.enabled or Config.DisarmAmbientPeds.enabled do
        calmNearbyAmbientPeds()
        Wait(math.min(Config.CalmAmbientPeds.scanInterval, Config.DisarmAmbientPeds.scanInterval))
    end
end)
