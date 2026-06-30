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
local truckLoadProps = {}
local targetedTrucks = {}
local rentedTruck = nil
local rentedPlate = nil
local nuiOpen = false
local StopScrapRoute

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
    local model = GetEntityModel(veh)
    return Config.GarbageTruckModels[model] == true or (Config.TrayVehicles and Config.TrayVehicles[model] ~= nil)
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

local function GetTrayConfig(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return Config.TrayVehicles and Config.TrayVehicles[GetEntityModel(veh)] or nil
end

local function GetTruckLoadLimit(veh)
    local tray = GetTrayConfig(veh)
    if tray and tray.slots and #tray.slots > 0 then
        return math.min(Config.HardRubbish.MaxCarry or #tray.slots, #tray.slots)
    end
    return Config.HardRubbish.MaxCarry or 12
end

local function ClearTruckLoadProps()
    for _, obj in pairs(truckLoadProps) do DeleteEntitySafe(obj) end
    truckLoadProps = {}
end

local function RemoveTruckLoadProp(slotIndex)
    DeleteEntitySafe(truckLoadProps[slotIndex])
    truckLoadProps[slotIndex] = nil
end

local function CreateTruckLoadProp(veh, propKey, slotIndex)
    local tray = GetTrayConfig(veh)
    if not tray or not tray.slots or not tray.slots[slotIndex] then return nil end

    local propCfg = Config.HardRubbish.Props[propKey]
    local slot = tray.slots[slotIndex]
    if not propCfg or not slot.offset then return nil end

    local hash = LoadModel(propCfg.loadModel or propCfg.model)
    local coords = GetEntityCoords(veh)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z + 1.0, true, true, false)
    local rot = slot.rotation or slot.rot or vector3(0.0, 0.0, 0.0)

    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, veh, 0, slot.offset.x, slot.offset.y, slot.offset.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    truckLoadProps[slotIndex] = obj
    return obj
end

local function PopTruckLoad()
    local slotIndex = #truckLoad
    if slotIndex <= 0 then return nil end

    local propKey = truckLoad[slotIndex]
    truckLoad[slotIndex] = nil
    RemoveTruckLoadProp(slotIndex)
    return propKey
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
                action = function()
                    TriggerServerEvent('prp-garbage:server:rentTruck')
                end
            },
            {
                icon = 'fas fa-undo',
                label = 'Return Trashmaster',
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
    if targetedTrucks[veh] then return end
    targetedTrucks[veh] = true

    exports['qb-target']:AddTargetEntity(veh, {
        options = {
            {
                icon = 'fas fa-dumpster',
                label = 'Place in Truck',
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
                            local loadLimit = GetTruckLoadLimit(entity)
                            if #truckLoad >= loadLimit then
                                Notify(Config.Notifications.CarryFull, 'error')
                                return
                            end
                            local propKey = carriedPropKey
                            local slotIndex = #truckLoad + 1
                            truckLoad[slotIndex] = propKey
                            CreateTruckLoadProp(entity, propKey, slotIndex)
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
    if activeMode == 'scrap' and StopScrapRoute then
        StopScrapRoute(false)
    else
        ClearTruckLoadProps()
        truckLoad = {}
    end

    if rentedTruck and DoesEntityExist(rentedTruck) then
        DeleteEntitySafe(rentedTruck)
    else
        local veh = GetNearestGarbageTruck(Config.Depot.returnDistance or 18.0)
        if veh and veh ~= 0 then DeleteEntitySafe(veh) end
    end
    rentedTruck = nil
    rentedPlate = nil
end)

CreateThread(function()
    while true do
        Wait(2500)
        if HasGarbageJob() or activeMode == 'scrap' then
            local pcoords = GetEntityCoords(PlayerPedId())
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if IsGarbageTruck(veh) and #(GetEntityCoords(veh) - pcoords) <= (Config.TruckDistance + 15.0) then
                    AddRearTruckTarget(veh)
                end
            end
        end
    end
end)

local function OpenJobMenu()
    local areas = {
        { id = 'scrap', label = Config.HardRubbish.label, description = Config.HardRubbish.description },
    }

    if HasGarbageJob() then
        table.insert(areas, 1, { id = 'mirrorpark', label = Config.Areas.mirrorpark.label, description = Config.Areas.mirrorpark.description })
    end

    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({
        action = 'open',
        areas = areas,
        canStopScrap = activeMode == 'scrap'
    })
end

RegisterCommand(Config.Command, OpenJobMenu, false)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb('ok')
end)

local function CanStartWithTruck(mode, cb)
    if not Config.RequireGarbageTruck then cb(true) return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if Config.RequirePlayerInTruckToStart then
        if veh == 0 or not IsGarbageTruck(veh) then
            Notify(Config.Notifications.NeedTruckToStart, 'error')
            cb(false)
            return
        end

        if mode == 'scrap' then
            cb(true)
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
    if data.id == 'mirrorpark' and not HasGarbageJob() then
        Notify(Config.Notifications.NeedJob, 'error')
        cb('ok')
        return
    end

    CanStartWithTruck(data.id, function(ok)
        if not ok then return end
        if data.id == 'mirrorpark' then StartBinRoute() end
        if data.id == 'scrap' then StartScrapRoute() end
    end)
    cb('ok')
end)

RegisterNUICallback('stopScrapJob', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    if StopScrapRoute then StopScrapRoute(true) end
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

StopScrapRoute = function(showNotify)
    if activeMode ~= 'scrap' then
        if showNotify then Notify('No scrap job is currently running.', 'error') end
        return
    end

    activeMode = nil
    currentClusterIndex = 1
    truckLoad = {}
    ClearTruckLoadProps()
    ClearScrapObjects()
    ClearCarry()
    ClearRouteBlip()

    if showNotify then
        Notify(Config.Notifications.ScrapStopped, 'primary')
    end
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
    ClearTruckLoadProps()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 and IsGarbageTruck(veh) then
        AddRearTruckTarget(veh)
    end
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
                    action = function()
                        if #truckLoad <= 0 then Notify(Config.Notifications.NothingCarried, 'error') return end
                        local label = 'Breaking down hard rubbish (' .. tostring(#truckLoad) .. ' left)...'
                        Progress(label, Config.Animations.Breakdown.time, Config.Animations.Breakdown, function(done)
                            if not done then return end
                            local propKey = PopTruckLoad()
                            if not propKey then
                                Notify(Config.Notifications.NothingCarried, 'error')
                                return
                            end

                            TriggerServerEvent('prp-garbage:server:breakdownScrap', { propKey })

                            if activeMode == 'scrap' and currentClusterIndex > #Config.HardRubbish.Clusters and #truckLoad <= 0 then
                                activeMode = nil
                                ClearRouteBlip()
                                Notify(Config.Notifications.ScrapComplete, 'success')
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
    ClearTruckLoadProps()
    for _, obj in pairs(spawnedBins) do DeleteEntitySafe(obj) end
    ClearScrapObjects()
end)
