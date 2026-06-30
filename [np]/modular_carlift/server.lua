local LiftStates = {}

local function initStates()
    for _, lift in ipairs(Config.Lifts) do
        LiftStates[lift.id] = {
            moving = false,
            direction = 'stop', -- up/down/stop
            height = 0.0,
            locked = false,
            updatedAt = os.time(),
        }
    end
end

CreateThread(initStates)

local function syncOne(liftId)
    TriggerClientEvent('modular_carlift_prp:client:syncState', -1, liftId, LiftStates[liftId])
end

RegisterNetEvent('modular_carlift_prp:server:requestStates', function()
    TriggerClientEvent('modular_carlift_prp:client:syncStates', source, LiftStates)
end)

RegisterNetEvent('modular_carlift_prp:server:setDirection', function(liftId, direction, height)
    if not LiftStates[liftId] then return end
    if direction ~= 'up' and direction ~= 'down' and direction ~= 'stop' then return end

    if direction == 'down' and LiftStates[liftId].locked then
        TriggerClientEvent('modular_carlift_prp:client:notify', source, 'Lift is locked.', 'error')
        return
    end

    LiftStates[liftId].direction = direction
    LiftStates[liftId].moving = direction ~= 'stop'
    if type(height) == 'number' then
        LiftStates[liftId].height = height
    end
    LiftStates[liftId].updatedAt = os.time()
    syncOne(liftId)
end)

RegisterNetEvent('modular_carlift_prp:server:updateHeight', function(liftId, height)
    if not LiftStates[liftId] or type(height) ~= 'number' then return end
    LiftStates[liftId].height = height
    syncOne(liftId)
end)

RegisterNetEvent('modular_carlift_prp:server:toggleLock', function(liftId)
    if not LiftStates[liftId] then return end
    LiftStates[liftId].locked = not LiftStates[liftId].locked
    syncOne(liftId)
end)
