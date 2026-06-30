-- Variables

local alcoholCount = 0
local healing, parachuteEquipped = false, false
local currVest, currVestTexture = nil, nil

-- Functions
RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function getProgressIcon(itemName, fallbackImage)
    local item = itemName and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[itemName]
    return (item and item.image) or fallbackImage
end

local function equipParachuteAnim()
    loadAnimDict('clothingshirt')
    TaskPlayAnim(PlayerPedId(), 'clothingshirt', 'try_shirt_positive_d', 8.0, 1.0, -1, 49, 0, false, false, false)
end

local function healOxy()
    if healing then return end

    healing = true

    local count = 9
    while count > 0 do
        Wait(1000)
        count -= 1
        SetEntityHealth(PlayerPedId(), GetEntityHealth(PlayerPedId()) + 6)
    end
    healing = false
end

local function trevorEffect()
    StartScreenEffect('DrugsTrevorClownsFightIn', 3.0, 0)
    Wait(3000)
    StartScreenEffect('DrugsTrevorClownsFight', 3.0, 0)
    Wait(3000)
    StartScreenEffect('DrugsTrevorClownsFightOut', 3.0, 0)
    StopScreenEffect('DrugsTrevorClownsFight')
    StopScreenEffect('DrugsTrevorClownsFightIn')
    StopScreenEffect('DrugsTrevorClownsFightOut')
end

local function methBagEffect()
    local startStamina = 8
    trevorEffect()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
    while startStamina > 0 do
        Wait(1000)
        if math.random(5, 100) < 10 then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        startStamina = startStamina - 1
        if math.random(5, 100) < 51 then
            trevorEffect()
        end
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

local function ecstasyEffect()
    local startStamina = 30
    SetFlash(0, 0, 500, 7000, 500)
    while startStamina > 0 do
        Wait(1000)
        startStamina -= 1
        RestorePlayerStamina(PlayerId(), 1.0)
        if math.random(1, 100) < 51 then
            SetFlash(0, 0, 500, 7000, 500)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
        end
    end
    if IsPedRunning(PlayerPedId()) then
        SetPedToRagdoll(PlayerPedId(), math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
    end
end

local function alienEffect()
    StartScreenEffect('DrugsMichaelAliensFightIn', 3.0, 0)
    Wait(math.random(5000, 8000))
    StartScreenEffect('DrugsMichaelAliensFight', 3.0, 0)
    Wait(math.random(5000, 8000))
    StartScreenEffect('DrugsMichaelAliensFightOut', 3.0, 0)
    StopScreenEffect('DrugsMichaelAliensFightIn')
    StopScreenEffect('DrugsMichaelAliensFight')
    StopScreenEffect('DrugsMichaelAliensFightOut')
end

local function crackBaggyEffect()
    local startStamina = 8
    local ped = PlayerPedId()
    alienEffect()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.3)
    while startStamina > 0 do
        Wait(1000)
        if math.random(1, 100) < 10 then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        startStamina -= 1
        if math.random(1, 100) < 60 and IsPedRunning(ped) then
            SetPedToRagdoll(ped, math.random(1000, 2000), math.random(1000, 2000), 3, false, false, false)
        end
        if math.random(1, 100) < 51 then
            alienEffect()
        end
    end
    if IsPedRunning(ped) then
        SetPedToRagdoll(ped, math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

local function cokeBaggyEffect()
    local startStamina = 20
    local ped = PlayerPedId()
    alienEffect()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.1)
    while startStamina > 0 do
        Wait(1000)
        if math.random(1, 100) < 20 then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        startStamina -= 1
        if math.random(1, 100) < 10 and IsPedRunning(ped) then
            SetPedToRagdoll(ped, math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
        end
        if math.random(1, 300) < 10 then
            alienEffect()
            Wait(math.random(3000, 6000))
        end
    end
    if IsPedRunning(ped) then
        SetPedToRagdoll(ped, math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

-- Events

RegisterNetEvent('consumables:client:Eat', function(itemName)
    QBCore.Functions.Progressbar('eat_something', Lang:t('consumables.eat_progress'), 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'mp_player_inteat@burger',
        anim = 'mp_player_int_eat_burger',
        flags = 49
    }, {
        model = 'prop_cs_burger_01',
        bone = 60309,
        coords = vec3(0.0, 0.0, -0.02),
        rotation = vec3(30, 0.0, 0.0),
    }, {}, function() -- Done
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
        TriggerServerEvent('consumables:server:addHunger', QBCore.Functions.GetPlayerData().metadata.hunger + Config.Consumables.eat[itemName])
        TriggerServerEvent('hud:server:RelieveStress', math.random(2, 4))
    end, nil, getProgressIcon(itemName, 'sandwich.png'))
end)

RegisterNetEvent('consumables:client:Drink', function(itemName)
    QBCore.Functions.Progressbar('drink_something', Lang:t('consumables.drink_progress'), 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'mp_player_intdrink',
        anim = 'loop_bottle',
        flags = 49
    }, {
        model = 'vw_prop_casino_water_bottle_01a',
        bone = 60309,
        coords = vec3(0.0, 0.0, -0.05),
        rotation = vec3(0.0, 0.0, -40),
    }, {}, function() -- Done
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
        TriggerServerEvent('consumables:server:addThirst', QBCore.Functions.GetPlayerData().metadata.thirst + Config.Consumables.drink[itemName])
    end, nil, getProgressIcon(itemName, 'water_bottle.png'))
end)

