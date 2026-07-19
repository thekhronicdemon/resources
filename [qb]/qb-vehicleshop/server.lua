local QBCore = exports['qb-core']:GetCoreObject()
local financetimer = {}
local stockTableReady = false

local stockTableSql = [[
    CREATE TABLE IF NOT EXISTS `prp_pdm_stock` (
        `shop` varchar(50) NOT NULL,
        `vehicle` varchar(50) NOT NULL,
        `stock` int(11) NOT NULL DEFAULT 0,
        `price` int(11) NOT NULL DEFAULT 0,
        `enabled` tinyint(1) NOT NULL DEFAULT 1,
        PRIMARY KEY (`shop`, `vehicle`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local vehicleTypes = {
    motorcycles = 'bike',
    boats = 'boat',
    helicopters = 'heli',
    planes = 'plane',
    submarines = 'submarine',
    trailer = 'trailer',
    train = 'train'
}

local function RefreshCoreObject()
    QBCore = exports['qb-core']:GetCoreObject()
    return QBCore
end

local function HasEntries(tbl)
    return type(tbl) == 'table' and next(tbl) ~= nil
end

local function CountEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local parsedSharedVehicles = nil

local function GetQuotedField(entry, field)
    return entry:match(field .. "%s*=%s*'([^']*)'") or entry:match(field .. '%s*=%s*"([^"]*)"')
end

local function GetShopField(entry)
    local shopList = entry:match('shop%s*=%s*{(.-)}')
    if shopList then
        local shops = {}
        for shop in shopList:gmatch("'([^']+)'") do
            shops[#shops + 1] = shop
        end
        for shop in shopList:gmatch('"([^"]+)"') do
            shops[#shops + 1] = shop
        end
        if #shops > 0 then return shops end
    end

    return GetQuotedField(entry, 'shop')
end

local function LoadSharedVehiclesFromFile()
    if parsedSharedVehicles then return parsedSharedVehicles end

    parsedSharedVehicles = {}
    local content = LoadResourceFile('qb-core', 'shared/vehicles.lua')
    if type(content) ~= 'string' then
        print('[qb-vehicleshop] Could not read qb-core/shared/vehicles.lua fallback.')
        return parsedSharedVehicles
    end

    local entry = nil
    for line in content:gmatch('[^\r\n]+') do
        if line:find('model%s*=') then
            entry = line
        elseif entry then
            entry = entry .. ' ' .. line
        end

        if entry and line:find('}%s*,?') then
            local model = GetQuotedField(entry, 'model')
            if model then
                parsedSharedVehicles[model] = {
                    spawncode = model,
                    name = GetQuotedField(entry, 'name') or model,
                    brand = GetQuotedField(entry, 'brand') or 'Unknown',
                    model = model,
                    price = tonumber(entry:match('price%s*=%s*(%d+)')) or 0,
                    category = GetQuotedField(entry, 'category') or 'other',
                    type = GetQuotedField(entry, 'type') or 'automobile',
                    shop = GetShopField(entry) or 'none'
                }
            end
            entry = nil
        end
    end

    if HasEntries(parsedSharedVehicles) then
        print(('[qb-vehicleshop] Loaded %s vehicles from qb-core shared file fallback.'):format(CountEntries(parsedSharedVehicles)))
    else
        print('[qb-vehicleshop] Shared vehicle fallback did not find any vehicle entries.')
    end

    return parsedSharedVehicles
end

local function GetSharedVehicles()
    local ok, vehicles = pcall(function()
        return exports['qb-core']:GetSharedVehicles()
    end)

    if ok and HasEntries(vehicles) then
        QBCore.Shared = QBCore.Shared or {}
        QBCore.Shared.Vehicles = vehicles
        return vehicles
    end

    if type(QBCore.Shared) == 'table' and HasEntries(QBCore.Shared.Vehicles) then
        return QBCore.Shared.Vehicles
    end

    RefreshCoreObject()
    if type(QBCore.Shared) == 'table' and HasEntries(QBCore.Shared.Vehicles) then
        return QBCore.Shared.Vehicles
    end

    if type(QBShared) == 'table' and HasEntries(QBShared.Vehicles) then
        QBCore.Shared = QBCore.Shared or {}
        QBCore.Shared.Vehicles = QBShared.Vehicles
        return QBShared.Vehicles
    end

    vehicles = LoadSharedVehiclesFromFile()
    if HasEntries(vehicles) then return vehicles end

    print('[qb-vehicleshop] QBCore shared vehicles are not loaded.')
    return {}
end

local function GetSharedVehicle(model)
    return GetSharedVehicles()[model]
end

local function Round(value)
    value = tonumber(value) or 0
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

local function CommaValue(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function GetVehicleTypeByModel(model)
    local vehicleData = GetSharedVehicle(model)
    if not vehicleData then return 'automobile' end
    return vehicleTypes[vehicleData.category] or vehicleData.type or 'automobile'
end

local function GeneratePlate()
    local plate = (QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(2)):upper()
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
    if result then return GeneratePlate() end
    return plate
end

local function CalculateFinance(vehiclePrice, downPayment, payments)
    local balance = vehiclePrice - downPayment
    local payment = balance / payments
    return Round(balance), Round(payment)
end

local function CalculateNewFinance(paymentAmount, vehData)
    local currentBalance = tonumber(vehData.balance) or 0
    local newBalance = currentBalance - paymentAmount
    local paymentsLeft = math.max((tonumber(vehData.paymentsLeft) or tonumber(vehData.paymentsleft) or 1) - 1, 0)
    if paymentsLeft <= 0 then return 0, 0, 0 end
    return Round(newBalance), Round(newBalance / paymentsLeft), paymentsLeft
end

local function VehicleInShop(vehicle, shopName)
    if not vehicle or not vehicle.shop then return false end
    if type(vehicle.shop) == 'table' then
        for _, shop in pairs(vehicle.shop) do
            if shop == shopName then return true end
        end
        return false
    end
    return vehicle.shop == shopName
end

local function EnsureStockTable()
    if stockTableReady then return true end

    local ok, err = pcall(function()
        MySQL.query.await(stockTableSql)
    end)

    if not ok then
        print(('[qb-vehicleshop] Failed to prepare prp_pdm_stock table: %s'):format(err))
        return false
    end

    stockTableReady = true
    return true
end

local function GetStockRow(shopName, model)
    local vehicle = GetSharedVehicle(model)
    if not vehicle then return nil end

    local defaultStock = Config.AdvancedPDM.DefaultStock or 0
    local row = nil

    if EnsureStockTable() then
        local ok, result = pcall(function()
            return MySQL.single.await('SELECT * FROM prp_pdm_stock WHERE shop = ? AND vehicle = ?', { shopName, model })
        end)

        if ok then
            row = result
        else
            print(('[qb-vehicleshop] Failed to read PDM stock for %s/%s: %s'):format(tostring(shopName), tostring(model), result))
        end
    end

    if row then
        return {
            stock = tonumber(row.stock) or 0,
            price = tonumber(row.price) or vehicle.price,
            enabled = tonumber(row.enabled) == 1,
        }
    end
    return {
        stock = defaultStock,
        price = tonumber(vehicle.price) or 0,
        enabled = true,
    }
end

local function UpsertStock(shopName, model, stock, price, enabled)
    if not EnsureStockTable() then return false end

    local ok, err = pcall(function()
        MySQL.update.await('INSERT INTO prp_pdm_stock (shop, vehicle, stock, price, enabled) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE stock = VALUES(stock), price = VALUES(price), enabled = VALUES(enabled)', {
            shopName,
            model,
            tonumber(stock) or 0,
            tonumber(price) or 0,
            enabled and 1 or 0
        })
    end)

    if not ok then
        print(('[qb-vehicleshop] Failed to update PDM stock for %s/%s: %s'):format(tostring(shopName), tostring(model), err))
        return false
    end

    return true
end

local function DecrementStock(shopName, model)
    local row = GetStockRow(shopName, model)
    if not row then return end
    local vehicle = GetSharedVehicle(model)
    local nextStock = math.max((tonumber(row.stock) or 0) - 1, 0)
    UpsertStock(shopName, model, nextStock, row.price or vehicle.price, row.enabled)
end

local function CanManageShop(src, shopName)
    local shop = Config.Shops[shopName]
    local player = QBCore.Functions.GetPlayer(src)
    if not shop or not player then return false end
    local jobName = shop.ManagementJob or (shop.Job ~= 'none' and shop.Job) or Config.AdvancedPDM.ManagementJob
    if not jobName or jobName == 'none' then return false end
    local job = player.PlayerData.job
    if not job or job.name ~= jobName then return false end
    if job.isboss then return true end
    local grade = tonumber(type(job.grade) == 'table' and job.grade.level or job.grade) or 0
    return grade >= (shop.ManagementGrade or Config.AdvancedPDM.ManagementGrade or 0)
end

local function BuildCatalog(shopName, includeDisabled)
    shopName = shopName or 'pdm'
    local shop = Config.Shops[shopName]
    if not shop then return nil end
    local vehicles, categories = {}, {}
    local sharedVehicles = GetSharedVehicles()
    local sharedCount, shopCount = 0, 0

    for model, vehicle in pairs(sharedVehicles) do
        sharedCount = sharedCount + 1
        if VehicleInShop(vehicle, shopName) then
            shopCount = shopCount + 1
            local stock = GetStockRow(shopName, model)
            if stock and (includeDisabled or stock.enabled) then
                vehicles[#vehicles + 1] = {
                    model = model,
                    name = vehicle.name or model,
                    brand = vehicle.brand or 'Unknown',
                    category = vehicle.category or 'other',
                    type = vehicle.type or GetVehicleTypeByModel(model),
                    price = stock.price or vehicle.price or 0,
                    basePrice = vehicle.price or 0,
                    stock = stock.stock,
                    enabled = stock.enabled,
                    lowStock = (tonumber(stock.stock) or 0) <= (Config.AdvancedPDM.LowStock or 2),
                }
                categories[vehicle.category or 'other'] = true
            end
        end
    end
    table.sort(vehicles, function(a, b)
        if a.category == b.category then return a.name < b.name end
        return a.category < b.category
    end)
    local categoryList = {}
    for category in pairs(categories) do categoryList[#categoryList + 1] = category end
    table.sort(categoryList)
    if #vehicles == 0 then
        print(('[qb-vehicleshop] Catalog for %s is empty. shared=%s matchingShop=%s visible=%s'):format(tostring(shopName), sharedCount, shopCount, #vehicles))
    end
    return {
        shop = {
            id = shopName,
            label = shop.ShopLabel or shopName,
            type = shop.Type,
        },
        vehicles = vehicles,
        categories = categoryList,
        colors = Config.AdvancedPDM.Colors,
        payments = Config.AdvancedPDM.PaymentMethods,
    }
end

local function RemoveFunds(player, payment, amount, reason)
    amount = tonumber(amount) or 0
    if payment == 'auto' then
        if player.Functions.GetMoney('cash') >= amount then
            player.Functions.RemoveMoney('cash', amount, reason)
            return true, 'cash'
        end
        if player.Functions.GetMoney('bank') >= amount then
            player.Functions.RemoveMoney('bank', amount, reason)
            return true, 'bank'
        end
        return false
    end
    if payment ~= 'cash' and payment ~= 'bank' then return false end
    if player.Functions.GetMoney(payment) < amount then return false end
    player.Functions.RemoveMoney(payment, amount, reason)
    return true, payment
end

local function AddSocietyMoney(shopName, amount)
    local shop = Config.Shops[shopName]
    local account = shop and (shop.ManagementJob or (shop.Job ~= 'none' and shop.Job))
    if not account or account == 'none' or GetResourceState('qb-banking') ~= 'started' then return end
    pcall(function()
        exports['qb-banking']:AddMoney(account, amount, 'PDM vehicle sale')
    end)
end

local function CompletePurchase(targetSrc, data, sellerSrc)
    local player = QBCore.Functions.GetPlayer(targetSrc)
    if not player then return false, 'Customer not found.' end

    local shopName = data.shop or 'pdm'
    local shop = Config.Shops[shopName]
    local vehicle = GetSharedVehicle(data.model)
    if not shop or not vehicle or not VehicleInShop(vehicle, shopName) then
        return false, 'Vehicle is not sold at this shop.'
    end

    local stock = GetStockRow(shopName, data.model)
    if not stock or not stock.enabled then return false, 'Vehicle is unavailable.' end
    if (tonumber(stock.stock) or 0) <= 0 then return false, 'This vehicle is out of stock.' end

    local price = tonumber(stock.price) or tonumber(vehicle.price) or 0
    local payment = data.payment or 'auto'
    local balance, paymentAmount, paymentsLeft = 0, 0, 0
    local removeAmount = price
    local removeAccount = payment

    if payment == 'finance' then
        if not Config.AdvancedPDM.PaymentMethods.finance then return false, 'Financing is disabled.' end
        local downPayment = tonumber(data.downPayment) or 0
        local payments = tonumber(data.payments) or 0
        local minDown = Round((Config.MinimumDown / 100) * price)
        if downPayment < minDown then return false, ('Down payment must be at least $%s.'):format(CommaValue(minDown)) end
        if downPayment > price then return false, 'Down payment is more than the vehicle value.' end
        if payments < 1 or payments > Config.MaximumPayments then return false, ('Payments must be between 1 and %s.'):format(Config.MaximumPayments) end
        balance, paymentAmount = CalculateFinance(price, downPayment, payments)
        paymentsLeft = payments
        removeAmount = downPayment
        removeAccount = data.financeAccount or 'bank'
    elseif payment ~= 'auto' and not Config.AdvancedPDM.PaymentMethods[payment] then
        return false, 'That payment method is disabled.'
    end

    local paid = RemoveFunds(player, removeAccount, removeAmount, 'vehicle-bought-in-showroom')
    if not paid then return false, 'Not enough money.' end

    local plate = GeneratePlate()
    local primary = tonumber(data.primary) or 111
    local secondary = tonumber(data.secondary) or primary
    local mods = json.encode({
        color1 = primary,
        color2 = secondary,
        pearlescentColor = primary,
        wheelColor = secondary,
    })

    MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state, balance, paymentamount, paymentsleft, financetime) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        player.PlayerData.license,
        player.PlayerData.citizenid,
        data.model,
        GetHashKey(data.model),
        mods,
        plate,
        shop.Garage or Config.AdvancedPDM.DefaultGarage,
        0,
        balance,
        paymentAmount,
        paymentsLeft,
        payment == 'finance' and (Config.PaymentInterval * 60) or 0
    })

    DecrementStock(shopName, data.model)
    AddSocietyMoney(shopName, price)

    if sellerSrc then
        local seller = QBCore.Functions.GetPlayer(sellerSrc)
        if seller and Config.Commission and Config.Commission > 0 then
            local commission = Round(price * Config.Commission)
            seller.Functions.AddMoney('bank', commission, 'vehicle sale commission')
            TriggerClientEvent('QBCore:Notify', sellerSrc, ('Commission earned: $%s'):format(CommaValue(commission)), 'success')
        end
    end

    TriggerClientEvent('qb-vehicleshop:client:purchaseComplete', targetSrc, data.model, plate, shopName)
    TriggerClientEvent('QBCore:Notify', targetSrc, ('Purchased %s %s.'):format(vehicle.brand or '', vehicle.name or data.model), 'success')
    return true
end

CreateThread(function()
    EnsureStockTable()
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:server:spawnvehicle', function(_, cb, plate, vehicle, coords)
    local vehicleData = GetSharedVehicle(vehicle)
    local vehType = vehicleData and vehicleData.type or GetVehicleTypeByModel(vehicle)
    local veh = CreateVehicleServerSetter(GetHashKey(vehicle), vehType, coords.x, coords.y, coords.z, coords.w)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetVehicleNumberPlateText(veh, plate)
    local vehProps = {}
    local result = MySQL.single.await('SELECT mods FROM player_vehicles WHERE plate = ?', { plate })
    if result and result.mods then vehProps = json.decode(result.mods) or {} end
    cb(netId, vehProps, plate)
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:server:getCatalog', function(source, cb, shopName)
    local ok, payload = pcall(BuildCatalog, shopName, false)
    if not ok then
        print(('[qb-vehicleshop] Failed to build catalog for %s: %s'):format(tostring(shopName), payload))
        TriggerClientEvent('QBCore:Notify', source, 'PDM catalog failed to load. Check server console.', 'error')
        cb(false)
        return
    end
    cb(payload)
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:server:getManagementData', function(source, cb, shopName)
    if not CanManageShop(source, shopName) then cb(false) return end
    local ok, payload = pcall(BuildCatalog, shopName, true)
    if not ok then
        print(('[qb-vehicleshop] Failed to build management catalog for %s: %s'):format(tostring(shopName), payload))
        cb(false)
        return
    end
    cb(payload)
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:server:getVehicles', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then cb({}) return end
    cb(MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { player.PlayerData.citizenid }) or {})
end)

RegisterNetEvent('qb-vehicleshop:server:addPlayer', function(citizenid)
    financetimer[citizenid] = os.time()
end)

RegisterNetEvent('qb-vehicleshop:server:removePlayer', function(citizenid)
    if financetimer[citizenid] then
        local playTime = financetimer[citizenid]
        local financeTime = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { citizenid })
        for _, vehicle in pairs(financeTime or {}) do
            if tonumber(vehicle.balance) and tonumber(vehicle.balance) >= 1 then
                local newTime = (vehicle.financetime - ((os.time() - playTime) / 60))
                if newTime < 0 then newTime = 0 end
                MySQL.update('UPDATE player_vehicles SET financetime = ? WHERE plate = ?', { math.ceil(newTime), vehicle.plate })
            end
        end
    end
    financetimer[citizenid] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local license
    for _, identifier in pairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then license = identifier break end
    end
    if not license then return end
    local vehicles = MySQL.query.await('SELECT * FROM player_vehicles WHERE license = ?', { license })
    for _, vehicle in pairs(vehicles or {}) do
        local playTime = financetimer[vehicle.citizenid]
        if tonumber(vehicle.balance) and tonumber(vehicle.balance) >= 1 and playTime then
            local newTime = (vehicle.financetime - ((os.time() - playTime) / 60))
            if newTime < 0 then newTime = 0 end
            MySQL.update('UPDATE player_vehicles SET financetime = ? WHERE plate = ?', { math.ceil(newTime), vehicle.plate })
        end
    end
    if vehicles and vehicles[1] then financetimer[vehicles[1].citizenid] = nil end
end)

RegisterNetEvent('qb-vehicleshop:server:deleteVehicle', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end)

RegisterNetEvent('qb-vehicleshop:server:purchaseVehicle', function(data)
    local src = source
    local ok, message = CompletePurchase(src, data or {})
    if not ok then TriggerClientEvent('QBCore:Notify', src, message or 'Purchase failed.', 'error') end
end)

RegisterNetEvent('qb-vehicleshop:server:updateStock', function(shopName, data)
    local src = source
    if not CanManageShop(src, shopName) then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot manage this shop.', 'error')
        return
    end
    local vehicle = data and data.model and GetSharedVehicle(data.model)
    if not data or not data.model or not vehicle then return end
    local stock = math.max(tonumber(data.stock) or 0, 0)
    local price = math.max(tonumber(data.price) or vehicle.price or 0, 0)
    if UpsertStock(shopName, data.model, stock, price, data.enabled ~= false) then
        TriggerClientEvent('QBCore:Notify', src, 'Stock updated.', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Stock could not be updated. Check server console.', 'error')
    end
end)

RegisterNetEvent('qb-vehicleshop:server:customTestDrive', function(vehicle, playerid)
    local src = source
    local target = tonumber(playerid)
    if not QBCore.Functions.GetPlayer(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID.', 'error')
        return
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) < 3 then
        TriggerClientEvent('qb-vehicleshop:client:customTestDrive', target, vehicle)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Player is too far away.', 'error')
    end
end)

RegisterNetEvent('qb-vehicleshop:server:buyShowroomVehicle', function(vehicle)
    local src = source
    local model = type(vehicle) == 'table' and (vehicle.buyVehicle or vehicle.model) or vehicle
    local ok, message = CompletePurchase(src, { shop = 'pdm', model = model, payment = 'auto' })
    if not ok then TriggerClientEvent('QBCore:Notify', src, message or 'Purchase failed.', 'error') end
end)

RegisterNetEvent('qb-vehicleshop:server:financeVehicle', function(downPayment, paymentAmount, vehicle)
    local src = source
    local ok, message = CompletePurchase(src, {
        shop = 'pdm',
        model = vehicle,
        payment = 'finance',
        downPayment = downPayment,
        payments = paymentAmount,
        financeAccount = 'auto',
    })
    if not ok then TriggerClientEvent('QBCore:Notify', src, message or 'Finance failed.', 'error') end
end)

RegisterNetEvent('qb-vehicleshop:server:sellShowroomVehicle', function(vehicle, playerid)
    local src = source
    local target = QBCore.Functions.GetPlayer(tonumber(playerid))
    if not target then TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID.', 'error') return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target.PlayerData.source))) > 3 then
        TriggerClientEvent('QBCore:Notify', src, 'Player is too far away.', 'error')
        return
    end
    local ok, message = CompletePurchase(target.PlayerData.source, { shop = 'pdm', model = vehicle, payment = 'auto' }, src)
    if not ok then TriggerClientEvent('QBCore:Notify', src, message or 'Sale failed.', 'error') end
end)

RegisterNetEvent('qb-vehicleshop:server:sellfinanceVehicle', function(downPayment, paymentAmount, vehicle, playerid)
    local src = source
    local target = QBCore.Functions.GetPlayer(tonumber(playerid))
    if not target then TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID.', 'error') return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target.PlayerData.source))) > 3 then
        TriggerClientEvent('QBCore:Notify', src, 'Player is too far away.', 'error')
        return
    end
    local ok, message = CompletePurchase(target.PlayerData.source, {
        shop = 'pdm',
        model = vehicle,
        payment = 'finance',
        downPayment = downPayment,
        payments = paymentAmount,
        financeAccount = 'auto',
    }, src)
    if not ok then TriggerClientEvent('QBCore:Notify', src, message or 'Finance failed.', 'error') end
end)

RegisterNetEvent('qb-vehicleshop:server:financePayment', function(paymentAmount, vehData)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    paymentAmount = tonumber(paymentAmount)
    if not paymentAmount or not vehData or not vehData.vehiclePlate then return end
    local plate = vehData.vehiclePlate
    local vehicle = MySQL.single.await('SELECT balance, paymentamount, paymentsleft FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, player.PlayerData.citizenid })
    if not vehicle or (tonumber(vehicle.balance) or 0) <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Finance account not found.', 'error')
        return
    end
    local minPayment = tonumber(vehicle.paymentamount) or 0
    local timer = (Config.PaymentInterval * 60)
    local newBalance, newPayment, newPaymentsLeft = CalculateNewFinance(paymentAmount, {
        balance = vehicle.balance,
        paymentsLeft = vehicle.paymentsleft,
    })
    if newBalance <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Overpaid finance balance.', 'error')
        return
    end
    if paymentAmount < minPayment then
        TriggerClientEvent('QBCore:Notify', src, ('Minimum payment is $%s.'):format(CommaValue(minPayment)), 'error')
        return
    end
    local paid = RemoveFunds(player, 'auto', paymentAmount, 'financed vehicle')
    if not paid then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money.', 'error')
        return
    end
    MySQL.update('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ? AND citizenid = ?', { newBalance, newPayment, newPaymentsLeft, timer, plate, player.PlayerData.citizenid })
    TriggerClientEvent('QBCore:Notify', src, 'Finance payment complete.', 'success')
end)

RegisterNetEvent('qb-vehicleshop:server:financePaymentFull', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    if not data or not data.vehPlate then return end
    local vehicle = MySQL.single.await('SELECT balance FROM player_vehicles WHERE plate = ? AND citizenid = ?', { data.vehPlate, player.PlayerData.citizenid })
    local balance = tonumber(vehicle and vehicle.balance) or 0
    if balance <= 0 then TriggerClientEvent('QBCore:Notify', src, 'This vehicle is already paid off.', 'error') return end
    local paid = RemoveFunds(player, 'auto', balance, 'paid off vehicle')
    if not paid then TriggerClientEvent('QBCore:Notify', src, 'Not enough money.', 'error') return end
    MySQL.update('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ? AND citizenid = ?', { 0, 0, 0, 0, data.vehPlate, player.PlayerData.citizenid })
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle paid off.', 'success')
end)

RegisterNetEvent('qb-vehicleshop:server:checkFinance', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local query = 'SELECT * FROM player_vehicles WHERE citizenid = ? AND balance > 0 AND financetime < 1'
    local result = MySQL.query.await(query, { player.PlayerData.citizenid })
    if result and result[1] then
        TriggerClientEvent('QBCore:Notify', src, ('Vehicle finance payment due in %s minutes.'):format(Config.PaymentWarning))
        Wait(Config.PaymentWarning * 60000)
        local vehicles = MySQL.query.await(query, { player.PlayerData.citizenid })
        for _, vehicle in pairs(vehicles or {}) do
            MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', { vehicle.plate })
            TriggerClientEvent('QBCore:Notify', src, ('Vehicle repossessed: %s'):format(vehicle.plate), 'error')
        end
    end
end)

QBCore.Commands.Add('pdmmanagement', 'Open PDM management', {}, false, function(source)
    TriggerClientEvent('qb-vehicleshop:client:openManagement', source, 'pdm')
end)

QBCore.Commands.Add('vehiclefinance', 'Open vehicle finance payments', {}, false, function(source)
    TriggerClientEvent('qb-vehicleshop:client:getVehicles', source)
end)

QBCore.Commands.Add('transfervehicle', 'Transfer or sell the current vehicle to another player', {
    { name = 'ID', help = 'Buyer server ID' },
    { name = 'amount', help = 'Optional sale price' }
}, false, function(source, args)
    local src = source
    local buyerId = tonumber(args[1])
    local sellAmount = tonumber(args[2])
    if not buyerId or buyerId == 0 then TriggerClientEvent('QBCore:Notify', src, 'Invalid buyer ID.', 'error') return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(buyerId)
    if targetPed == 0 then TriggerClientEvent('QBCore:Notify', src, 'Buyer not found.', 'error') return end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then TriggerClientEvent('QBCore:Notify', src, 'You are not in a vehicle.', 'error') return end
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
    local player = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(buyerId)
    if not player or not target then return end
    local row = MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ?', { plate })
    if not row then TriggerClientEvent('QBCore:Notify', src, 'Vehicle not found.', 'error') return end
    if Config.PreventFinanceSelling and tonumber(row.balance) and tonumber(row.balance) > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot transfer financed vehicles.', 'error')
        return
    end
    if row.citizenid ~= player.PlayerData.citizenid then TriggerClientEvent('QBCore:Notify', src, 'You do not own this vehicle.', 'error') return end
    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > 5.0 then TriggerClientEvent('QBCore:Notify', src, 'Buyer is too far away.', 'error') return end

    local targetCid = target.PlayerData.citizenid
    local targetLicense = QBCore.Functions.GetIdentifier(target.PlayerData.source, 'license')
    if sellAmount and sellAmount > 0 then
        local paid = RemoveFunds(target, 'auto', sellAmount, 'transferred vehicle')
        if not paid then TriggerClientEvent('QBCore:Notify', src, 'Buyer cannot afford this.', 'error') return end
        player.Functions.AddMoney('bank', sellAmount, 'transferred vehicle')
        TriggerClientEvent('QBCore:Notify', src, ('Vehicle sold for $%s.'):format(CommaValue(sellAmount)), 'success')
        TriggerClientEvent('QBCore:Notify', buyerId, ('Vehicle bought for $%s.'):format(CommaValue(sellAmount)), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Vehicle gifted.', 'success')
        TriggerClientEvent('QBCore:Notify', buyerId, 'You received a vehicle.', 'success')
    end

    MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?', { targetCid, targetLicense, plate })
    TriggerClientEvent('vehiclekeys:client:SetOwner', buyerId, plate)
end)
