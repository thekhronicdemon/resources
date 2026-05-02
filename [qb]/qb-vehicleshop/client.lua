local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = {}
local Initialized = false
local insideShop = nil
local currentShop = nil
local catalogOpen = false
local catalogVehicles = {}
local selectedVehicle = nil
local selectedColor = nil
local previewVehicle = 0
local previewCam = 0
local showroomVehicles = {}
local zones = {}
local testDriveVeh = 0
local inTestDrive = false
local testDriveZone = nil
local canReturnTestDrive = false
local nuiNonce = 0
local nuiReady = false
local lastPDMMessage = nil

local function Notify(message, notifyType)
    QBCore.Functions.Notify(message, notifyType or 'primary')
end

local function DispatchPDMUI(message)
    if GetResourceState('prp-pdm-ui') == 'started' then
        TriggerEvent('prp-pdm-ui:client:sendMessage', message)
        return
    end

    if message and (message.action == 'open' or message.action == 'openFinanceShell' or message.action == 'openManagementShell' or message.action == 'debugOpen') then
        SetNuiFocus(false, false)
        Notify('prp-pdm-ui is not started. Run refresh then ensure prp-pdm-ui.', 'error')
    end
end

local function SendPDMMessage(message)
    local nonce = nuiNonce
    lastPDMMessage = message
    DispatchPDMUI(message)
    local delays = { 250, 750, 1500, 3000, 6000, 10000, 15000 }
    for _, delay in ipairs(delays) do
        SetTimeout(delay, function()
            if catalogOpen and nonce == nuiNonce then
                DispatchPDMUI(message)
            end
        end)
    end
end

local function LoadModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        Wait(25)
        if GetGameTimer() > timeout then return false end
    end
    return hash
end

local function TableLength(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local function Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

local function FormatMoney(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function DrawText3D(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = string.len(text) / 370
    DrawRect(0.0, 0.012, 0.018 + factor, 0.032, 6, 10, 14, 160)
    ClearDrawOrigin()
end

local function GetShopValue(shopName, key, fallback)
    local shop = Config.Shops[shopName]
    if shop and shop[key] ~= nil then return shop[key] end
    return fallback
end

local function GetCatalogLocation(shopName)
    return GetShopValue(shopName, 'CatalogLocation', Config.Shops[shopName].Location)
end

local function GetManagementLocation(shopName)
    return GetShopValue(shopName, 'ManagementLocation', Config.Shops[shopName].FinanceZone or Config.Shops[shopName].Location)
end

local function GetFinanceLocation(shopName)
    return GetShopValue(shopName, 'FinanceZone', Config.Shops[shopName].Location)
end

local function GetPreviewCoords(shopName)
    local shop = Config.Shops[shopName]
    if shop.PreviewLocation then return shop.PreviewLocation end
    if shop.ShowroomVehicles and shop.ShowroomVehicles[1] then return shop.ShowroomVehicles[1].coords end
    return shop.VehicleSpawn
end

local function CanManageShop(shopName)
    local shop = Config.Shops[shopName]
    if not shop or not PlayerData.job then return false end
    local jobName = shop.ManagementJob or (shop.Job ~= 'none' and shop.Job) or Config.AdvancedPDM.ManagementJob
    if not jobName or jobName == 'none' then return false end
    if PlayerData.job.name ~= jobName then return false end
    if PlayerData.job.isboss then return true end
    local grade = PlayerData.job.grade
    local level = tonumber(type(grade) == 'table' and grade.level or grade) or 0
    return level >= (shop.ManagementGrade or Config.AdvancedPDM.ManagementGrade or 0)
end

local function ApplyVehicleColor(vehicle, color)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    color = color or selectedColor or Config.AdvancedPDM.Colors[1]
    local primary = tonumber(color.primary or color.color1) or 111
    local secondary = tonumber(color.secondary or color.color2) or primary
    SetVehicleColours(vehicle, primary, secondary)
    SetVehicleExtraColours(vehicle, primary, secondary)
    SetVehicleDirtLevel(vehicle, 0.0)
end

local function DeletePreviewVehicle()
    if previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
        SetEntityAsMissionEntity(previewVehicle, true, true)
        DeleteEntity(previewVehicle)
    end
    previewVehicle = 0
end

local function DestroyPreviewCamera()
    if previewCam ~= 0 then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(previewCam, false)
        previewCam = 0
    end
end

local function SetupPreviewCamera(shopName)
    DestroyPreviewCamera()
    local preview = GetPreviewCoords(shopName)
    local cam = Config.Shops[shopName].CameraLocation
    if not cam then
        cam = vector4(preview.x - 5.4, preview.y - 4.4, preview.z + 2.2, 0.0)
    end
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cam.x, cam.y, cam.z, 0.0, 0.0, cam.w or 0.0, 45.0, true, 2)
    PointCamAtCoord(previewCam, preview.x, preview.y, preview.z + 0.55)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 350, true, true)
end

local function SendPreviewStats(model)
    local hash = joaat(model)
    DispatchPDMUI({
        action = 'stats',
        stats = {
            speed = math.floor((GetVehicleModelEstimatedMaxSpeed(hash) or 0.0) * 3.6),
            acceleration = Round((GetVehicleModelAcceleration(hash) or 0.0) * 10.0, 1),
            traction = Round((GetVehicleModelMaxTraction(hash) or 0.0) * 10.0, 1),
            braking = Round((GetVehicleModelMaxBraking(hash) or 0.0) * 10.0, 1),
        }
    })
end

local function SpawnPreviewVehicle(model, color)
    if not currentShop then return end
    DeletePreviewVehicle()
    local hash = LoadModel(model)
    if not hash then
        Notify('Vehicle model could not be loaded.', 'error')
        return
    end
    local coords = GetPreviewCoords(currentShop)
    previewVehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w or 0.0, false, false)
    while not DoesEntityExist(previewVehicle) do Wait(25) end
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetEntityInvincible(previewVehicle, true)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleNumberPlateText(previewVehicle, 'PRP PDM')
    ApplyVehicleColor(previewVehicle, color)
    SetModelAsNoLongerNeeded(hash)
    SendPreviewStats(model)
