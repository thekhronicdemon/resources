local QBCore = exports['qb-core']:GetCoreObject()
local function now() return os.date('%Y-%m-%d %H:%M:%S') end

local function hasAccess(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local job = Player.PlayerData.job and Player.PlayerData.job.name
    return Config.AllowedJobs[job] == true
end

local function isBoss(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local job = Player.PlayerData.job or {}
    local min = Config.BossGrades[job.name]
    return min and (job.grade.level or 0) >= min
end

local function log(src, action, target, detail)
    local Player = QBCore.Functions.GetPlayer(src)
    local name = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or GetPlayerName(src)
    MySQL.insert('INSERT INTO prp_mdt_audit (admin_src, admin_name, action, target, detail) VALUES (?, ?, ?, ?, ?)', { tostring(src), name, action, target or '', detail or '' })
end

local function ensureTables()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_mdt_cases (
        id INT AUTO_INCREMENT PRIMARY KEY,
        case_id VARCHAR(40) UNIQUE,
        title VARCHAR(255),
        status VARCHAR(30) DEFAULT 'open',
        summary LONGTEXT,
        report_html LONGTEXT,
        created_by VARCHAR(100),
        assigned JSON NULL,
        people JSON NULL,
        charges JSON NULL,
        photos JSON NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_mdt_callsigns (
        citizenid VARCHAR(50) PRIMARY KEY,
        callsign VARCHAR(30),
        rank_label VARCHAR(80),
        added_by VARCHAR(100),
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_mdt_applications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50),
        name VARCHAR(120),
        answers LONGTEXT,
        status VARCHAR(30) DEFAULT 'pending',
        reviewed_by VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_mdt_audit (
        id INT AUTO_INCREMENT PRIMARY KEY,
        admin_src VARCHAR(20),
        admin_name VARCHAR(120),
        action VARCHAR(80),
        target VARCHAR(120),
        detail LONGTEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_mdt_profiles (
        citizenid VARCHAR(50) PRIMARY KEY,
        photo LONGTEXT,
        notes LONGTEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_mdt_evidence (
        id INT AUTO_INCREMENT PRIMARY KEY,
        case_id VARCHAR(40),
        type VARCHAR(20),
        label VARCHAR(120),
        url LONGTEXT,
        data LONGTEXT,
        added_by VARCHAR(120),
        added_citizenid VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])
end
CreateThread(ensureTables)

local function dutyPolice()
    local list = {}
    for _, src in ipairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(src)
        if P and P.PlayerData.job and (P.PlayerData.job.name == 'police' or P.PlayerData.job.name == 'sheriff') and P.PlayerData.job.onduty then
            local cs = MySQL.single.await('SELECT callsign FROM prp_mdt_callsigns WHERE citizenid = ?', { P.PlayerData.citizenid })
            list[#list+1] = { id = src, stateid = src, citizenid = P.PlayerData.citizenid, name = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname, callsign = cs and cs.callsign or 'Unassigned', job = P.PlayerData.job.label, grade = P.PlayerData.job.grade.name }
        end
    end
    return list
end

local function getCharges() return Config.Charges end

RegisterNetEvent('prp-mdt:server:open', function()
    local src = source
    if not hasAccess(src) then return end
    TriggerClientEvent('prp-mdt:client:update', src, {
        charges = getCharges(),
        dashboard = { dutyPolice = dutyPolice(), isBoss = isBoss(src), serverTime = now() }
    })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:getDashboard', function(src, cb)
    if not hasAccess(src) then return cb({ ok=false }) end
    local recent = MySQL.query.await('SELECT case_id,title,status,created_at,updated_at FROM prp_mdt_cases ORDER BY updated_at DESC LIMIT 20') or {}
    local audit = MySQL.query.await('SELECT * FROM prp_mdt_audit ORDER BY id DESC LIMIT 30') or {}
    cb({ ok=true, dutyPolice=dutyPolice(), recentCases=recent, audit=audit, charges=Config.Charges, isBoss=isBoss(src), time=now() })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:searchPlayers', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local q = '%' .. tostring(data.query or '') .. '%'
    local rows = MySQL.query.await([[SELECT citizenid, charinfo, job, metadata FROM players
        WHERE citizenid LIKE ? OR JSON_EXTRACT(charinfo, '$.firstname') LIKE ? OR JSON_EXTRACT(charinfo, '$.lastname') LIKE ? LIMIT 50]], { q, q, q }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ci = json.decode(r.charinfo or '{}') or {}
        local job = json.decode(r.job or '{}') or {}
        out[#out+1] = { citizenid=r.citizenid, name=(ci.firstname or 'Unknown')..' '..(ci.lastname or ''), job=job.label or job.name or 'Unemployed' }
    end
    cb({ ok=true, players=out })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:getProfile', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local cid = data.citizenid
    local r = MySQL.single.await('SELECT citizenid, charinfo, job, money, metadata FROM players WHERE citizenid = ?', { cid })
    if not r then return cb({ ok=false, error='not_found' }) end
    local ci = json.decode(r.charinfo or '{}') or {}; local job=json.decode(r.job or '{}') or {}; local money=json.decode(r.money or '{}') or {}; local meta=json.decode(r.metadata or '{}') or {}
    local licenses = meta.licences or meta.licenses or {}
    local cars = MySQL.query.await('SELECT plate, vehicle, garage, state FROM player_vehicles WHERE citizenid = ?', { cid }) or {}
    local prof = MySQL.single.await('SELECT photo, notes FROM prp_mdt_profiles WHERE citizenid = ?', { cid })
    cb({ ok=true, profile={ citizenid=cid, name=(ci.firstname or 'Unknown')..' '..(ci.lastname or ''), dob=ci.birthdate, phone=ci.phone, nationality=ci.nationality, job=job, money=money, licenses=licenses, vehicles=cars, photo=prof and prof.photo or '', notes=prof and prof.notes or '' } })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:saveProfilePhoto', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    MySQL.insert.await('INSERT INTO prp_mdt_profiles (citizenid, photo) VALUES (?, ?) ON DUPLICATE KEY UPDATE photo = VALUES(photo)', { data.citizenid, data.photo or '' })
    log(src, 'profile_photo', data.citizenid, 'Updated player photo')
    cb({ ok=true })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:createCase', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local P = QBCore.Functions.GetPlayer(src)
    local caseId = 'PRP-' .. os.date('%y%m%d') .. '-' .. math.random(1000,9999)
    local creator = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
    MySQL.insert.await('INSERT INTO prp_mdt_cases (case_id,title,summary,report_html,created_by,assigned,people,charges,photos) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { caseId, data.title or 'New Case', data.summary or '', data.report_html or '', creator, json.encode({P.PlayerData.citizenid}), json.encode({}), json.encode({}), json.encode({}) })
    log(src, 'create_case', caseId, data.title or '')
    cb({ ok=true, case_id=caseId })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:updateCase', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    MySQL.update.await('UPDATE prp_mdt_cases SET title=?, summary=?, report_html=? WHERE case_id=?', { data.title or '', data.summary or '', data.report_html or '', data.case_id })
    log(src, 'update_case', data.case_id, 'Updated case details')
    cb({ ok=true })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:closeCase', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    MySQL.update.await('UPDATE prp_mdt_cases SET status=? WHERE case_id=?', { data.status or 'closed', data.case_id })
    log(src, 'case_status', data.case_id, data.status or 'closed')
    cb({ ok=true })
end)

local function mutateCaseArray(caseId, field, value, removeId)
    local r = MySQL.single.await(('SELECT %s FROM prp_mdt_cases WHERE case_id = ?'):format(field), { caseId })
    local arr = json.decode(r and r[field] or '[]') or {}
    if removeId then
        local n = {}; for _, v in ipairs(arr) do if tostring(v.id or v.citizenid or v.chargeId or v) ~= tostring(removeId) then n[#n+1]=v end end; arr=n
    else arr[#arr+1] = value end
    MySQL.update.await(('UPDATE prp_mdt_cases SET %s=? WHERE case_id=?'):format(field), { json.encode(arr), caseId })
    return arr
end

QBCore.Functions.CreateCallback('prp-mdt:server:assignCase', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local P = QBCore.Functions.GetPlayer(src)
    local arr = mutateCaseArray(data.case_id, 'assigned', P.PlayerData.citizenid)
    log(src, 'assign_case', data.case_id, P.PlayerData.citizenid)
    cb({ ok=true, assigned=arr })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:addCasePerson', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local arr = mutateCaseArray(data.case_id, 'people', { citizenid=data.citizenid, role=data.role or 'Involved', added_at=now() })
    log(src, 'case_person', data.case_id, data.citizenid)
    cb({ ok=true, people=arr })
end)


QBCore.Functions.CreateCallback('prp-mdt:server:removeCasePerson', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local arr = mutateCaseArray(data.case_id, 'people', nil, data.citizenid)
    log(src, 'remove_case_person', data.case_id, data.citizenid)
    cb({ ok=true, people=arr })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:addCharge', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local charge
    for _, c in ipairs(Config.Charges) do if c.id == data.chargeId then charge = c end end
    if not charge then return cb({ ok=false }) end
    local arr = mutateCaseArray(data.case_id, 'charges', { chargeId=charge.id, title=charge.title, fine=charge.fine, months=charge.months, added_at=now() })
    log(src, 'add_charge', data.case_id, charge.title)
    cb({ ok=true, charges=arr })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:removeCharge', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local arr = mutateCaseArray(data.case_id, 'charges', nil, data.chargeId)
    log(src, 'remove_charge', data.case_id, data.chargeId)
    cb({ ok=true, charges=arr })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:searchCases', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local q = '%' .. tostring(data.query or '') .. '%'
    local rows = MySQL.query.await('SELECT case_id,title,status,created_by,created_at,updated_at FROM prp_mdt_cases WHERE case_id LIKE ? OR title LIKE ? OR summary LIKE ? ORDER BY updated_at DESC LIMIT 80', { q,q,q }) or {}
    cb({ ok=true, cases=rows })
end)



QBCore.Functions.CreateCallback('prp-mdt:server:getCasesForPlayer', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end

    local cid = tostring((data and data.citizenid) or '')
    if cid == '' then return cb({ ok=true, current={}, past={} }) end

    local rows = MySQL.query.await('SELECT case_id,title,status,people,assigned,created_at,updated_at FROM prp_mdt_cases ORDER BY updated_at DESC LIMIT 300') or {}
    local current, past = {}, {}

    for _, r in ipairs(rows) do
        local attached = false
        local role = 'Attached'

        local people = json.decode(r.people or '[]') or {}
        for _, p in ipairs(people) do
            if tostring(p.citizenid or '') == cid then
                attached = true
                role = p.role or role
                break
            end
        end

        if not attached then
            local assigned = json.decode(r.assigned or '[]') or {}
            for _, a in ipairs(assigned) do
                if tostring(a) == cid or tostring(a.citizenid or '') == cid then
                    attached = true
                    role = 'Assigned Officer'
                    break
                end
            end
        end

        if attached then
            local item = {
                case_id = r.case_id,
                title = r.title,
                status = r.status,
                role = role,
                created_at = r.created_at,
                updated_at = r.updated_at
            }

            if tostring(r.status or 'open') == 'closed' then
                past[#past+1] = item
            else
                current[#current+1] = item
            end
        end
    end

    cb({ ok=true, current=current, past=past })
end)


QBCore.Functions.CreateCallback('prp-mdt:server:getCase', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local r = MySQL.single.await('SELECT * FROM prp_mdt_cases WHERE case_id=?', { data.case_id })
    if not r then return cb({ ok=false }) end
    r.assigned=json.decode(r.assigned or '[]') or {}; r.people=json.decode(r.people or '[]') or {}; r.charges=json.decode(r.charges or '[]') or {}; r.photos=json.decode(r.photos or '[]') or {}
    cb({ ok=true, case=r })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:saveCallsign', function(src, cb, data)
    if not isBoss(src) then return cb({ ok=false, error='boss_only' }) end
    local P = QBCore.Functions.GetPlayer(src)
    local name = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
    MySQL.insert.await('INSERT INTO prp_mdt_callsigns (citizenid,callsign,rank_label,added_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE callsign=VALUES(callsign), rank_label=VALUES(rank_label), added_by=VALUES(added_by)', { data.citizenid, data.callsign, data.rank_label or '', name })
    log(src, 'callsign', data.citizenid, data.callsign)
    cb({ ok=true })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:getApplications', function(src, cb)
    if not isBoss(src) then return cb({ ok=false }) end
    local rows = MySQL.query.await('SELECT * FROM prp_mdt_applications ORDER BY id DESC LIMIT 100') or {}
    cb({ ok=true, applications=rows })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:setApplicationStatus', function(src, cb, data)
    if not isBoss(src) then return cb({ ok=false }) end
    local P = QBCore.Functions.GetPlayer(src); local name = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
    MySQL.update.await('UPDATE prp_mdt_applications SET status=?, reviewed_by=? WHERE id=?', { data.status, name, data.id })
    log(src, 'application_'..tostring(data.status), tostring(data.id), '')
    cb({ ok=true })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:addApplication', function(src, cb, data)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb({ ok=false }) end
    local name = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
    MySQL.insert.await('INSERT INTO prp_mdt_applications (citizenid,name,answers) VALUES (?, ?, ?)', { P.PlayerData.citizenid, name, data.answers or '' })
    cb({ ok=true })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:deleteCase', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local caseId = tostring(data.case_id or '')
    if caseId == '' then return cb({ ok=false, error='missing_case_id' }) end
    MySQL.update.await('DELETE FROM prp_mdt_cases WHERE case_id = ?', { caseId })
    log(src, 'delete_case', caseId, 'Deleted MDT case')
    cb({ ok=true })
end)


local function getEvidenceStashId(caseId)
    caseId = tostring(caseId or ''):gsub('[^%w%-_]', '')
    return 'mdt_evidence_' .. caseId
end

local function readEvidenceItems(caseId)
    local stashId = getEvidenceStashId(caseId)
    local items = {}
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT items FROM inventories WHERE identifier = ? LIMIT 1', { stashId })
    end)
    if ok and rows and rows[1] and rows[1].items then
        items = json.decode(rows[1].items or '[]') or {}
    else
        local ok2, rows2 = pcall(function()
            return MySQL.query.await('SELECT items FROM stashitems WHERE stash = ? LIMIT 1', { stashId })
        end)
        if ok2 and rows2 and rows2[1] and rows2[1].items then
            items = json.decode(rows2[1].items or '[]') or {}
        end
    end
    local out = {}
    for _, item in pairs(items or {}) do
        if item and item.name then
            out[#out+1] = {
                name = item.name,
                label = item.label or (QBCore.Shared.Items[item.name] and QBCore.Shared.Items[item.name].label) or item.name,
                amount = item.amount or item.count or 1,
                slot = item.slot,
                image = item.image or ((QBCore.Shared.Items[item.name] and QBCore.Shared.Items[item.name].image) or (item.name .. '.png')),
                info = item.info or item.metadata or {}
            }
        end
    end
    return out
end

RegisterNetEvent('prp-mdt:server:openEvidenceInventory', function(caseId)
    local src = source
    if not hasAccess(src) then return end
    caseId = tostring(caseId or '')
    if caseId == '' then return end
    local stashId = getEvidenceStashId(caseId)
    local label = 'Report ' .. caseId .. ' Evidence'
    local slots = Config.EvidenceSlots or 40
    local weight = Config.EvidenceWeight or 100000

    -- Newer qb-inventory builds. pcall prevents crashes if your qb/prp inventory uses an older API.
    local opened = false
    local ok = pcall(function()
        if exports['qb-inventory'] and exports['qb-inventory'].OpenInventory then
            exports['qb-inventory']:OpenInventory(src, stashId, { label = label, maxweight = weight, slots = slots })
            opened = true
        end
    end)
    if ok and opened then
        log(src, 'open_evidence_locker', caseId, stashId)
        return
    end

    -- Common older qb-inventory / qb-inventory flow
    TriggerClientEvent('inventory:client:SetCurrentStash', src, stashId)
    TriggerClientEvent('inventory:client:OpenInventory', src, { type = 'stash', id = stashId, title = label, weight = weight, slots = slots })
    TriggerEvent('inventory:server:OpenInventory', 'stash', stashId, { maxweight = weight, slots = slots, label = label })
    log(src, 'open_evidence_locker', caseId, stashId)
end)

QBCore.Functions.CreateCallback('prp-mdt:server:addEvidencePhoto', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local P = QBCore.Functions.GetPlayer(src)
    local name = P and (P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname) or GetPlayerName(src)
    MySQL.insert.await('INSERT INTO prp_mdt_evidence (case_id,type,label,url,data,added_by,added_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.case_id, 'photo', data.label or 'Photo Evidence', data.url or '', '{}', name, P and P.PlayerData.citizenid or ''
    })
    log(src, 'add_evidence_photo', data.case_id, data.label or '')
    cb({ ok=true })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:getEvidence', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    local caseId = tostring(data.case_id or '')
    local photos = MySQL.query.await('SELECT * FROM prp_mdt_evidence WHERE case_id=? AND type=? ORDER BY id DESC', { caseId, 'photo' }) or {}
    local items = readEvidenceItems(caseId)
    cb({ ok=true, photos=photos, items=items, stash=getEvidenceStashId(caseId) })
end)

QBCore.Functions.CreateCallback('prp-mdt:server:deleteEvidence', function(src, cb, data)
    if not hasAccess(src) then return cb({ ok=false }) end
    MySQL.update.await('DELETE FROM prp_mdt_evidence WHERE id=?', { data.id })
    log(src, 'delete_evidence', tostring(data.id), 'Deleted photo evidence')
    cb({ ok=true })
end)
