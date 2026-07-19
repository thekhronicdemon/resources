local QBCore = exports['qb-core']:GetCoreObject()
local databaseReady = false
local runtimeAirbagStates = {}

local function trimPlate(plate)
    return string.upper((plate or ''):gsub('^%s*(.-)%s*$', '%1'))
end

local function notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind or 'primary')
end

local function isMechanic(Player)
    if not Player then return false end
    local job = Player.PlayerData.job
    local minGrade = job and Config.MechanicJobs[job.name]
    local grade = job and job.grade
    local level = type(grade) == 'table' and (grade.level or grade.grade or 0) or tonumber(grade) or 0
    return minGrade ~= nil and level >= minGrade
end

local function clamp(value, min, max)
    value = tonumber(value) or 0.0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function databaseBoolean(value)
    if value == true then return true end
    if value == false or value == nil then return false end

    local valueType = type(value)
    if valueType == 'number' then return value == 1 end
    if valueType == 'string' then
        value = value:lower()
        return value == '1' or value == 'true' or value == 'yes' or value == 'on'
    end

    return false
end

local function sanitiseStance(input)
    input = type(input) == 'table' and input or {}
    local output = {}
    for key, default in pairs(Config.Defaults) do
        local limit = Config.Limits[key]
        local value = tonumber(input[key])
        -- v2.1 stored wheel width as an absolute value (normally 1.0). Convert it to a safe adjustment.
        if key == 'wheelWidth' and value and value >= 0.50 then value = 0.0 end
        output[key] = limit and clamp(value ~= nil and value or default, limit.min, limit.max) or default
    end
    return output
end