end

local function CheckPlate(vehicle, plateToSet)
    local vehiclePlate = promise.new()
    CreateThread(function()
        while true do
            Wait(500)
            if GetVehicleNumberPlateText(vehicle) == plateToSet then
                vehiclePlate:resolve(true)
                return
            end
            SetVehicleNumberPlateText(vehicle, plateToSet)
        end
    end)
    return vehiclePlate
end

local function FuelVehicle(vehicle)
    if GetResourceState('prp_fuel') == 'started' then
        exports['prp_fuel']:SetFuel(vehicle, 100)
    end
end

local function DeliverVehicle(vehicle, plate, shopName)
    shopName = shopName or currentShop or insideShop or 'pdm'
    local spawn = Config.Shops[shopName] and Config.Shops[shopName].VehicleSpawn or Config.Shops.pdm.VehicleSpawn
    QBCore.Functions.TriggerCallback('qb-vehicleshop:server:spawnvehicle', function(netId, properties, vehPlate)
        local timeout = GetGameTimer() + 7000
        while not NetworkDoesNetworkIdExist(netId) do
            Wait(20)
            if GetGameTimer() > timeout then return end
        end
        local veh = NetworkGetEntityFromNetworkId(netId)
        Citizen.Await(CheckPlate(veh, vehPlate))
        QBCore.Functions.SetVehicleProperties(veh, properties or {})
        ApplyVehicleColor(veh, properties or selectedColor)
        FuelVehicle(veh)
        TriggerEvent('vehiclekeys:client:SetOwner', vehPlate)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        SetVehicleEngineOn(veh, true, true, false)
    end, plate, vehicle, spawn)
end

local function CloseCatalog(keepPreview)
    catalogOpen = false
    nuiNonce = nuiNonce + 1
    SetNuiFocus(false, false)
    DispatchPDMUI({ action = 'close' })
    DestroyPreviewCamera()
    if not keepPreview then DeletePreviewVehicle() end
    currentShop = nil
end

