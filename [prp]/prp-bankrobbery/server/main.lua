local QBCore = exports['qb-core']:GetCoreObject()

local State = {
    vaultOpen = false,
    barOpen = false,
    drilled = {},
    nextHack = 0,
}

local ResetActive = false

local function Notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

local function HasItem(src, item)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local found = Player.Functions.GetItemByName(item)
    return found and found.amount and found.amount > 0
end

local function RemoveItem(src, item, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.Functions.RemoveItem(item, amount or 1) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove')
    end
end

local function AddItem(src, item, amount, info)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.Functions.AddItem(item, amount or 1, false, info or {}) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
    else
        Notify(src, 'Your pockets are too full.', 'error')
    end
end

local function CountPolice()
    local count = 0
    for _, src in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.job and Config.PoliceJobs[Player.PlayerData.job.name] and Player.PlayerData.job.onduty then
            count = count + 1
        end
    end
    return count
end

local function PoliceAlert(alertType)
    if not Config.Alert.Enabled then return end

    local message = Config.Alert.HackFailMessage
    if alertType == 'hack_success' then message = Config.Alert.HackSuccessMessage end
    if alertType == 'lockpick' then message = Config.Alert.LockpickMessage end
    if alertType == 'drill' then message = Config.Alert.DrillMessage end

    TriggerEvent(Config.Alert.DispatchEvent, message)
end

local function SyncAll()
    TriggerClientEvent('prp-bankrobbery:client:SyncState', -1, State)
end

local function ResetBank()
    State.vaultOpen = false
    State.barOpen = false
    State.drilled = {}
    ResetActive = false
    TriggerClientEvent('prp-bankrobbery:client:SetDoor', -1, 'vault', false)
    TriggerClientEvent('prp-bankrobbery:client:SetDoor', -1, 'bar', false)
    SyncAll()
end

local function StartResetTimer()
    if ResetActive then return end
    ResetActive = true
    SetTimeout(Config.Timers.DoorReset * 1000, function()
        ResetBank()
    end)
end

QBCore.Functions.CreateCallback('prp-bankrobbery:server:HasItem', function(source, cb, item)
    cb(HasItem(source, item))
end)

QBCore.Functions.CreateCallback('prp-bankrobbery:server:CanHack', function(source, cb)
    if CountPolice() < Config.RequiredPolice then
        cb(false, ('Not enough police. Required: %s'):format(Config.RequiredPolice))
        return
    end

    if State.vaultOpen then
        cb(false, 'The vault is already open.')
        return
    end

    local now = os.time()
    if State.nextHack > now then
        cb(false, ('The keypad is locked out. Wait %s seconds.'):format(State.nextHack - now))
        return
    end

    cb(true)
end)

RegisterNetEvent('prp-bankrobbery:server:RequestState', function()
    TriggerClientEvent('prp-bankrobbery:client:SyncState', source, State)
end)

RegisterNetEvent('prp-bankrobbery:server:PoliceAlert', function(alertType)
    PoliceAlert(alertType)
end)

RegisterNetEvent('prp-bankrobbery:server:VaultHackResult', function(success)
    local src = source
    if not HasItem(src, Config.Items.GateCrack) then
        Notify(src, ('You need a %s.'):format(Config.Items.GateCrack), 'error')
        return
    end

    if Config.Consume.GateCrackOnUse then
        RemoveItem(src, Config.Items.GateCrack, 1)
    end

    if success then
        State.vaultOpen = true
        State.nextHack = 0
        PoliceAlert('hack_success')
        TriggerClientEvent('prp-bankrobbery:client:SetDoor', -1, 'vault', true)
        SyncAll()
        StartResetTimer()
        Notify(src, 'Vault keypad bypassed. Door opening.', 'success')
    else
        State.nextHack = os.time() + Config.Timers.FailedHackCooldown
        PoliceAlert('hack_fail')
        Notify(src, ('Hack failed. The keypad is locked for %s seconds.'):format(Config.Timers.FailedHackCooldown), 'error')
    end
end)

RegisterNetEvent('prp-bankrobbery:server:BarLockpickResult', function(success)
    local src = source
    if not State.vaultOpen then
        Notify(src, 'The vault is not open.', 'error')
        return
    end

    if not HasItem(src, Config.Items.Lockpick) then
        Notify(src, ('You need a %s.'):format(Config.Items.Lockpick), 'error')
        return
    end

    if success then
        State.barOpen = true
        TriggerClientEvent('prp-bankrobbery:client:SetDoor', -1, 'bar', true)
        SyncAll()
        Notify(src, 'Security gate unlocked.', 'success')
    else
        if math.random(1, 100) <= Config.Consume.LockpickBreakChance then
            RemoveItem(src, Config.Items.Lockpick, 1)
            Notify(src, 'Your lockpick snapped.', 'error')
        else
            Notify(src, 'Lockpick failed.', 'error')
        end
    end
end)

RegisterNetEvent('prp-bankrobbery:server:DrillResult', function(spotId, success)
    local src = source
    local id = tostring(spotId)

    if not State.vaultOpen or not State.barOpen then
        Notify(src, 'You are not inside the loot room.', 'error')
        return
    end

    if State.drilled[id] then
        Notify(src, 'This deposit box has already been drilled.', 'error')
        return
    end

    if not HasItem(src, Config.Items.Drill) then
        Notify(src, ('You need a %s.'):format(Config.Items.Drill), 'error')
        return
    end

    if Config.Consume.DrillOnUse then
        RemoveItem(src, Config.Items.Drill, 1)
    end

    if not success then
        Notify(src, 'The drill slipped and failed.', 'error')
        return
    end

    State.drilled[id] = true
    SyncAll()

    local gotSomething = false
    for _, reward in pairs(Config.Rewards) do
        if math.random(1, 100) <= reward.chance then
            local amount = math.random(reward.min or 1, reward.max or 1)
            local info = {}
            if reward.item == 'markedbills' then
                info.worth = math.random(reward.worthMin or 500, reward.worthMax or 1500)
            end
            AddItem(src, reward.item, amount, info)
            gotSomething = true
        end
    end

    if gotSomething then
        Notify(src, 'You pulled valuables from the deposit box.', 'success')
    else
        Notify(src, 'This box was empty.', 'error')
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetTimeout(1500, function()
        SyncAll()
    end)
end)
