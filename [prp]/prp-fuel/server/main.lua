local QBCore = exports[Config.CoreName]:GetCoreObject()

local function ClampFuel(fuel)
    fuel = tonumber(fuel) or Config.DefaultFuel
    if fuel < 0.0 then return 0.0 end
    if fuel > Config.MaxFuel then return Config.MaxFuel end
    return fuel + 0.0
end

QBCore.Functions.CreateCallback('prp-fuel:server:canPay', function(source, cb, amount, paymentType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    amount = math.floor(tonumber(amount) or 0)
    paymentType = paymentType == 'bank' and 'bank' or 'cash'

    cb((Player.PlayerData.money[paymentType] or 0) >= amount)
end)

RegisterNetEvent('prp-fuel:server:payFuel', function(amount, paymentType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    paymentType = paymentType == 'bank' and 'bank' or 'cash'

    if (Player.PlayerData.money[paymentType] or 0) >= amount then
        Player.Functions.RemoveMoney(paymentType, amount, 'prp-fuel-refuel')
    end
end)

RegisterNetEvent('prp-fuel:server:setFuelState', function(netId, fuel)
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 or not DoesEntityExist(entity) then return end

    Entity(entity).state:set(Config.FuelStateName, ClampFuel(fuel), true)
end)