local function setupDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `prp_vehicle_upgrades` (
          `plate` varchar(20) NOT NULL,
          `airbags` tinyint(1) NOT NULL DEFAULT 0,
          `stancer` tinyint(1) NOT NULL DEFAULT 0,
          `hydraulics` tinyint(1) NOT NULL DEFAULT 0,
          `airbags_down` tinyint(1) NOT NULL DEFAULT 0,
          `stance_data` longtext DEFAULT NULL,
          `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    local columns = MySQL.query.await('SHOW COLUMNS FROM `prp_vehicle_upgrades`') or {}
    local found = {}
    for _, column in ipairs(columns) do found[column.Field] = true end
    if not found.airbags then
        MySQL.query.await('ALTER TABLE `prp_vehicle_upgrades` ADD COLUMN `airbags` tinyint(1) NOT NULL DEFAULT 0 AFTER `plate`')
    end
    if not found.stancer then
        MySQL.query.await('ALTER TABLE `prp_vehicle_upgrades` ADD COLUMN `stancer` tinyint(1) NOT NULL DEFAULT 0 AFTER `airbags`')
    end
    if not found.hydraulics then
        MySQL.query.await('ALTER TABLE `prp_vehicle_upgrades` ADD COLUMN `hydraulics` tinyint(1) NOT NULL DEFAULT 0 AFTER `stancer`')
    end
    if not found.airbags_down then
        MySQL.query.await('ALTER TABLE `prp_vehicle_upgrades` ADD COLUMN `airbags_down` tinyint(1) NOT NULL DEFAULT 0 AFTER `hydraulics`')
    end
    if not found.stance_data then
        MySQL.query.await('ALTER TABLE `prp_vehicle_upgrades` ADD COLUMN `stance_data` longtext DEFAULT NULL AFTER `airbags_down`')
    end
    databaseReady = true
    print('[prp-mechanic-tablet] Database ready and usable items registered.')
end

CreateThread(function()
    local ok, err = pcall(setupDatabase)
    if not ok then
        print(('[prp-mechanic-tablet] DATABASE ERROR: %s'):format(err))
    end
end)

local function ensureVehicleRow(plate)
    if not databaseReady then return false end
    MySQL.insert.await([[
        INSERT IGNORE INTO prp_vehicle_upgrades
        (plate, airbags, stancer, hydraulics, airbags_down, stance_data)
        VALUES (?, 0, 0, 0, 0, ?)
    ]], { plate, json.encode(Config.Defaults) })
    return true
end

local function getVehicleData(plate)
    plate = trimPlate(plate)
    if plate == '' or not ensureVehicleRow(plate) then return nil end
    local row = MySQL.single.await('SELECT * FROM prp_vehicle_upgrades WHERE plate = ?', { plate })
    if not row then return nil end
    row.airbags = databaseBoolean(row.airbags)
    row.stancer = databaseBoolean(row.stancer)
    row.hydraulics = databaseBoolean(row.hydraulics)
    row.airbags_down = databaseBoolean(row.airbags_down)
    if runtimeAirbagStates[plate] ~= nil then
        row.airbags_down = runtimeAirbagStates[plate]
    end
    local decoded = {}
    if row.stance_data and row.stance_data ~= '' then
        local ok, value = pcall(json.decode, row.stance_data)
        if ok and type(value) == 'table' then decoded = value end
    end
    row.stance_data = sanitiseStance(decoded)
    return row
end

local function broadcastVehicle(plate)
    local data = getVehicleData(plate)
    if data then TriggerClientEvent('prp-mechanic-tablet:client:applyVehicleData', -1, plate, data) end
end

QBCore.Functions.CreateCallback('prp-mechanic-tablet:server:getVehicleData', function(src, cb, plate)
    if not databaseReady then
        notify(src, 'Mechanic tablet database is not ready. Check the server console.', 'error')
        cb(nil)
        return
    end
    local ok, data = pcall(getVehicleData, plate)
    if not ok then
        print(('[prp-mechanic-tablet] getVehicleData error: %s'):format(data))
        notify(src, 'Could not load vehicle upgrades. Check the server console.', 'error')
        cb(nil)
        return
    end
    cb(data)
end)

QBCore.Functions.CreateCallback('prp-mechanic-tablet:server:installUpgrade', function(src, cb, plate, upgrade, itemName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ ok = false, message = 'Player could not be loaded.' }) return end
    if not databaseReady then cb({ ok = false, message = 'Upgrade database is not ready.' }) return end
    if Config.RequireMechanicForInstall and not isMechanic(Player) then
        cb({ ok = false, message = 'You must be a mechanic to install this upgrade.' })
        return
    end

    local valid = {
        airbags = Config.Items.Airbags,
        stancer = Config.Items.Stancer,
        hydraulics = Config.Items.Hydraulics
    }
    if valid[upgrade] ~= itemName then
        cb({ ok = false, message = 'Invalid upgrade item.' })
        return
    end

    plate = trimPlate(plate)
    if plate == '' then cb({ ok = false, message = 'Vehicle plate could not be read.' }) return end

    local item = Player.Functions.GetItemByName(itemName)
    if not item or (item.amount or 0) < 1 then
        cb({ ok = false, message = 'Required upgrade item not found.' })
        return
    end

    local data = getVehicleData(plate)
    if not data then cb({ ok = false, message = 'Could not create the vehicle upgrade record.' }) return end
    if data[upgrade] then
        cb({ ok = false, alreadyInstalled = true, message = 'This upgrade is already installed on this vehicle.', data = data })
        return
    end

    local queries = {
        airbags = 'UPDATE prp_vehicle_upgrades SET airbags = 1 WHERE plate = ?',
        stancer = 'UPDATE prp_vehicle_upgrades SET stancer = 1 WHERE plate = ?',
        hydraulics = 'UPDATE prp_vehicle_upgrades SET hydraulics = 1 WHERE plate = ?'
    }

    local affected = MySQL.update.await(queries[upgrade], { plate })
    if affected == nil then
        print(('[prp-mechanic-tablet] Failed database update: plate=%s upgrade=%s affected=nil'):format(plate, upgrade))
        cb({ ok = false, message = 'The upgrade could not be saved to the database.' })
        return
    end

    -- oxmysql may return 0 when the column was already 1. Always verify the stored row.
    local saved = getVehicleData(plate)
    if not saved or saved[upgrade] ~= true then
        print(('[prp-mechanic-tablet] Upgrade verification failed: plate=%s upgrade=%s row=%s'):format(plate, upgrade, json.encode(saved or {})))
        cb({ ok = false, message = 'Database verification failed; the item was not consumed.' })
        return
    end

    if not Player.Functions.RemoveItem(itemName, 1) then
        MySQL.update.await(('UPDATE prp_vehicle_upgrades SET `%s` = 0 WHERE plate = ?'):format(upgrade), { plate })
        cb({ ok = false, message = 'Could not remove the item; installation was rolled back.' })
        return
    end

    local sharedItem = QBCore.Shared.Items[itemName]
    if sharedItem then TriggerClientEvent('inventory:client:ItemBox', src, sharedItem, 'remove') end

    broadcastVehicle(plate)
    cb({ ok = true, message = (upgrade:gsub('^%l', string.upper) .. ' installed successfully.'), data = saved })
end)

RegisterNetEvent('prp-mechanic-tablet:server:debugVehicle', function(plate)
    local src = source
    local data = getVehicleData(plate)
    print(('[prp-mechanic-tablet] DEBUG plate=%s data=%s'):format(trimPlate(plate), json.encode(data or {})))
    TriggerClientEvent('prp-mechanic-tablet:client:debugVehicleResult', src, data)
end)

RegisterNetEvent('prp-mechanic-tablet:server:saveStance', function(plate, stanceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not databaseReady then return end
    if Config.RequireMechanicForTablet and not isMechanic(Player) then return end
    plate = trimPlate(plate)
    local data = getVehicleData(plate)
    if not data or not data.stancer then notify(src, 'This vehicle does not have a stancer kit installed.', 'error') return end
    MySQL.update.await('UPDATE prp_vehicle_upgrades SET stance_data = ? WHERE plate = ?', { json.encode(sanitiseStance(stanceData)), plate })
    broadcastVehicle(plate)
end)

RegisterNetEvent('prp-mechanic-tablet:server:toggleAirbagsState', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not databaseReady then return end
    if Config.RequireMechanicForTablet and not isMechanic(Player) then return end
    plate = trimPlate(plate)
    local data = getVehicleData(plate)
    if not data or not data.airbags then notify(src, 'This vehicle does not have airbags installed.', 'error') return end
    local down = not data.airbags_down
    runtimeAirbagStates[plate] = down
    MySQL.update.await('UPDATE prp_vehicle_upgrades SET airbags_down = ? WHERE plate = ?', { down and 1 or 0, plate })
    broadcastVehicle(plate)
end)

RegisterNetEvent('prp-mechanic-tablet:server:setAirbagsState', function(plate, down)
    if not databaseReady then return end
    plate = trimPlate(plate)
    if plate == '' then return end
    local data = getVehicleData(plate)
    if not data or not data.airbags then return end
    runtimeAirbagStates[plate] = down == true
    broadcastVehicle(plate)
end)

local function registerUsable(itemName)
    QBCore.Functions.CreateUseableItem(itemName, function(source)
        TriggerClientEvent('prp-mechanic-tablet:client:useItem', source, itemName)
    end)
end

registerUsable(Config.Items.Tablet)
registerUsable(Config.Items.Airbags)
registerUsable(Config.Items.Stancer)
registerUsable(Config.Items.Hydraulics)