RegisterNetEvent('consumables:client:DrinkAlcohol', function(itemName)
    QBCore.Functions.Progressbar('drink_alcohol', Lang:t('consumables.liqour_progress'), math.random(3000, 6000), false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'mp_player_intdrink',
        anim = 'loop_bottle',
        flags = 49
    }, {
        model = 'prop_cs_beer_bot_40oz',
        bone = 60309,
        coords = vec3(0.0, 0.0, -0.05),
        rotation = vec3(0.0, 0.0, -40),
    }, {}, function() -- Done
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
        TriggerServerEvent('consumables:server:drinkAlcohol', itemName)
        TriggerServerEvent('consumables:server:addThirst', QBCore.Functions.GetPlayerData().metadata.thirst + Config.Consumables.alcohol[itemName])
        TriggerServerEvent('hud:server:RelieveStress', math.random(2, 4))
        alcoholCount += 1
        AlcoholLoop()
        if alcoholCount > 1 and alcoholCount < 4 then
            TriggerEvent('evidence:client:SetStatus', 'alcohol', 200)
        elseif alcoholCount >= 4 then
            TriggerEvent('evidence:client:SetStatus', 'heavyalcohol', 200)
        end
    end, function() -- Cancel
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end, getProgressIcon(itemName, 'beer.png'))
end)

RegisterNetEvent('consumables:client:Custom', function(itemName)
    QBCore.Functions.TriggerCallback('consumables:itemdata', function(data)
        QBCore.Functions.Progressbar('custom_consumable', data.progress.label, data.progress.time, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true
        }, {
            animDict = data.animation.animDict,
            anim = data.animation.anim,
            flags = data.animation.flags
        }, {
            model = data.prop.model,
            bone = data.prop.bone,
            coords = data.prop.coords,
            rotation = data.prop.rotation
        }, {}, function() -- Done
            ClearPedTasks(PlayerPedId())
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
            if data.replenish.type then
                TriggerServerEvent('consumables:server:add' .. data.replenish.type, QBCore.Functions.GetPlayerData().metadata[string.lower(data.replenish.type)] + data.replenish.replenish)
            end
            if data.replenish.isAlcohol then
                alcoholCount += 1
                AlcoholLoop()
                if alcoholCount > 1 and alcoholCount < 4 then
                    TriggerEvent('evidence:client:SetStatus', 'alcohol', 200)
                elseif alcoholCount >= 4 then
                    TriggerEvent('evidence:client:SetStatus', 'heavyalcohol', 200)
                end
            end
            if data.replenish.event then
                TriggerEvent(data.replenish.event)
            end
        end, nil, data.progress.icon or getProgressIcon(itemName))
    end, itemName)
