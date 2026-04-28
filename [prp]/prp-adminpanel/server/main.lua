local QBCore = exports['qb-core']:GetCoreObject()
local Sessions, Activity = {}, {}

local function IsPanelAdmin(src)
    if src == 0 then return true end
    local aceOk = IsPlayerAceAllowed(src, Config.AcePermission)
    if Config.PermissionMode == 'ace' then return aceOk end
    local qbOk = false
    for _, perm in ipairs(Config.QBPermissions) do
        if QBCore.Functions.HasPermission(src, perm) then qbOk = true break end
    end
    if Config.PermissionMode == 'qbcore' then return qbOk end
    return aceOk or qbOk
end

local function IsDevAdmin(src)
    if not Config.EnableDevTools or not IsPanelAdmin(src) then return false end
    if not Config.DevToolsRequireGod then return true end
    return QBCore.Functions.HasPermission(src, 'god') or IsPlayerAceAllowed(src, 'prp.adminpanel.dev')
end
exports('IsPanelAdmin', IsPanelAdmin)

local function getIdentifier(src, idType)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do if identifier:find(idType .. ':') then return identifier end end
    return nil
end
local function adminName(src) return GetPlayerName(src) or ('Admin %s'):format(src) end
local function audit(src, action, target, details)
    MySQL.insert.await('INSERT INTO prp_admin_audit (admin_src, admin_name, action, target_id, target_citizenid, details) VALUES (?, ?, ?, ?, ?, ?)', {
        src, adminName(src), action, tostring(target and target.id or ''), tostring(target and target.citizenid or target or ''), tostring(details or '')
    })
end
local function logPlayer(eventType, src, citizenid, name, details)
    MySQL.insert.await('INSERT INTO prp_player_logs (event_type, src, citizenid, name, details) VALUES (?, ?, ?, ?, ?)', {
        eventType, src and tostring(src) or '', citizenid or '', name or '', details or ''
    })
end
local function normalizeInventory(inv)
    local out = {}
    if type(inv) ~= 'table' then return out end
    for k, item in pairs(inv) do
        if type(item) == 'table' and item.name then
            local name = tostring(item.name)
            local shared = QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[name:lower()] or nil
            out[#out+1] = {
                name = name,
                label = item.label or (shared and shared.label) or name,
                amount = tonumber(item.amount or item.count or 1) or 1,
                slot = tonumber(item.slot or k) or k,
                image = item.image or (shared and shared.image) or (name .. '.png'),
                info = item.info or item.metadata or {}
            }
        end
    end
    table.sort(out, function(a, b) return tonumber(a.slot) < tonumber(b.slot) end)
    return out
end

local function findPlayerByCitizenid(citizenid)
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local P = QBCore.Functions.GetPlayer(src)
        if P and P.PlayerData.citizenid == citizenid then return src, P end
    end
    return nil, nil
end

local function firstFreeSlot(inv)
    local used = {}
    if type(inv) == 'table' then
        for k, item in pairs(inv) do
            if type(item) == 'table' then used[tonumber(item.slot or k) or k] = true end
        end
    end
    for i = 1, 100 do if not used[i] then return i end end
    return #inv + 1
end

local function sanitizeHtml(html)
    html = tostring(html or '')
    html = html:gsub('<script.->.-</script>', ''):gsub('<iframe.->.-</iframe>', ''):gsub('on%w+%s*=%s*".-"', ''):gsub("on%w+%s*=%s*'.-'", '')
    return html:sub(1, Config.MaxNoteLength or 5000)
end

local function columnExists(tableName, columnName)
    local rows = MySQL.query.await(('SHOW COLUMNS FROM `%s` LIKE ?'):format(tableName), { columnName }) or {}
    return rows[1] ~= nil
end

