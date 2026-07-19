local QBCore = exports['qb-core']:GetCoreObject()
local lastAttempt = 0

local function canSellTo(entity)
    if not Config.Selling.enabled then return false end
    if entity == PlayerPedId() or not DoesEntityExist(entity) or not IsEntityAPed(entity) then return false end
    if IsPedAPlayer(entity) or IsPedDeadOrDying(entity, true) then return false end
    if IsPedInAnyVehicle(entity, false) then return false end
    if Config.Selling.blacklistedPedModels[GetEntityModel(entity)] then return false end
    if GetEntitySpeed(entity) > Config.Selling.maxNpcSpeed then return false end
    return true
end

CreateThread(function()
    exports[Config.Target]:AddGlobalPed({
        options = {{
            icon = 'fas fa-handshake',
            label = 'Offer drugs',
            canInteract = function(entity)
                return canSellTo(entity) and (GetGameTimer() - lastAttempt) > (Config.Selling.cooldownSeconds * 1000)
            end,
            action = function(entity)
                if not canSellTo(entity) then return end
                lastAttempt = GetGameTimer()
                if not NetworkGetEntityIsNetworked(entity) then
                    NetworkRegisterEntityAsNetworked(entity)
                    local timeout = GetGameTimer() + 1000
                    while not NetworkGetEntityIsNetworked(entity) and GetGameTimer() < timeout do Wait(0) end
                end
                local netId = NetworkGetNetworkIdFromEntity(entity)
                if netId == 0 then
                    return QBCore.Functions.Notify('This NPC cannot be interacted with right now.', 'error')
                end
                TaskTurnPedToFaceEntity(entity, PlayerPedId(), 1500)
                Wait(800)
                TriggerServerEvent('prp-drugs:server:sellToNpc', netId)
            end,
        }},
        distance = Config.Selling.distance,
    })
end)

RegisterNetEvent('prp-drugs:client:npcSaleResult', function(netId, accepted)
    local ped = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ped) then return end

    if accepted then
        RequestAnimDict('mp_common')
        while not HasAnimDictLoaded('mp_common') do Wait(10) end
        TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_a', 8.0, -8.0, 1200, 48, 0, false, false, false)
        TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1200, 48, 0, false, false, false)
    else
        TaskSmartFleePed(ped, PlayerPedId(), 20.0, 8000, false, false)
    end
end)


RegisterNetEvent('prp-drugs:client:dispatch', function(coords)
    Config.Dispatch(coords)
end)
