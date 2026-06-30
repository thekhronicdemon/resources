local stateBag = {}

local function normalizeState(state)
    state = type(state) == 'table' and state or {}

    return {
        lights = state.lights == true,
        siren = state.siren == true,
        sirenTone = math.floor(tonumber(state.sirenTone) or 1),
        right = state.right == true,
        left = state.left == true,
        hazards = state.hazards == true,
        airhorn = state.airhorn == true,
        manual = state.manual == true,
        aux = state.aux == true
    }
end

RegisterNetEvent('prp-els:server:setState', function(netId, state)
    if type(netId) ~= 'number' or type(state) ~= 'table' then return end

    if netId <= 0 then
        stateBag[netId] = nil
        return
    end

    stateBag[netId] = normalizeState(state)

    TriggerClientEvent('prp-els:client:applyState', -1, netId, stateBag[netId])
end)

AddEventHandler('playerJoining', function()
    local src = source
    for netId, state in pairs(stateBag) do
        TriggerClientEvent('prp-els:client:applyState', src, netId, state)
    end
end)
