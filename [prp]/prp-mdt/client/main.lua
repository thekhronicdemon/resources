local QBCore = exports['qb-core']:GetCoreObject()
local open = false

local function canUseMDT()
    local pdata = QBCore.Functions.GetPlayerData()
    return pdata and pdata.job and Config.AllowedJobs[pdata.job.name] == true
end

RegisterCommand(Config.Command, function()
    if not canUseMDT() then
        QBCore.Functions.Notify('You are not authorised to use the MDT.', 'error')
        return
    end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('prp-mdt:server:open')
end, false)

RegisterKeyMapping(Config.Command, 'Open MDT/CAD', 'keyboard', 'F6')

RegisterNetEvent('prp-mdt:client:update', function(payload)
    SendNUIMessage({ action = 'hydrate', data = payload })
end)

RegisterNetEvent('prp-mdt:client:notify', function(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

local function cbTrigger(name, data, cb)
    QBCore.Functions.TriggerCallback('prp-mdt:server:' .. name, function(result)
        cb(result or { ok = false })
    end, data or {})
end

for _, name in ipairs({
    'searchPlayers','getProfile','createCase','updateCase','closeCase','assignCase','addCasePerson','removeCasePerson',
    'addCharge','removeCharge','searchCases','getCase','saveReport','saveCallsign','getApplications',
    'setApplicationStatus','addApplication','getDashboard','saveProfilePhoto','deleteCase','addEvidencePhoto','getEvidence','deleteEvidence', 'getCasesForPlayer'
}) do
    RegisterNUICallback(name, function(data, cb) cbTrigger(name, data, cb) end)
end


RegisterNUICallback('openEvidenceInventory', function(data, cb)
    TriggerServerEvent('prp-mdt:server:openEvidenceInventory', data.case_id)
    cb({ ok = true })
end)
