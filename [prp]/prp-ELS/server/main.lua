local stateBag = {}

RegisterNetEvent('prp-els:server:setState', function(netId, state)
    if type(netId) ~= 'number' or type(state) ~= 'table' then return end

    stateBag[netId] = {
        lights = state.lights == true,
        siren = state.siren == true
    }

    TriggerClientEvent('prp-els:client:applyState', -1, netId, stateBag[netId])
end)