local function OpenCatalog(shopName)
    if catalogOpen then return end
    QBCore.Functions.TriggerCallback('qb-vehicleshop:server:getCatalog', function(payload)
        if not payload or not payload.vehicles or #payload.vehicles == 0 then
            Notify('There are no vehicles configured for this shop.', 'error')
            return
        end
        currentShop = shopName
        catalogOpen = true
        catalogVehicles = payload.vehicles
        selectedVehicle = payload.vehicles[1]
        selectedColor = payload.colors and payload.colors[1] or Config.AdvancedPDM.Colors[1]
        SetupPreviewCamera(shopName)
        SpawnPreviewVehicle(selectedVehicle.model, selectedColor)
        SetNuiFocus(true, true)
        SendPDMMessage({
            action = 'open',
            shop = payload.shop,
            vehicles = payload.vehicles,
            categories = payload.categories,
            colors = payload.colors,
            payments = payload.payments,
            canManage = CanManageShop(shopName),
            limits = {
                minimumDown = Config.MinimumDown,
                maximumPayments = Config.MaximumPayments
            }
        })
    end, shopName)
end

local function OpenManagement(shopName)
    QBCore.Functions.TriggerCallback('qb-vehicleshop:server:getManagementData', function(payload)
        if not payload then
            Notify('You cannot manage this shop.', 'error')
            return
        end
        if not catalogOpen then
            currentShop = shopName
            catalogOpen = true
            SetNuiFocus(true, true)
            SendPDMMessage({ action = 'openManagementShell', shop = payload.shop })
        end
        SendPDMMessage({ action = 'managementData', data = payload })
    end, shopName)
end

local function OpenFinance(shopName)
    QBCore.Functions.TriggerCallback('qb-vehicleshop:server:getVehicles', function(vehicles)
        local financed = {}
        for _, vehicle in pairs(vehicles or {}) do
            local balance = tonumber(vehicle.balance) or 0
            if balance > 0 then
                local model = vehicle.vehicle or vehicle.model
                local shared = model and QBCore.Shared.Vehicles[model] or {}
                financed[#financed + 1] = {
                    plate = vehicle.plate,
                    model = model,
                    name = shared and shared.name or model or 'Vehicle',
                    brand = shared and shared.brand or '',
                    balance = balance,
                    paymentAmount = tonumber(vehicle.paymentamount) or 0,
                    paymentsLeft = tonumber(vehicle.paymentsleft) or 0,
                    financeTime = tonumber(vehicle.financetime) or 0,
                }
            end
        end

        if not catalogOpen then
            currentShop = shopName or insideShop or 'pdm'
            catalogOpen = true
            SetNuiFocus(true, true)
            SendPDMMessage({ action = 'openFinanceShell' })
        end

        SendPDMMessage({
            action = 'financeData',
            vehicles = financed
        })
    end)
end

local function StartTestDrive(model)
    if inTestDrive then
        Notify('You are already in a test drive.', 'error')
        return
    end
    local shopName = currentShop or insideShop
    if not shopName then return end
    local prevCoords = GetEntityCoords(PlayerPedId())
    local spawn = Config.Shops[shopName].TestDriveSpawn or Config.Shops[shopName].VehicleSpawn
    CloseCatalog()
    inTestDrive = true
    QBCore.Functions.TriggerCallback('qb-vehicleshop:server:spawnvehicle', function(netId, properties, vehPlate)
        local timeout = GetGameTimer() + 7000
        while not NetworkDoesNetworkIdExist(netId) do
            Wait(20)
            if GetGameTimer() > timeout then return end
        end
        local veh = NetworkGetEntityFromNetworkId(netId)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleNumberPlateText(veh, vehPlate)
        QBCore.Functions.SetVehicleProperties(veh, properties or {})
        ApplyVehicleColor(veh, selectedColor)
        FuelVehicle(veh)
        TriggerEvent('vehiclekeys:client:SetOwner', vehPlate)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        SetVehicleEngineOn(veh, true, true, false)
        testDriveVeh = netId
        Notify(('Test drive started. Return in %s minutes.'):format(Config.Shops[shopName].TestDriveTimeLimit), 'success')
    end, 'TESTDRIVE', model, spawn)

    if Config.Shops[shopName].ReturnLocation then
        testDriveZone = BoxZone:Create(Config.Shops[shopName].ReturnLocation, 3.0, 5.0, {
            name = 'prp_pdm_testdrive_return_' .. shopName,
        })
        testDriveZone:onPlayerInOut(function(isInside)
            canReturnTestDrive = isInside
        end)
    end

    local limit = (Config.Shops[shopName].TestDriveTimeLimit or 1.0) * 60
    local started = GetGameTimer()
    CreateThread(function()
        Wait(2000)
        while inTestDrive do
            local seconds = math.floor(limit - ((GetGameTimer() - started) / 1000))
            if seconds <= 0 then
                TriggerServerEvent('qb-vehicleshop:server:deleteVehicle', testDriveVeh)
                testDriveVeh = 0
                inTestDrive = false
                canReturnTestDrive = false
                SetEntityCoords(PlayerPedId(), prevCoords.x, prevCoords.y, prevCoords.z, false, false, false, false)
                if testDriveZone then testDriveZone:destroy() testDriveZone = nil end
                Notify('Test drive complete.', 'primary')
                break
            end
            SetTextFont(4)
            SetTextScale(0.48, 0.48)
            SetTextColour(255, 255, 255, 210)
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentString(('Test drive: %ss'):format(seconds))
            EndTextCommandDisplayText(0.5, 0.92)
            if canReturnTestDrive and Config.Shops[shopName].ReturnLocation then
                DrawText3D(Config.Shops[shopName].ReturnLocation + vector3(0.0, 0.0, 0.45), '[E] Return test drive')
            end
            if canReturnTestDrive and testDriveZone and IsControlJustReleased(0, 38) then
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if veh ~= 0 and NetworkGetEntityFromNetworkId(testDriveVeh) == veh then
                    TriggerServerEvent('qb-vehicleshop:server:deleteVehicle', testDriveVeh)
                    testDriveVeh = 0
                    inTestDrive = false
                    DeleteEntity(veh)
                    testDriveZone:destroy()
                    testDriveZone = nil
                    canReturnTestDrive = false
                    Notify('Test drive returned.', 'success')
                    break
                end
            end
            Wait(0)
        end
    end)
