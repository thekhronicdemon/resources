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
local function sanitizeHtml(html)
    html = tostring(html or '')
    html = html:gsub('<script.->.-</script>', ''):gsub('<iframe.->.-</iframe>', ''):gsub('on%w+%s*=%s*".-"', ''):gsub("on%w+%s*=%s*'.-'", '')
    return html:sub(1, Config.MaxNoteLength or 5000)
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS prp_admin_notes (id INT AUTO_INCREMENT PRIMARY KEY, citizenid VARCHAR(64) NOT NULL, note_html MEDIUMTEXT, note_text TEXT, admin_src VARCHAR(20), admin_name VARCHAR(128), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]])
    pcall(function() MySQL.query.await([[ALTER TABLE prp_admin_notes ADD COLUMN IF NOT EXISTS note_html MEDIUMTEXT]]) end)
    pcall(function() MySQL.query.await([[ALTER TABLE prp_admin_notes ADD COLUMN IF NOT EXISTS note_text TEXT]]) end)
    pcall(function() MySQL.query.await([[ALTER TABLE prp_admin_notes ADD COLUMN IF NOT EXISTS admin_src VARCHAR(20)]]) end)
    pcall(function() MySQL.query.await([[ALTER TABLE prp_admin_notes ADD COLUMN IF NOT EXISTS admin_name VARCHAR(128)]]) end)
    pcall(function() MySQL.query.await([[ALTER TABLE prp_admin_notes ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP]]) end)
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
        local pd=target.PlayerData; profile.online=true; profile.id=targetId; profile.name=GetPlayerName(targetId); profile.job=pd.job and pd.job.name; profile.jobLabel=pd.job and pd.job.label; profile.gang=pd.gang and pd.gang.name; profile.gangLabel=pd.gang and pd.gang.label; profile.money=pd.money or {}; profile.inventory=pd.items or pd.inventory or {}
    else
        local row=MySQL.single.await('SELECT * FROM players WHERE citizenid=? LIMIT 1', {citizenid})
        if row then local char=json.decode(row.charinfo or '{}') or {}; local job=json.decode(row.job or '{}') or {}; local gang=json.decode(row.gang or '{}') or {}; profile.name=((char.firstname or '')..' '..(char.lastname or '')):gsub('^%s*(.-)%s*$','%1'); profile.job=job.name; profile.jobLabel=job.label; profile.gang=gang.name; profile.gangLabel=gang.label; profile.money=json.decode(row.money or '{}') or {}; profile.inventory=json.decode(row.inventory or '[]') or {} end
    end
    profile.notes=MySQL.query.await('SELECT * FROM prp_admin_notes WHERE citizenid=? ORDER BY created_at DESC LIMIT 50', {citizenid}) or {}
    profile.flags=MySQL.query.await('SELECT * FROM prp_admin_flags WHERE citizenid=? AND active=1 ORDER BY created_at DESC LIMIT 50', {citizenid}) or {}
    profile.logs=MySQL.query.await('SELECT * FROM prp_player_logs WHERE citizenid=? ORDER BY created_at DESC LIMIT 50', {citizenid}) or {}
    profile.bans=MySQL.query.await('SELECT *, FROM_UNIXTIME(expire) as expire_label FROM bans WHERE license IN (SELECT license FROM players WHERE citizenid=?) OR name LIKE ? ORDER BY expire DESC LIMIT 25', {citizenid, '%'..(profile.name or '')..'%'}) or {}
    local warnings=MySQL.query.await('SELECT id FROM prp_admin_flags WHERE citizenid=? AND flag_type="warning" AND active=1', {citizenid}) or {}; profile.warn_count=#warnings
    cb(profile)
end)