end)

RegisterNetEvent('consumables:client:Cokebaggy', function()
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('snort_coke', Lang:t('consumables.coke_progress'), math.random(5000, 8000), false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'switch@trevor@trev_smoking_meth',
        anim = 'trev_smoking_meth_loop',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        TriggerServerEvent('consumables:server:useCokeBaggy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['cokebaggy'], 'remove')
        TriggerEvent('evidence:client:SetStatus', 'widepupils', 200)
        cokeBaggyEffect()
    end, function() -- Cancel
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end, getProgressIcon('cokebaggy', 'cocaine_baggy.png'))
end)

RegisterNetEvent('consumables:client:Crackbaggy', function()
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('snort_coke', Lang:t('consumables.crack_progress'), math.random(7000, 10000), false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'switch@trevor@trev_smoking_meth',
        anim = 'trev_smoking_meth_loop',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        TriggerServerEvent('consumables:server:useCrackBaggy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['crack_baggy'], 'remove')
        TriggerEvent('evidence:client:SetStatus', 'widepupils', 300)
        crackBaggyEffect()
    end, function() -- Cancel
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end, getProgressIcon('crack_baggy', 'crack_baggy.png'))
end)

RegisterNetEvent('consumables:client:EcstasyBaggy', function()
    QBCore.Functions.Progressbar('use_ecstasy', Lang:t('consumables.ecstasy_progress'), 3000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mp_suicide',
        anim = 'pill',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        TriggerServerEvent('consumables:server:useXTCBaggy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['xtcbaggy'], 'remove')
        ecstasyEffect()
    end, function() -- Cancel
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end, getProgressIcon('xtcbaggy', 'xtc_baggy.png'))
end)

RegisterNetEvent('consumables:client:oxy', function()
    QBCore.Functions.Progressbar('use_oxy', Lang:t('consumables.healing_progress'), 2000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mp_suicide',
        anim = 'pill',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        TriggerServerEvent('consumables:server:useOxy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['oxy'], 'remove')
        ClearPedBloodDamage(PlayerPedId())
        healOxy()
    end, function() -- Cancel
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end, getProgressIcon('oxy', 'oxy.png'))
end)

RegisterNetEvent('consumables:client:meth', function()
    QBCore.Functions.Progressbar('snort_meth', Lang:t('consumables.meth_progress'), 1500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'switch@trevor@trev_smoking_meth',
        anim = 'trev_smoking_meth_loop',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(PlayerPedId(), 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        TriggerServerEvent('consumables:server:useMeth')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['meth'], 'remove')
        TriggerEvent('evidence:client:SetStatus', 'widepupils', 300)
        TriggerEvent('evidence:client:SetStatus', 'agitated', 300)
        methBagEffect()
    end, function() -- Cancel
        StopAnimTask(PlayerPedId(), 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end, getProgressIcon('meth', 'meth_baggy.png'))
end)

RegisterNetEvent('consumables:client:UseJoint', function()
    QBCore.Functions.Progressbar('smoke_joint', Lang:t('consumables.joint_progress'), 1500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['joint'], 'remove')
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            QBCore.Functions.PlayAnim('timetable@gardener@smoking_joint', 'smoke_idle', false)
        else
            QBCore.Functions.PlayAnim('timetable@gardener@smoking_joint', 'smoke_idle', false)
        end
        TriggerEvent('evidence:client:SetStatus', 'weedsmell', 300)
        TriggerServerEvent('hud:server:RelieveStress', Config.RelieveWeedStress)
    end, nil, getProgressIcon('joint', 'joint.png'))
end)
local leanTripActive = false

local function StartLeanTrip()
    if leanTripActive then return end
    leanTripActive = true

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local spawnedEntities = {}

    StartScreenEffect("DrugsTrevorClownsFight", 60000, false)
    ShakeGameplayCam("DRUNK_SHAKE", 0.35)

    SetPedMotionBlur(ped, true)
    SetPedIsDrunk(ped, true)

    -- Alien hallucinations
    local alienModel = `s_m_m_movalien_01`
    RequestModel(alienModel)

    while not HasModelLoaded(alienModel) do
        Wait(10)
    end

    for i = 1, 5 do
        local offset = vector3(
            math.random(-18, 18),
            math.random(-18, 18),
            0.0
        )

        local spawnCoords = coords + offset

        local alien = CreatePed(
            4,
            alienModel,
            spawnCoords.x,
            spawnCoords.y,
            spawnCoords.z,
            math.random(0, 360),
            false,
            false
        )

        SetEntityAsMissionEntity(alien, true, true)
        SetBlockingOfNonTemporaryEvents(alien, true)

        TaskWanderStandard(alien, 10.0, 10)

        table.insert(spawnedEntities, alien)
    end

    -- Fake vehicles
    local vehicleModel = `blista`

    RequestModel(vehicleModel)

    while not HasModelLoaded(vehicleModel) do
        Wait(10)
    end

    for i = 1, 3 do
        local spawnCoords = coords + vector3(
            math.random(-25, 25),
            math.random(-25, 25),
            0.0
        )

        local veh = CreateVehicle(
            vehicleModel,
            spawnCoords.x,
            spawnCoords.y,
            spawnCoords.z,
            math.random(0, 360),
            false,
            false
        )

        SetEntityAsMissionEntity(veh, true, true)

        SetVehicleEngineOn(veh, true, true, false)

        SetVehicleForwardSpeed(veh, math.random(20, 40) + 0.0)

        ApplyForceToEntity(
            veh,
            1,
            math.random(-15, 15) + 0.0,
            math.random(-15, 15) + 0.0,
            5.0,
            0.0,
            0.0,
            0.0,
            0,
            false,
            true,
            true,
            false,
            true
        )

        table.insert(spawnedEntities, veh)
    end

    SetModelAsNoLongerNeeded(alienModel)
    SetModelAsNoLongerNeeded(vehicleModel)

    CreateThread(function()
        Wait(60000)

        StopScreenEffect("DrugsTrevorClownsFight")

        StopGameplayCamShaking(true)

        SetPedMotionBlur(PlayerPedId(), false)
        SetPedIsDrunk(PlayerPedId(), false)

        for _, entity in ipairs(spawnedEntities) do
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end

        leanTripActive = false
    end)
end

RegisterNetEvent('consumables:client:DrinkLean', function()
    local ped = PlayerPedId()

    -- CREATE CUP
    local prop = CreateObject(`prop_cs_paper_cup`, 0, 0, 0, true, true, true)

    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, 57005),
        0.12, 0.03, -0.04,
        -85.0, 160.0, 0.0,
        true, true, false, true, 1, true
    )

    QBCore.Functions.Progressbar(
        "drink_lean",
        "Drinking Lean...",
        5000,
        false,
        true,
        {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        },
        {
            animDict = "amb@world_human_drinking@coffee@male@idle_a",
            anim = "idle_c",
            flags = 49,
        },
        {},
        {},
        function() -- DONE

            -- DELETE CUP
            DeleteObject(prop)

            TriggerServerEvent('hud:server:RelieveStress', math.random(10, 20))

            QBCore.Functions.Notify("You feel strange...", "success")

            StartLeanTrip()
        end,
        function() -- CANCEL

            -- DELETE CUP
            DeleteObject(prop)

            QBCore.Functions.Notify("Cancelled", "error")
        end,
        getProgressIcon('lean', 'lean_cup.png')
    )
end)

RegisterNetEvent('consumables:client:UseParachute', function()
    equipParachuteAnim()
    QBCore.Functions.Progressbar('use_parachute', Lang:t('consumables.use_parachute_progress'), 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        local ped = PlayerPedId()
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['parachute'], 'remove')
        GiveWeaponToPed(ped, `GADGET_PARACHUTE`, 1, false, false)
        local parachuteData = {
            outfitData = { ['bag'] = { item = 7, texture = 0 } } -- Adding Parachute Clothing
        }
        TriggerEvent('qb-clothing:client:loadOutfit', parachuteData)
        parachuteEquipped = true
        TaskPlayAnim(ped, 'clothingshirt', 'exit', 8.0, 1.0, -1, 49, 0, false, false, false)
    end, nil, getProgressIcon('parachute', 'parachute.png'))
end)

RegisterNetEvent('consumables:client:ResetParachute', function()
    if parachuteEquipped then
        equipParachuteAnim()
        QBCore.Functions.Progressbar('reset_parachute', Lang:t('consumables.pack_parachute_progress'), 40000, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            local ped = PlayerPedId()
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['parachute'], 'add')
            local parachuteResetData = {
                outfitData = { ['bag'] = { item = 0, texture = 0 } } -- Removing Parachute Clothing
            }
            TriggerEvent('qb-clothing:client:loadOutfit', parachuteResetData)
            TaskPlayAnim(ped, 'clothingshirt', 'exit', 8.0, 1.0, -1, 49, 0, false, false, false)
            TriggerServerEvent('consumables:server:AddParachute')
            parachuteEquipped = false
        end, nil, getProgressIcon('parachute', 'parachute.png'))
    else
        QBCore.Functions.Notify(Lang:t('consumables.no_parachute'), 'error')
    end
end)

