local QBCore = exports['qb-core']:GetCoreObject()

local PlayerJob = {}
local depotPed, depotBlip, routeBlip, scrapBlip, scrapyardBlip, breakdownObj
local activeMode = nil
local spawnedBins = {}
local spawnedScrap = {}
local currentBinIndex = 1
local currentClusterIndex = 1
local carriedObj = nil
local carriedType = nil
local carriedPropKey = nil
local truckLoad = {}
local rentedTruck = nil
local rentedPlate = nil
local nuiOpen = false

local function Debug(msg)
    if Config.Debug then print('[prp-garbage] ' .. tostring(msg)) end
end

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end
    end
    return hash
end

local function LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function Notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function HasGarbageJob()
    return PlayerJob and PlayerJob.name == Config.JobName
end

local function CleanPlate(plate)
    return tostring(plate or ''):gsub('%s+', '')
end

local function IsGarbageTruck(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    return Config.GarbageTruckModels[GetEntityModel(veh)] == true
end

local function GetNearestGarbageTruck(maxDist)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')
    local closest, closestDist = 0, maxDist or Config.TruckDistance

    for _, veh in ipairs(vehicles) do
        if IsGarbageTruck(veh) then
            local dist = #(GetEntityCoords(veh) - pcoords)
            if dist < closestDist then
                closest = veh
                closestDist = dist
            end
        end
    end

    return closest, closestDist
end

local function SetRouteBlip(coords, sprite, colour, label)
    if routeBlip and DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
    routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(routeBlip, sprite or Config.RouteBlipSprite)
    SetBlipColour(routeBlip, colour or Config.RouteBlipColour)
    SetBlipScale(routeBlip, 0.85)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, colour or Config.RouteBlipColour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Garbage Stop')
    EndTextCommandSetBlipName(routeBlip)
end

local function ClearRouteBlip()
    if routeBlip and DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
    routeBlip = nil
end

local function DeleteEntitySafe(ent)
    if ent and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local function ClearCarry()
    if carriedObj then DeleteEntitySafe(carriedObj) end
    carriedObj, carriedType, carriedPropKey = nil, nil, nil
    ClearPedTasks(PlayerPedId())
end

local function AttachCarryObject(model, attach)
    ClearCarry()
    local ped = PlayerPedId()
    local hash = LoadModel(model)
    local coords = GetEntityCoords(ped)
    carriedObj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(carriedObj, ped, GetPedBoneIndex(ped, attach.bone), attach.pos.x, attach.pos.y, attach.pos.z, attach.rot.x, attach.rot.y, attach.rot.z, true, true, false, true, 1, true)
end

local function PlayAnim(anim)
    LoadAnim(anim.dict)
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, -8.0, anim.time or -1, anim.flag or 49, 0.0, false, false, false)
end

local function Progress(label, time, anim, cb)
    if anim then PlayAnim(anim) end
    QBCore.Functions.Progressbar('prp_garbage_action', label, time, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(PlayerPedId())
        if cb then cb(true) end
    end, function()
        ClearPedTasks(PlayerPedId())
        if cb then cb(false) end
    end)
end

