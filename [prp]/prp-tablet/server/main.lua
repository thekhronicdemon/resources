local QBCore = exports['qb-core']:GetCoreObject()
local TabletMining = {}
local TabletTablesReady = false
local BossLocationCache = nil

local DefaultMdtCharges = {
    { category = 'Controlled Substance', label = 'Possession of Controlled Substance (Marijuana)', scope = 'Principal', fine = 1000, jail = 0, sortOrder = 10, description = 'Simple possession of marijuana.' },
    { category = 'Controlled Substance', label = 'Possession with Intent to Distribute (Marijuana)', scope = 'Principal', fine = 5000, jail = 26, sortOrder = 20, description = 'Possession of marijuana with intent to distribute.' },
    { category = 'Controlled Substance', label = 'Manufacture of Controlled Substance (Marijuana)', scope = 'Principal', fine = 25000, jail = 30, sortOrder = 30, description = 'Production or manufacture of marijuana products.' },
    { category = 'Controlled Substance', label = 'Possession of Controlled Substance (Meth)', scope = 'Principal', fine = 2500, jail = 15, sortOrder = 40, description = 'Simple possession of methamphetamine.' },
    { category = 'Controlled Substance', label = 'Possession with Intent to Distribute (Meth)', scope = 'Principal', fine = 9000, jail = 34, sortOrder = 50, description = 'Possession of methamphetamine with distribution intent.' },
    { category = 'Controlled Substance', label = 'Manufacture of Controlled Substance (Meth)', scope = 'Principal', fine = 30000, jail = 40, sortOrder = 60, description = 'Production or manufacture of methamphetamine.' },
    { category = 'Weapons', label = 'Criminal Possession of a Firearm Class 1', scope = 'Principal', fine = 5000, jail = 5, sortOrder = 70, description = 'Possession of a prohibited Class 1 firearm.' },
    { category = 'Weapons', label = 'Unlawful Discharge of a Firearm', scope = 'Principal', fine = 4000, jail = 8, sortOrder = 80, description = 'Discharging a firearm in an unlawful manner.' },
    { category = 'Weapons', label = 'Weapons Trafficking', scope = 'Principal', fine = 15000, jail = 28, sortOrder = 90, description = 'Transporting or selling illegal weapons.' },
    { category = 'Violent Crime', label = 'Hostage Taking', scope = 'Principal', fine = 7500, jail = 15, sortOrder = 100, description = 'Holding another person against their will.' },
    { category = 'Violent Crime', label = 'Attempted Murder', scope = 'Principal', fine = 18000, jail = 40, sortOrder = 110, description = 'Attempting to unlawfully kill another person.' },
    { category = 'Violent Crime', label = 'Assault on Government Employee', scope = 'Principal', fine = 8500, jail = 18, sortOrder = 120, description = 'Violent assault against state or city staff.' },
    { category = 'Property Crime', label = 'Armed Robbery', scope = 'Principal', fine = 12000, jail = 24, sortOrder = 130, description = 'Robbery while armed with a deadly weapon.' },
    { category = 'Property Crime', label = 'Bank Robbery', scope = 'Principal', fine = 25000, jail = 45, sortOrder = 140, description = 'Robbery or attempted robbery of a bank.' },
    { category = 'Property Crime', label = 'Possession of Stolen Property', scope = 'Principal', fine = 3000, jail = 6, sortOrder = 150, description = 'Knowingly possessing stolen property.' },
    { category = 'Traffic', label = 'Street Racing', scope = 'Principal', fine = 5000, jail = 4, sortOrder = 160, description = 'Participating in unlawful speed competitions.' },
    { category = 'Traffic', label = 'Evading Police', scope = 'Principal', fine = 4500, jail = 10, sortOrder = 170, description = 'Fleeing from lawful police pursuit.' },
    { category = 'Traffic', label = 'Reckless Endangerment', scope = 'Principal', fine = 3500, jail = 7, sortOrder = 180, description = 'Creating a substantial risk to public safety.' },
    { category = 'Conspiracy', label = 'Accessory to Controlled Substance Distribution', scope = 'Accessory', fine = 3500, jail = 19, sortOrder = 190, description = 'Assisting a controlled substance distribution offense.' },
    { category = 'Conspiracy', label = 'Conspiracy to Manufacture Controlled Substance', scope = 'Conspiracy', fine = 10000, jail = 15, sortOrder = 200, description = 'Coordinating a manufacturing offense before completion.' },
}

local function Notify(source, message, notifyType)
    TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
end

