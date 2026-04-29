local QBCore = exports['qb-core']:GetCoreObject()

local DoorState = {
    vaultOpen = false,
    barOpen = false,
    drilled = {},
}

local function DebugPrint(msg)
    if Config.Debug then print(('[prp-bankrobbery] %s'):format(msg)) end
end

local function Notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function PlayAnim(dict, anim, flag)
    LoadAnimDict(dict)
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, -1, flag or 49, 0, false, false, false)
end

local function Progress(label, time, animDict, animName, cb)
    if animDict and animName then PlayAnim(animDict, animName, 49) end
    QBCore.Functions.Progressbar('prp_bank_action', label, time, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(PlayerPedId())
        cb(true)
    end, function()
        ClearPedTasks(PlayerPedId())
        cb(false)
    end)
end

local function HasItem(item, cb)
    QBCore.Functions.TriggerCallback('prp-bankrobbery:server:HasItem', function(has)
        cb(has)
    end, item)
end

local nuiBusy = false
local nuiCallback = nil

local function StartBuiltInMinigame(gameType, opts, cb)
    if nuiBusy then
        Notify('You are already doing something.', 'error')
        cb(false)
        return
    end

    nuiBusy = true
    nuiCallback = cb
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMinigame',
        game = gameType,
        opts = opts or {}
    })
end

RegisterNUICallback('minigameComplete', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })

    local callback = nuiCallback
    nuiBusy = false
    nuiCallback = nil

    if callback then
        callback(data and data.success == true)
    end

    cb('ok')
end)

RegisterNUICallback('minigameCancel', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })

    local callback = nuiCallback
    nuiBusy = false
    nuiCallback = nil

    if callback then
        callback(false)
    end

    cb('ok')
end)

local function RunHackMinigame(cb)
    StartBuiltInMinigame('keypad', {
        title = 'Gatecrack Keypad Bypass',
        subtitle = 'Repeat the access sequence before the trace completes.',
        rounds = 4,
        showTime = 1100,
        inputTime = 9000,
        sequenceMin = 2,
        sequenceMax = 4,
    }, cb)
end

local function RunLockpickMinigame(cb)
    StartBuiltInMinigame('lockpick', {
        title = 'Security Gate Lockpick',
        subtitle = 'Stop the pin inside the green zone.',
        rounds = 3,
        speed = 1.35,
        zoneSize = 16,
    }, cb)
end

local function RunDrillMinigame(cb)
    StartBuiltInMinigame('drill', {
        title = 'Deposit Box Drill',
        subtitle = 'Keep pressure steady. Too much heat will fail the drill.',
        duration = 14000,
        heatGain = 0.82,
        coolRate = 0.48,
        progressGain = 0.24,
    }, cb)
end

local function GetDoorObject(door)
    return GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 2.0, door.model, false, false, false)
end

local function SetDoor(door, open)
    local obj = GetDoorObject(door)
    if not obj or obj == 0 then
        DebugPrint(('Door object missing: %s'):format(door.id))
        return
    end

    FreezeEntityPosition(obj, true)
    local targetHeading = open and door.openHeading or door.lockedHeading
    local current = GetEntityHeading(obj)

    for i = 1, 45 do
        current = current + ((targetHeading - current) * 0.18)
        SetEntityHeading(obj, current)
        Wait(10)
    end

    SetEntityHeading(obj, targetHeading)
    FreezeEntityPosition(obj, true)
end

local function RefreshDoors()
    SetDoor(Config.Doors.Vault, DoorState.vaultOpen)
    SetDoor(Config.Doors.Bar, DoorState.barOpen)
end

RegisterNetEvent('prp-bankrobbery:client:SyncState', function(state)
    DoorState.vaultOpen = state.vaultOpen or false
    DoorState.barOpen = state.barOpen or false
    DoorState.drilled = state.drilled or {}
    RefreshDoors()
end)