end

local function SpawnShowroomVehicles()
    for shopName, shop in pairs(Config.Shops) do
        showroomVehicles[shopName] = showroomVehicles[shopName] or {}
        for index, display in pairs(shop.ShowroomVehicles or {}) do
            local model = display.chosenVehicle or display.defaultVehicle
            local hash = LoadModel(model)
            if hash then
                local coords = display.coords
                local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w or 0.0, false, false)
                while not DoesEntityExist(veh) do Wait(25) end
                SetEntityInvincible(veh, true)
                SetVehicleDirtLevel(veh, 0.0)
                SetVehicleDoorsLocked(veh, 3)
                FreezeEntityPosition(veh, true)
                SetVehicleOnGroundProperly(veh)
                SetVehicleNumberPlateText(veh, 'FOR SALE')
                showroomVehicles[shopName][index] = veh
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

local function CreateShopZones()
    for shopName, shop in pairs(Config.Shops) do
        local zone = PolyZone:Create(shop.Zone.Shape, {
            name = 'prp_pdm_' .. shopName,
            minZ = shop.Zone.minZ,
            maxZ = shop.Zone.maxZ,
            debugPoly = false,
        })
        zones[#zones + 1] = zone
        zone:onPlayerInOut(function(isInside)
            if isInside then
                insideShop = shopName
            elseif insideShop == shopName then
                insideShop = nil
                if catalogOpen and currentShop == shopName then CloseCatalog() end
            end
        end)
    end
end

function Init()
    if Initialized then return end
    Initialized = true
    CreateShopZones()
    SpawnShowroomVehicles()
    CreateThread(function()
        for shopName, shop in pairs(Config.Shops) do
            if shop.showBlip then
                local blip = AddBlipForCoord(shop.Location)
                SetBlipSprite(blip, shop.blipSprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 0.70)
                SetBlipAsShortRange(blip, true)
                SetBlipColour(blip, shop.blipColor)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(shop.ShopLabel)
                EndTextCommandSetBlipName(blip)
            end
        end
    end)
end

RegisterNUICallback('close', function(_, cb)
    CloseCatalog()
    cb('ok')
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    print('[prp-pdm] NUI ready callback received')
    if catalogOpen and lastPDMMessage then
        DispatchPDMUI(lastPDMMessage)
    end
    cb('ok')
end)

RegisterNUICallback('previewVehicle', function(data, cb)
    if data and data.model then
        selectedVehicle = data
        SpawnPreviewVehicle(data.model, selectedColor)
    end
    cb('ok')
end)

RegisterNUICallback('setColor', function(data, cb)
    selectedColor = data or selectedColor
    ApplyVehicleColor(previewVehicle, selectedColor)
    cb('ok')
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
    if not currentShop or not data or not data.model then
        cb(false)
        return
    end
    data.shop = currentShop
    data.primary = selectedColor and selectedColor.primary or data.primary
    data.secondary = selectedColor and selectedColor.secondary or data.secondary
    TriggerServerEvent('qb-vehicleshop:server:purchaseVehicle', data)
    cb('ok')
end)

RegisterNUICallback('testDrive', function(data, cb)
    if data and data.model then StartTestDrive(data.model) end
    cb('ok')
end)

RegisterNUICallback('openManagement', function(_, cb)
    if currentShop then OpenManagement(currentShop) end
    cb('ok')
end)

RegisterNUICallback('saveStock', function(data, cb)
    if currentShop and data and data.model then
        TriggerServerEvent('qb-vehicleshop:server:updateStock', currentShop, data)
        Wait(250)
        OpenManagement(currentShop)
    end
    cb('ok')
end)

RegisterNUICallback('makeFinancePayment', function(data, cb)
    if data and data.plate and data.amount then
        TriggerServerEvent('qb-vehicleshop:server:financePayment', data.amount, {
            vehiclePlate = data.plate,
            balance = data.balance,
            paymentsLeft = data.paymentsLeft,
            paymentAmount = data.paymentAmount,
        })
        Wait(350)
        OpenFinance(currentShop or insideShop or 'pdm')
    end
    cb('ok')
end)

RegisterNUICallback('payFinanceFull', function(data, cb)
    if data and data.plate then
        TriggerServerEvent('qb-vehicleshop:server:financePaymentFull', {
            vehPlate = data.plate,
            vehBalance = data.balance,
        })
        Wait(350)
        OpenFinance(currentShop or insideShop or 'pdm')
    end
    cb('ok')
end)

RegisterNetEvent('qb-vehicleshop:client:uiReady', function()
    nuiReady = true
    print('[prp-pdm] PRP PDM UI ready callback received')
    if catalogOpen and lastPDMMessage then
        DispatchPDMUI(lastPDMMessage)
    end
end)

RegisterNetEvent('qb-vehicleshop:client:uiClose', function()
    CloseCatalog()
end)

RegisterNetEvent('qb-vehicleshop:client:uiPreviewVehicle', function(data)
    if data and data.model then
        selectedVehicle = data
        SpawnPreviewVehicle(data.model, selectedColor)
    end
end)

RegisterNetEvent('qb-vehicleshop:client:uiSetColor', function(data)
    selectedColor = data or selectedColor
    ApplyVehicleColor(previewVehicle, selectedColor)
end)

RegisterNetEvent('qb-vehicleshop:client:uiPurchaseVehicle', function(data)
    if not currentShop or not data or not data.model then return end
    data.shop = currentShop
    data.primary = selectedColor and selectedColor.primary or data.primary
    data.secondary = selectedColor and selectedColor.secondary or data.secondary
    TriggerServerEvent('qb-vehicleshop:server:purchaseVehicle', data)
end)

RegisterNetEvent('qb-vehicleshop:client:uiTestDrive', function(data)
    if data and data.model then StartTestDrive(data.model) end
end)

RegisterNetEvent('qb-vehicleshop:client:uiOpenManagement', function()
    if currentShop then OpenManagement(currentShop) end
end)

RegisterNetEvent('qb-vehicleshop:client:uiSaveStock', function(data)
    if currentShop and data and data.model then
        TriggerServerEvent('qb-vehicleshop:server:updateStock', currentShop, data)
        Wait(250)
        OpenManagement(currentShop)
    end
end)

RegisterNetEvent('qb-vehicleshop:client:uiMakeFinancePayment', function(data)
    if data and data.plate and data.amount then
        TriggerServerEvent('qb-vehicleshop:server:financePayment', data.amount, {
            vehiclePlate = data.plate,
            balance = data.balance,
            paymentsLeft = data.paymentsLeft,
            paymentAmount = data.paymentAmount,
        })
        Wait(350)
        OpenFinance(currentShop or insideShop or 'pdm')
    end
end)

RegisterNetEvent('qb-vehicleshop:client:uiPayFinanceFull', function(data)
    if data and data.plate then
        TriggerServerEvent('qb-vehicleshop:server:financePaymentFull', {
            vehPlate = data.plate,
            vehBalance = data.balance,
        })
        Wait(350)
        OpenFinance(currentShop or insideShop or 'pdm')
    end
end)

RegisterCommand('closepdm', function()
    CloseCatalog()
end, false)

RegisterCommand('pdmdebugui', function()
    catalogOpen = true
    currentShop = insideShop or currentShop or 'pdm'
    SetNuiFocus(true, true)
    SendPDMMessage({ action = 'debugOpen' })
    Notify('PDM debug UI sent. If nothing appears, the NUI page is not mounted.', 'primary')
end, false)

RegisterCommand('pdmnuistatus', function()
    Notify(('PDM NUI status: ui=%s, ready=%s, open=%s, shop=%s'):format(GetResourceState('prp-pdm-ui'), tostring(nuiReady), tostring(catalogOpen), tostring(currentShop or insideShop or 'none')), 'primary')
end, false)

RegisterNetEvent('qb-vehicleshop:client:purchaseComplete', function(vehicle, plate, shopName)
    CloseCatalog()
    DeliverVehicle(vehicle, plate, shopName)
end)

RegisterNetEvent('qb-vehicleshop:client:buyShowroomVehicle', function(vehicle, plate, shopName)
    CloseCatalog()
    DeliverVehicle(vehicle, plate, shopName)
end)

RegisterNetEvent('qb-vehicleshop:client:customTestDrive', function(vehicle)
    StartTestDrive(vehicle)
end)

RegisterNetEvent('qb-vehicleshop:client:homeMenu', function()
    if insideShop then OpenCatalog(insideShop) end
end)

RegisterNetEvent('qb-vehicleshop:client:showVehOptions', function()
    if insideShop then OpenCatalog(insideShop) end
end)

RegisterNetEvent('qb-vehicleshop:client:TestDrive', function()
    if selectedVehicle then StartTestDrive(selectedVehicle.model) end
end)

RegisterNetEvent('qb-vehicleshop:client:openManagement', function(shopName)
    OpenManagement(shopName or insideShop or 'pdm')
end)

RegisterNetEvent('qb-vehicleshop:client:getVehicles', function()
    OpenFinance(insideShop or currentShop or 'pdm')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('qb-vehicleshop:server:addPlayer', PlayerData.citizenid)
    TriggerServerEvent('qb-vehicleshop:server:checkFinance')
    Init()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if PlayerData.citizenid then TriggerServerEvent('qb-vehicleshop:server:removePlayer', PlayerData.citizenid) end
    PlayerData = {}
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.citizenid then
        TriggerServerEvent('qb-vehicleshop:server:addPlayer', PlayerData.citizenid)
        TriggerServerEvent('qb-vehicleshop:server:checkFinance')
    end
    Init()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CloseCatalog()
    for _, shopVehicles in pairs(showroomVehicles) do
        for _, veh in pairs(shopVehicles) do
            if DoesEntityExist(veh) then DeleteEntity(veh) end
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if insideShop and Config.Shops[insideShop] and not catalogOpen then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local catalog = GetCatalogLocation(insideShop)
            local management = GetManagementLocation(insideShop)
            local finance = GetFinanceLocation(insideShop)
            local catalogDist = #(coords - catalog)
            local managementDist = #(coords - management)
            local financeDist = #(coords - finance)
            if catalogDist < Config.AdvancedPDM.DrawDistance then
                sleep = 0
                DrawText3D(catalog + vector3(0.0, 0.0, 0.45), '[E] Vehicle Catalog')
                if catalogDist <= Config.AdvancedPDM.CatalogDistance and IsControlJustReleased(0, 38) then
                    OpenCatalog(insideShop)
                end
            end
            if CanManageShop(insideShop) and managementDist < Config.AdvancedPDM.DrawDistance then
                sleep = 0
                DrawText3D(management + vector3(0.0, 0.0, 0.45), '[G] PDM Management')
                if managementDist <= Config.AdvancedPDM.ManagementDistance and IsControlJustReleased(0, 47) then
                    OpenManagement(insideShop)
                end
            end
            if financeDist < Config.AdvancedPDM.DrawDistance then
                sleep = 0
                DrawText3D(finance + vector3(0.0, 0.0, 0.45), '[F] Finance Payments')
                if financeDist <= Config.AdvancedPDM.ManagementDistance and IsControlJustReleased(0, 23) then
                    OpenFinance(insideShop)
                end
            end
        end
        if catalogOpen and previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
            SetEntityHeading(previewVehicle, GetEntityHeading(previewVehicle) + 0.045)
        end
        Wait(sleep)
    end
end)
