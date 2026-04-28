local QBCore = exports['qb-core']:GetCoreObject()
local ResetStress = false

QBCore.Commands.Add('cash', 'Check Cash Balance', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    TriggerClientEvent('hud:client:ShowAccounts', source, 'cash', Player.PlayerData.money.cash)
end)

QBCore.Commands.Add('bank', 'Check Bank Balance', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    TriggerClientEvent('hud:client:ShowAccounts', source, 'bank', Player.PlayerData.money.bank)
end)

QBCore.Commands.Add('dev', 'Enable/Disable developer Mode', {}, false, function(source)
    TriggerClientEvent('qb-admin:client:ToggleDevmode', source)
end, 'admin')

local function isStressImmune(Player)
    if not Config.EnableStressWhitelist then
        return false
    end

    local job = Player.PlayerData.job or {}
    return Config.WhitelistedJobs[job.name] or Config.WhitelistedJobs[job.type]
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or 0
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function getStress(Player)
    local metadata = Player.PlayerData.metadata or {}
    return clamp(metadata.stress or 0, 0, 100)
end

local function setStress(src, Player, newStress)
    newStress = clamp(newStress, 0, 100)
    Player.Functions.SetMetaData('stress', newStress)
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)
    return newStress
end

local function notifyStress(src, message, notifyType)
    if Config.NotifyStress then
        TriggerClientEvent('hud:client:StressNotify', src, message, notifyType or 'primary', 1500)
    end
end

local function handleGainStress(src, amount)
    if Config.DisableStress then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or isStressImmune(Player) then return end

    amount = clamp(amount, 0, 100)
    if amount <= 0 then return end

    local newStress = ResetStress and 0 or getStress(Player) + amount
    setStress(src, Player, newStress)
    notifyStress(src, 'Stress increased', 'error')
end

local function handleRelieveStress(src, amount)
    if Config.DisableStress then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = clamp(amount, 0, 100)
    if amount <= 0 then return end

    local newStress = ResetStress and 0 or getStress(Player) - amount
    setStress(src, Player, newStress)
    notifyStress(src, 'Stress relieved', 'success')
end

RegisterNetEvent('hud:server:GainStress', function(amount)
    handleGainStress(source, amount)
end)

RegisterNetEvent('prp-hud:server:GainStress', function(amount)
    handleGainStress(source, amount)
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    handleRelieveStress(source, amount)
end)

RegisterNetEvent('prp-hud:server:RelieveStress', function(amount)
    handleRelieveStress(source, amount)
end)

QBCore.Commands.Add('stresshud', 'Set your stress for HUD testing', {
    { name = 'amount', help = 'Stress amount 0-100' },
}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local newStress = setStress(source, Player, args[1] or 0)
    notifyStress(source, ('Stress set to %d'):format(newStress), 'primary')
end, 'admin')