RegisterNetEvent('prp-bankrobbery:client:SetDoor', function(doorName, open)
    if doorName == 'vault' then
        DoorState.vaultOpen = open
        SetDoor(Config.Doors.Vault, open)
    elseif doorName == 'bar' then
        DoorState.barOpen = open
        SetDoor(Config.Doors.Bar, open)
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('prp-bankrobbery:server:RequestState')

    exports[Config.Target]:AddBoxZone('prp_bank_vault_keypad', Config.Doors.Vault.coords, 1.0, 1.0, {
        name = 'prp_bank_vault_keypad',
        heading = Config.Doors.Vault.lockedHeading,
        debugPoly = Config.Debug,
        minZ = Config.Doors.Vault.coords.z - 1.0,
        maxZ = Config.Doors.Vault.coords.z + 1.0,
    }, {
        options = {
            {
                icon = 'fas fa-keyboard',
                label = Config.Text.HackDoor,
                action = function()
                    TriggerEvent('prp-bankrobbery:client:HackVault')
                end,
                canInteract = function()
                    return not DoorState.vaultOpen
                end,
            }
        },
        distance = Config.Doors.Vault.interactDistance
    })

    exports[Config.Target]:AddBoxZone('prp_bank_bar_gate', Config.Doors.Bar.coords, 1.0, 1.0, {
        name = 'prp_bank_bar_gate',
        heading = Config.Doors.Bar.lockedHeading,
        debugPoly = Config.Debug,
        minZ = Config.Doors.Bar.coords.z - 1.0,
        maxZ = Config.Doors.Bar.coords.z + 1.0,
    }, {
        options = {
            {
                icon = 'fas fa-screwdriver',
                label = Config.Text.LockpickDoor,
                action = function()
                    TriggerEvent('prp-bankrobbery:client:LockpickBar')
                end,
                canInteract = function()
                    return DoorState.vaultOpen and not DoorState.barOpen
                end,
            }
        },
        distance = Config.Doors.Bar.interactDistance
    })

    for _, spot in pairs(Config.DrillSpots) do
        exports[Config.Target]:AddBoxZone(('prp_bank_drill_%s'):format(spot.id), spot.coords, 0.8, 0.8, {
            name = ('prp_bank_drill_%s'):format(spot.id),
            heading = spot.heading,
            debugPoly = Config.Debug,
            minZ = spot.coords.z - 1.0,
            maxZ = spot.coords.z + 1.0,
        }, {
            options = {
                {
                    icon = 'fas fa-bore-hole',
                    label = Config.Text.DrillBox,
                    action = function()
                        TriggerEvent('prp-bankrobbery:client:DrillSpot', spot.id)
                    end,
                    canInteract = function()
                        return DoorState.vaultOpen and DoorState.barOpen and not DoorState.drilled[tostring(spot.id)]
                    end,
                }
            },
            distance = 1.5
        })
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        RefreshDoors()
    end
end)

RegisterNetEvent('prp-bankrobbery:client:HackVault', function()
    if DoorState.vaultOpen then Notify('The vault door is already open.', 'error') return end

    HasItem(Config.Items.GateCrack, function(has)
        if not has then Notify(('You need a %s.'):format(Config.Items.GateCrack), 'error') return end

        QBCore.Functions.TriggerCallback('prp-bankrobbery:server:CanHack', function(canHack, reason)
            if not canHack then Notify(reason or 'You cannot do this right now.', 'error') return end

            Progress('Placing gatecrack device...', 3500, 'anim@heists@ornate_bank@hack', 'hack_enter', function(done)
                if not done then return end
                RunHackMinigame(function(success)
                    TriggerServerEvent('prp-bankrobbery:server:VaultHackResult', success)
                end)
            end)
        end)
    end)
end)

RegisterNetEvent('prp-bankrobbery:client:LockpickBar', function()
    if not DoorState.vaultOpen then Notify('The vault door needs to be opened first.', 'error') return end
    if DoorState.barOpen then Notify('The security gate is already open.', 'error') return end

    HasItem(Config.Items.Lockpick, function(has)
        if not has then Notify(('You need a %s.'):format(Config.Items.Lockpick), 'error') return end

        TriggerServerEvent('prp-bankrobbery:server:PoliceAlert', 'lockpick')
        PlayAnim('veh@break_in@0h@p_m_one@', 'low_force_entry_ds', 49)
        RunLockpickMinigame(function(success)
            ClearPedTasks(PlayerPedId())
            TriggerServerEvent('prp-bankrobbery:server:BarLockpickResult', success)
        end)
    end)
end)

RegisterNetEvent('prp-bankrobbery:client:DrillSpot', function(spotId)
    if not DoorState.vaultOpen or not DoorState.barOpen then Notify('You need to get inside the loot room first.', 'error') return end
    if DoorState.drilled[tostring(spotId)] then Notify('This deposit box has already been drilled.', 'error') return end

    HasItem(Config.Items.Drill, function(has)
        if not has then Notify(('You need a %s.'):format(Config.Items.Drill), 'error') return end

        TriggerServerEvent('prp-bankrobbery:server:PoliceAlert', 'drill')
        RunDrillMinigame(function(success)
            TriggerServerEvent('prp-bankrobbery:server:DrillResult', spotId, success)
        end)
    end)
end)