RegisterNetEvent('prp-adminpanel:server:addNote', function(data)
    local src=source; if not IsPanelAdmin(src) then return end
    local citizenid=tostring(data.citizenid or ''); if citizenid=='' then return end
    local html=sanitizeHtml(data.note_html); local text=tostring(data.note_text or ''):sub(1, Config.MaxNoteLength or 5000); if text=='' then return end
    MySQL.insert.await('INSERT INTO prp_admin_notes (citizenid, note_html, note_text, admin_src, admin_name) VALUES (?, ?, ?, ?, ?)', {citizenid, html, text, tostring(src), adminName(src)})
    audit(src, 'add_note', citizenid, text:sub(1, 250))
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

RegisterNetEvent('prp-adminpanel:server:playerAction', function(data)
    local src = source
    if not IsPanelAdmin(src) then return end
    local action = tostring(data.action or '')
    local target = tonumber(data.id)
    if not target or not GetPlayerName(target) then return end

    local TP = QBCore.Functions.GetPlayer(target)
    local targetMeta = { id = target, citizenid = TP and TP.PlayerData.citizenid or '' }

    if action == 'spectate' then
        TriggerClientEvent('prp-adminpanel:client:spectatePlayer', src, target)
        audit(src, 'spectate_player', targetMeta, ('Spectating ID %s'):format(target))
    elseif action == 'goto' then
        local ped = GetPlayerPed(target)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            TriggerClientEvent('prp-adminpanel:client:teleportToCoords', src, coords)
            audit(src, 'spawn_to_player', targetMeta, ('Teleported to ID %s'):format(target))
        end
    elseif action == 'freeze' then
        TriggerClientEvent('prp-adminpanel:client:toggleFreezeSelf', target)
        audit(src, 'freeze_player_toggle', targetMeta, ('Toggled freeze on ID %s'):format(target))
    elseif action == 'kill' then
        TriggerClientEvent('prp-adminpanel:client:killSelf', target)
        audit(src, 'kill_player', targetMeta, ('Killed ID %s'):format(target))
    elseif action == 'revive' then
        TriggerClientEvent('prp-adminpanel:client:reviveSelf', target)
        audit(src, 'revive_player', targetMeta, ('Revived ID %s'):format(target))
    end
end)

RegisterNetEvent('prp-adminpanel:server:adminMassAction', function(data)
    local src = source
    if not IsDevAdmin(src) then return end
    local action = tostring(data.action or '')

    if action == 'healEveryone' then
        for _, id in ipairs(GetPlayers()) do
            TriggerClientEvent('prp-adminpanel:client:healSelf', tonumber(id))
        end
        audit(src, 'heal_everyone', nil, 'Healed all online players')
    elseif action == 'reviveEveryone' then
        for _, id in ipairs(GetPlayers()) do
            TriggerClientEvent('prp-adminpanel:client:reviveSelf', tonumber(id))
        end
        audit(src, 'revive_everyone', nil, 'Revived all online players')
    end
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

local function findOnlineByCitizenId(citizenid)
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local P = QBCore.Functions.GetPlayer(src)
        if P and P.PlayerData and P.PlayerData.citizenid == citizenid then return src, P end
    end
    return nil, nil
end

RegisterNetEvent('prp-adminpanel:server:editNote', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local id = tonumber(data.id); if not id then return end
    local html = sanitizeHtml(data.note_html); local text = tostring(data.note_text or ''):sub(1, Config.MaxNoteLength or 5000)
    local row = MySQL.single.await('SELECT citizenid FROM prp_admin_notes WHERE id=? LIMIT 1', { id })
    MySQL.update.await('UPDATE prp_admin_notes SET note_html=?, note_text=?, admin_src=?, admin_name=? WHERE id=?', { html, text, tostring(src), adminName(src), id })
    audit(src, 'edit_note', row and row.citizenid or '', ('Edited note #%s'):format(id))
end)

RegisterNetEvent('prp-adminpanel:server:deleteNote', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local id = tonumber(data.id); if not id then return end
    local row = MySQL.single.await('SELECT citizenid FROM prp_admin_notes WHERE id=? LIMIT 1', { id })
    MySQL.update.await('DELETE FROM prp_admin_notes WHERE id=?', { id })
    audit(src, 'delete_note', row and row.citizenid or '', ('Deleted note #%s'):format(id))
end)

RegisterNetEvent('prp-adminpanel:server:editFlag', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local id = tonumber(data.id); if not id then return end
    local reason = tostring(data.reason or ''):sub(1, 500)
    local row = MySQL.single.await('SELECT citizenid FROM prp_admin_flags WHERE id=? LIMIT 1', { id })
    MySQL.update.await('UPDATE prp_admin_flags SET reason=?, admin_src=?, admin_name=? WHERE id=?', { reason, tostring(src), adminName(src), id })
    audit(src, 'edit_flag', row and row.citizenid or '', ('Edited flag/warning #%s'):format(id))
end)

RegisterNetEvent('prp-adminpanel:server:deleteFlag', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local id = tonumber(data.id); if not id then return end
    local row = MySQL.single.await('SELECT citizenid FROM prp_admin_flags WHERE id=? LIMIT 1', { id })
    MySQL.update.await('UPDATE prp_admin_flags SET active=0 WHERE id=?', { id })
    audit(src, 'delete_flag', row and row.citizenid or '', ('Deleted flag/warning #%s'):format(id))
end)

RegisterNetEvent('prp-adminpanel:server:setMoney', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local citizenid = tostring(data.citizenid or '')
    local moneyType = tostring(data.type or '')
    local amount = tonumber(data.amount) or 0
    if citizenid == '' or (moneyType ~= 'cash' and moneyType ~= 'bank' and moneyType ~= 'crypto') then return end
    local targetSrc, P = findOnlineByCitizenId(citizenid)
    if P and P.Functions and P.Functions.SetMoney then
        P.Functions.SetMoney(moneyType, amount, 'admin-panel-set')
    else
        local row = MySQL.single.await('SELECT money FROM players WHERE citizenid=? LIMIT 1', { citizenid })
        if row then
            local money = json.decode(row.money or '{}') or {}
            money[moneyType] = amount
            MySQL.update.await('UPDATE players SET money=? WHERE citizenid=?', { json.encode(money), citizenid })
        end
    end
    audit(src, 'set_money_' .. moneyType, { id = targetSrc or '', citizenid = citizenid }, ('Set %s to %s'):format(moneyType, amount))
end)

RegisterNetEvent('prp-adminpanel:server:addItem', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local citizenid = tostring(data.citizenid or '')
    local item = tostring(data.item or '')
    local amount = tonumber(data.amount) or 1
    if citizenid == '' or item == '' or amount <= 0 then return end
    local targetSrc, P = findOnlineByCitizenId(citizenid)
    if P and P.Functions and P.Functions.AddItem then
        P.Functions.AddItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', targetSrc, QBCore.Shared.Items[item], 'add', amount)
    else
        local row = MySQL.single.await('SELECT inventory FROM players WHERE citizenid=? LIMIT 1', { citizenid })
        if row then
            local inv = json.decode(row.inventory or '[]') or {}
            local added = false
            for _, it in ipairs(inv) do
                if it.name == item then it.amount = (tonumber(it.amount) or tonumber(it.count) or 0) + amount; added = true; break end
            end
            if not added then inv[#inv+1] = { name = item, amount = amount, slot = #inv + 1, info = {} } end
            MySQL.update.await('UPDATE players SET inventory=? WHERE citizenid=?', { json.encode(inv), citizenid })
        end
    end
    audit(src, 'add_item', { id = targetSrc or '', citizenid = citizenid }, ('Added %sx %s'):format(amount, item))
end)

RegisterNetEvent('prp-adminpanel:server:removeItem', function(data)
    local src = source; if not IsPanelAdmin(src) then return end
    local citizenid = tostring(data.citizenid or '')
    local item = tostring(data.item or '')
    local amount = tonumber(data.amount) or 1
    if citizenid == '' or item == '' or amount <= 0 then return end
    local targetSrc, P = findOnlineByCitizenId(citizenid)
    if P and P.Functions and P.Functions.RemoveItem then
        P.Functions.RemoveItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', targetSrc, QBCore.Shared.Items[item], 'remove', amount)
    else
        local row = MySQL.single.await('SELECT inventory FROM players WHERE citizenid=? LIMIT 1', { citizenid })
        if row then
            local inv = json.decode(row.inventory or '[]') or {}
            for i = #inv, 1, -1 do
                local it = inv[i]
                if it.name == item then
                    local current = tonumber(it.amount) or tonumber(it.count) or 0
                    current = current - amount
                    if current <= 0 then table.remove(inv, i) else it.amount = current end
                    break
                end
            end
            MySQL.update.await('UPDATE players SET inventory=? WHERE citizenid=?', { json.encode(inv), citizenid })
        end
    end
    audit(src, 'remove_item', { id = targetSrc or '', citizenid = citizenid }, ('Removed %sx %s'):format(amount, item))
end)