local function ensureNotesTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_admin_notes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(64) NOT NULL,
        note_html MEDIUMTEXT NULL,
        note_text TEXT NULL,
        admin_src VARCHAR(20) NULL,
        admin_name VARCHAR(128) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])

    if not columnExists('prp_admin_notes', 'note_html') then
        MySQL.query.await('ALTER TABLE prp_admin_notes ADD COLUMN note_html MEDIUMTEXT NULL')
    end
    if not columnExists('prp_admin_notes', 'note_text') then
        MySQL.query.await('ALTER TABLE prp_admin_notes ADD COLUMN note_text TEXT NULL')
    end
    if not columnExists('prp_admin_notes', 'admin_src') then
        MySQL.query.await('ALTER TABLE prp_admin_notes ADD COLUMN admin_src VARCHAR(20) NULL')
    end
    if not columnExists('prp_admin_notes', 'admin_name') then
        MySQL.query.await('ALTER TABLE prp_admin_notes ADD COLUMN admin_name VARCHAR(128) NULL')
    end
    if not columnExists('prp_admin_notes', 'created_at') then
        MySQL.query.await('ALTER TABLE prp_admin_notes ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
    end
end

CreateThread(function()
    ensureNotesTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_player_logs (id INT AUTO_INCREMENT PRIMARY KEY, event_type VARCHAR(32), src VARCHAR(20), citizenid VARCHAR(64), name VARCHAR(128), details TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_admin_flags (id INT AUTO_INCREMENT PRIMARY KEY, citizenid VARCHAR(64), flag_type VARCHAR(64), reason TEXT, admin_src VARCHAR(20), admin_name VARCHAR(128), active TINYINT DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_admin_audit (id INT AUTO_INCREMENT PRIMARY KEY, admin_src VARCHAR(20), admin_name VARCHAR(128), action VARCHAR(64), target_id VARCHAR(20), target_citizenid VARCHAR(64), details TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]])
end)

local function getPlayerSummary(src)
    local Player = QBCore.Functions.GetPlayer(src)
    local name = GetPlayerName(src) or 'Unknown'
    if not Player then return { id = src, name = name, citizenid = 'unknown', job = 'unknown', jobLabel = 'Unknown', grade = '', ping = GetPlayerPing(src), online = true } end
    return { id = src, name = name, citizenid = Player.PlayerData.citizenid, job = Player.PlayerData.job and Player.PlayerData.job.name or 'unemployed', jobLabel = Player.PlayerData.job and Player.PlayerData.job.label or 'Unemployed', grade = Player.PlayerData.job and Player.PlayerData.job.grade and Player.PlayerData.job.grade.name or '', ping = GetPlayerPing(src), online = true }
end
local function getOnlinePlayers()
    local players = {}; for _, s in ipairs(GetPlayers()) do players[#players+1] = getPlayerSummary(tonumber(s)) end
    table.sort(players, function(a,b) return a.id < b.id end); return players
end
local function getAdminsOnline()
    local admins = {}; for _, s in ipairs(GetPlayers()) do local src=tonumber(s); if IsPanelAdmin(src) then local P=QBCore.Functions.GetPlayer(src); admins[#admins+1]={id=src,name=GetPlayerName(src),citizenid=P and P.PlayerData.citizenid or 'unknown',ping=GetPlayerPing(src)} end end
    return admins
end
local function recordActivityPeak() local h=tonumber(os.date('%H')) or 0; Activity[h]=math.max(Activity[h] or 0, #GetPlayers()) end
local function buildActivityGraph() recordActivityPeak(); local g={}; for h=0,(Config.ActivityBuckets or 24)-1 do g[#g+1]={hour=h,count=Activity[h] or 0} end; return g end
local function dashboard(src) return {players=getOnlinePlayers(), admins=getAdminsOnline(), activity=buildActivityGraph(), jobButtons=Config.JobButtons, devAccess=IsDevAdmin(src)} end

RegisterNetEvent('prp-adminpanel:server:open', function()
    local src=source; if not IsPanelAdmin(src) then TriggerClientEvent('QBCore:Notify', src, 'Access denied.', 'error') return end
    audit(src, 'open_panel', nil, 'Opened admin panel')
    TriggerClientEvent('prp-adminpanel:client:open', src, dashboard(src))
end)
QBCore.Functions.CreateCallback('prp-adminpanel:server:getDashboard', function(src, cb) if not IsPanelAdmin(src) then cb(false) return end cb(dashboard(src)) end)

QBCore.Functions.CreateCallback('prp-adminpanel:server:searchPlayer', function(src, cb, query)
    if not IsPanelAdmin(src) then cb({}) return end
    query=tostring(query or ''):lower(); local results={}; local seen={}
    for _, p in ipairs(getOnlinePlayers()) do
        if query=='' or tostring(p.id)==query or p.name:lower():find(query,1,true) or (p.citizenid or ''):lower():find(query,1,true) then
            local c=p.citizenid; seen[c]=true
            local notes=MySQL.query.await('SELECT id FROM prp_admin_notes WHERE citizenid=?', {c}) or {}
            local flags=MySQL.query.await('SELECT id FROM prp_admin_flags WHERE citizenid=? AND flag_type="warning" AND active=1', {c}) or {}
            p.notes=notes; p.warn_count=#flags; results[#results+1]=p
        end
    end
    if #query >= 2 then
        local rows=MySQL.query.await('SELECT citizenid, charinfo, job, license, money FROM players WHERE citizenid LIKE ? OR charinfo LIKE ? OR license LIKE ? LIMIT 35', {'%'..query..'%','%'..query..'%','%'..query..'%'}) or {}
        for _, row in ipairs(rows) do if not seen[row.citizenid] then
            local char=json.decode(row.charinfo or '{}') or {}; local job=json.decode(row.job or '{}') or {}
            local notes=MySQL.query.await('SELECT id FROM prp_admin_notes WHERE citizenid=?', {row.citizenid}) or {}; local flags=MySQL.query.await('SELECT id FROM prp_admin_flags WHERE citizenid=? AND flag_type="warning" AND active=1', {row.citizenid}) or {}
            results[#results+1]={id='offline',name=((char.firstname or '')..' '..(char.lastname or '')):gsub('^%s*(.-)%s*$','%1'),citizenid=row.citizenid,job=job.name or 'unknown',jobLabel=job.label or 'Unknown',license=row.license,online=false,notes=notes,warn_count=#flags}
        end end
    end
    cb(results)
end)

QBCore.Functions.CreateCallback('prp-adminpanel:server:getProfile', function(src, cb, data)
    if not IsPanelAdmin(src) then cb({}) return end
    local citizenid=tostring(data.citizenid or ''); local targetId=tonumber(data.id); local profile={citizenid=citizenid, id=data.id, online=false, autoPunishWarnings=Config.AutoPunishWarnings or 3}
    local target = targetId and QBCore.Functions.GetPlayer(targetId) or nil
    if target then
        local pd=target.PlayerData; profile.online=true; profile.id=targetId; profile.name=GetPlayerName(targetId); profile.job=pd.job and pd.job.name; profile.jobLabel=pd.job and pd.job.label; profile.gang=pd.gang and pd.gang.name; profile.gangLabel=pd.gang and pd.gang.label; profile.money=pd.money or {}; profile.inventory=normalizeInventory(pd.items or pd.inventory or {})
    else
        local row=MySQL.single.await('SELECT * FROM players WHERE citizenid=? LIMIT 1', {citizenid})
        if row then local char=json.decode(row.charinfo or '{}') or {}; local job=json.decode(row.job or '{}') or {}; local gang=json.decode(row.gang or '{}') or {}; profile.name=((char.firstname or '')..' '..(char.lastname or '')):gsub('^%s*(.-)%s*$','%1'); profile.job=job.name; profile.jobLabel=job.label; profile.gang=gang.name; profile.gangLabel=gang.label; profile.money=json.decode(row.money or '{}') or {}; profile.inventory=normalizeInventory(json.decode(row.inventory or '[]') or {}) end
    end
    profile.notes=MySQL.query.await('SELECT * FROM prp_admin_notes WHERE citizenid=? ORDER BY created_at DESC LIMIT 50', {citizenid}) or {}
    profile.flags=MySQL.query.await('SELECT * FROM prp_admin_flags WHERE citizenid=? AND active=1 ORDER BY created_at DESC LIMIT 50', {citizenid}) or {}
    profile.logs=MySQL.query.await('SELECT * FROM prp_player_logs WHERE citizenid=? ORDER BY created_at DESC LIMIT 50', {citizenid}) or {}
    profile.bans=MySQL.query.await('SELECT *, FROM_UNIXTIME(expire) as expire_label FROM bans WHERE license IN (SELECT license FROM players WHERE citizenid=?) OR name LIKE ? ORDER BY expire DESC LIMIT 25', {citizenid, '%'..(profile.name or '')..'%'}) or {}
    local warnings=MySQL.query.await('SELECT id FROM prp_admin_flags WHERE citizenid=? AND flag_type="warning" AND active=1', {citizenid}) or {}; profile.warn_count=#warnings
    cb(profile)
end)


QBCore.Functions.CreateCallback('prp-adminpanel:server:addNote', function(src, cb, data)
    if not IsPanelAdmin(src) then cb({ ok = false, error = 'no_permission' }) return end
    data = data or {}

    local citizenid = tostring(data.citizenid or '')
    if citizenid == '' or citizenid == 'nil' then cb({ ok = false, error = 'missing_citizenid' }) return end

    local html = sanitizeHtml(data.note_html or '')
    local text = tostring(data.note_text or ''):sub(1, Config.MaxNoteLength or 5000)
    if text:gsub('%s+', '') == '' then cb({ ok = false, error = 'empty_note' }) return end

    local ok, result = pcall(function()
        ensureNotesTable()
        local insertId = MySQL.insert.await('INSERT INTO prp_admin_notes (citizenid, note_html, note_text, admin_src, admin_name) VALUES (?, ?, ?, ?, ?)', {
            citizenid, html, text, tostring(src), adminName(src)
        })
        local saved = nil
        if insertId then
            saved = MySQL.single.await('SELECT * FROM prp_admin_notes WHERE id = ? LIMIT 1', { insertId })
        end
        if not saved then
            saved = MySQL.single.await('SELECT * FROM prp_admin_notes WHERE citizenid = ? AND admin_src = ? ORDER BY id DESC LIMIT 1', { citizenid, tostring(src) })
        end
        audit(src, 'add_note', citizenid, text:sub(1, 250))
        return saved
    end)

    if not ok then
        print(('^1[prp-adminpanel] Failed to save note for %s: %s^7'):format(citizenid, tostring(result)))
        cb({ ok = false, error = 'database_error_check_console' })
        return
    end

    cb({ ok = true, note = result or { citizenid = citizenid, note_html = html, note_text = text, admin_name = adminName(src), created_at = os.date('%Y-%m-%d %H:%M:%S') }, admin_name = adminName(src) })
end)

QBCore.Functions.CreateCallback('prp-adminpanel:server:getNotes', function(src, cb, citizenid)
    if not IsPanelAdmin(src) then cb({}) return end
    citizenid = tostring(citizenid or '')
    if citizenid == '' then cb({}) return end
    local ok, notes = pcall(function()
        ensureNotesTable()
        return MySQL.query.await('SELECT * FROM prp_admin_notes WHERE citizenid=? ORDER BY created_at DESC, id DESC LIMIT 50', { citizenid }) or {}
    end)
    if not ok then
        print(('^1[prp-adminpanel] Failed to load notes for %s: %s^7'):format(citizenid, tostring(notes)))
        cb({})
        return
    end
    cb(notes)
end)

RegisterNetEvent('prp-adminpanel:server:setMoney', function(data)
    local src = source
    if not IsPanelAdmin(src) then return end
    data = data or {}
    local citizenid = tostring(data.citizenid or '')
    local moneyType = tostring(data.moneyType or '')
    local amount = tonumber(data.amount)
    if citizenid == '' or not amount or amount < 0 then return end

    local allowed = { cash = true, bank = true, crypto = true }
    if not allowed[moneyType] then return end
    amount = math.floor(amount)

    local targetSrc = nil
    for _, s in ipairs(GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(tonumber(s))
        if P and P.PlayerData.citizenid == citizenid then targetSrc = tonumber(s) break end
    end

    if targetSrc then
        local P = QBCore.Functions.GetPlayer(targetSrc)
        local current = tonumber(P.PlayerData.money and P.PlayerData.money[moneyType] or 0) or 0
        if amount > current then
            P.Functions.AddMoney(moneyType, amount - current, 'admin-panel-set-money')
        elseif amount < current then
            P.Functions.RemoveMoney(moneyType, current - amount, 'admin-panel-set-money')
        end
    else
        local row = MySQL.single.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
        if not row then return end
        local money = json.decode(row.money or '{}') or {}
        money[moneyType] = amount
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), citizenid })
    end

    audit(src, 'set_' .. moneyType, citizenid, ('Set %s to %s'):format(moneyType, amount))
end)

QBCore.Functions.CreateCallback('prp-adminpanel:server:addItem', function(src, cb, data)
    if not IsPanelAdmin(src) then cb({ ok = false, error = 'no_permission' }) return end
    data = data or {}
    local citizenid = tostring(data.citizenid or '')
    local itemName = tostring(data.itemName or ''):lower():gsub('%s+', '')
    local amount = math.floor(tonumber(data.amount) or 0)
    if citizenid == '' or itemName == '' or amount <= 0 then cb({ ok = false, error = 'missing_data' }) return end

    local shared = QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[itemName]
    if not shared then cb({ ok = false, error = 'invalid_item' }) return end

    local targetSrc, P = findPlayerByCitizenid(citizenid)
    if P then
        local ok = P.Functions.AddItem(itemName, amount, false, {})
        if not ok then cb({ ok = false, error = 'add_failed' }) return end
        TriggerClientEvent('inventory:client:ItemBox', targetSrc, shared, 'add', amount)
    else
        local row = MySQL.single.await('SELECT inventory FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
        if not row then cb({ ok = false, error = 'player_not_found' }) return end
        local inv = json.decode(row.inventory or '[]') or {}
        local found = false
        for k, item in pairs(inv) do
            if type(item) == 'table' and tostring(item.name):lower() == itemName then
                item.amount = (tonumber(item.amount or item.count or 0) or 0) + amount
                found = true
                break
            end
        end
        if not found then
            inv[#inv + 1] = { name = itemName, amount = amount, info = {}, type = shared.type or 'item', slot = firstFreeSlot(inv) }
        end
        MySQL.update.await('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(inv), citizenid })
    end

    audit(src, 'add_item', citizenid, ('Added %sx %s'):format(amount, itemName))
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('prp-adminpanel:server:removeItem', function(src, cb, data)
    if not IsPanelAdmin(src) then cb({ ok = false, error = 'no_permission' }) return end
    data = data or {}
    local citizenid = tostring(data.citizenid or '')
    local itemName = tostring(data.itemName or ''):lower():gsub('%s+', '')
    local amount = math.floor(tonumber(data.amount) or 0)
    local slot = tonumber(data.slot)
    if citizenid == '' or itemName == '' or amount <= 0 then cb({ ok = false, error = 'missing_data' }) return end

    local shared = QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[itemName] or { label = itemName, image = itemName .. '.png' }
    local targetSrc, P = findPlayerByCitizenid(citizenid)
    if P then
        local ok = P.Functions.RemoveItem(itemName, amount, slot)
        if not ok then cb({ ok = false, error = 'remove_failed' }) return end
        TriggerClientEvent('inventory:client:ItemBox', targetSrc, shared, 'remove', amount)
    else
        local row = MySQL.single.await('SELECT inventory FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
        if not row then cb({ ok = false, error = 'player_not_found' }) return end
        local inv = json.decode(row.inventory or '[]') or {}
        local removed = false
        for k, item in pairs(inv) do
            if type(item) == 'table' and tostring(item.name):lower() == itemName and (not slot or tonumber(item.slot or k) == slot) then
                local current = tonumber(item.amount or item.count or 0) or 0
                local newAmount = current - amount
                if newAmount > 0 then item.amount = newAmount else inv[k] = nil end
                removed = true
                break
            end
        end
        if not removed then cb({ ok = false, error = 'item_not_found' }) return end
        local packed = {}
        for _, item in pairs(inv) do if type(item) == 'table' then packed[#packed + 1] = item end end
        MySQL.update.await('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(packed), citizenid })
    end

    audit(src, 'remove_item', citizenid, ('Removed %sx %s%s'):format(amount, itemName, slot and (' from slot '..slot) or ''))
    cb({ ok = true })
end)

RegisterNetEvent('prp-adminpanel:server:addFlag', function(data)
    local src=source; if not IsPanelAdmin(src) then return end
    local citizenid=tostring(data.citizenid or ''); local flag=tostring(data.flagType or 'warning'); local reason=tostring(data.reason or 'No reason supplied.'):sub(1,500)
    MySQL.insert.await('INSERT INTO prp_admin_flags (citizenid, flag_type, reason, admin_src, admin_name) VALUES (?, ?, ?, ?, ?)', {citizenid, flag, reason, tostring(src), adminName(src)})
    audit(src, 'add_flag_'..flag, citizenid, reason)
    local warnings=MySQL.query.await('SELECT id FROM prp_admin_flags WHERE citizenid=? AND flag_type="warning" AND active=1', {citizenid}) or {}
    if flag == 'warning' and Config.AutoPunishWarnings and #warnings >= Config.AutoPunishWarnings then
        for _, s in ipairs(GetPlayers()) do local P=QBCore.Functions.GetPlayer(tonumber(s)); if P and P.PlayerData.citizenid==citizenid then DropPlayer(tonumber(s), ('Auto punishment: %s warnings reached.'):format(#warnings)); audit(src, 'auto_punish_kick', citizenid, ('Warnings reached %s'):format(#warnings)) end end
    end
end)
RegisterNetEvent('prp-adminpanel:server:kick', function(target, reason)
    local src=source; if not IsPanelAdmin(src) then return end; target=tonumber(target); if not target or not GetPlayerName(target) then return end
    local P=QBCore.Functions.GetPlayer(target); audit(src,'kick',{id=target,citizenid=P and P.PlayerData.citizenid or ''},reason or 'Kicked by admin.'); DropPlayer(target, reason or 'Kicked by admin.')
end)
RegisterNetEvent('prp-adminpanel:server:ban', function(target, reason, hours)
    local src=source; if not IsPanelAdmin(src) then return end; target=tonumber(target); if not target or not GetPlayerName(target) then return end
    reason=reason or 'Banned by admin.'; hours=tonumber(hours) or Config.DefaultBanHours; local expire = hours <= 0 and 2147483647 or os.time() + (hours*3600); local P=QBCore.Functions.GetPlayer(target)
    MySQL.insert.await('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {GetPlayerName(target),getIdentifier(target,'license') or 'unknown',getIdentifier(target,'discord') or 'unknown',getIdentifier(target,'ip') or 'unknown',reason,expire,adminName(src)})
    audit(src,'ban',{id=target,citizenid=P and P.PlayerData.citizenid or ''},reason); DropPlayer(target, ('Banned: %s'):format(reason))
end)

QBCore.Functions.CreateCallback('prp-adminpanel:server:getLogs', function(src, cb, data) if not IsPanelAdmin(src) then cb({}) return end local t=tostring(data.type or ''); if t~='' then cb(MySQL.query.await('SELECT * FROM prp_player_logs WHERE event_type=? ORDER BY created_at DESC LIMIT 150',{t}) or {}) else cb(MySQL.query.await('SELECT * FROM prp_player_logs ORDER BY created_at DESC LIMIT 150') or {}) end end)
QBCore.Functions.CreateCallback('prp-adminpanel:server:getAudit', function(src, cb) if not IsPanelAdmin(src) then cb({}) return end cb(MySQL.query.await('SELECT * FROM prp_admin_audit ORDER BY created_at DESC LIMIT 150') or {}) end)

RegisterNetEvent('prp-adminpanel:server:deathLog', function(details)
    local src=source; local P=QBCore.Functions.GetPlayer(src); logPlayer('death', src, P and P.PlayerData.citizenid or '', GetPlayerName(src), tostring(details or 'Player death'))
end)
AddEventHandler('playerJoining', function() Sessions[source]=os.time(); recordActivityPeak() end)
AddEventHandler('playerDropped', function(reason)
    local src=source; local P=QBCore.Functions.GetPlayer(src); local played=Sessions[src] and (os.time()-Sessions[src]) or 0
    logPlayer('drop', src, P and P.PlayerData.citizenid or '', GetPlayerName(src), ('Reason: %s | Session: %s seconds'):format(reason or 'unknown', played)); Sessions[src]=nil; recordActivityPeak()
end)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src=source; local P=QBCore.Functions.GetPlayer(src); logPlayer('join', src, P and P.PlayerData.citizenid or '', GetPlayerName(src), 'Player loaded into server'); Sessions[src]=os.time(); recordActivityPeak()
end)
CreateThread(function() while true do recordActivityPeak(); Wait((Config.ActivitySampleMinutes or 5)*60*1000) end end)
RegisterCommand(Config.Command, function(src) if src<=0 then return end if not IsPanelAdmin(src) then TriggerClientEvent('QBCore:Notify',src,'Access denied.','error') return end TriggerClientEvent('prp-adminpanel:client:requestOpen', src) end, false)