RegisterNetEvent('consumables:client:UseArmor', function(slot)
    QBCore.Functions.Progressbar('use_armor', Lang:t('consumables.armor_progress'), 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerServerEvent('consumables:server:useArmor', slot)
    end, nil, getProgressIcon('armor', 'armor.png'))
end)

RegisterNetEvent('consumables:client:UseHeavyArmor', function(slot)
    QBCore.Functions.Progressbar('use_heavyarmor', Lang:t('consumables.heavy_armor_progress'), 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerServerEvent('consumables:server:useHeavyArmor', slot)
    end, nil, getProgressIcon('heavyarmor', 'armor.png'))
end)

RegisterNetEvent('consumables:client:UseArmorPlate', function(slot)
    QBCore.Functions.Progressbar('use_armor_plate', Lang:t('consumables.armor_progress'), 3500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerServerEvent('consumables:server:useArmorPlate', slot)
    end, nil, getProgressIcon('armor_plate', 'armor.png'))
end)

RegisterNetEvent('consumables:client:ResetArmor', function()
    local ped = PlayerPedId()
    if currVest ~= nil and currVestTexture ~= nil then
        QBCore.Functions.Progressbar('remove_armor', Lang:t('consumables.remove_armor_progress'), 2500, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            SetPedComponentVariation(ped, 9, currVest, currVestTexture, 2)
            SetPedArmour(ped, 0)
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['heavyarmor'], 'add')
            TriggerServerEvent('consumables:server:resetArmor')
        end, nil, getProgressIcon('heavyarmor', 'armor.png'))
    else
        QBCore.Functions.Notify(Lang:t('consumables.armor_empty'), 'error')
    end
end)

-- RegisterNetEvent('consumables:client:UseRedSmoke', function()
--     if parachuteEquipped then
--         local ped = PlayerPedId()
--         SetPlayerParachuteSmokeTrailColor(ped, 255, 0, 0)
--         SetPlayerCanLeaveParachuteSmokeTrail(ped, true)
--         TriggerEvent("qb-inventory:client:ItemBox", QBCore.Shared.Items["smoketrailred"], "remove")
--     else
--         QBCore.Functions.Notify("You need to have a paracute to activate smoke!", "error")
--     end
-- end)

--Threads
local looped = false
function AlcoholLoop()
    if not looped then
        looped = true
        CreateThread(function()
            while true do
                Wait(10)
                if alcoholCount > 0 then
                    Wait(1000 * 60 * 15)
                    alcoholCount -= 1
                else
                    looped = false
                    break
                end
            end
        end)
    end
end