local function SpawnDepotPed()
    if not Config.Depot.ped.enabled then return end
    local c = Config.Depot.coords
    local hash = LoadModel(Config.Depot.ped.model)
    depotPed = CreatePed(0, hash, c.x, c.y, c.z - 1.0, c.w, false, false)
    FreezeEntityPosition(depotPed, true)
    SetEntityInvincible(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    if Config.Depot.ped.scenario then TaskStartScenarioInPlace(depotPed, Config.Depot.ped.scenario, 0, true) end

    exports['qb-target']:AddTargetEntity(depotPed, {
        options = {
            {
                icon = 'fas fa-truck',
                label = 'Rent Trashmaster ($' .. tostring(Config.Depot.deposit or 250) .. ' Deposit)',
                job = Config.JobName,
                action = function()
                    TriggerServerEvent('prp-garbage:server:rentTruck')
                end
            },
            {
                icon = 'fas fa-undo',
                label = 'Return Trashmaster',
                job = Config.JobName,
                action = function()
                    local veh = rentedTruck
                    if not veh or not DoesEntityExist(veh) then
                        veh = GetNearestGarbageTruck(Config.Depot.returnDistance or 18.0)
                    end
                    if not veh or veh == 0 or not DoesEntityExist(veh) then
                        Notify(Config.Notifications.BringTruckCloser, 'error')
                        return
                    end
                    local dist = #(GetEntityCoords(veh) - vector3(Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z))
                    if dist > (Config.Depot.returnDistance or 18.0) then
                        Notify(Config.Notifications.BringTruckCloser, 'error')
                        return
                    end
                    TriggerServerEvent('prp-garbage:server:returnTruck', GetVehicleNumberPlateText(veh))
                end
            }
        },
        distance = Config.TargetDistance
    })
end

local function SpawnDepotBlip()
    if not Config.Depot.blip.enabled then return end
    local c = Config.Depot.coords
    depotBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(depotBlip, Config.Depot.blip.sprite)
    SetBlipColour(depotBlip, Config.Depot.blip.colour)
    SetBlipScale(depotBlip, Config.Depot.blip.scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Depot.label)
    EndTextCommandSetBlipName(depotBlip)
end

local function AddRearTruckTarget(veh)
    if not DoesEntityExist(veh) then return end
    exports['qb-target']:AddTargetEntity(veh, {
        options = {
            {
                icon = 'fas fa-dumpster',
                label = 'Place in Truck',
                job = Config.JobName,
                canInteract = function(entity)
                    if not carriedType then return false end
                    local rear = GetOffsetFromEntityInWorldCoords(entity, Config.TruckRearOffset.x, Config.TruckRearOffset.y, Config.TruckRearOffset.z)
                    return #(GetEntityCoords(PlayerPedId()) - rear) <= Config.TruckRearDistance + 1.0
                end,
                action = function(entity)
                    if not carriedType then return end
                    local rear = GetOffsetFromEntityInWorldCoords(entity, Config.TruckRearOffset.x, Config.TruckRearOffset.y, Config.TruckRearOffset.z)
                    if #(GetEntityCoords(PlayerPedId()) - rear) > Config.TruckRearDistance + 1.0 then
                        Notify('Go to the back of the Trashmaster.', 'error')
                        return
                    end
                    Progress('Placing in truck...', Config.Animations.PlaceInTruck.time, Config.Animations.PlaceInTruck, function(done)
                        if not done then return end
                        if carriedType == 'binbag' then
                            ClearCarry()
                            Notify(Config.Notifications.TruckLoaded, 'success')
                            currentBinIndex = currentBinIndex + 1
                            if activeMode == 'bins' then
                                if currentBinIndex > #Config.Areas.mirrorpark.bins then
                                    TriggerServerEvent('prp-garbage:server:payRoute', Config.Areas.mirrorpark.payKey)
                                    activeMode = nil
                                    ClearRouteBlip()
                                else
                                    local n = Config.Areas.mirrorpark.bins[currentBinIndex]
                                    SetRouteBlip(vector3(n.x, n.y, n.z), Config.RouteBlipSprite, Config.RouteBlipColour, 'Next Bin')
                                end
                            end
                        elseif carriedType == 'scrap' then
                            if #truckLoad >= Config.HardRubbish.MaxCarry then
                                Notify(Config.Notifications.CarryFull, 'error')
                                return
                            end
                            truckLoad[#truckLoad + 1] = carriedPropKey
                            ClearCarry()
                            Notify(Config.Notifications.TruckLoaded, 'success')
                            local allGone = true
                            for _, obj in pairs(spawnedScrap) do
                                if obj and DoesEntityExist(obj) then allGone = false break end
                            end
                            if allGone and activeMode == 'scrap' then
                                currentClusterIndex = currentClusterIndex + 1
                                if currentClusterIndex <= #Config.HardRubbish.Clusters then
                                    SpawnScrapCluster(currentClusterIndex)
                                else
                                    SetRouteBlip(vector3(Config.HardRubbish.Scrapyard.x, Config.HardRubbish.Scrapyard.y, Config.HardRubbish.Scrapyard.z), Config.ScrapyardBlipSprite, Config.ScrapyardBlipColour, 'Scrapyard')
                                    Notify('All clusters collected. Head to the scrapyard.', 'success')
                                end
                            end
                        end
                    end)
                end
            }
        },
        distance = Config.TruckRearDistance + 1.0
    })
end

RegisterNetEvent('prp-garbage:client:spawnTruck', function()
    local s = Config.Depot.spawn
    local spawnCoords = vector3(s.x, s.y, s.z)
    if IsAnyVehicleNearPoint(spawnCoords.x, spawnCoords.y, spawnCoords.z, 4.0) then
        Notify(Config.Notifications.DepotTruckBlocked, 'error')
        return
    end

    QBCore.Functions.SpawnVehicle(Config.Depot.vehicle, function(vehicle)
        SetEntityHeading(vehicle, s.w)
        SetVehicleOnGroundProperly(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        local plate = (Config.Depot.platePrefix or 'GARB') .. tostring(math.random(1000, 9999))
        SetVehicleNumberPlateText(vehicle, plate)
        Wait(100)
        rentedTruck = vehicle
        rentedPlate = CleanPlate(GetVehicleNumberPlateText(vehicle))
        TriggerServerEvent('prp-garbage:server:setTruckPlate', rentedPlate)
        AddRearTruckTarget(vehicle)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(vehicle))
        Notify(Config.Notifications.DepotTruckSpawned, 'success')
    end, Config.Depot.spawn, true)
end)

RegisterNetEvent('prp-garbage:client:deleteReturnedTruck', function()
    if rentedTruck and DoesEntityExist(rentedTruck) then
        DeleteEntitySafe(rentedTruck)
    else
        local veh = GetNearestGarbageTruck(Config.Depot.returnDistance or 18.0)
        if veh and veh ~= 0 then DeleteEntitySafe(veh) end
    end
    rentedTruck = nil
    rentedPlate = nil
end)

local function OpenJobMenu()
    if not HasGarbageJob() then Notify(Config.Notifications.NeedJob, 'error') return end
    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({
        action = 'open',
        areas = {
            { id = 'mirrorpark', label = Config.Areas.mirrorpark.label, description = Config.Areas.mirrorpark.description },
            { id = 'scrap', label = Config.HardRubbish.label, description = Config.HardRubbish.description },
        }
    })
end

RegisterCommand(Config.Command, OpenJobMenu, false)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb('ok')
end)

local function CanStartWithTruck(cb)
    if not Config.RequireGarbageTruck then cb(true) return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if Config.RequirePlayerInTruckToStart then
        if veh == 0 or not IsGarbageTruck(veh) then
            Notify(Config.Notifications.NeedTruckToStart, 'error')
            cb(false)
            return
        end
        QBCore.Functions.TriggerCallback('prp-garbage:server:isOwnedTruck', function(isOwned)
            if not isOwned then Notify(Config.Notifications.WrongTruck, 'error') end
            cb(isOwned)
        end, GetVehicleNumberPlateText(veh))
    else
        local truck = GetNearestGarbageTruck(Config.TruckDistance)
        cb(truck ~= 0)
    end
end

RegisterNUICallback('selectJob', function(data, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    if activeMode then Notify(Config.Notifications.AlreadyRunning, 'error') cb('ok') return end
    CanStartWithTruck(function(ok)
        if not ok then return end
        if data.id == 'mirrorpark' then StartBinRoute() end
        if data.id == 'scrap' then StartScrapRoute() end
    end)
    cb('ok')
end)

function SpawnBins()
    for i, coords in ipairs(Config.Areas.mirrorpark.bins) do
        if not spawnedBins[i] or not DoesEntityExist(spawnedBins[i]) then
            local hash = LoadModel(Config.Props.ClosedBin)
            local obj = CreateObject(hash, coords.x, coords.y, coords.z - 1.0, true, true, true)
            SetEntityHeading(obj, coords.w)
            PlaceObjectOnGroundProperly(obj)
            SetEntityAsMissionEntity(obj, true, true)
            FreezeEntityPosition(obj, false)
            spawnedBins[i] = obj
            exports['qb-target']:AddTargetEntity(obj, {
                options = {
                    {
                        icon = 'fas fa-trash',
                        label = 'Collect Bin Bag',
                        job = Config.JobName,
                        canInteract = function()
                            return activeMode == 'bins' and currentBinIndex == i and carriedType == nil
                        end,
                        action = function(entity)
                            if activeMode ~= 'bins' or currentBinIndex ~= i or carriedType then return end
                            Progress('Collecting bin...', Config.Animations.BinCollect.time, Config.Animations.BinCollect, function(done)
                                if not done then return end
                                DeleteEntitySafe(entity)
                                local c = Config.Areas.mirrorpark.bins[i]
                                local openHash = LoadModel(Config.Props.OpenBin)
                                local openObj = CreateObject(openHash, c.x, c.y, c.z - 1.0, true, true, true)
                                SetEntityHeading(openObj, c.w)
                                PlaceObjectOnGroundProperly(openObj)
                                SetEntityAsMissionEntity(openObj, true, true)
                                FreezeEntityPosition(openObj, false)
                                spawnedBins[i] = openObj
                                AttachCarryObject(Config.Props.BinBag, Config.BinBagAttach)
                                carriedType = 'binbag'
                                PlayAnim(Config.Animations.CarryScrap)
                                Notify(Config.Notifications.PutItemInTruck, 'primary')
                            end)
                        end
                    }
                },
                distance = Config.TargetDistance
            })
        end
    end
end

function StartBinRoute()
    activeMode = 'bins'
    currentBinIndex = 1
    SpawnBins()
    local first = Config.Areas.mirrorpark.bins[1]
    SetRouteBlip(vector3(first.x, first.y, first.z), Config.RouteBlipSprite, Config.RouteBlipColour, 'First Bin')
    Notify(Config.Notifications.StartedRoute, 'success')
end

function ClearScrapObjects()
    for _, obj in pairs(spawnedScrap) do DeleteEntitySafe(obj) end
    spawnedScrap = {}
end

function SpawnScrapCluster(index)
    ClearScrapObjects()
    local cluster = Config.HardRubbish.Clusters[index]
    if not cluster then return end
    SetRouteBlip(vector3(cluster.center.x, cluster.center.y, cluster.center.z), Config.ScrapBlipSprite, Config.ScrapBlipColour, cluster.label)
    for i, item in ipairs(cluster.items) do
        local propCfg = Config.HardRubbish.Props[item.prop]
        if propCfg then
            local pos = vector3(cluster.center.x, cluster.center.y, cluster.center.z) + item.offset
            local hash = LoadModel(propCfg.model)
            local obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, true)
            SetEntityHeading(obj, item.heading or cluster.center.w)
            PlaceObjectOnGroundProperly(obj)
            SetEntityAsMissionEntity(obj, true, true)
            FreezeEntityPosition(obj, false)
            spawnedScrap[i] = obj
            exports['qb-target']:AddTargetEntity(obj, {
                options = {
                    {
                        icon = 'fas fa-recycle',
                        label = 'Pick Up ' .. propCfg.label,
                        job = Config.JobName,
                        canInteract = function(entity)
                            return activeMode == 'scrap' and carriedType == nil and DoesEntityExist(entity)
                        end,
                        action = function(entity)
                            if carriedType then return end
                            Progress('Picking up rubbish...', Config.Animations.ScrapCollect.time, Config.Animations.ScrapCollect, function(done)
                                if not done then return end
                                DeleteEntitySafe(entity)
                                spawnedScrap[i] = nil
                                AttachCarryObject(propCfg.model, Config.HardRubbish.CarryAttach)
                                carriedType = 'scrap'
                                carriedPropKey = item.prop
                                PlayAnim(Config.Animations.CarryScrap)
                                Notify(Config.Notifications.PutItemInTruck, 'primary')
                            end)
                        end
                    }
                },
                distance = Config.TargetDistance
            })
        end
    end
end

function StartScrapRoute()
    activeMode = 'scrap'
    currentClusterIndex = 1
    truckLoad = {}
    SpawnScrapCluster(1)
    Notify(Config.Notifications.ScrapStarted, 'success')
end

local function SpawnScrapyard()
    local c = Config.HardRubbish.Scrapyard
    scrapyardBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(scrapyardBlip, Config.ScrapyardBlipSprite)
    SetBlipColour(scrapyardBlip, Config.ScrapyardBlipColour)
    SetBlipScale(scrapyardBlip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Scrapyard Breakdown')
    EndTextCommandSetBlipName(scrapyardBlip)

    if Config.HardRubbish.BreakdownObject.enabled then
        local b = Config.HardRubbish.BreakdownObject
        local pos = vector3(c.x, c.y, c.z) + b.offset
        local hash = LoadModel(b.model)
        breakdownObj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(breakdownObj, b.heading or c.w)
        FreezeEntityPosition(breakdownObj, true)
        SetEntityAsMissionEntity(breakdownObj, true, true)
        exports['qb-target']:AddTargetEntity(breakdownObj, {
            options = {
                {
                    icon = 'fas fa-hammer',
                    label = 'Break Down Hard Rubbish',
                    job = Config.JobName,
                    action = function()
                        if #truckLoad <= 0 then Notify(Config.Notifications.NothingCarried, 'error') return end
                        Progress('Breaking down hard rubbish...', Config.Animations.Breakdown.time, Config.Animations.Breakdown, function(done)
                            if not done then return end
                            TriggerServerEvent('prp-garbage:server:breakdownScrap', truckLoad)
                            truckLoad = {}
                            if activeMode == 'scrap' and currentClusterIndex > #Config.HardRubbish.Clusters then
                                activeMode = nil
                                ClearRouteBlip()
                                Notify('Scrap job complete.', 'success')
                            end
                        end)
                    end
                }
            },
            distance = Config.TargetDistance
        })
    end
end

CreateThread(function()
    while not QBCore.Functions.GetPlayerData().job do Wait(250) end
    PlayerJob = QBCore.Functions.GetPlayerData().job
    SpawnDepotPed()
    SpawnDepotBlip()
    SpawnScrapyard()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if depotPed then DeleteEntitySafe(depotPed) end
    if breakdownObj then DeleteEntitySafe(breakdownObj) end
    if depotBlip then RemoveBlip(depotBlip) end
    if scrapyardBlip then RemoveBlip(scrapyardBlip) end
    ClearRouteBlip()
    ClearCarry()
    for _, obj in pairs(spawnedBins) do DeleteEntitySafe(obj) end
    ClearScrapObjects()
end)