local function Trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function CopyTable(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, data in pairs(value) do
        copy[key] = CopyTable(data)
    end

    return copy
end

local function EncodeJson(value)
    if value == nil then return nil end
    local ok, encoded = pcall(json.encode, value)
    return ok and encoded or nil
end

local function DecodeStoredTable(value)
    if type(value) == 'table' then
        return value
    end
    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

local function Lower(value)
    return Trim(value):lower()
end

local function IsLeoJob(job)
    job = type(job) == 'table' and job or {}
    if job.type == 'leo' then
        return true
    end

    local name = Lower(job.name or '')
    local label = Lower(job.label or '')
    local combined = ('%s %s'):format(name, label)

    return combined:find('police', 1, true) ~= nil
        or combined:find('law enforcement', 1, true) ~= nil
        or combined:find('sheriff', 1, true) ~= nil
        or combined:find('trooper', 1, true) ~= nil
        or combined:find('marshal', 1, true) ~= nil
        or combined:find('ranger', 1, true) ~= nil
        or combined:find('highway patrol', 1, true) ~= nil
        or name == 'lspd'
        or name == 'bcso'
        or name == 'sasp'
        or name == 'sahp'
        or name == 'police'
end

local function HasAdminAccess(source)
    return QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')
end

local function SeedDefaultCharges()
    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM prp_tablet_mdt_charges', {})) or 0
    if count > 0 then return end

    for _, charge in ipairs(DefaultMdtCharges) do
        MySQL.insert.await([[
            INSERT INTO prp_tablet_mdt_charges (category, label, scope, fine_amount, jail_time, description, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            charge.category,
            charge.label,
            charge.scope,
            tonumber(charge.fine) or 0,
            tonumber(charge.jail) or 0,
            charge.description or '',
            tonumber(charge.sortOrder) or 0,
        })
    end
end

local function EnsureTabletTables()
    if TabletTablesReady then return end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_ads (
            id INT NOT NULL AUTO_INCREMENT,
            job_name VARCHAR(50) NULL DEFAULT NULL,
            author_citizenid VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL,
            title VARCHAR(80) NOT NULL,
            body TEXT NOT NULL,
            background_url VARCHAR(255) NULL DEFAULT NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY job_name (job_name)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_business_chat (
            id INT NOT NULL AUTO_INCREMENT,
            job_name VARCHAR(50) NOT NULL,
            author_citizenid VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL,
            message TEXT NOT NULL,
            reply_to_id INT NULL DEFAULT NULL,
            edited_at TIMESTAMP NULL DEFAULT NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY job_name (job_name)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_mdt_profiles (
            citizenid VARCHAR(50) NOT NULL,
            note TEXT NULL,
            warrant_active TINYINT(1) NOT NULL DEFAULT 0,
            warrant_note TEXT NULL,
            mugshot_url VARCHAR(255) NULL DEFAULT NULL,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_mdt_reports (
            id INT NOT NULL AUTO_INCREMENT,
            author_citizenid VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL,
            suspect_citizenid VARCHAR(50) NULL DEFAULT NULL,
            suspect_name VARCHAR(100) NULL DEFAULT NULL,
            report_type VARCHAR(40) NOT NULL DEFAULT 'Incident',
            title VARCHAR(100) NOT NULL,
            details TEXT NULL,
            charges TEXT NULL,
            charges_json LONGTEXT NULL,
            warrants TEXT NULL,
            evidence_json LONGTEXT NULL,
            officers_json LONGTEXT NULL,
            fine_amount INT NOT NULL DEFAULT 0,
            jail_time INT NOT NULL DEFAULT 0,
            status VARCHAR(25) NOT NULL DEFAULT 'Open',
            incident_date VARCHAR(40) NULL DEFAULT NULL,
            due_date VARCHAR(40) NULL DEFAULT NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY suspect_citizenid (suspect_citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_devices (
            citizenid VARCHAR(50) NOT NULL,
            crypto_drive LONGTEXT NULL,
            app_state LONGTEXT NULL,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_mdt_charges (
            id INT NOT NULL AUTO_INCREMENT,
            category VARCHAR(80) NOT NULL,
            label VARCHAR(120) NOT NULL,
            scope VARCHAR(25) NOT NULL DEFAULT 'Principal',
            fine_amount INT NOT NULL DEFAULT 0,
            jail_time INT NOT NULL DEFAULT 0,
            description TEXT NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_mdt_profile_entries (
            id INT NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            author_citizenid VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL,
            entry_type VARCHAR(30) NOT NULL DEFAULT 'Note',
            title VARCHAR(120) NOT NULL,
            body TEXT NOT NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY citizenid (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_police_warnings (
            id INT NOT NULL AUTO_INCREMENT,
            officer_citizenid VARCHAR(50) NOT NULL,
            officer_name VARCHAR(100) NOT NULL,
            issuer_citizenid VARCHAR(50) NOT NULL,
            issuer_name VARCHAR(100) NOT NULL,
            title VARCHAR(120) NOT NULL,
            body TEXT NOT NULL,
            severity VARCHAR(25) NOT NULL DEFAULT 'Warning',
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY officer_citizenid (officer_citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prp_tablet_deleted_records (
            id INT NOT NULL AUTO_INCREMENT,
            record_type VARCHAR(30) NOT NULL,
            target_citizenid VARCHAR(50) NULL DEFAULT NULL,
            target_name VARCHAR(100) NULL DEFAULT NULL,
            record_id VARCHAR(50) NULL DEFAULT NULL,
            title VARCHAR(120) NOT NULL,
            payload_json LONGTEXT NULL,
            deleted_by_citizenid VARCHAR(50) NOT NULL,
            deleted_by_name VARCHAR(100) NOT NULL,
            deleted_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY target_citizenid (target_citizenid)
        )
    ]])

    pcall(function()
        MySQL.query.await('ALTER TABLE prp_tablet_ads ADD COLUMN background_url VARCHAR(255) NULL DEFAULT NULL', {})
    end)

    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_business_chat ADD COLUMN reply_to_id INT NULL DEFAULT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_business_chat ADD COLUMN edited_at TIMESTAMP NULL DEFAULT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_mdt_profiles ADD COLUMN mugshot_url VARCHAR(255) NULL DEFAULT NULL', {}) end)
    pcall(function() MySQL.query.await("ALTER TABLE prp_tablet_mdt_reports ADD COLUMN report_type VARCHAR(40) NOT NULL DEFAULT 'Incident'", {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_mdt_reports ADD COLUMN charges_json LONGTEXT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_mdt_reports ADD COLUMN evidence_json LONGTEXT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_mdt_reports ADD COLUMN officers_json LONGTEXT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_mdt_reports ADD COLUMN incident_date VARCHAR(40) NULL DEFAULT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE prp_tablet_mdt_reports ADD COLUMN due_date VARCHAR(40) NULL DEFAULT NULL', {}) end)

    SeedDefaultCharges()

    TabletTablesReady = true
end

local function LoadBossLocations()
    if BossLocationCache ~= nil then
        return BossLocationCache
    end

    local file = LoadResourceFile('qb-management', 'config.lua')
    if not file or file == '' then
        BossLocationCache = {}
        return BossLocationCache
    end

    local env = {
        Config = {},
        vector3 = function(x, y, z)
            return { x = x, y = y, z = z }
        end,
        GetConvar = function(_, default)
            return default
        end
    }

    local chunk, err = load(file, '@qb-management/config.lua', 't', env)
    if not chunk then
        print(('[prp-tablet] Failed to parse qb-management config: %s'):format(err or 'unknown error'))
        BossLocationCache = {}
        return BossLocationCache
    end

    local ok, runErr = pcall(chunk)
    if not ok then
        print(('[prp-tablet] Failed to load qb-management config: %s'):format(runErr or 'unknown error'))
        BossLocationCache = {}
        return BossLocationCache
    end

    BossLocationCache = env.Config.BossMenus or {}
    return BossLocationCache
end

local function GetBusinessWaypoint(jobName)
    local menus = LoadBossLocations()[jobName]
    if type(menus) ~= 'table' or type(menus[1]) ~= 'table' then
        return nil
    end

    return {
        x = tonumber(menus[1].x) or 0.0,
        y = tonumber(menus[1].y) or 0.0,
        z = tonumber(menus[1].z) or 0.0,
    }
end

local function GetTabletItem(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return nil end

    local fallback = nil
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name and item.name:lower() == 'tablet' then
            if type(item.info) == 'table' and item.info.cryptoDrive then
                return item
            end
            fallback = fallback or item
        end
    end

    return fallback
end

local function SetInventoryItemInfo(Player, slot, info)
    if not Player or not slot then return false end

    slot = tonumber(slot)
    if not slot then return false end
    local items = Player.PlayerData.items or {}
    for key, item in pairs(items) do
        if item and tonumber(item.slot) == slot then
            items[key].info = info or {}
            if items[key].info.description then
                items[key].description = items[key].info.description
            end
            Player.Functions.SetPlayerData('items', items)
            return true
        end
    end

    return false
end

local function GetTabletDriveDescription(drive)
    if type(drive) ~= 'table' then
        return 'No crypto drive inserted'
    end

    return ('Crypto drive installed: %s'):format(drive.label or drive.item or 'Crypto USB')
end

local function GetTabletDeviceState(citizenid)
    EnsureTabletTables()
    citizenid = Trim(citizenid)
    if citizenid == '' then
        return {
            citizenid = '',
            cryptoDrive = nil,
            appState = {},
        }
    end

    MySQL.insert.await(
        'INSERT INTO prp_tablet_devices (citizenid) VALUES (?) ON DUPLICATE KEY UPDATE citizenid = citizenid',
        { citizenid }
    )

    local row = MySQL.single.await(
        'SELECT crypto_drive AS cryptoDrive, app_state AS appState FROM prp_tablet_devices WHERE citizenid = ?',
        { citizenid }
    ) or {}

    local cryptoDrive = DecodeStoredTable(row.cryptoDrive)
    if next(cryptoDrive) == nil then
        cryptoDrive = nil
    end

    return {
        citizenid = citizenid,
        cryptoDrive = cryptoDrive,
        appState = DecodeStoredTable(row.appState),
    }
end

local function SaveTabletDeviceState(citizenid, state)
    citizenid = Trim(citizenid)
    if citizenid == '' then return end

    state = state or {}
    MySQL.insert.await(
        'INSERT INTO prp_tablet_devices (citizenid, crypto_drive, app_state) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE crypto_drive = VALUES(crypto_drive), app_state = VALUES(app_state)',
        {
            citizenid,
            state.cryptoDrive and EncodeJson(state.cryptoDrive) or nil,
            state.appState and EncodeJson(state.appState) or nil,
        }
    )
end

local function SetTabletCryptoDrive(citizenid, drive)
    local state = GetTabletDeviceState(citizenid)
    state.cryptoDrive = type(drive) == 'table' and CopyTable(drive) or nil
    SaveTabletDeviceState(citizenid, state)
    return state
end

local function SyncTabletDriveState(Player)
    if not Player or not Player.PlayerData then
        return nil, nil, {}
    end

    local citizenid = Player.PlayerData.citizenid
    local device = GetTabletDeviceState(citizenid)
    local tablet = GetTabletItem(Player)
    local info = tablet and type(tablet.info) == 'table' and CopyTable(tablet.info) or {}
    local metadataDrive = type(info.cryptoDrive) == 'table' and CopyTable(info.cryptoDrive) or nil

    if metadataDrive then
        if not device.cryptoDrive or EncodeJson(device.cryptoDrive) ~= EncodeJson(metadataDrive) then
            SetTabletCryptoDrive(citizenid, metadataDrive)
        end
        info.description = GetTabletDriveDescription(metadataDrive)
        return metadataDrive, tablet, info
    end

    if device.cryptoDrive then
        info.cryptoDrive = CopyTable(device.cryptoDrive)
        info.description = GetTabletDriveDescription(device.cryptoDrive)
        if tablet and tablet.slot then
            SetInventoryItemInfo(Player, tablet.slot, info)
        end
        return CopyTable(device.cryptoDrive), tablet, info
    end

    info.description = GetTabletDriveDescription(nil)
    return nil, tablet, info
end

local function AddCryptoTransaction(citizenid, title, message)
    pcall(function()
        MySQL.insert('INSERT INTO crypto_transactions (citizenid, title, message) VALUES (?, ?, ?)', {
            citizenid,
            title,
            message
        })
    end)
end

local function GetTabletMiningJobs(source)
    local jobs = {}
    local running = TabletMining[source]
    if type(running) ~= 'table' then return jobs end

    local now = os.time()
    for _, job in pairs(running) do
        if type(job) == 'table' then
            local seconds = tonumber(job.seconds) or 0
            local startedAt = tonumber(job.startedAt) or now
            local finishesAt = tonumber(job.finishesAt) or (startedAt + seconds)
            local remaining = math.max(finishesAt - now, 0)
            local elapsed = math.max(now - startedAt, 0)
            local progress = seconds > 0 and math.floor(math.min((elapsed / seconds) * 100, 100)) or 0

            jobs[#jobs + 1] = {
                id = job.id,
                item = job.item,
                label = job.label or 'Crypto USB',
                image = job.image,
                startedAt = startedAt,
                finishesAt = finishesAt,
                seconds = seconds,
                remaining = remaining,
                progress = progress
            }
        end
    end

    table.sort(jobs, function(a, b)
        return (a.finishesAt or 0) < (b.finishesAt or 0)
    end)

    return jobs
end

local function RemoveTabletMiningJob(source, jobId)
    local running = TabletMining[source]
    if type(running) ~= 'table' then return end

    for i = #running, 1, -1 do
        if running[i].id == jobId then
            table.remove(running, i)
            break
        end
    end

    if #running == 0 then
        TabletMining[source] = nil
    end
end

local function GetTabletStatus(source, Player)
    local drive = nil
    if Player and Player.PlayerData then
        drive = SyncTabletDriveState(Player)
    end

    return {
        cryptoDrive = drive,
        activeMining = GetTabletMiningJobs(source)
    }
end

local function GetPermissionData(source, Player)
    local job = Player and Player.PlayerData and Player.PlayerData.job or {}
    return {
        admin = HasAdminAccess(source),
        leo = IsLeoJob(job),
    }
end

local function GetBusinessContext(Player)
    if not Player then return nil end
    local job = Player.PlayerData.job or {}
    if not job.name or job.name == 'unemployed' then return nil end
    return job
end

local function GetCharacterName(charinfo)
    charinfo = charinfo or {}
    return ((charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')):gsub('%s+$', '')
end

local function FormatEmployee(Target)
    local charinfo = Target.PlayerData.charinfo or {}
    local job = Target.PlayerData.job or {}
    local grade = job.grade or {}

    return {
        citizenid = Target.PlayerData.citizenid,
        name = GetCharacterName(charinfo),
        grade = grade.name or tostring(grade.level or 0),
        gradeLevel = tonumber(grade.level) or 0,
        salary = tonumber(job.payment) or 0,
        isBoss = job.isboss == true,
        online = Target.PlayerData.source ~= nil,
        duty = job.onduty == true
    }
end

local function GetSocietyBalance(jobName)
    if GetResourceState('qb-banking') ~= 'started' then return 0 end

    local ok, balance = pcall(function()
        return exports['qb-banking']:GetAccountBalance(jobName)
    end)

    if not ok then return 0 end
    return tonumber(balance) or 0
end

local function GetDailyIncome(jobName)
    local ok, total = pcall(function()
        return MySQL.scalar.await(
            "SELECT COALESCE(SUM(amount), 0) FROM bank_statements WHERE account_name = ? AND statement_type = 'deposit' AND DATE(date) = CURDATE()",
            { jobName }
        )
    end)

    if not ok then return 0 end
    return tonumber(total) or 0
end

local function IsHttpUrl(value)
    local text = Trim(value)
    return text == '' or text:match('^https?://') ~= nil
end

local CanManagePoliceWarnings

local function BuildAdvertisements(limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 15), 50))
    local rows = MySQL.query.await(
        ('SELECT id, job_name AS jobName, author_citizenid AS authorCitizenId, author_name AS authorName, title, body, background_url AS backgroundUrl, created_at AS createdAt FROM prp_tablet_ads ORDER BY created_at DESC LIMIT %s'):format(amount),
        {}
    ) or {}

    for _, row in ipairs(rows) do
        row.jobName = row.jobName or 'City'
    end

    return rows
end

local function BuildBusinessMessages(jobName, limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 20), 50))
    local rows = MySQL.query.await(
        ([[
            SELECT
                chat.id,
                chat.author_citizenid AS authorCitizenId,
                chat.author_name AS authorName,
                chat.message,
                chat.reply_to_id AS replyToId,
                chat.edited_at AS editedAt,
                chat.created_at AS createdAt,
                parent.author_name AS replyAuthorName,
                parent.message AS replyMessage
            FROM prp_tablet_business_chat chat
            LEFT JOIN prp_tablet_business_chat parent ON parent.id = chat.reply_to_id
            WHERE chat.job_name = ?
            ORDER BY chat.created_at DESC
            LIMIT %s
        ]]):format(amount),
        { jobName }
    ) or {}

    return rows
end

local function CanManageBusinessMessages(source, Player, authorCitizenId)
    if HasAdminAccess(source) then
        return true
    end

    local job = GetBusinessContext(Player)
    if not job then
        return false
    end

    return job.isboss == true or Player.PlayerData.citizenid == Trim(authorCitizenId)
end

local function GetBusinessMessageById(messageId)
    messageId = tonumber(messageId)
    if not messageId then return nil end

    return MySQL.single.await([[
        SELECT id, job_name AS jobName, author_citizenid AS authorCitizenId, message, reply_to_id AS replyToId
        FROM prp_tablet_business_chat
        WHERE id = ?
    ]], {
        messageId
    })
end

local function CanViewDeletedRecords(source, Player)
    if HasAdminAccess(source) then
        return true
    end

    local job = Player and Player.PlayerData and Player.PlayerData.job or {}
    return IsLeoJob(job) and (job.isboss == true or CanManagePoliceWarnings(source, Player))
end

local function LogDeletedRecord(recordType, targetCitizenId, targetName, recordId, title, payload, Player)
    if not Player or not Player.PlayerData then return end

    EnsureTabletTables()
    MySQL.insert.await([[
        INSERT INTO prp_tablet_deleted_records (record_type, target_citizenid, target_name, record_id, title, payload_json, deleted_by_citizenid, deleted_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        Trim(recordType),
        Trim(targetCitizenId),
        Trim(targetName),
        Trim(recordId),
        Trim(title),
        EncodeJson(payload or {}),
        Player.PlayerData.citizenid,
        GetCharacterName(Player.PlayerData.charinfo),
    })
end

local function BuildBusinessData(Player)
    local job = GetBusinessContext(Player)
    if not job then
        return { success = false, message = 'You are not employed by a business.', employees = {}, messages = {} }
    end

    local employees = {}
    local query = '%"name":"' .. job.name .. '"%'
    local players = MySQL.query.await('SELECT citizenid FROM players WHERE job LIKE ?', { query }) or {}
    for _, value in pairs(players) do
        local Target = QBCore.Functions.GetPlayerByCitizenId(value.citizenid) or QBCore.Functions.GetOfflinePlayerByCitizenId(value.citizenid)
        if Target and Target.PlayerData.job and Target.PlayerData.job.name == job.name then
            employees[#employees + 1] = FormatEmployee(Target)
        end
    end

    table.sort(employees, function(a, b)
        if a.gradeLevel == b.gradeLevel then
            return a.name < b.name
        end
        return a.gradeLevel > b.gradeLevel
    end)

    return {
        success = true,
        job = {
            name = job.name,
            label = job.label or job.name,
            role = (job.grade and job.grade.name) or tostring(job.grade and job.grade.level or 0),
            salary = tonumber(job.payment) or 0,
            gradeLevel = tonumber(job.grade and job.grade.level) or 0,
            isBoss = job.isboss == true,
            duty = job.onduty == true,
            dailyIncome = GetDailyIncome(job.name),
            balance = GetSocietyBalance(job.name),
            waypoint = GetBusinessWaypoint(job.name),
        },
        employees = employees,
        messages = BuildBusinessMessages(job.name, 24)
    }
end

local function BuildChargeCatalog()
    EnsureTabletTables()
    local rows = MySQL.query.await([[
        SELECT id, category, label, scope, fine_amount AS fineAmount, jail_time AS jailTime, description
        FROM prp_tablet_mdt_charges
        WHERE active = 1
        ORDER BY category ASC, sort_order ASC, label ASC
    ]], {}) or {}

    local charges = {}
    for _, row in ipairs(rows) do
        charges[#charges + 1] = {
            id = tonumber(row.id) or 0,
            category = row.category or 'General',
            label = row.label or 'Charge',
            scope = row.scope or 'Principal',
            fineAmount = tonumber(row.fineAmount) or 0,
            jailTime = tonumber(row.jailTime) or 0,
            description = row.description or '',
        }
    end

    return charges
end

local function NormalizeChargeSelections(value)
    local entries = {}
    for _, entry in pairs(type(value) == 'table' and value or {}) do
        if type(entry) == 'table' then
            local label = Trim(entry.label)
            if label ~= '' then
                entries[#entries + 1] = {
                    chargeId = tonumber(entry.chargeId) or tonumber(entry.id) or nil,
                    category = Trim(entry.category) ~= '' and Trim(entry.category) or 'General',
                    label = label,
                    scope = Trim(entry.scope) ~= '' and Trim(entry.scope) or 'Principal',
                    fineAmount = math.max(0, math.floor(tonumber(entry.fineAmount or entry.fine) or 0)),
                    jailTime = math.max(0, math.floor(tonumber(entry.jailTime or entry.jail) or 0)),
                    quantity = math.max(1, math.min(math.floor(tonumber(entry.quantity) or 1), 20)),
                    description = entry.description or '',
                }
            end
        end
    end

    return entries
end

local function NormalizeEvidenceList(value)
    local list = {}
    for _, entry in pairs(type(value) == 'table' and value or {}) do
        if type(entry) == 'table' then
            local url = Trim(entry.url)
            if url ~= '' then
                list[#list + 1] = {
                    label = Trim(entry.label) ~= '' and Trim(entry.label) or ('Evidence %s'):format(#list + 1),
                    url = url,
                }
            end
        end
    end
    return list
end

local function NormalizeOfficerList(value)
    local officers = {}

    if type(value) == 'string' then
        for piece in string.gmatch(value, '([^,\n\r]+)') do
            local name = Trim(piece)
            if name ~= '' then
                officers[#officers + 1] = { name = name }
            end
        end
        return officers
    end

    for _, entry in pairs(type(value) == 'table' and value or {}) do
        if type(entry) == 'table' then
            local name = Trim(entry.name)
            if name ~= '' then
                officers[#officers + 1] = {
                    citizenid = Trim(entry.citizenid),
                    name = name,
                }
            end
        elseif type(entry) == 'string' and Trim(entry) ~= '' then
            officers[#officers + 1] = { name = Trim(entry) }
        end
    end

    return officers
end

local function SummarizeCharges(entries)
    local labels = {}
    local totalFine = 0
    local totalJail = 0

    for _, entry in ipairs(entries or {}) do
        local quantity = math.max(1, math.floor(tonumber(entry.quantity) or 1))
        local fine = math.max(0, math.floor(tonumber(entry.fineAmount) or 0))
        local jail = math.max(0, math.floor(tonumber(entry.jailTime) or 0))

        totalFine = totalFine + (fine * quantity)
        totalJail = totalJail + (jail * quantity)
        labels[#labels + 1] = quantity > 1 and ('%sx %s'):format(quantity, entry.label or 'Charge') or (entry.label or 'Charge')
    end

    return table.concat(labels, ', '), totalFine, totalJail
end

CanManagePoliceWarnings = function(source, Player)
    if HasAdminAccess(source) then
        return true
    end

    local job = Player and Player.PlayerData and Player.PlayerData.job or {}
    if not IsLeoJob(job) then
        return false
    end

    local grade = job.grade or {}
    local gradeName = Lower(grade.name or grade.label or '')
    local level = tonumber(grade.level) or 0

    return gradeName:find('chief', 1, true) ~= nil
        or gradeName:find('commissioner', 1, true) ~= nil
        or gradeName:find('deputy chief', 1, true) ~= nil
        or level >= 5
        or job.isboss == true
end

local BuildReportRow
local BuildSuspectSnapshot
local BuildActiveWarrants

local function BuildPoliceWarnings(limit, officerCitizenId)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 20), 60))
    local params = {}
    local sql = [[
        SELECT
            id,
            officer_citizenid AS officerCitizenId,
            officer_name AS officerName,
            issuer_citizenid AS issuerCitizenId,
            issuer_name AS issuerName,
            title,
            body,
            severity,
            created_at AS createdAt
        FROM prp_tablet_police_warnings
    ]]

    officerCitizenId = Trim(officerCitizenId)
    if officerCitizenId ~= '' then
        sql = sql .. ' WHERE officer_citizenid = ?'
        params[#params + 1] = officerCitizenId
    end

    sql = sql .. (' ORDER BY created_at DESC LIMIT %s'):format(amount)
    return MySQL.query.await(sql, params) or {}
end

local function BuildPolicePersonnel(query, limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 24), 50))
    local search = Trim(query)
    local sql = [[
        SELECT citizenid, charinfo, job
        FROM players
        WHERE (
            job LIKE '%"type":"leo"%'
            OR job LIKE '%"name":"police"%'
            OR job LIKE '%"name":"lspd"%'
            OR job LIKE '%"name":"bcso"%'
            OR job LIKE '%"name":"sasp"%'
            OR job LIKE '%"name":"sahp"%'
            OR job LIKE '%police%'
            OR job LIKE '%sheriff%'
            OR job LIKE '%trooper%'
            OR job LIKE '%marshal%'
            OR job LIKE '%ranger%'
        )
    ]]
    local params = {}

    if search ~= '' then
        local lookup = '%' .. search .. '%'
        sql = sql .. ' AND (citizenid LIKE ? OR charinfo LIKE ? OR job LIKE ?)'
        params[#params + 1] = lookup
        params[#params + 1] = lookup
        params[#params + 1] = lookup
    end

    sql = sql .. (' LIMIT %s'):format(amount)
    local rows = MySQL.query.await(sql, params) or {}
    local personnel = {}

    for _, row in ipairs(rows) do
        local charinfo = DecodeStoredTable(row.charinfo)
        local job = DecodeStoredTable(row.job)
        if IsLeoJob(job) then
            personnel[#personnel + 1] = {
                citizenid = row.citizenid,
                name = GetCharacterName(charinfo),
                department = job.label or job.name or 'Police',
                role = (job.grade and (job.grade.name or job.grade.level)) or 'Officer',
                warningCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM prp_tablet_police_warnings WHERE officer_citizenid = ?', {
                    row.citizenid
                })) or 0,
                lastWarningAt = MySQL.scalar.await('SELECT MAX(created_at) FROM prp_tablet_police_warnings WHERE officer_citizenid = ?', {
                    row.citizenid
                }),
            }
        end
    end

    table.sort(personnel, function(a, b)
        return (a.name or '') < (b.name or '')
    end)

    return personnel
end

local function BuildOfficerDetails(citizenId)
    local row = MySQL.single.await('SELECT citizenid, charinfo, job FROM players WHERE citizenid = ?', {
        citizenId
    })
    if not row then return nil end

    local charinfo = DecodeStoredTable(row.charinfo)
    local job = DecodeStoredTable(row.job)
    if not IsLeoJob(job) then return nil end

    return {
        citizenid = row.citizenid,
        name = GetCharacterName(charinfo),
        department = job.label or job.name or 'Police',
        role = (job.grade and (job.grade.name or job.grade.level)) or 'Officer',
        warnings = BuildPoliceWarnings(24, row.citizenid),
    }
end

local function BuildAssignedReports(citizenid, limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 8), 24))
    local rows = MySQL.query.await(([[
        SELECT id, title, suspect_citizenid AS suspectCitizenId, suspect_name AS suspectName, author_name AS authorName, charges, charges_json AS chargesJson, warrants, evidence_json AS evidenceJson, officers_json AS officersJson, fine_amount AS fineAmount, jail_time AS jailTime, status, details, report_type AS reportType, incident_date AS incidentDate, due_date AS dueDate, created_at AS createdAt, updated_at AS updatedAt
        FROM prp_tablet_mdt_reports
        WHERE author_citizenid = ?
        ORDER BY updated_at DESC
        LIMIT %s
    ]]):format(amount), {
        citizenid
    }) or {}

    local reports = {}
    for _, row in ipairs(rows) do
        reports[#reports + 1] = BuildReportRow(row)
    end
    return reports
end

BuildReportRow = function(row)
    local chargeSelections = NormalizeChargeSelections(DecodeStoredTable(row.chargesJson))
    local evidence = NormalizeEvidenceList(DecodeStoredTable(row.evidenceJson))
    local officers = NormalizeOfficerList(DecodeStoredTable(row.officersJson))
    local chargeSummary, totalFine, totalJail = SummarizeCharges(chargeSelections)
    local subject = BuildSuspectSnapshot(row.suspectCitizenId)

    return {
        id = row.id,
        title = row.title,
        suspectCitizenId = row.suspectCitizenId,
        suspectName = row.suspectName or subject.name,
        suspectMugshotUrl = subject.mugshotUrl,
        suspectFingerprint = subject.fingerprint,
        authorName = row.authorName,
        charges = row.charges or chargeSummary or '',
        warrants = row.warrants or '',
        fineAmount = tonumber(row.fineAmount) or totalFine or 0,
        jailTime = tonumber(row.jailTime) or totalJail or 0,
        status = row.status or 'Open',
        details = row.details or '',
        reportType = row.reportType or 'Incident',
        incidentDate = row.incidentDate,
        dueDate = row.dueDate,
        chargeSelections = chargeSelections,
        evidence = evidence,
        officers = officers,
        createdAt = row.createdAt,
        updatedAt = row.updatedAt,
    }
end

local function BuildMdtReports(limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 20), 60))
    local rows = MySQL.query.await(
        ('SELECT id, title, suspect_citizenid AS suspectCitizenId, suspect_name AS suspectName, author_name AS authorName, charges, charges_json AS chargesJson, warrants, evidence_json AS evidenceJson, officers_json AS officersJson, fine_amount AS fineAmount, jail_time AS jailTime, status, details, report_type AS reportType, incident_date AS incidentDate, due_date AS dueDate, created_at AS createdAt, updated_at AS updatedAt FROM prp_tablet_mdt_reports ORDER BY updated_at DESC LIMIT %s'):format(amount),
        {}
    ) or {}

    local reports = {}
    for _, row in ipairs(rows) do
        reports[#reports + 1] = BuildReportRow(row)
    end
    return reports
end

local function BuildMdtSummary(source, Player)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        return { success = false, message = 'MDT access required.', reports = {} }
    end

    EnsureTabletTables()
    local warrantCount = MySQL.scalar.await('SELECT COUNT(*) FROM prp_tablet_mdt_profiles WHERE warrant_active = 1', {}) or 0
    local reportCount = MySQL.scalar.await('SELECT COUNT(*) FROM prp_tablet_mdt_reports', {}) or 0
    local openCount = MySQL.scalar.await("SELECT COUNT(*) FROM prp_tablet_mdt_reports WHERE status = 'Open'", {}) or 0
    local citizenid = Player and Player.PlayerData and Player.PlayerData.citizenid or ''

    return {
        success = true,
        warrants = tonumber(warrantCount) or 0,
        reportsCount = tonumber(reportCount) or 0,
        openReports = tonumber(openCount) or 0,
        reports = BuildMdtReports(24),
        assignedReports = citizenid ~= '' and BuildAssignedReports(citizenid, 8) or {},
        warrantList = BuildActiveWarrants(18),
        chargesCatalog = BuildChargeCatalog(),
        recentWarnings = BuildPoliceWarnings(12),
        personnel = BuildPolicePersonnel('', 16),
        myWarnings = citizenid ~= '' and BuildPoliceWarnings(8, citizenid) or {},
        canIssueWarnings = CanManagePoliceWarnings(source, Player),
        canViewDeletedRecords = CanViewDeletedRecords(source, Player),
    }
end

local function BuildAdminData(source)
    if not HasAdminAccess(source) then
        return { success = false, message = 'Admin access required.' }
    end

    EnsureTabletTables()
    local racing = { success = false, tracks = {}, publicRaces = {} }
    if GetResourceState('qb-lapraces') == 'started' then
        local ok, state = pcall(function()
            return exports['qb-lapraces']:GetTabletState(source)
        end)
        if ok and type(state) == 'table' then
            racing = state
        end
    end

    local adCount = MySQL.scalar.await('SELECT COUNT(*) FROM prp_tablet_ads', {}) or 0
    local reportCount = MySQL.scalar.await('SELECT COUNT(*) FROM prp_tablet_mdt_reports', {}) or 0

    return {
        success = true,
        summary = {
            tracks = #(racing.tracks or {}),
            liveRaces = #(racing.publicRaces or {}),
            ads = tonumber(adCount) or 0,
            reports = tonumber(reportCount) or 0,
        },
        ads = BuildAdvertisements(16),
        reports = BuildMdtReports(16)
    }
end

local function DecodeJsonTable(value)
    if type(value) == 'table' then
        return value
    end
    if type(value) ~= 'string' or value == '' then
        return {}
    end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then
        return decoded
    end
    return {}
end

local function SearchSuspects(query)
    EnsureTabletTables()
    local search = Trim(query)
    if search == '' then return {} end

    local lookup = '%' .. search .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo, job
        FROM players
        WHERE citizenid LIKE ? OR charinfo LIKE ?
        LIMIT 25
    ]], { lookup, lookup }) or {}

    local suspects = {}
    for _, row in ipairs(rows) do
        local charinfo = DecodeJsonTable(row.charinfo)
        local job = DecodeJsonTable(row.job)
        local profile = MySQL.single.await('SELECT warrant_active AS warrantActive, warrant_note AS warrantNote, note FROM prp_tablet_mdt_profiles WHERE citizenid = ?', {
            row.citizenid
        }) or {}

        suspects[#suspects + 1] = {
            citizenid = row.citizenid,
            name = GetCharacterName(charinfo),
            job = job.label or job.name or 'Unknown',
            warrantActive = tonumber(profile.warrantActive) == 1,
            warrantNote = profile.warrantNote or '',
            note = profile.note or '',
        }
    end

    table.sort(suspects, function(a, b)
        return (a.name or '') < (b.name or '')
    end)

    return suspects
end

local function BuildVehicleList(citizenId)
    local rows = MySQL.query.await(
        'SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ? ORDER BY plate ASC LIMIT 12',
        { citizenId }
    ) or {}

    local vehicles = {}
    for _, row in ipairs(rows) do
        vehicles[#vehicles + 1] = {
            plate = row.plate,
            vehicle = row.vehicle,
        }
    end

    return vehicles
end

BuildSuspectSnapshot = function(citizenId)
    citizenId = Trim(citizenId)
    if citizenId == '' then
        return {
            citizenid = '',
            name = 'Unknown',
            mugshotUrl = nil,
            fingerprint = nil,
        }
    end

    local row = MySQL.single.await('SELECT citizenid, charinfo, metadata FROM players WHERE citizenid = ?', {
        citizenId
    })
    if not row then
        return {
            citizenid = citizenId,
            name = 'Unknown',
            mugshotUrl = nil,
            fingerprint = nil,
        }
    end

    local charinfo = DecodeJsonTable(row.charinfo)
    local metadata = DecodeJsonTable(row.metadata)
    local profile = MySQL.single.await('SELECT mugshot_url AS mugshotUrl FROM prp_tablet_mdt_profiles WHERE citizenid = ?', {
        citizenId
    }) or {}

    return {
        citizenid = citizenId,
        name = GetCharacterName(charinfo),
        mugshotUrl = profile.mugshotUrl or metadata.mugshot or charinfo.image or nil,
        fingerprint = metadata.fingerprint,
    }
end

local function BuildDeletedRecords(citizenId, limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 18), 40))
    local rows = MySQL.query.await(([[
        SELECT id, record_type AS recordType, record_id AS recordId, title, payload_json AS payloadJson, deleted_by_name AS deletedByName, deleted_at AS deletedAt
        FROM prp_tablet_deleted_records
        WHERE target_citizenid = ?
        ORDER BY deleted_at DESC
        LIMIT %s
    ]]):format(amount), {
        citizenId
    }) or {}

    local records = {}
    for _, row in ipairs(rows) do
        records[#records + 1] = {
            id = tonumber(row.id) or 0,
            recordType = row.recordType or 'Record',
            recordId = row.recordId,
            title = row.title or 'Record',
            payload = DecodeStoredTable(row.payloadJson),
            deletedByName = row.deletedByName or 'Unknown',
            deletedAt = row.deletedAt,
        }
    end

    return records
end

BuildActiveWarrants = function(limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 20), 50))
    local rows = MySQL.query.await(([[
        SELECT players.citizenid, players.charinfo, players.metadata, profiles.warrant_note AS warrantNote, profiles.updated_at AS updatedAt, profiles.mugshot_url AS mugshotUrl
        FROM prp_tablet_mdt_profiles profiles
        INNER JOIN players ON players.citizenid = profiles.citizenid
        WHERE profiles.warrant_active = 1
        ORDER BY profiles.updated_at DESC
        LIMIT %s
    ]]):format(amount), {}) or {}

    local warrants = {}
    for _, row in ipairs(rows) do
        local charinfo = DecodeJsonTable(row.charinfo)
        local metadata = DecodeJsonTable(row.metadata)
        warrants[#warrants + 1] = {
            citizenid = row.citizenid,
            name = GetCharacterName(charinfo),
            warrantNote = row.warrantNote or '',
            updatedAt = row.updatedAt,
            fingerprint = metadata.fingerprint,
            mugshotUrl = row.mugshotUrl or metadata.mugshot or charinfo.image or nil,
        }
    end

    return warrants
end

local function SearchMdtReports(query, limit)
    EnsureTabletTables()
    local amount = math.max(1, math.min(math.floor(tonumber(limit) or 20), 50))
    local search = Trim(query)
    local lookup = '%' .. search .. '%'

    local sql = ([[
        SELECT id, title, suspect_citizenid AS suspectCitizenId, suspect_name AS suspectName, author_name AS authorName, charges, charges_json AS chargesJson, warrants, evidence_json AS evidenceJson, officers_json AS officersJson, fine_amount AS fineAmount, jail_time AS jailTime, status, details, report_type AS reportType, incident_date AS incidentDate, due_date AS dueDate, created_at AS createdAt, updated_at AS updatedAt
        FROM prp_tablet_mdt_reports
    ]])
    local params = {}
    if search ~= '' then
        sql = sql .. ' WHERE title LIKE ? OR suspect_name LIKE ? OR suspect_citizenid LIKE ? OR charges LIKE ? OR warrants LIKE ?'
        params = { lookup, lookup, lookup, lookup, lookup }
    end
    sql = sql .. (' ORDER BY updated_at DESC LIMIT %s'):format(amount)

    local rows = MySQL.query.await(sql, params) or {}

    local reports = {}
    for _, row in ipairs(rows) do
        reports[#reports + 1] = BuildReportRow(row)
    end
    return reports
end

local function BuildSuspectDetails(citizenId, includeDeleted)
    local row = MySQL.single.await('SELECT citizenid, charinfo, job, metadata FROM players WHERE citizenid = ?', {
        citizenId
    })
    if not row then return nil end

    local charinfo = DecodeJsonTable(row.charinfo)
    local job = DecodeJsonTable(row.job)
    local metadata = DecodeJsonTable(row.metadata)
    local profile = MySQL.single.await(
        'SELECT note, warrant_active AS warrantActive, warrant_note AS warrantNote, mugshot_url AS mugshotUrl, updated_at AS updatedAt FROM prp_tablet_mdt_profiles WHERE citizenid = ?',
        { citizenId }
    ) or {}

    local reportRows = MySQL.query.await([[
        SELECT id, title, suspect_citizenid AS suspectCitizenId, suspect_name AS suspectName, author_name AS authorName, charges, warrants, fine_amount AS fineAmount, jail_time AS jailTime, status, details, created_at AS createdAt, updated_at AS updatedAt
        FROM prp_tablet_mdt_reports
        WHERE suspect_citizenid = ?
        ORDER BY updated_at DESC
        LIMIT 12
    ]], { citizenId }) or {}

    local reports = {}
    for _, report in ipairs(reportRows) do
        reports[#reports + 1] = BuildReportRow(report)
    end

    local profileEntries = MySQL.query.await([[
        SELECT id, entry_type AS entryType, title, body, author_name AS authorName, created_at AS createdAt
        FROM prp_tablet_mdt_profile_entries
        WHERE citizenid = ?
        ORDER BY created_at DESC
        LIMIT 18
    ]], { citizenId }) or {}

    return {
        citizenid = citizenId,
        name = GetCharacterName(charinfo),
        job = job.label or job.name or 'Unknown',
        fingerprint = metadata.fingerprint,
        mugshotUrl = profile.mugshotUrl or metadata.mugshot or charinfo.image or nil,
        licences = metadata.licences or {},
        note = profile.note or '',
        warrantActive = tonumber(profile.warrantActive) == 1,
        warrantNote = profile.warrantNote or '',
        updatedAt = profile.updatedAt,
        vehicles = BuildVehicleList(citizenId),
        reports = reports,
        profileEntries = profileEntries,
        deletedRecords = includeDeleted and BuildDeletedRecords(citizenId, 18) or {},
    }
end

local function GetMdtReportById(reportId)
    reportId = tonumber(reportId)
    if not reportId then return nil end

    local row = MySQL.single.await([[
        SELECT
            id,
            title,
            suspect_citizenid AS suspectCitizenId,
            suspect_name AS suspectName,
            author_name AS authorName,
            charges,
            charges_json AS chargesJson,
            warrants,
            evidence_json AS evidenceJson,
            officers_json AS officersJson,
            fine_amount AS fineAmount,
            jail_time AS jailTime,
            status,
            details,
            report_type AS reportType,
            incident_date AS incidentDate,
            due_date AS dueDate,
            created_at AS createdAt,
            updated_at AS updatedAt
        FROM prp_tablet_mdt_reports
        WHERE id = ?
    ]], { reportId })

    return row and BuildReportRow(row) or nil
end

local function GetRacingSummary(source)
    if GetResourceState('qb-lapraces') ~= 'started' then
        return { success = false, tracks = {}, publicRaces = {} }
    end

    local ok, snapshot = pcall(function()
        return exports['qb-lapraces']:GetTabletState(source)
    end)

    if ok and type(snapshot) == 'table' then
        return snapshot
    end

    return { success = false, tracks = {}, publicRaces = {} }
end

QBCore.Functions.CreateUseableItem('tablet', function(source)
    TriggerClientEvent('prp-tablet:client:UseTablet', source)
end)

QBCore.Functions.CreateUseableItem('crypto_usb', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not GetTabletItem(Player) then
        Notify(source, 'You need a tablet before installing this crypto drive.', 'error')
        return
    end

    Notify(source, 'Install this crypto drive into a tablet from inventory attachments.', 'primary')
    TriggerClientEvent('prp-tablet:client:UseTablet', source)
end)

QBCore.Functions.CreateUseableItem('cryptostick', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not GetTabletItem(Player) then
        Notify(source, 'You need a tablet before installing this crypto drive.', 'error')
        return
    end

    Notify(source, 'Install this crypto drive into a tablet from inventory attachments.', 'primary')
    TriggerClientEvent('prp-tablet:client:UseTablet', source)
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetTabletData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    if not GetTabletItem(Player) then
        cb({ success = false, message = 'You need a tablet.' })
        return
    end

    cb({
        success = true,
        status = GetTabletStatus(source, Player),
        permissions = GetPermissionData(source, Player),
        business = BuildBusinessData(Player),
        ads = {
            success = true,
            items = BuildAdvertisements(18),
        },
        admin = BuildAdminData(source),
        mdt = BuildMdtSummary(source, Player),
        racingSummary = GetRacingSummary(source),
        crypto = tonumber(Player.PlayerData.money.crypto) or 0,
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:StartCryptoMine', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    local miningConfig = Config.CryptoMining or {}
    local insertedDrive, tablet, tabletInfo = SyncTabletDriveState(Player)

    if not tablet or not insertedDrive or not insertedDrive.item then
        local activeJobs = GetTabletMiningJobs(src)
        if #activeJobs > 0 then
            cb({ success = true, message = 'Active crypto USBs shown.', activeMining = activeJobs })
            return
        end

        cb({ success = false, message = 'Insert a crypto drive into the tablet first.', activeMining = activeJobs })
        return
    end

    tabletInfo.cryptoDrive = nil
    tabletInfo.description = GetTabletDriveDescription(nil)
    if not SetInventoryItemInfo(Player, tablet.slot, tabletInfo) then
        cb({ success = false, message = 'Could not read the crypto drive.' })
        return
    end
    SetTabletCryptoDrive(Player.PlayerData.citizenid, nil)

    TriggerClientEvent('qb-inventory:client:updateInventory', src, Player.PlayerData.items or {})
    Notify(src, ('%s consumed by the crypto rig.'):format(insertedDrive.label or 'Crypto USB'), 'primary')

    local minSeconds = tonumber(miningConfig.MinSeconds) or 180
    local maxSeconds = tonumber(miningConfig.MaxSeconds) or 900
    if maxSeconds < minSeconds then maxSeconds = minSeconds end

    local minReward = math.floor((tonumber(miningConfig.MinReward) or 0.12) * 1000000)
    local maxReward = math.floor((tonumber(miningConfig.MaxReward) or 0.85) * 1000000)
    if maxReward < minReward then maxReward = minReward end

    local seconds = math.random(minSeconds, maxSeconds)
    local reward = math.random(minReward, maxReward) / 1000000
    local jobId = 'RIG-' .. QBCore.Shared.RandomStr(4) .. QBCore.Shared.RandomInt(4)
    local startedAt = os.time()
    local miningJob = {
        id = jobId,
        item = insertedDrive.item,
        label = insertedDrive.label or 'Crypto USB',
        image = insertedDrive.image,
        reward = reward,
        seconds = seconds,
        startedAt = startedAt,
        finishesAt = startedAt + seconds
    }

    TabletMining[src] = TabletMining[src] or {}
    TabletMining[src][#TabletMining[src] + 1] = miningJob

    SetTimeout(seconds * 1000, function()
        local Target = QBCore.Functions.GetPlayer(src)
        RemoveTabletMiningJob(src, jobId)

        if not Target then return end

        Target.Functions.AddMoney('crypto', reward, 'tablet crypto mining')
        local message = ('Crypto rig paid out %.6f Qbit.'):format(reward)
        AddCryptoTransaction(Target.PlayerData.citizenid, 'Tablet Rig', message)
        Notify(src, message, 'success')
        TriggerClientEvent('prp-tablet:client:MiningComplete', src, reward, message, GetTabletMiningJobs(src))
    end)

    cb({
        success = true,
        message = ('%s started. ETA %s minute(s).'):format(miningJob.label, math.ceil(seconds / 60)),
        seconds = seconds,
        status = GetTabletStatus(src, Player),
        activeMining = GetTabletMiningJobs(src)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetBusinessData', function(source, cb)
    cb(BuildBusinessData(QBCore.Functions.GetPlayer(source)))
end)

QBCore.Functions.CreateCallback('prp-tablet:server:ToggleDuty', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessContext(Player)
    if not job then
        cb({ success = false, message = 'You are not employed by a business.' })
        return
    end

    Player.Functions.SetJobDuty(not job.onduty)
    Notify(source, Player.PlayerData.job.onduty and 'Clocked on duty.' or 'Clocked off duty.', 'success')
    local data = BuildBusinessData(Player)
    data.message = 'Duty updated.'
    cb(data)
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessHireClosest', function(source, cb, targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    local job = GetBusinessContext(Player)

    if not job or job.isboss ~= true then
        cb({ success = false, message = 'Business owner access required.' })
        return
    end

    if not Target then
        cb({ success = false, message = 'No one is nearby.' })
        return
    end

    if Target.PlayerData.citizenid == Player.PlayerData.citizenid then
        cb({ success = false, message = 'You cannot hire yourself.' })
        return
    end

    if Target.Functions.SetJob(job.name, 0) then
        Target.Functions.Save()
        Notify(src, ('You hired %s into %s.'):format(Target.PlayerData.charinfo.firstname, job.label or job.name), 'success')
        Notify(Target.PlayerData.source, ('You were hired by %s.'):format(job.label or job.name), 'success')
        local data = BuildBusinessData(Player)
        data.message = 'Employee hired.'
        cb(data)
        return
    end

    cb({ success = false, message = 'Could not hire that player.' })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessHireCitizen', function(source, cb, citizenid)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessContext(Player)

    if not job or job.isboss ~= true then
        cb({ success = false, message = 'Business owner access required.' })
        return
    end

    citizenid = Trim(citizenid)
    if citizenid == '' then
        cb({ success = false, message = 'Enter a citizen ID.' })
        return
    end

    if citizenid == Player.PlayerData.citizenid then
        cb({ success = false, message = 'You cannot hire yourself.' })
        return
    end

    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid) or QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
    if not Target then
        cb({ success = false, message = 'Citizen ID not found.' })
        return
    end

    if Target.Functions.SetJob(job.name, 0) then
        Target.Functions.Save()
        if Target.PlayerData.source then
            Notify(Target.PlayerData.source, ('You were hired by %s.'):format(job.label or job.name), 'success')
        end
        local data = BuildBusinessData(Player)
        data.message = 'Employee hired by citizen ID.'
        cb(data)
        return
    end

    cb({ success = false, message = 'Could not hire that citizen.' })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessFireMember', function(source, cb, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local job = GetBusinessContext(Player)

    if not job or job.isboss ~= true then
        cb({ success = false, message = 'Business owner access required.' })
        return
    end

    if citizenid == Player.PlayerData.citizenid then
        cb({ success = false, message = 'You cannot fire yourself.' })
        return
    end

    local Employee = QBCore.Functions.GetPlayerByCitizenId(citizenid) or QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
    if not Employee or not Employee.PlayerData.job or Employee.PlayerData.job.name ~= job.name then
        cb({ success = false, message = 'That person is not in your business.' })
        return
    end

    local targetLevel = tonumber(Employee.PlayerData.job.grade and Employee.PlayerData.job.grade.level) or 0
    local bossLevel = tonumber(job.grade and job.grade.level) or 0
    if targetLevel > bossLevel then
        cb({ success = false, message = 'You cannot fire that employee.' })
        return
    end

    if Employee.Functions.SetJob('unemployed', '0') then
        Employee.Functions.Save()
        Notify(src, 'Employee fired.', 'success')
        if Employee.PlayerData.source then
            Notify(Employee.PlayerData.source, 'You have been fired.', 'error')
        end
        local data = BuildBusinessData(Player)
        data.message = 'Employee fired.'
        cb(data)
        return
    end

    cb({ success = false, message = 'Could not fire that employee.' })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessAdjustMoney', function(source, cb, action, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessContext(Player)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if not job or job.isboss ~= true then
        cb({ success = false, message = 'Business owner access required.' })
        return
    end

    if amount <= 0 then
        cb({ success = false, message = 'Enter an amount greater than zero.' })
        return
    end

    if GetResourceState('qb-banking') ~= 'started' then
        cb({ success = false, message = 'Banking is offline.' })
        return
    end

    if action == 'deposit' then
        local success = Player.Functions.RemoveMoney('bank', amount, 'business deposit')
        if not success then
            cb({ success = false, message = 'You do not have enough money in bank.' })
            return
        end

        exports['qb-banking']:AddMoney(job.name, amount, 'tablet business deposit')
        local data = BuildBusinessData(Player)
        data.message = ('Deposited $%s to the business.'):format(amount)
        cb(data)
        return
    end

    if action == 'withdraw' then
        local balance = GetSocietyBalance(job.name)
        if balance < amount then
            cb({ success = false, message = 'Business account does not have enough money.' })
            return
        end

        exports['qb-banking']:RemoveMoney(job.name, amount, 'tablet business withdraw')
        Player.Functions.AddMoney('bank', amount, 'business withdraw')
        local data = BuildBusinessData(Player)
        data.message = ('Withdrew $%s from the business.'):format(amount)
        cb(data)
        return
    end

    cb({ success = false, message = 'Unknown business money action.' })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessSendMessage', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessContext(Player)
    local payload = type(data) == 'table' and data or { message = data }
    local message = Trim(payload.message)
    local replyToId = tonumber(payload.replyToId)

    if not job then
        cb({ success = false, message = 'You are not employed by a business.' })
        return
    end

    if message == '' or #message > 220 then
        cb({ success = false, message = 'Message must be 1-220 characters.' })
        return
    end

    if replyToId then
        local parent = GetBusinessMessageById(replyToId)
        if not parent or parent.jobName ~= job.name then
            cb({ success = false, message = 'Reply target no longer exists.' })
            return
        end
    end

    EnsureTabletTables()
    MySQL.insert.await([[
        INSERT INTO prp_tablet_business_chat (job_name, author_citizenid, author_name, message, reply_to_id)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        job.name,
        Player.PlayerData.citizenid,
        GetCharacterName(Player.PlayerData.charinfo),
        message,
        replyToId
    })

    local data = BuildBusinessData(Player)
    data.message = replyToId and 'Business reply sent.' or 'Business message sent.'
    cb(data)
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessEditMessage', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessContext(Player)
    data = type(data) == 'table' and data or {}
    local messageId = tonumber(data.id)
    local message = Trim(data.message)

    if not job then
        cb({ success = false, message = 'You are not employed by a business.' })
        return
    end

    if not messageId then
        cb({ success = false, message = 'Message not found.' })
        return
    end

    if message == '' or #message > 220 then
        cb({ success = false, message = 'Message must be 1-220 characters.' })
        return
    end

    local row = GetBusinessMessageById(messageId)
    if not row or row.jobName ~= job.name then
        cb({ success = false, message = 'Message not found.' })
        return
    end

    if not CanManageBusinessMessages(source, Player, row.authorCitizenId) then
        cb({ success = false, message = 'You cannot edit that message.' })
        return
    end

    EnsureTabletTables()
    MySQL.update.await([[
        UPDATE prp_tablet_business_chat
        SET message = ?, edited_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], {
        message,
        messageId
    })

    local data = BuildBusinessData(Player)
    data.message = 'Business message updated.'
    cb(data)
end)

QBCore.Functions.CreateCallback('prp-tablet:server:BusinessDeleteMessage', function(source, cb, messageId)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessContext(Player)
    local row = GetBusinessMessageById(messageId)

    if not job then
        cb({ success = false, message = 'You are not employed by a business.' })
        return
    end

    if not row or row.jobName ~= job.name then
        cb({ success = false, message = 'Message not found.' })
        return
    end

    if not CanManageBusinessMessages(source, Player, row.authorCitizenId) then
        cb({ success = false, message = 'You cannot delete that message.' })
        return
    end

    EnsureTabletTables()
    MySQL.update.await('UPDATE prp_tablet_business_chat SET reply_to_id = NULL WHERE reply_to_id = ?', {
        tonumber(messageId)
    })
    MySQL.query.await('DELETE FROM prp_tablet_business_chat WHERE id = ?', {
        tonumber(messageId)
    })

    local data = BuildBusinessData(Player)
    data.message = 'Business message deleted.'
    cb(data)
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetAdsData', function(_, cb)
    cb({
        success = true,
        items = BuildAdvertisements(24)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:CreateAdvertisement', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    local job = GetBusinessContext(Player)
    if not job and not HasAdminAccess(source) then
        cb({ success = false, message = 'You need a business role to post ads.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local title = Trim(data.title)
    local body = Trim(data.body)
    local backgroundUrl = Trim(data.backgroundUrl)

    if #title < 3 or #title > 60 then
        cb({ success = false, message = 'Ad title must be 3-60 characters.' })
        return
    end

    if #body < 8 or #body > 300 then
        cb({ success = false, message = 'Ad body must be 8-300 characters.' })
        return
    end

    if not IsHttpUrl(backgroundUrl) then
        cb({ success = false, message = 'Background image must be a valid http or https URL.' })
        return
    end

    EnsureTabletTables()
    MySQL.insert.await([[
        INSERT INTO prp_tablet_ads (job_name, author_citizenid, author_name, title, body, background_url)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        job and job.name or 'admin',
        Player.PlayerData.citizenid,
        GetCharacterName(Player.PlayerData.charinfo),
        title,
        body,
        backgroundUrl ~= '' and backgroundUrl or nil
    })

    cb({
        success = true,
        message = 'Advertisement posted.',
        items = BuildAdvertisements(24)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:DeleteAdvertisement', function(source, cb, adId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    EnsureTabletTables()
    local ad = MySQL.single.await('SELECT author_citizenid AS authorCitizenId FROM prp_tablet_ads WHERE id = ?', {
        tonumber(adId)
    })

    if not ad then
        cb({ success = false, message = 'Advertisement not found.' })
        return
    end

    if ad.authorCitizenId ~= Player.PlayerData.citizenid and not HasAdminAccess(source) then
        cb({ success = false, message = 'You cannot delete that advertisement.' })
        return
    end

    MySQL.query.await('DELETE FROM prp_tablet_ads WHERE id = ?', { tonumber(adId) })
    cb({
        success = true,
        message = 'Advertisement deleted.',
        items = BuildAdvertisements(24)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetAdminData', function(source, cb)
    cb(BuildAdminData(source))
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetMdtData', function(source, cb)
    cb(BuildMdtSummary(source, QBCore.Functions.GetPlayer(source)))
end)

QBCore.Functions.CreateCallback('prp-tablet:server:SearchMdtSuspects', function(source, cb, query)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.', suspects = {} })
        return
    end

    cb({
        success = true,
        suspects = SearchSuspects(query)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetMdtSuspect', function(source, cb, citizenid)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    local suspect = BuildSuspectDetails(Trim(citizenid), CanViewDeletedRecords(source, Player))
    if not suspect then
        cb({ success = false, message = 'Suspect not found.' })
        return
    end

    cb({
        success = true,
        suspect = suspect
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:SaveMdtSuspect', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local citizenid = Trim(data.citizenid)
    if citizenid == '' then
        cb({ success = false, message = 'Citizen ID required.' })
        return
    end

    local existing = MySQL.single.await(
        'SELECT warrant_active AS warrantActive, warrant_note AS warrantNote FROM prp_tablet_mdt_profiles WHERE citizenid = ?',
        { citizenid }
    ) or {}
    local nextWarrantActive = data.warrantActive == true
    local mugshotUrl = Trim(data.mugshotUrl)
    if not IsHttpUrl(mugshotUrl) then
        cb({ success = false, message = 'Mugshot must be a valid http or https URL.' })
        return
    end

    EnsureTabletTables()
    MySQL.insert.await([[
        INSERT INTO prp_tablet_mdt_profiles (citizenid, note, warrant_active, warrant_note, mugshot_url)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE note = VALUES(note), warrant_active = VALUES(warrant_active), warrant_note = VALUES(warrant_note), mugshot_url = VALUES(mugshot_url)
    ]], {
        citizenid,
        data.note or '',
        nextWarrantActive and 1 or 0,
        data.warrantNote or '',
        mugshotUrl ~= '' and mugshotUrl or nil
    })

    if tonumber(existing.warrantActive) == 1 and not nextWarrantActive then
        local snapshot = BuildSuspectSnapshot(citizenid)
        LogDeletedRecord('Warrant', citizenid, snapshot.name, citizenid, 'Cleared Active Warrant', {
            warrantNote = existing.warrantNote or '',
        }, Player)
    end

    cb({
        success = true,
        message = 'Suspect profile updated.',
        suspect = BuildSuspectDetails(citizenid, CanViewDeletedRecords(source, Player))
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:SaveMdtReport', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local title = Trim(data.title)
    if #title < 3 or #title > 80 then
        cb({ success = false, message = 'Report title must be 3-80 characters.' })
        return
    end

    local reportId = tonumber(data.id)
    local existingReport = reportId and MySQL.single.await([[
        SELECT id, title, suspect_citizenid AS suspectCitizenId, suspect_name AS suspectName, evidence_json AS evidenceJson
        FROM prp_tablet_mdt_reports
        WHERE id = ?
    ]], {
        reportId
    }) or nil
    local chargeSelections = NormalizeChargeSelections(data.chargeSelections)
    local evidence = NormalizeEvidenceList(data.evidence)
    local officers = NormalizeOfficerList(data.officers)
    local chargeSummary, derivedFine, derivedJail = SummarizeCharges(chargeSelections)
    local fineAmount = math.max(0, math.floor(tonumber(data.fineAmount) or derivedFine or 0))
    local jailTime = math.max(0, math.floor(tonumber(data.jailTime) or derivedJail or 0))
    local suspectCitizenId = Trim(data.suspectCitizenId)
    local suspectName = Trim(data.suspectName)
    if suspectName == '' and suspectCitizenId ~= '' then
        local suspect = BuildSuspectDetails(suspectCitizenId)
        suspectName = suspect and suspect.name or ''
    end

    local params = {
        Player.PlayerData.citizenid,
        GetCharacterName(Player.PlayerData.charinfo),
        suspectCitizenId,
        suspectName,
        Trim(data.reportType) ~= '' and Trim(data.reportType) or 'Incident',
        title,
        data.details or '',
        Trim(data.charges) ~= '' and Trim(data.charges) or chargeSummary,
        EncodeJson(chargeSelections),
        data.warrants or '',
        EncodeJson(evidence),
        EncodeJson(officers),
        fineAmount,
        jailTime,
        Trim(data.status) ~= '' and Trim(data.status) or 'Open',
        Trim(data.incidentDate),
        Trim(data.dueDate),
    }

    EnsureTabletTables()
    if reportId then
        MySQL.update.await([[
            UPDATE prp_tablet_mdt_reports
            SET author_citizenid = ?, author_name = ?, suspect_citizenid = ?, suspect_name = ?, report_type = ?, title = ?, details = ?, charges = ?, charges_json = ?, warrants = ?, evidence_json = ?, officers_json = ?, fine_amount = ?, jail_time = ?, status = ?, incident_date = ?, due_date = ?
            WHERE id = ?
        ]], {
            params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], params[11], params[12], params[13], params[14], params[15], params[16], params[17], reportId
        })
    else
        reportId = MySQL.insert.await([[
            INSERT INTO prp_tablet_mdt_reports (author_citizenid, author_name, suspect_citizenid, suspect_name, report_type, title, details, charges, charges_json, warrants, evidence_json, officers_json, fine_amount, jail_time, status, incident_date, due_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], params)
    end

    if existingReport then
        local existingEvidence = NormalizeEvidenceList(DecodeStoredTable(existingReport.evidenceJson))
        local nextEvidenceKeys = {}

        for _, entry in ipairs(evidence) do
            nextEvidenceKeys[Lower(Trim(entry.label)) .. '|' .. Lower(Trim(entry.url))] = true
        end

        for _, entry in ipairs(existingEvidence) do
            local key = Lower(Trim(entry.label)) .. '|' .. Lower(Trim(entry.url))
            if Trim(entry.url) ~= '' and not nextEvidenceKeys[key] then
                LogDeletedRecord('Evidence', suspectCitizenId ~= '' and suspectCitizenId or existingReport.suspectCitizenId, suspectName ~= '' and suspectName or existingReport.suspectName, tostring(reportId), Trim(entry.label) ~= '' and entry.label or 'Evidence File', {
                    reportId = reportId,
                    reportTitle = title,
                    evidence = entry,
                }, Player)
            end
        end
    end

    local report = GetMdtReportById(reportId)

    cb({
        success = true,
        message = 'MDT report saved.',
        reports = BuildMdtReports(24),
        report = report,
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:DeleteMdtReport', function(source, cb, reportId)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    EnsureTabletTables()
    local report = GetMdtReportById(reportId)
    if report then
        for _, entry in ipairs(report.evidence or {}) do
            if Trim(entry.url) ~= '' then
                LogDeletedRecord('Evidence', report.suspectCitizenId, report.suspectName, tostring(report.id), Trim(entry.label) ~= '' and entry.label or 'Evidence File', {
                    reportId = report.id,
                    reportTitle = report.title,
                    evidence = entry,
                }, Player)
            end
        end

        LogDeletedRecord('Report', report.suspectCitizenId, report.suspectName, tostring(report.id), report.title, {
            report = report,
        }, Player)
    end

    MySQL.query.await('DELETE FROM prp_tablet_mdt_reports WHERE id = ?', { tonumber(reportId) })
    cb({
        success = true,
        message = 'MDT report deleted.',
        reports = BuildMdtReports(18)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:AddMdtProfileEntry', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local citizenid = Trim(data.citizenid)
    local title = Trim(data.title)
    local body = Trim(data.body)
    local entryType = Trim(data.entryType) ~= '' and Trim(data.entryType) or 'Note'

    if citizenid == '' then
        cb({ success = false, message = 'Citizen ID required.' })
        return
    end

    if #title < 3 or #title > 120 then
        cb({ success = false, message = 'Entry title must be 3-120 characters.' })
        return
    end

    if #body < 6 or #body > 800 then
        cb({ success = false, message = 'Entry body must be 6-800 characters.' })
        return
    end

    EnsureTabletTables()
    MySQL.insert.await([[
        INSERT INTO prp_tablet_mdt_profile_entries (citizenid, author_citizenid, author_name, entry_type, title, body)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        Player.PlayerData.citizenid,
        GetCharacterName(Player.PlayerData.charinfo),
        entryType,
        title,
        body,
    })

    cb({
        success = true,
        message = 'Profile write-up added.',
        suspect = BuildSuspectDetails(citizenid, CanViewDeletedRecords(source, Player)),
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:SearchMdtReports', function(source, cb, query)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.', reports = {} })
        return
    end

    cb({
        success = true,
        reports = SearchMdtReports(query, 18)
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:ClearMdtWarrant', function(source, cb, citizenid)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    citizenid = Trim(citizenid)
    if citizenid == '' then
        cb({ success = false, message = 'Citizen ID required.' })
        return
    end

    local existing = MySQL.single.await('SELECT warrant_active AS warrantActive, warrant_note AS warrantNote FROM prp_tablet_mdt_profiles WHERE citizenid = ?', {
        citizenid
    }) or {}

    if tonumber(existing.warrantActive) ~= 1 then
        cb({
            success = false,
            message = 'No active warrant on file.',
            suspect = BuildSuspectDetails(citizenid, CanViewDeletedRecords(source, Player)),
            warrants = BuildActiveWarrants(18),
        })
        return
    end

    EnsureTabletTables()
    MySQL.update.await('UPDATE prp_tablet_mdt_profiles SET warrant_active = 0, warrant_note = ? WHERE citizenid = ?', {
        '',
        citizenid
    })

    local snapshot = BuildSuspectSnapshot(citizenid)
    LogDeletedRecord('Warrant', citizenid, snapshot.name, citizenid, 'Cleared Active Warrant', {
        warrantNote = existing.warrantNote or '',
    }, Player)

    cb({
        success = true,
        message = 'Warrant cleared.',
        suspect = BuildSuspectDetails(citizenid, CanViewDeletedRecords(source, Player)),
        warrants = BuildActiveWarrants(18),
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:SearchPolicePersonnel', function(source, cb, query)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.', personnel = {} })
        return
    end

    cb({
        success = true,
        personnel = BuildPolicePersonnel(query, 24),
        canIssueWarnings = CanManagePoliceWarnings(source, Player),
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:GetPoliceOfficer', function(source, cb, citizenid)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    local officer = BuildOfficerDetails(Trim(citizenid))
    if not officer then
        cb({ success = false, message = 'Officer not found.' })
        return
    end

    cb({
        success = true,
        officer = officer,
        canIssueWarnings = CanManagePoliceWarnings(source, Player),
    })
end)

QBCore.Functions.CreateCallback('prp-tablet:server:SavePoliceWarning', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    local perms = GetPermissionData(source, Player)
    if not perms.admin and not perms.leo then
        cb({ success = false, message = 'MDT access required.' })
        return
    end

    if not CanManagePoliceWarnings(source, Player) then
        cb({ success = false, message = 'Chief rank or higher required.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local officerCitizenId = Trim(data.officerCitizenId)
    local title = Trim(data.title)
    local body = Trim(data.body)
    local severity = Trim(data.severity) ~= '' and Trim(data.severity) or 'Warning'
    local officer = BuildOfficerDetails(officerCitizenId)

    if not officer then
        cb({ success = false, message = 'Officer not found.' })
        return
    end

    if #title < 3 or #title > 120 then
        cb({ success = false, message = 'Warning title must be 3-120 characters.' })
        return
    end

    if #body < 6 or #body > 800 then
        cb({ success = false, message = 'Warning details must be 6-800 characters.' })
        return
    end

    EnsureTabletTables()
    MySQL.insert.await([[
        INSERT INTO prp_tablet_police_warnings (officer_citizenid, officer_name, issuer_citizenid, issuer_name, title, body, severity)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        officerCitizenId,
        officer.name,
        Player.PlayerData.citizenid,
        GetCharacterName(Player.PlayerData.charinfo),
        title,
        body,
        severity,
    })

    cb({
        success = true,
        message = 'Police warning added.',
        officer = BuildOfficerDetails(officerCitizenId),
        warnings = BuildPoliceWarnings(18),
        personnel = BuildPolicePersonnel('', 16),
        canIssueWarnings = true,
    })
end)

CreateThread(function()
    EnsureTabletTables()
end)
