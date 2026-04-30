local QBCore = exports[Config.Core]:GetCoreObject()

local function IsMechanicJob(job)
    return job and job.name and Config.Mechanic.JobNames[job.name] == true
end

local function IsPlayerOnDutyMechanic(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return false end

    local job = Player.PlayerData.job
    if not IsMechanicJob(job) then return false end
    if Config.Mechanic.RequireOnDuty and not job.onduty then return false end

    return true
end

local function IsMechanicOnline(ignoreSource)
    if not Config.Mechanic.Enabled then return false end

    local players = QBCore.Functions.GetPlayers()
    for _, src in pairs(players) do
        if not ignoreSource or tonumber(src) ~= tonumber(ignoreSource) then
            local Player = QBCore.Functions.GetPlayer(src)
            if IsPlayerOnDutyMechanic(Player) then
                return true
            end
        end
    end

    return false
end

QBCore.Functions.CreateCallback('prp-repairStore:server:canUseStore', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local isMechanic = IsPlayerOnDutyMechanic(Player)

    -- On-duty mechanics are allowed to use the store, but client restricts them to cosmetics/liveries.
    if isMechanic then
        cb(true, nil, {
            isMechanic = true,
            discountPercent = Config.Payment.MechanicDiscountPercent or 75,
            allowedModes = {
                repair = false,
                customize = true,
                livery = true,
                engine = false
            }
        })
        return
    end

    -- Civilians are blocked if any on-duty mechanic is online.
    if IsMechanicOnline(source) then
        cb(false, Config.Mechanic.BlockMessage)
        return
    end

    cb(true, nil, {
        isMechanic = false,
        discountPercent = 0,
        allowedModes = {
            repair = true,
            customize = true,
            livery = true,
            engine = true
        }
    })
end)

QBCore.Functions.CreateCallback('prp-repairStore:server:pay', function(source, cb, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    amount = tonumber(amount) or 0

    if amount <= 0 then
        cb(true)
        return
    end

    if not Player then
        cb(false, 'Player not found.')
        return
    end

    local account = Config.Payment.Account or 'cash'
    local money = Player.PlayerData.money[account] or 0

    if money < amount then
        cb(false, ('Not enough %s. Need $%s.'):format(account, amount))
        return
    end

    Player.Functions.RemoveMoney(account, amount, 'prp-repair-store')
    cb(true)
end)


QBCore.Functions.CreateCallback('prp-repairStore:server:payPurchase', function(source, cb, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    amount = tonumber(amount) or 0

    local finalAmount = amount
    if IsPlayerOnDutyMechanic(Player) then
        local discount = tonumber(Config.Payment.MechanicDiscountPercent) or 75
        finalAmount = math.floor(amount * ((100 - discount) / 100))
    end

    if finalAmount <= 0 then
        cb(true, 0)
        return
    end

    if not Player then
        cb(false, 'Player not found.')
        return
    end

    local account = Config.Payment.Account or 'cash'
    local money = Player.PlayerData.money[account] or 0

    if money < finalAmount then
        cb(false, ('Not enough %s. Need $%s.'):format(account, finalAmount))
        return
    end

    Player.Functions.RemoveMoney(account, finalAmount, 'prp-repair-store-purchase')
    cb(true, finalAmount)
end)

RegisterNetEvent('prp-repairStore:server:saveMods', function(plate, props)
    if not Config.SaveOwnedVehicleMods then return end
    if not plate or type(props) ~= 'table' then return end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    -- We allow stolen/unowned vehicles to be modified, but only owned vehicles should save.
    -- If oxmysql/MySQL is not running, skip saving without crashing the server.
    if not MySQL or not MySQL.query or not MySQL.update then
        if Config.Debug then
            print('^3[prp-repairStore]^7 MySQL not found. Skipping mod save.')
        end
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if not citizenid then return end

    plate = string.upper((plate:gsub('%s+', '')))
    local jsonProps = json.encode(props)

    local ownershipQuery = ('SELECT `%s` FROM `%s` WHERE `citizenid` = ? AND REPLACE(UPPER(`%s`), " ", "") = ? LIMIT 1'):format(
        Config.PlayerVehiclesPlateColumn,
        Config.PlayerVehiclesTable,
        Config.PlayerVehiclesPlateColumn
    )

    MySQL.query(ownershipQuery, { citizenid, plate }, function(result)
        if not result or not result[1] then
            -- Not owned by this player. Mods still apply until the vehicle despawns/restarts.
            if Config.Debug then
                print(('[prp-repairStore] Skipped save. Vehicle not owned by %s: %s'):format(citizenid, plate))
            end
            return
        end

        local updateQuery = ('UPDATE `%s` SET `%s` = ? WHERE `citizenid` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
            Config.PlayerVehiclesTable,
            Config.PlayerVehiclesModsColumn,
            Config.PlayerVehiclesPlateColumn
        )

        MySQL.update(updateQuery, { jsonProps, citizenid, plate }, function(affectedRows)
            if Config.Debug then
                print(('[prp-repairStore] Saved mods for owned vehicle %s. Rows affected: %s'):format(plate, affectedRows or 0))
            end
        end)
    end)
end)
