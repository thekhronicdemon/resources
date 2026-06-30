local QBCore = exports['qb-core']:GetCoreObject()
local QBPhone = {}
local AppAlerts = {}
local MentionedTweets = {}
local Hashtags = {}
local Calls = {}
local Adverts = {}
local GeneratedPlates = {}
local WebHook = ''
local FivemerrApiToken = ''
local bannedCharacters = { '%', '$', ';' }
local TWData = {}
local TabletMining = {}
local SpeakerPhoneSessions = {}

local PhoneItems = {
    phone = true,
    iphone = true,
    samsungphone = true,
}

local SimCardItems = {
    simcard = true,
    sim_card = true,
}

local function CopyTable(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, data in pairs(value) do
        copy[key] = CopyTable(data)
    end

    return copy
end

local function SafeSchemaQuery(query, params)
    local ok, err = pcall(function()
        MySQL.query.await(query, params or {})
    end)

    if not ok then
        print(('^3[prp-phone] Schema update skipped: %s^7'):format(tostring(err)))
    end
end

local function SchemaColumnExists(tableName, columnName)
    local ok, result = pcall(function()
        return MySQL.scalar.await([[
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = ?
              AND COLUMN_NAME = ?
        ]], { tableName, columnName })
    end)

    return ok and tonumber(result) and tonumber(result) > 0
end

local function SchemaIndexExists(tableName, indexName)
    local ok, result = pcall(function()
        return MySQL.scalar.await([[
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = ?
              AND INDEX_NAME = ?
        ]], { tableName, indexName })
    end)

    return ok and tonumber(result) and tonumber(result) > 0
end

local function AddSchemaColumnIfMissing(tableName, columnName, definition)
    if not SchemaColumnExists(tableName, columnName) then
        SafeSchemaQuery(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, columnName, definition))
    end
end

local function CopySchemaColumnIfExists(tableName, fromColumn, toColumn)
    if SchemaColumnExists(tableName, fromColumn) and SchemaColumnExists(tableName, toColumn) then
        SafeSchemaQuery(('UPDATE `%s` SET `%s` = `%s` WHERE (`%s` IS NULL OR `%s` = \'\') AND `%s` IS NOT NULL'):format(
            tableName,
            toColumn,
            fromColumn,
            toColumn,
            toColumn,
            fromColumn
        ))
    end
end

local function AddSchemaIndexIfMissing(tableName, indexName, columns)
    if not SchemaIndexExists(tableName, indexName) then
        SafeSchemaQuery(('ALTER TABLE `%s` ADD INDEX `%s` (%s)'):format(tableName, indexName, columns))
    end
end

local function AddSchemaPrimaryKeyIfMissing(tableName, columnName)
    if not SchemaIndexExists(tableName, 'PRIMARY') then
        SafeSchemaQuery(('ALTER TABLE `%s` ADD PRIMARY KEY (`%s`)'):format(tableName, columnName))
    end
end

MySQL.ready(function()
    SafeSchemaQuery([[
        CREATE TABLE IF NOT EXISTS phone_messages (
            id int(11) NOT NULL AUTO_INCREMENT,
            citizenid varchar(80) DEFAULT NULL,
            number varchar(50) DEFAULT NULL,
            messages LONGTEXT DEFAULT NULL,
            PRIMARY KEY (id),
            KEY citizenid (citizenid),
            KEY number (number)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    if SchemaColumnExists('phone_messages', 'CitizendID') and not SchemaColumnExists('phone_messages', 'citizenid') then
        SafeSchemaQuery('ALTER TABLE phone_messages CHANGE COLUMN `CitizendID` `citizenid` varchar(80) DEFAULT NULL')
    end

    AddSchemaColumnIfMissing('phone_messages', 'citizenid', 'varchar(80) DEFAULT NULL')
    AddSchemaColumnIfMissing('phone_messages', 'number', 'varchar(50) DEFAULT NULL')
    AddSchemaColumnIfMissing('phone_messages', 'messages', 'LONGTEXT DEFAULT NULL')
    AddSchemaColumnIfMissing('phone_messages', 'id', 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY')
    CopySchemaColumnIfExists('phone_messages', 'CitizendID', 'citizenid')
    CopySchemaColumnIfExists('phone_messages', 'CitizenID', 'citizenid')
    CopySchemaColumnIfExists('phone_messages', 'CitizenId', 'citizenid')
    CopySchemaColumnIfExists('phone_messages', 'Number', 'number')
    CopySchemaColumnIfExists('phone_messages', 'Messages', 'messages')
    if SchemaColumnExists('phone_messages', 'CitizendID') then
        SafeSchemaQuery('ALTER TABLE phone_messages MODIFY COLUMN `CitizendID` varchar(80) DEFAULT NULL')
    end

    SafeSchemaQuery('ALTER TABLE phone_gallery MODIFY image LONGTEXT NOT NULL')
    AddSchemaPrimaryKeyIfMissing('phone_messages', 'id')
    SafeSchemaQuery('ALTER TABLE phone_messages MODIFY COLUMN id int(11) NOT NULL AUTO_INCREMENT')
    SafeSchemaQuery('ALTER TABLE phone_messages MODIFY messages LONGTEXT DEFAULT NULL')
    AddSchemaIndexIfMissing('phone_messages', 'phone_messages_owner_number', '`citizenid`, `number`')
    SafeSchemaQuery('ALTER TABLE phone_tweets MODIFY url LONGTEXT DEFAULT NULL')
    SafeSchemaQuery('ALTER TABLE phone_tweets MODIFY picture LONGTEXT DEFAULT \'./img/default.png\'')
    SafeSchemaQuery([[
        CREATE TABLE IF NOT EXISTS phone_recent_calls (
            id int(11) NOT NULL AUTO_INCREMENT,
            citizenid varchar(80) DEFAULT NULL,
            name varchar(80) DEFAULT NULL,
            number varchar(50) DEFAULT NULL,
            `type` varchar(20) DEFAULT NULL,
            anonymous tinyint(1) NOT NULL DEFAULT 0,
            `time` varchar(20) DEFAULT NULL,
            `date` timestamp NULL DEFAULT current_timestamp(),
            PRIMARY KEY (id),
            KEY citizenid (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

-- Functions

local function Notify(source, message, notifyType)
    TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
end

local function ClearSpeakerPhone(source)
    local session = SpeakerPhoneSessions[source]
    if not session then return end

    for target in pairs(session.targets or {}) do
        if GetPlayerPing(target) > 0 and tonumber(Player(target).state.callChannel) == tonumber(session.callId) then
            exports['pma-voice']:setPlayerCall(target, 0)
        end
    end

    SpeakerPhoneSessions[source] = nil
end

local function SetSpeakerPhoneTargets(source, callId, targets)
    callId = tonumber(callId)
    local session = SpeakerPhoneSessions[source]
    if not session or not callId or tonumber(session.callId) ~= callId then return end

    local nextTargets = {}
    local seen = {}

    for _, target in pairs(targets or {}) do
        target = tonumber(target)
        if target and target ~= source and not seen[target] and GetPlayerPing(target) > 0 then
            seen[target] = true
            local currentCall = tonumber(Player(target).state.callChannel) or 0
            if session.targets[target] or currentCall == 0 then
                nextTargets[target] = true
            end
        end
    end

    for target in pairs(session.targets or {}) do
        if not nextTargets[target] and GetPlayerPing(target) > 0 and tonumber(Player(target).state.callChannel) == callId then
            exports['pma-voice']:setPlayerCall(target, 0)
        end
    end

    for target in pairs(nextTargets) do
        if not session.targets[target] and GetPlayerPing(target) > 0 then
            local currentCall = tonumber(Player(target).state.callChannel) or 0
            if currentCall == 0 then
                exports['pma-voice']:setPlayerCall(target, callId)
            else
                nextTargets[target] = nil
            end
        end
    end

    session.targets = nextTargets
end

local function CleanTransferValue(value)
    local cleaned = tostring(value or ''):gsub('%s+', '')
    for _, blocked in pairs(bannedCharacters) do
        cleaned = string.gsub(cleaned, '%' .. blocked, '')
    end
    return cleaned
end

local function GetTransferTarget(identifier)
    identifier = CleanTransferValue(identifier)
    if identifier == '' then return nil, nil, nil end

    local Player = QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetPlayerByAccount(identifier)
    if Player then
        return Player.PlayerData.citizenid, Player, nil
    end

    local rows = MySQL.query.await('SELECT citizenid, money FROM players WHERE citizenid = ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.account")) = ? LIMIT 1', { identifier, identifier })
    local row = rows and rows[1]
    if row then
        return row.citizenid, nil, row
    end

    return nil, nil, nil
end

local function AddBankMoneyToTransferTarget(citizenid, Player, row, amount, reason)
    if Player then
        Player.Functions.AddMoney('bank', amount, reason)
        return true
    end

    row = row or (MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { citizenid }) or {})[1]
    if not row then return false end

    local money = json.decode(row.money or '{}') or {}
    money.bank = (tonumber(money.bank) or 0) + amount
    local result = MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), citizenid })
    return result == true or (tonumber(result) or 0) > 0
end

local function TransferBankMoney(sender, targetIdentifier, amount)
    amount = tonumber(amount)
    if not sender or not amount or amount <= 0 then return false end
    if (sender.PlayerData.money.bank - amount) < 0 then return false end

    local targetCitizenId, receiver, receiverRow = GetTransferTarget(targetIdentifier)
    if not targetCitizenId or targetCitizenId == sender.PlayerData.citizenid then return false end

    sender.Functions.RemoveMoney('bank', amount, 'phone-transfered-to-' .. targetCitizenId)
    if not AddBankMoneyToTransferTarget(targetCitizenId, receiver, receiverRow, amount, 'phone-transfered-from-' .. sender.PlayerData.citizenid) then
        sender.Functions.AddMoney('bank', amount, 'phone-transfer-refund')
        return false
    end

    return true, receiver
end

local function GenerateSimNumber()
    local simConfig = Config.SimCards or {}
    local prefix = simConfig.NumberPrefix or '04'
    local length = tonumber(simConfig.NumberLength) or 8
    local number = prefix

    for _ = 1, length do
        number = number .. tostring(math.random(0, 9))
    end

    return number
end

local function GenerateUniqueSimNumber()
    for _ = 1, 25 do
        local number = GenerateSimNumber()
        local existsOnline = QBCore.Functions.GetPlayerByPhone(number)
        local existsSaved = MySQL.scalar.await('SELECT citizenid FROM players WHERE charinfo LIKE ? LIMIT 1', { '%"phone":"' .. number .. '"%' })
        local existsInventory = MySQL.scalar.await('SELECT citizenid FROM players WHERE inventory LIKE ? LIMIT 1', { '%"simNumber":"' .. number .. '"%' })
        local existsEquipment = MySQL.scalar.await('SELECT citizenid FROM players WHERE metadata LIKE ? LIMIT 1', { '%"simNumber":"' .. number .. '"%' })

        if not existsOnline and not existsSaved and not existsInventory and not existsEquipment then
            return number
        end
    end

    return GenerateSimNumber()
end

local function NormalizeSimCardInfo(info)
    info = type(info) == 'table' and info or {}
    local simNumber = info.simNumber or info.phoneNumber or info.number
    if not simNumber or tostring(simNumber) == '' or tostring(simNumber):lower() == 'unknown' then
        simNumber = GenerateUniqueSimNumber()
    end

    info.simNumber = tostring(simNumber)
    info.simSerial = info.simSerial or ('SIM-' .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(4))
    info.description = ('Phone number: %s'):format(info.simNumber)
    return info
end

local function IsPhoneItem(item)
    if not item or not item.name then return false end

    local itemName = tostring(item.name):lower()
    local itemInfo = QBCore.Shared.Items[itemName]
    return PhoneItems[itemName] == true or (itemInfo and itemInfo.phone == true)
end

local function IsSimCardItem(item)
    if not item or not item.name then return false end

    local itemName = tostring(item.name):lower()
    local itemInfo = QBCore.Shared.Items[itemName]
    return SimCardItems[itemName] == true or (itemInfo and itemInfo.simcard == true)
end

local function GetEquipment(Player)
    if not Player or not Player.PlayerData then return {} end

    local metadata = Player.PlayerData.metadata or {}
    return type(metadata.equipment) == 'table' and metadata.equipment or {}
end

local function SetEquipment(Player, equipment)
    if not Player or not Player.Functions then return false end

    Player.Functions.SetMetaData('equipment', equipment or {})
    return true
end

local function GetEquippedPhoneItem(Player)
    if not Player or not Player.PlayerData then return nil end

    local equipment = GetEquipment(Player)
    local phone = equipment.phone
    if IsPhoneItem(phone) then
        return phone
    end

    return nil
end

local function GetEquippedSimCardItem(Player)
    local simcard = GetEquipment(Player).simcard
    if IsSimCardItem(simcard) then
        return simcard
    end

    return nil
end

local function SetEquippedSimCardInfo(Player, info)
    local equipment = GetEquipment(Player)
    if not IsSimCardItem(equipment.simcard) then return false end

    equipment.simcard.info = info or {}
    if equipment.simcard.info.description then
        equipment.simcard.description = equipment.simcard.info.description
    end

    return SetEquipment(Player, equipment)
end

local function GetActiveSimInfo(Player, phone)
    local phoneInfo = type(phone and phone.info) == 'table' and phone.info or {}
    if phoneInfo.simNumber and tostring(phoneInfo.simNumber) ~= '' and tostring(phoneInfo.simNumber):lower() ~= 'unknown' then
        return phoneInfo, 'phone', phone
    end

    local simcard = GetEquippedSimCardItem(Player)
    if not simcard then return nil end

    local simInfo = NormalizeSimCardInfo(CopyTable(simcard.info or {}))
    if type(simInfo.simContacts) ~= 'table' then
        simInfo.simContacts = type(simInfo.contacts) == 'table' and simInfo.contacts or {}
    end
    simInfo.contacts = type(simInfo.contacts) == 'table' and simInfo.contacts or simInfo.simContacts

    SetEquippedSimCardInfo(Player, simInfo)
    simcard.info = simInfo

    return simInfo, 'simcard', simcard
end

local function GetPhoneItem(Player, requireSim)
    local phone = GetEquippedPhoneItem(Player)
    if not phone then return nil end

    if requireSim and not GetActiveSimInfo(Player, phone) then
        return nil
    end

    return phone
end

local function GetPhoneWithoutSim(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return nil end

    for _, item in pairs(Player.PlayerData.items) do
        if IsPhoneItem(item) then
            if not item.info or not item.info.simNumber then
                return item
            end
        end
    end

    return nil
end

local function GetPhoneBySlot(Player, slot)
    if not Player or not Player.PlayerData or not Player.PlayerData.items or not slot then return nil end

    slot = tonumber(slot)
    for _, item in pairs(Player.PlayerData.items) do
        if IsPhoneItem(item) and tonumber(item.slot) == slot then
            return item
        end
    end

    return nil
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

local function SetEquippedPhoneInfo(Player, info)
    if not Player or not Player.PlayerData then return false end

    local metadata = Player.PlayerData.metadata or {}
    local equipment = type(metadata.equipment) == 'table' and metadata.equipment or {}
    if not IsPhoneItem(equipment.phone) then return false end

    equipment.phone.info = info or {}
    if equipment.phone.info.description then
        equipment.phone.description = equipment.phone.info.description
    end

    Player.Functions.SetMetaData('equipment', equipment)
    return true
end

local function RemoveMatchingInventoryItems(Player, itemName, matcher)
    if not Player or not itemName or type(matcher) ~= 'function' then return false end

    local items = Player.PlayerData.items or {}
    local changed = false
    for key, item in pairs(items) do
        if item and item.name and item.name:lower() == itemName:lower() and matcher(item) then
            items[key] = nil
            changed = true
        end
    end

    if changed then
        Player.Functions.SetPlayerData('items', items)
    end

    return changed
end

local function SetActivePhoneNumber(Player, phoneNumber)
    if not Player or not phoneNumber then return end

    local charinfo = Player.PlayerData.charinfo or {}
    charinfo.phone = tostring(phoneNumber)
    Player.Functions.SetPlayerData('charinfo', charinfo)

    local phonedata = Player.PlayerData.metadata['phonedata'] or {}
    phonedata.ActiveSim = tostring(phoneNumber)
    Player.Functions.SetMetaData('phonedata', phonedata)
end

local function ClearActivePhoneNumber(Player, phoneNumber)
    if not Player then return end

    local removedNumber = phoneNumber and tostring(phoneNumber) or nil
    local charinfo = Player.PlayerData.charinfo or {}
    if not removedNumber or tostring(charinfo.phone or '') == removedNumber then
        charinfo.phone = ''
        Player.Functions.SetPlayerData('charinfo', charinfo)
    end

    local phonedata = Player.PlayerData.metadata['phonedata'] or {}
    if not removedNumber or tostring(phonedata.ActiveSim or '') == removedNumber then
        phonedata.ActiveSim = nil
    end
    Player.Functions.SetMetaData('phonedata', phonedata)
end

local function LoadContactRows(citizenid)
    local contacts = {}
    if not citizenid then return contacts end

    local rows = MySQL.query.await('SELECT name, number, iban FROM player_contacts WHERE citizenid = ? ORDER BY name ASC', { citizenid }) or {}
    for _, row in pairs(rows) do
        contacts[#contacts + 1] = {
            name = row.name,
            number = row.number,
            iban = row.iban
        }
    end

    return contacts
end

local function GetCitizenProfile(citizenid)
    local profile = {}
    if not citizenid then return profile end

    local OnlinePlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if OnlinePlayer then
        return OnlinePlayer.PlayerData.charinfo or {}
    end

    local result = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if result and result[1] and result[1].charinfo then
        profile = json.decode(result[1].charinfo) or {}
    end

    return profile
end

local function NormalizePhoneNumber(number)
    if number == nil then return nil end

    number = tostring(number)
    if number == '' or number:lower() == 'unknown' then return nil end

    return number
end

local function GetPhoneDataId(info, Player)
    info = type(info) == 'table' and info or {}

    if info.simNumber and tostring(info.simNumber) ~= '' then
        return 'phone:' .. tostring(info.simNumber)
    end

    if info.phoneDataId and tostring(info.phoneDataId) ~= '' then
        return tostring(info.phoneDataId)
    end

    if info.deviceId and tostring(info.deviceId) ~= '' then
        return 'device:' .. tostring(info.deviceId)
    end

    if info.deviceOwnerCitizenid and tostring(info.deviceOwnerCitizenid) ~= '' then
        return tostring(info.deviceOwnerCitizenid)
    end

    return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

local function EnsurePhoneDeviceInfo(Player, phone)
    if not phone then return {} end

    local info = type(phone.info) == 'table' and phone.info or {}
    local changed = false

    if not info.deviceId then
        info.deviceId = 'PHONE-' .. QBCore.Shared.RandomStr(4) .. QBCore.Shared.RandomInt(4)
        changed = true
    end

    if not info.deviceOwnerCitizenid and Player and Player.PlayerData then
        info.deviceOwnerCitizenid = Player.PlayerData.citizenid
        changed = true
    end

    local phoneDataId = GetPhoneDataId(info, Player)
    if phoneDataId and info.phoneDataId ~= phoneDataId then
        info.phoneDataId = phoneDataId
        changed = true
    end

    if changed then
        if phone.slot == 'phone' then
            SetEquippedPhoneInfo(Player, info)
        elseif phone.slot then
            SetInventoryItemInfo(Player, phone.slot, info)
        end
        phone.info = info
    end

    return info
end

local function GetPhoneContext(Player, requireSim)
    local phone = GetPhoneItem(Player, requireSim)
    if not phone then return nil end

    local deviceInfo = EnsurePhoneDeviceInfo(Player, phone)
    local simInfo, simSource, simItem = GetActiveSimInfo(Player, phone)
    if requireSim and not simInfo then return nil end

    local info = CopyTable(deviceInfo)
    if simInfo then
        info.simNumber = simInfo.simNumber
        info.simSerial = simInfo.simSerial
        info.simContacts = type(simInfo.simContacts) == 'table' and simInfo.simContacts or (type(simInfo.contacts) == 'table' and simInfo.contacts or {})
        info.simSlot = simInfo.simSlot
    end

    local dataCitizenid = GetPhoneDataId(info, Player)
    if dataCitizenid then
        info.phoneDataId = dataCitizenid
    end

    if info.simNumber then
        SetActivePhoneNumber(Player, info.simNumber)
    end

    return {
        phone = phone,
        info = info,
        deviceInfo = deviceInfo,
        simInfo = simInfo,
        simSource = simSource,
        simItem = simItem,
        dataCitizenid = dataCitizenid,
        phoneNumber = info.simNumber and tostring(info.simNumber) or nil,
        simContacts = type(info.simContacts) == 'table' and info.simContacts or {},
        profile = GetCitizenProfile(info.deviceOwnerCitizenid or Player.PlayerData.citizenid)
    }
end

local function SyncInstalledSimContacts(Player, contacts)
    local context = GetPhoneContext(Player, true)
    if not context then return end

    contacts = contacts or {}

    if context.simSource == 'simcard' then
        local simInfo = CopyTable(context.simInfo or (context.simItem and context.simItem.info) or {})
        simInfo.simContacts = contacts
        simInfo.contacts = contacts
        SetEquippedSimCardInfo(Player, simInfo)
        return
    end

    local phone = context.phone
    local info = EnsurePhoneDeviceInfo(Player, phone)
    info.simContacts = contacts or {}
    if phone.slot == 'phone' then
        SetEquippedPhoneInfo(Player, info)
    else
        SetInventoryItemInfo(Player, phone.slot, info)
    end
end

local function DecodeJsonObject(value, fallback)
    if type(value) == 'table' then return value end
    if not value or value == '' then return fallback or {} end

    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return fallback or {}
end

local function FindPhoneItemByNumber(items, number)
    number = NormalizePhoneNumber(number)
    if not number or type(items) ~= 'table' then return nil end

    for _, item in pairs(items) do
        if IsPhoneItem(item) then
            local info = type(item.info) == 'table' and item.info or {}
            if NormalizePhoneNumber(info.simNumber) == number then
                return item, info
            end
        end
    end

    return nil
end

local function FindMetadataPhoneByNumber(metadata, number)
    number = NormalizePhoneNumber(number)
    if not number or type(metadata) ~= 'table' then return nil end

    local equipment = type(metadata.equipment) == 'table' and metadata.equipment or {}
    local phone = equipment.phone
    if IsPhoneItem(phone) then
        local info = type(phone.info) == 'table' and phone.info or {}
        if NormalizePhoneNumber(info.simNumber) == number then
            return phone, info
        end

        local simcard = equipment.simcard
        if IsSimCardItem(simcard) then
            local simInfo = type(simcard.info) == 'table' and simcard.info or {}
            if NormalizePhoneNumber(simInfo.simNumber) == number then
                local mergedInfo = CopyTable(info)
                mergedInfo.simNumber = simInfo.simNumber
                mergedInfo.simSerial = simInfo.simSerial
                mergedInfo.simContacts = type(simInfo.simContacts) == 'table' and simInfo.simContacts or (type(simInfo.contacts) == 'table' and simInfo.contacts or {})
                mergedInfo.phoneDataId = GetPhoneDataId(mergedInfo, nil)
                return phone, mergedInfo
            end
        end
    end

    return nil
end

local function GetOnlinePhoneContextByNumber(number)
    number = NormalizePhoneNumber(number)
    if not number then return nil end

    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        local context = Player and GetPhoneContext(Player, true) or nil
        if context and NormalizePhoneNumber(context.phoneNumber or context.info.simNumber) == number then
            context.source = Player.PlayerData.source
            context.Player = Player
            return context
        end
    end

    return nil
end

local function BuildStoredPhoneContext(row, phone, info, number)
    number = NormalizePhoneNumber(number)
    info = type(info) == 'table' and info or {}

    return {
        phone = phone,
        info = info,
        dataCitizenid = GetPhoneDataId(info, nil) or (number and ('phone:' .. number)) or row.citizenid,
        phoneNumber = NormalizePhoneNumber(info.simNumber) or number,
        ownerCitizenid = info.deviceOwnerCitizenid or row.citizenid,
        profile = GetCitizenProfile(info.deviceOwnerCitizenid or row.citizenid),
        offline = true
    }
end

local function GetStoredPhoneContextByNumber(number)
    number = NormalizePhoneNumber(number)
    if not number then return nil end

    local rows = MySQL.query.await(
        'SELECT citizenid, charinfo, inventory, metadata FROM players WHERE inventory LIKE ? OR metadata LIKE ? OR charinfo LIKE ? LIMIT 25',
        { '%' .. number .. '%', '%' .. number .. '%', '%' .. number .. '%' }
    ) or {}

    for _, row in pairs(rows) do
        local metadata = DecodeJsonObject(row.metadata, {})
        local phone, info = FindMetadataPhoneByNumber(metadata, number)
        if phone then
            return BuildStoredPhoneContext(row, phone, info, number)
        end

        local inventory = DecodeJsonObject(row.inventory, {})
        phone, info = FindPhoneItemByNumber(inventory, number)
        if phone then
            return BuildStoredPhoneContext(row, phone, info, number)
        end

        local charinfo = DecodeJsonObject(row.charinfo, {})
        if NormalizePhoneNumber(charinfo.phone) == number then
            return BuildStoredPhoneContext(row, nil, {
                simNumber = number,
                phoneDataId = 'phone:' .. number,
                deviceOwnerCitizenid = row.citizenid
            }, number)
        end
    end

    return nil
end

local function GetPhoneContextByNumber(number)
    return GetOnlinePhoneContextByNumber(number) or GetStoredPhoneContextByNumber(number)
end

local function SaveChatThread(ownerKey, otherNumber, messages)
    ownerKey = ownerKey and tostring(ownerKey) or nil
    otherNumber = NormalizePhoneNumber(otherNumber)
    if not ownerKey or not otherNumber then return false end

    local encodedMessages = json.encode(messages or {})
    local chat = MySQL.query.await('SELECT id FROM phone_messages WHERE citizenid = ? AND number = ? LIMIT 1', { ownerKey, otherNumber })
    if chat and chat[1] then
        local ok, err = pcall(function()
            MySQL.update.await('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', { encodedMessages, ownerKey, otherNumber })
        end)
        if not ok then
            print(('^1[prp-phone] Failed to update saved messages for %s/%s: %s^7'):format(ownerKey, otherNumber, tostring(err)))
        end

        return true
    end

    local ok, err = pcall(function()
        MySQL.insert.await('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', { ownerKey, otherNumber, encodedMessages })
    end)
    if not ok then
        local fallbackOk, fallbackErr = pcall(function()
            MySQL.insert.await('INSERT INTO phone_messages (id, citizenid, number, messages) SELECT COALESCE(MAX(id), 0) + 1, ?, ?, ? FROM phone_messages', { ownerKey, otherNumber, encodedMessages })
        end)

        if not fallbackOk then
            print(('^1[prp-phone] Failed to insert saved messages for %s/%s: %s / %s^7'):format(ownerKey, otherNumber, tostring(err), tostring(fallbackErr)))
        end
    end

    return false
end

local function LoadRecentCalls(phoneKey)
    local calls = {}
    if not phoneKey then return calls end

    local rows = MySQL.query.await(
        'SELECT name, number, `type`, anonymous, `time` FROM phone_recent_calls WHERE citizenid = ? ORDER BY id ASC LIMIT 50',
        { phoneKey }
    ) or {}

    for _, row in pairs(rows) do
        calls[#calls + 1] = {
            name = row.name or row.number,
            number = row.number,
            type = row.type,
            anonymous = tonumber(row.anonymous) == 1,
            time = row.time
        }
    end

    return calls
end

local function StoreRecentCall(phoneKey, data, label, callType, addAlert)
    phoneKey = phoneKey and tostring(phoneKey) or nil
    if not phoneKey or not data or not data.number then return end

    MySQL.insert(
        'INSERT INTO phone_recent_calls (citizenid, name, number, `type`, anonymous, `time`) VALUES (?, ?, ?, ?, ?, ?)',
        {
            phoneKey,
            tostring(data.name or data.number),
            tostring(data.number),
            tostring(callType or 'missed'),
            data.anonymous and 1 or 0,
            tostring(label or os.date('%H:%M'))
        }
    )

    if addAlert then
        QBPhone.SetPhoneAlerts(phoneKey, 'phone')
    end
end

local function GetMailCitizenId(Player)
    local context = GetPhoneContext(Player, true)
    return context and context.dataCitizenid or Player.PlayerData.citizenid
end

local function InstallSimCard(source, simItem)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local phone = GetPhoneWithoutSim(Player) or GetPhoneItem(Player, false)
    if not phone then
        Notify(source, 'You need a phone before installing a SIM card.', 'error')
        return
    end

    local simInfo = NormalizeSimCardInfo(simItem and simItem.info or {})
    local simNumber = simInfo.simNumber
    local simSerial = simInfo.simSerial
    local simContacts = simInfo.contacts or simInfo.simContacts or LoadContactRows(Player.PlayerData.citizenid)
    simInfo.contacts = simContacts
    simInfo.simContacts = simContacts
    simInfo.description = ('Phone number: %s'):format(simNumber)
    local phoneSlot = phone.slot
    local phoneEquipped = phoneSlot == 'phone'
    local phoneInfo = EnsurePhoneDeviceInfo(Player, phone)

    if phoneInfo.simNumber then
        Notify(source, 'That phone already has a SIM card installed.', 'error')
        return
    end

    if not exports['prp-inventory']:RemoveItem(source, 'simcard', 1, simItem and simItem.slot, 'installed sim card') then
        Notify(source, 'Could not install the SIM card.', 'error')
        return
    end

    phone = phoneEquipped and GetEquippedPhoneItem(Player) or GetPhoneBySlot(Player, phoneSlot)
    if not phone then
        exports['prp-inventory']:AddItem(source, 'simcard', 1, false, simInfo, 'failed sim install refund')
        Notify(source, 'Could not find a phone slot for the SIM card.', 'error')
        return
    end

    phoneInfo = EnsurePhoneDeviceInfo(Player, phone)
    phoneInfo.simNumber = simNumber
    phoneInfo.simSerial = simSerial
    phoneInfo.simContacts = simContacts
    phoneInfo.phoneDataId = GetPhoneDataId(phoneInfo, Player)
    phoneInfo.description = 'SIM: ' .. simNumber

    local saved = phoneEquipped and SetEquippedPhoneInfo(Player, phoneInfo) or SetInventoryItemInfo(Player, phoneSlot, phoneInfo)
    if not saved then
        exports['prp-inventory']:AddItem(source, 'simcard', 1, false, simInfo, 'failed sim install refund')
        Notify(source, 'Could not save the SIM card to this phone.', 'error')
        return
    end

    RemoveMatchingInventoryItems(Player, 'simcard', function(item)
        local info = type(item.info) == 'table' and item.info or {}
        return tostring(info.simNumber or '') == tostring(simNumber)
    end)
    SetActivePhoneNumber(Player, simNumber)
    TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items['simcard'], 'remove')
    TriggerClientEvent('qb-inventory:client:updateInventory', source, Player.PlayerData.items or {})
    Notify(source, ('SIM installed. Phone number %s is now active.'):format(simNumber), 'success')
end

local function FindCryptoShopItem(itemName)
    if not itemName or not Config.CryptoShopItems then return nil end

    for _, item in pairs(Config.CryptoShopItems) do
        if item.item == itemName then
            return item
        end
    end

    return nil
end

local function GetCryptoDisplayShort()
    return (Config.PhoneCrypto and Config.PhoneCrypto.DisplayShort) or 'BTC'
end

local function AddCryptoTransaction(citizenid, title, message)
    MySQL.insert('INSERT INTO crypto_transactions (citizenid, title, message) VALUES (?, ?, ?)', {
        citizenid,
        title,
        message
    })
end

local function GetTabletMiningJobs(source)
    local jobs = {}
    local running = TabletMining[source]
    if type(running) ~= 'table' then return jobs end
    if running.id or running.reward then
        running = { running }
    end

    local now = os.time()
    for _, job in pairs(running) do
        if type(job) == 'table' then
            local seconds = tonumber(job.seconds) or 0
            local startedAt = tonumber(job.startedAt) or tonumber(job.started) or now
            local finishesAt = tonumber(job.finishesAt) or (startedAt + seconds)
            local remaining = math.max(finishesAt - now, 0)
            local elapsed = math.max(now - startedAt, 0)
            local progress = 0

            if seconds > 0 then
                progress = math.floor(math.min((elapsed / seconds) * 100, 100))
            end

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

local function GetOnlineStatus(number)
    return GetOnlinePhoneContextByNumber(number) ~= nil
end

local function GenerateMailId()
    return math.random(111111, 999999)
end

local function escape_sqli(source)
    local replacements = {
        ['"'] = '\\"',
        ["'"] = "\\'"
    }
    return source:gsub("['\"]", replacements)
end

function QBPhone.AddMentionedTweet(citizenid, TweetData)
    if MentionedTweets[citizenid] == nil then
        MentionedTweets[citizenid] = {}
    end
    MentionedTweets[citizenid][#MentionedTweets[citizenid] + 1] = TweetData
end

function QBPhone.SetPhoneAlerts(citizenid, app, alerts)
    if citizenid ~= nil and app ~= nil then
        if AppAlerts[citizenid] == nil then
            AppAlerts[citizenid] = {}
            if AppAlerts[citizenid][app] == nil then
                if alerts == nil then
                    AppAlerts[citizenid][app] = 1
                else
                    AppAlerts[citizenid][app] = alerts
                end
            end
        else
            if AppAlerts[citizenid][app] == nil then
                if alerts == nil then
                    AppAlerts[citizenid][app] = 1
                else
                    AppAlerts[citizenid][app] = 0
                end
            else
                if alerts == nil then
                    AppAlerts[citizenid][app] = AppAlerts[citizenid][app] + 1
                else
                    AppAlerts[citizenid][app] = AppAlerts[citizenid][app] + 0
                end
            end
        end
    end
end

local function SplitStringToArray(string)
    local retval = {}
    for i in string.gmatch(string, '%S+') do
        retval[#retval + 1] = i
    end
    return retval
end

local function GenerateOwnerName()
    local names = {
        [1] = { name = 'Bailey Sykes', citizenid = 'DSH091G93' },
        [2] = { name = 'Aroush Goodwin', citizenid = 'AVH09M193' },
        [3] = { name = 'Tom Warren', citizenid = 'DVH091T93' },
        [4] = { name = 'Abdallah Friedman', citizenid = 'GZP091G93' },
        [5] = { name = 'Lavinia Powell', citizenid = 'DRH09Z193' },
        [6] = { name = 'Andrew Delarosa', citizenid = 'KGV091J93' },
        [7] = { name = 'Skye Cardenas', citizenid = 'ODF09S193' },
        [8] = { name = 'Amelia-Mae Walter', citizenid = 'KSD0919H3' },
        [9] = { name = 'Elisha Cote', citizenid = 'NDX091D93' },
        [10] = { name = 'Janice Rhodes', citizenid = 'ZAL0919X3' },
        [11] = { name = 'Justin Harris', citizenid = 'ZAK09D193' },
        [12] = { name = 'Montel Graves', citizenid = 'POL09F193' },
        [13] = { name = 'Benjamin Zavala', citizenid = 'TEW0J9193' },
        [14] = { name = 'Mia Willis', citizenid = 'YOO09H193' },
        [15] = { name = 'Jacques Schmitt', citizenid = 'QBC091H93' },
        [16] = { name = 'Mert Simmonds', citizenid = 'YDN091H93' },
        [17] = { name = 'Rickie Browne', citizenid = 'PJD09D193' },
        [18] = { name = 'Deacon Stanley', citizenid = 'RND091D93' },
        [19] = { name = 'Daisy Fraser', citizenid = 'QWE091A93' },
        [20] = { name = 'Kitty Walters', citizenid = 'KJH0919M3' },
        [21] = { name = 'Jareth Fernandez', citizenid = 'ZXC09D193' },
        [22] = { name = 'Meredith Calhoun', citizenid = 'XYZ0919C3' },
        [23] = { name = 'Teagan Mckay', citizenid = 'ZYX0919F3' },
        [24] = { name = 'Kurt Bain', citizenid = 'IOP091O93' },
        [25] = { name = 'Burt Kain', citizenid = 'PIO091R93' },
        [26] = { name = 'Joanna Huff', citizenid = 'LEK091X93' },
        [27] = { name = 'Carrie-Ann Pineda', citizenid = 'ALG091Y93' },
        [28] = { name = 'Gracie-Mai Mcghee', citizenid = 'YUR09E193' },
        [29] = { name = 'Robyn Boone', citizenid = 'SOM091W93' },
        [30] = { name = 'Aliya William', citizenid = 'KAS009193' },
        [31] = { name = 'Rohit West', citizenid = 'SOK091093' },
        [32] = { name = 'Skylar Archer', citizenid = 'LOK091093' },
        [33] = { name = 'Jake Kumar', citizenid = 'AKA420609' },
    }
    return names[math.random(1, #names)]
end


local function sendNewMailToOffline(citizenid, mailData)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        local src = Player.PlayerData.source
        if mailData.button == nil then
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0 })
            TriggerClientEvent('prp-phone:client:NewMailNotify', src, mailData)
        else
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0, json.encode(mailData.button) })
            TriggerClientEvent('prp-phone:client:NewMailNotify', src, mailData)
        end
        SetTimeout(200, function()
            local mails = MySQL.query.await(
                'SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', { Player.PlayerData.citizenid })
            if mails[1] ~= nil then
                for k, _ in pairs(mails) do
                    if mails[k].button ~= nil then
                        mails[k].button = json.decode(mails[k].button)
                    end
                end
            end

            TriggerClientEvent('prp-phone:client:UpdateMails', src, mails)
        end)
    else
        if mailData.button == nil then
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', { citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0 })
        else
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', { citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0, json.encode(mailData.button) })
        end
    end
end
exports('sendNewMailToOffline', sendNewMailToOffline)

-- Usable items

QBCore.Functions.CreateUseableItem('phone', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    if Config.SimCards and Config.SimCards.RequireSim and not (item.info and item.info.simNumber) then
        Notify(source, 'This phone needs a SIM card before it can be used.', 'error')
        return
    end

    if item.info and item.info.simNumber then
        SetActivePhoneNumber(Player, item.info.simNumber)
    end

    TriggerClientEvent('prp-phone:client:UsePhone', source)
end)

QBCore.Functions.CreateUseableItem('simcard', function(source, item)
    InstallSimCard(source, item)
end)

-- Callbacks

QBCore.Functions.CreateCallback("prp-phone:server:GetInvoices", function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)

    if Player then
        local invoices = MySQL.query.await('SELECT * FROM phone_invoices WHERE citizenid = ?', { Player.PlayerData.citizenid })
        for _, v in pairs(invoices) do
            local Ply = QBCore.Functions.GetPlayerByCitizenId(v.sender)
            if Ply ~= nil then
                v.number = Ply.PlayerData.charinfo.phone
            else
                local res = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { v.sender })
                if res[1] ~= nil then
                    res[1].charinfo = json.decode(res[1].charinfo)
                    v.number = res[1].charinfo.phone
                else
                    v.number = nil
                end
            end
        end
        cb(invoices)
        return
    end

    cb({})
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetCallState', function(_, cb, ContactData)
    local targetContext = ContactData and GetPhoneContextByNumber(ContactData.number) or nil
    if not targetContext then
        cb(false, false)
        return
    end

    local targetKey = targetContext.dataCitizenid
    local isOnline = targetContext.source ~= nil
    local canCall = not (Calls[targetKey] and Calls[targetKey].inCall)
    cb(canCall, isOnline)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetPhoneData', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player == nil then
        cb({})
        return
    end

    local phonedata = Player.PlayerData.metadata['phonedata'] or {}
    local PhoneData = {
        Applications = {},
        PlayerContacts = {},
        MentionedTweets = {},
        Chats = {},
        Hashtags = {},
        Garage = {},
        Mails = {},
        Adverts = {},
        CryptoTransactions = {},
        Tweets = {},
        Images = {},
        RecentCalls = {},
        InstalledApps = phonedata.InstalledApps or {}
    }
    PhoneData.Adverts = Adverts

    local context = GetPhoneContext(Player, true)
    if not context then
        PhoneData.NoSim = true
        cb(PhoneData)
        return
    end

    local dataCitizenid = context.dataCitizenid
    PhoneData.DeviceProfile = {
        citizenid = dataCitizenid,
        charinfo = context.profile or {}
    }
    PhoneData.ActiveSim = context.info.simNumber
    PhoneData.RecentCalls = LoadRecentCalls(dataCitizenid)

    local contacts = context.simContacts
    if type(contacts) ~= 'table' or next(contacts) == nil then
        contacts = LoadContactRows(dataCitizenid)
        SyncInstalledSimContacts(Player, contacts)
    end

    for _, contact in pairs(contacts) do
        PhoneData.PlayerContacts[#PhoneData.PlayerContacts + 1] = {
            id = contact.id,
            name = contact.name,
            number = contact.number,
            iban = contact.iban,
            status = GetOnlineStatus(contact.number)
        }
    end

    local garageresult = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { Player.PlayerData.citizenid })
    if garageresult[1] ~= nil then
        PhoneData.Garage = garageresult
    end

    local messages = MySQL.query.await('SELECT id, citizenid, number AS number, messages AS messages FROM phone_messages WHERE citizenid = ?', { dataCitizenid })
    if messages ~= nil and next(messages) ~= nil then
        PhoneData.Chats = messages
    end

    if AppAlerts[dataCitizenid] ~= nil then
        PhoneData.Applications = AppAlerts[dataCitizenid]
    end

    if MentionedTweets[dataCitizenid] ~= nil then
        PhoneData.MentionedTweets = MentionedTweets[dataCitizenid]
    end

    if Hashtags ~= nil and next(Hashtags) ~= nil then
        PhoneData.Hashtags = Hashtags
    end

    local Tweets = MySQL.query.await('SELECT * FROM phone_tweets WHERE `date` > NOW() - INTERVAL ? hour', { Config.TweetDuration })

    if Tweets ~= nil and next(Tweets) ~= nil then
        PhoneData.Tweets = Tweets
        TWData = Tweets
    end

    local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', { dataCitizenid })
    if mails[1] ~= nil then
        for k, _ in pairs(mails) do
            if mails[k].button ~= nil then
                mails[k].button = json.decode(mails[k].button)
            end
        end
        PhoneData.Mails = mails
    end

    local transactions = MySQL.query.await('SELECT * FROM crypto_transactions WHERE citizenid = ? ORDER BY `date` ASC', { Player.PlayerData.citizenid })
    if transactions[1] ~= nil then
        for _, v in pairs(transactions) do
            PhoneData.CryptoTransactions[#PhoneData.CryptoTransactions + 1] = {
                TransactionTitle = v.title,
                TransactionMessage = v.message
            }
        end
    end
    local images = MySQL.query.await('SELECT * FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC', { dataCitizenid })
    if images ~= nil and next(images) ~= nil then
        PhoneData.Images = images
    end
    cb(PhoneData)
end)

QBCore.Functions.CreateCallback('prp-phone:server:PayInvoice', function(source, cb, society, amount, invoiceId, sendercitizenid)
    local Ply = QBCore.Functions.GetPlayer(source)
    local SenderPly = QBCore.Functions.GetPlayerByCitizenId(sendercitizenid)
    local invoiceMailData = nil
    if Ply then
        local exists = MySQL.query.await('select count(1) as count FROM phone_invoices WHERE id = ? and citizenid = ?', { invoiceId, Ply.PlayerData.citizenid })

        if exists[1] and exists[1]["count"] == 1 then
            if SenderPly and Config.BillingCommissions[society] then
                local commission = QBCore.Shared.Round(amount * Config.BillingCommissions[society])
                SenderPly.Functions.AddMoney('bank', commission)
                invoiceMailData = {
                    sender = 'Billing Department',
                    subject = 'Commission Received',
                    message = string.format('You received a commission check of $%s when %s %s paid a bill of $%s.', commission, Ply.PlayerData.charinfo.firstname, Ply.PlayerData.charinfo.lastname, amount)
                }
            elseif not SenderPly and Config.BillingCommissions[society] then
                invoiceMailData = {
                    sender = 'Billing Department',
                    subject = 'Bill Paid',
                    message = string.format('%s %s paid a bill of $%s', Ply.PlayerData.charinfo.firstname, Ply.PlayerData.charinfo.lastname, amount)
                }
            end
            if Ply.Functions.RemoveMoney('bank', amount, 'paid-invoice') then
                MySQL.query('DELETE FROM phone_invoices WHERE id = ? and citizenid = ?', { invoiceId, Ply.PlayerData.citizenid })
                if invoiceMailData then
                    exports['prp-phone']:sendNewMailToOffline(sendercitizenid, invoiceMailData)
                end
                TriggerEvent("prp-phone:server:paidInvoice", source, invoiceId)
                exports['qb-banking']:AddMoney(society, amount, 'Phone invoice')
                cb(true)
                return
            end
        end
    end
    cb(false)
end)

QBCore.Functions.CreateCallback('prp-phone:server:DeclineInvoice', function(source, cb, _, _, invoiceId)
    local Ply = QBCore.Functions.GetPlayer(source)
    if Ply then
        local exists = MySQL.query.await('select count(1) as count FROM phone_invoices WHERE id = ? and citizenid = ? and candecline = ?', { invoiceId, Ply.PlayerData.citizenid, 1 })

        if exists[1] and exists[1]["count"] == 1 then
            TriggerEvent("prp-phone:server:declinedInvoice", source, invoiceId)
            MySQL.query('DELETE FROM phone_invoices WHERE id = ? and citizenid = ? and candecline = ?', { invoiceId, Ply.PlayerData.citizenid, 1 })
            cb(true)
            return
        end
    end

    cb(false)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetContactPictures', function(_, cb, Chats)
    for _, v in pairs(Chats) do
        local query = '%' .. v.number .. '%'
        local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
        if result[1] ~= nil then
            local MetaData = DecodeJsonObject(result[1].metadata, {})
            local PhoneMeta = type(MetaData.phone) == 'table' and MetaData.phone or {}

            if PhoneMeta.profilepicture ~= nil then
                v.picture = PhoneMeta.profilepicture
            else
                v.picture = 'default'
            end
        else
            v.picture = v.picture or 'default'
        end
    end
    SetTimeout(100, function()
        cb(Chats)
    end)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetContactPicture', function(_, cb, Chat)
    local query = '%' .. Chat.number .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
    Chat.picture = 'default'
    if result and result[1] ~= nil then
        local MetaData = DecodeJsonObject(result[1].metadata, {})
        local PhoneMeta = type(MetaData.phone) == 'table' and MetaData.phone or {}
        if PhoneMeta.profilepicture ~= nil then
            Chat.picture = PhoneMeta.profilepicture
        end
    end
    SetTimeout(100, function()
        cb(Chat)
    end)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetPicture', function(_, cb, number)
    local query = '%' .. number .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
    if result[1] ~= nil then
        local Picture = 'default'
        local MetaData = json.decode(result[1].metadata)
        if MetaData.phone.profilepicture ~= nil then
            Picture = MetaData.phone.profilepicture
        end
        cb(Picture)
    else
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('prp-phone:server:FetchResult', function(_, cb, search)
    search = escape_sqli(search)
    local searchData = {}
    local ApaData = {}
    local query = 'SELECT * FROM `players` WHERE `citizenid` = "' .. search .. '"'
    -- Split on " " and check each var individual
    local searchParameters = SplitStringToArray(search)
    -- Construct query dynamicly for individual parm check
    if #searchParameters > 1 then
        query = query .. ' OR `charinfo` LIKE "%' .. searchParameters[1] .. '%"'
        for i = 2, #searchParameters do
            query = query .. ' AND `charinfo` LIKE  "%' .. searchParameters[i] .. '%"'
        end
    else
        query = query .. ' OR `charinfo` LIKE "%' .. search .. '%"'
    end
    local ApartmentData = MySQL.query.await('SELECT * FROM apartments', {})
    for k, v in pairs(ApartmentData) do
        ApaData[v.citizenid] = ApartmentData[k]
    end
    local result = MySQL.query.await(query)
    if result[1] ~= nil then
        for _, v in pairs(result) do
            local charinfo = json.decode(v.charinfo)
            local metadata = json.decode(v.metadata)
            local appiepappie = {}
            if ApaData[v.citizenid] ~= nil and next(ApaData[v.citizenid]) ~= nil then
                appiepappie = ApaData[v.citizenid]
            end
            searchData[#searchData + 1] = {
                citizenid = v.citizenid,
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                birthdate = charinfo.birthdate,
                phone = charinfo.phone,
                nationality = charinfo.nationality,
                gender = charinfo.gender,
                warrant = false,
                driverlicense = metadata['licences']['driver'],
                appartmentdata = appiepappie
            }
        end
        cb(searchData)
    else
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetVehicleSearchResults', function(_, cb, search)
    search = escape_sqli(search)
    local searchData = {}
    local query = '%' .. search .. '%'
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate LIKE ? OR citizenid = ?',
        { query, search })
    if result[1] ~= nil then
        for k, _ in pairs(result) do
            local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { result[k].citizenid })
            if player[1] ~= nil then
                local charinfo = json.decode(player[1].charinfo)
                local vehicleInfo = QBCore.Shared.Vehicles[result[k].vehicle]
                if vehicleInfo ~= nil then
                    searchData[#searchData + 1] = {
                        plate = result[k].plate,
                        status = true,
                        owner = charinfo.firstname .. ' ' .. charinfo.lastname,
                        citizenid = result[k].citizenid,
                        label = vehicleInfo['name']
                    }
                else
                    searchData[#searchData + 1] = {
                        plate = result[k].plate,
                        status = true,
                        owner = charinfo.firstname .. ' ' .. charinfo.lastname,
                        citizenid = result[k].citizenid,
                        label = 'Name not found..'
                    }
                end
            end
        end
    else
        if GeneratedPlates[search] ~= nil then
            searchData[#searchData + 1] = {
                plate = GeneratedPlates[search].plate,
                status = GeneratedPlates[search].status,
                owner = GeneratedPlates[search].owner,
                citizenid = GeneratedPlates[search].citizenid,
                label = 'Brand unknown..'
            }
        else
            local ownerInfo = GenerateOwnerName()
            GeneratedPlates[search] = {
                plate = search,
                status = true,
                owner = ownerInfo.name,
                citizenid = ownerInfo.citizenid
            }
            searchData[#searchData + 1] = {
                plate = search,
                status = true,
                owner = ownerInfo.name,
                citizenid = ownerInfo.citizenid,
                label = 'Brand unknown..'
            }
        end
    end
    cb(searchData)
end)

QBCore.Functions.CreateCallback('prp-phone:server:ScanPlate', function(source, cb, plate)
    local src = source
    local vehicleData
    if plate ~= nil then
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', { plate })
        if result[1] ~= nil then
            local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { result[1].citizenid })
            local charinfo = json.decode(player[1].charinfo)
            vehicleData = {
                plate = plate,
                status = true,
                owner = charinfo.firstname .. ' ' .. charinfo.lastname,
                citizenid = result[1].citizenid
            }
        elseif GeneratedPlates ~= nil and GeneratedPlates[plate] ~= nil then
            vehicleData = GeneratedPlates[plate]
        else
            local ownerInfo = GenerateOwnerName()
            GeneratedPlates[plate] = {
                plate = plate,
                status = true,
                owner = ownerInfo.name,
                citizenid = ownerInfo.citizenid
            }
            vehicleData = {
                plate = plate,
                status = true,
                owner = ownerInfo.name,
                citizenid = ownerInfo.citizenid
            }
        end
        cb(vehicleData)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No Vehicle Nearby', 'error')
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('prp-phone:server:HasPhone', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player ~= nil then
        local requireSim = Config.SimCards and Config.SimCards.RequireSim
        local phone = GetPhoneItem(Player, false)
        if not phone then
            cb(false, false, false)
            return
        end

        local hasSim = not requireSim or GetActiveSimInfo(Player, phone) ~= nil
        cb(hasSim, true, requireSim and not hasSim)
        return
    end

    cb(false, false, false)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetTabletStatus', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local tablet = GetTabletItem(Player)
    local info = tablet and type(tablet.info) == 'table' and tablet.info or {}

    cb({
        cryptoDrive = info.cryptoDrive,
        activeMining = GetTabletMiningJobs(source)
    })
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetCryptoShopItems', function(_, cb)
    cb(Config.CryptoShopItems or {})
end)

QBCore.Functions.CreateCallback('prp-phone:server:BuyCryptoShopItem', function(source, cb, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    if type(itemName) == 'table' then
        itemName = itemName.item
    end

    local shopItem = FindCryptoShopItem(itemName)
    if not shopItem then
        cb({ success = false, message = 'That item is not for sale.' })
        return
    end

    if not QBCore.Shared.Items[shopItem.item] then
        cb({ success = false, message = 'That shop item is missing from shared items.' })
        return
    end

    local price = tonumber(shopItem.price) or 0
    local amount = tonumber(shopItem.amount) or 1
    local crypto = tonumber(Player.PlayerData.money.crypto) or 0

    if crypto < price then
        cb({ success = false, message = ('Not enough %s.'):format(GetCryptoDisplayShort()) })
        return
    end

    if not Player.Functions.RemoveMoney('crypto', price, 'crypto shop purchase') then
        cb({ success = false, message = 'Payment failed.' })
        return
    end

    if not exports['prp-inventory']:AddItem(src, shopItem.item, amount, false, shopItem.info or {}, 'crypto shop purchase') then
        Player.Functions.AddMoney('crypto', price, 'crypto shop refund')
        cb({ success = false, message = 'Your inventory is full.' })
        return
    end

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[shopItem.item], 'add')
    AddCryptoTransaction(Player.PlayerData.citizenid, 'Crypto Shop', ('Purchased %sx %s for %.2f %s.'):format(amount, shopItem.label or shopItem.item, price, GetCryptoDisplayShort()))
    cb({ success = true, message = ('Purchased %sx %s.'):format(amount, shopItem.label or shopItem.item) })
end)

QBCore.Functions.CreateCallback('prp-phone:server:StartTabletCryptoMine', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    local miningConfig = Config.TabletCryptoMining or {}
    local tablet = GetTabletItem(Player)
    local tabletInfo = tablet and type(tablet.info) == 'table' and tablet.info or {}
    local insertedDrive = tabletInfo.cryptoDrive

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
    tabletInfo.description = 'No crypto drive inserted'
    if not SetInventoryItemInfo(Player, tablet.slot, tabletInfo) then
        cb({ success = false, message = 'Could not read the crypto drive.' })
        return
    end

    TriggerClientEvent('qb-inventory:client:updateInventory', src)

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
        local message = ('Crypto rig paid out %.6f %s.'):format(reward, GetCryptoDisplayShort())
        AddCryptoTransaction(Target.PlayerData.citizenid, 'Tablet Rig', message)
        TriggerClientEvent('prp-phone:client:TabletMiningComplete', src, reward, message, GetTabletMiningJobs(src))
        TriggerClientEvent('prp-phone:client:AddTransaction', src, Target, {}, message, 'Tablet Rig')
    end)

    cb({ success = true, message = ('%s started. ETA %s minute(s).'):format(miningJob.label, math.ceil(seconds / 60)), seconds = seconds, activeMining = GetTabletMiningJobs(src) })
end)

local function GetBusinessAccess(Player)
    if not Player then return nil end

    local job = Player.PlayerData.job or {}
    if not job.isboss or not job.name or job.name == 'unemployed' then
        return nil
    end

    return job
end

local function FormatEmployee(Target)
    local charinfo = Target.PlayerData.charinfo or {}
    local job = Target.PlayerData.job or {}
    local grade = job.grade or {}

    return {
        citizenid = Target.PlayerData.citizenid,
        name = ((charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')):gsub('%s+$', ''),
        grade = grade.name or tostring(grade.level or 0),
        gradeLevel = tonumber(grade.level) or 0,
        isBoss = job.isboss == true,
        online = Target.PlayerData.source ~= nil
    }
end

QBCore.Functions.CreateCallback('prp-phone:server:GetBusinessControlData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = GetBusinessAccess(Player)
    if not job then
        cb({ success = false, message = 'Business boss access required.', employees = {} })
        return
    end

    local employees = {}
    local players = MySQL.query.await('SELECT citizenid FROM players WHERE job LIKE ?', { '%' .. job.name .. '%' }) or {}
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

    cb({
        success = true,
        job = {
            name = job.name,
            label = job.label or job.name,
            grade = job.grade
        },
        employees = employees
    })
end)

QBCore.Functions.CreateCallback('prp-phone:server:BusinessHireClosest', function(source, cb, targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    local job = GetBusinessAccess(Player)

    if not job then
        cb({ success = false, message = 'Business boss access required.' })
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
        TriggerClientEvent('QBCore:Notify', src, ('You hired %s into %s.'):format(Target.PlayerData.charinfo.firstname, job.label or job.name), 'success')
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('You were hired by %s.'):format(job.label or job.name), 'success')
        TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Tablet Business Hire', 'lightgreen', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' hired ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. job.name .. ')', false)
        cb({ success = true, message = 'Closest player hired.' })
        return
    end

    cb({ success = false, message = 'Could not hire that player.' })
end)

QBCore.Functions.CreateCallback('prp-phone:server:BusinessFireMember', function(source, cb, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local job = GetBusinessAccess(Player)

    if not job then
        cb({ success = false, message = 'Business boss access required.' })
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
        TriggerClientEvent('QBCore:Notify', src, 'Employee fired.', 'success')
        if Employee.PlayerData.source then
            TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, 'You have been fired.', 'error')
        end
        TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Tablet Business Fire', 'orange', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' fired ' .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. job.name .. ')', false)
        cb({ success = true, message = 'Employee fired.' })
        return
    end

    cb({ success = false, message = 'Could not fire that employee.' })
end)

QBCore.Functions.CreateCallback('prp-phone:server:GangHireClosest', function(source, cb, targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))

    if not Player or not Target then
        cb({ success = false, message = 'No one is nearby.' })
        return
    end

    local gang = Player.PlayerData.gang or {}
    if not gang.isboss or gang.name == 'none' then
        cb({ success = false, message = 'Gang boss access required.' })
        return
    end

    if Target.Functions.SetGang(gang.name, 0) then
        Target.Functions.Save()
        TriggerClientEvent('QBCore:Notify', src, ('You hired %s into %s.'):format(Target.PlayerData.charinfo.firstname, gang.label), 'success')
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('You have been hired into %s.'):format(gang.label), 'success')
        TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Phone Gang Hire', 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' recruited ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. gang.name .. ')', false)
        cb({ success = true, message = 'Closest player hired.' })
        return
    end

    cb({ success = false, message = 'Could not hire that player.' })
end)

QBCore.Functions.CreateCallback('prp-phone:server:GangFireClosest', function(source, cb, targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))

    if not Player or not Target then
        cb({ success = false, message = 'No one is nearby.' })
        return
    end

    local gang = Player.PlayerData.gang or {}
    local targetGang = Target.PlayerData.gang or {}
    if not gang.isboss or gang.name == 'none' then
        cb({ success = false, message = 'Gang boss access required.' })
        return
    end

    if targetGang.name ~= gang.name then
        cb({ success = false, message = 'That player is not in your gang.' })
        return
    end

    local targetLevel = tonumber(targetGang.grade and targetGang.grade.level) or 0
    local bossLevel = tonumber(gang.grade and gang.grade.level) or 0
    if targetLevel > bossLevel then
        cb({ success = false, message = 'You cannot fire that member.' })
        return
    end

    if Target.Functions.SetGang('none', '0') then
        Target.Functions.Save()
        TriggerClientEvent('QBCore:Notify', src, 'Gang member fired.', 'success')
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'You have been expelled from the gang.', 'error')
        TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Phone Gang Fire', 'orange', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' fired ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. gang.name .. ')', false)
        cb({ success = true, message = 'Closest member fired.' })
        return
    end

    cb({ success = false, message = 'Could not fire that member.' })
end)

QBCore.Functions.CreateCallback('prp-phone:server:CanTransferMoney', function(source, cb, amount, citizenid)
    amount = tonumber(CleanTransferValue(amount))
    local Player = QBCore.Functions.GetPlayer(source)
    local transferred = TransferBankMoney(Player, citizenid, amount)
    cb(transferred)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetCurrentLawyers', function(_, cb)
    local Lawyers = {}
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(v)
        if Player ~= nil then
            if (Player.PlayerData.job.name == 'lawyer' or Player.PlayerData.job.name == 'realestate' or
                    Player.PlayerData.job.name == 'mechanic' or Player.PlayerData.job.name == 'taxi' or
                    Player.PlayerData.job.name == 'police' or Player.PlayerData.job.name == 'ambulance') and
                Player.PlayerData.job.onduty then
                Lawyers[#Lawyers + 1] = {
                    name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                    phone = Player.PlayerData.charinfo.phone,
                    typejob = Player.PlayerData.job.name
                }
            end
        end
    end
    cb(Lawyers)
end)

QBCore.Functions.CreateCallback('prp-phone:server:GetWebhook', function(_, cb)
    if WebHook ~= '' then
        cb(WebHook)
    else
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('prp-phone:server:UploadToFivemerr', function(source, cb)
    local src = source

    if Config.Fivemerr == true and FivemerrApiToken == '' then
        print("^1--- Fivemerr is enabled but no API token has been specified. ---^7")
        return cb(nil)
    end

    exports['screenshot-basic']:requestClientScreenshot(src, {
        encoding = 'png'
    }, function(err, data)
        if err then return cb(nil) end
        PerformHttpRequest(WebHook, function(status, response)
            if status ~= 200 then
                print("^1--- ERROR UPLOADING IMAGE: " .. status .. " ---^7")
                cb(nil)
            end

            cb(response)
        end, "POST", json.encode({ data = data }), {
            ['Authorization'] = FivemerrApiToken,
            ['Content-Type'] = 'application/json'
        })
    end)
end)

-- Events

RegisterNetEvent('prp-phone:server:AddAdvert', function(msg, url)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid
    if Adverts[CitizenId] ~= nil then
        Adverts[CitizenId].message = msg
        Adverts[CitizenId].name = '@' .. Player.PlayerData.charinfo.firstname .. '' .. Player.PlayerData.charinfo.lastname
        Adverts[CitizenId].number = Player.PlayerData.charinfo.phone
        Adverts[CitizenId].url = url
    else
        Adverts[CitizenId] = {
            message = msg,
            name = '@' .. Player.PlayerData.charinfo.firstname .. '' .. Player.PlayerData.charinfo.lastname,
            number = Player.PlayerData.charinfo.phone,
            url = url
        }
    end
    TriggerClientEvent('prp-phone:client:UpdateAdverts', -1, Adverts, '@' .. Player.PlayerData.charinfo.firstname .. '' .. Player.PlayerData.charinfo.lastname)
end)

RegisterNetEvent('prp-phone:server:DeleteAdvert', function()
    local Player = QBCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid
    Adverts[citizenid] = nil
    TriggerClientEvent('prp-phone:client:UpdateAdvertsDel', -1, Adverts)
end)

RegisterNetEvent('prp-phone:server:SetCallState', function(bool)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    if not Ply then return end
    if not bool then
        ClearSpeakerPhone(src)
    end

    local context = GetPhoneContext(Ply, true)
    local callKey = context and context.dataCitizenid or Ply.PlayerData.citizenid
    if Calls[callKey] ~= nil then
        Calls[callKey].inCall = bool
    else
        Calls[callKey] = {}
        Calls[callKey].inCall = bool
    end
end)

RegisterNetEvent('prp-phone:server:SetSpeakerPhone', function(enabled, callId)
    local src = source
    ClearSpeakerPhone(src)

    callId = tonumber(callId)
    if enabled and callId and callId > 0 then
        SpeakerPhoneSessions[src] = {
            callId = callId,
            targets = {},
        }
    end
end)

RegisterNetEvent('prp-phone:server:UpdateSpeakerTargets', function(callId, targets)
    SetSpeakerPhoneTargets(source, callId, targets)
end)

RegisterNetEvent('prp-phone:server:RemoveMail', function(MailId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local mailCitizenid = GetMailCitizenId(Player)
    MySQL.query('DELETE FROM player_mails WHERE mailid = ? AND citizenid = ?', { MailId, mailCitizenid })
    SetTimeout(100, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', { mailCitizenid })
        if mails[1] ~= nil then
            for k, _ in pairs(mails) do
                if mails[k].button ~= nil then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('prp-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('prp-phone:server:sendNewMail', function(mailData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if mailData.button == nil then
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0 })
    else
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0, json.encode(mailData.button) })
    end
    TriggerClientEvent('prp-phone:client:NewMailNotify', src, mailData)
    SetTimeout(200, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` DESC',
            { Player.PlayerData.citizenid })
        if mails[1] ~= nil then
            for k, _ in pairs(mails) do
                if mails[k].button ~= nil then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end

        TriggerClientEvent('prp-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('prp-phone:server:sendNewEventMail', function(citizenid, mailData)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if mailData.button == nil then
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', { citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0 })
    else
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', { citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0, json.encode(mailData.button) })
    end
    SetTimeout(200, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', { citizenid })
        if mails[1] ~= nil then
            for k, _ in pairs(mails) do
                if mails[k].button ~= nil then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('prp-phone:client:UpdateMails', Player.PlayerData.source, mails)
    end)
end)

RegisterNetEvent('prp-phone:server:ClearButtonData', function(mailId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local mailCitizenid = GetMailCitizenId(Player)
    MySQL.update('UPDATE player_mails SET button = ? WHERE mailid = ? AND citizenid = ?', { '', mailId, mailCitizenid })
    SetTimeout(200, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', { mailCitizenid })
        if mails[1] ~= nil then
            for k, _ in pairs(mails) do
                if mails[k].button ~= nil then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('prp-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('prp-phone:server:MentionedPlayer', function(firstName, lastName, TweetMessage)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(v)
        if Player ~= nil then
            if (Player.PlayerData.charinfo.firstname == firstName and Player.PlayerData.charinfo.lastname == lastName) then
                QBPhone.SetPhoneAlerts(Player.PlayerData.citizenid, 'twitter')
                QBPhone.AddMentionedTweet(Player.PlayerData.citizenid, TweetMessage)
                TriggerClientEvent('prp-phone:client:GetMentioned', Player.PlayerData.source, TweetMessage, AppAlerts[Player.PlayerData.citizenid]['twitter'])
            else
                local query1 = '%' .. firstName .. '%'
                local query2 = '%' .. lastName .. '%'
                local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ? AND charinfo LIKE ?', { query1, query2 })
                if result[1] ~= nil then
                    local MentionedTarget = result[1].citizenid
                    QBPhone.SetPhoneAlerts(MentionedTarget, 'twitter')
                    QBPhone.AddMentionedTweet(MentionedTarget, TweetMessage)
                end
            end
        end
    end
end)

RegisterNetEvent('prp-phone:server:CallContact', function(TargetData, CallId, AnonymousCall)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    if not Ply or not TargetData or not TargetData.number then return end

    local callerContext = GetPhoneContext(Ply, true)
    if not callerContext then return end

    local callerNumber = tostring(callerContext.phoneNumber or Ply.PlayerData.charinfo.phone or '')
    local label = os.date('%H:%M')
    StoreRecentCall(callerContext.dataCitizenid, TargetData, label, 'outgoing', false)
    TriggerClientEvent('prp-phone:client:AddRecentCall', src, TargetData, label, 'outgoing', true)

    local targetContext = GetPhoneContextByNumber(TargetData.number)
    if targetContext and targetContext.source then
        TriggerClientEvent('prp-phone:client:GetCalled', targetContext.source, callerNumber, CallId, AnonymousCall)
    elseif targetContext then
        StoreRecentCall(targetContext.dataCitizenid, {
            name = AnonymousCall and 'Anonymous' or callerNumber,
            number = callerNumber,
            anonymous = AnonymousCall
        }, label, 'missed', true)
    end
end)

RegisterNetEvent('prp-phone:server:BillingEmail', function(data, paid)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local target = QBCore.Functions.GetPlayer(v)
        if target.PlayerData.job.name == data.society then
            if paid then
                local name = '' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.firstname .. ' ' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.lastname .. ''
                TriggerClientEvent('prp-phone:client:BillingEmail', target.PlayerData.source, data, true, name)
            else
                local name = '' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.firstname .. ' ' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.lastname .. ''
                TriggerClientEvent('prp-phone:client:BillingEmail', target.PlayerData.source, data, false, name)
            end
        end
    end
end)

RegisterNetEvent('prp-phone:server:UpdateHashtags', function(Handle, messageData)
    if Hashtags[Handle] ~= nil and next(Hashtags[Handle]) ~= nil then
        Hashtags[Handle].messages[#Hashtags[Handle].messages + 1] = messageData
    else
        Hashtags[Handle] = {
            hashtag = Handle,
            messages = {}
        }
        Hashtags[Handle].messages[#Hashtags[Handle].messages + 1] = messageData
    end
    TriggerClientEvent('prp-phone:client:UpdateHashtags', -1, Handle, messageData)
end)

RegisterNetEvent('prp-phone:server:SetPhoneAlerts', function(app, alerts)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local CitizenId = context and context.dataCitizenid or Player.PlayerData.citizenid
    QBPhone.SetPhoneAlerts(CitizenId, app, alerts)
end)

RegisterNetEvent('prp-phone:server:DeleteTweet', function(tweetId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    local delete = false
    local TID = tweetId
    local Data = MySQL.scalar.await('SELECT citizenid FROM phone_tweets WHERE tweetId = ?', { TID })
    if Data == dataCitizenid then
        MySQL.query.await('DELETE FROM phone_tweets WHERE tweetId = ?', { TID })
        delete = true
    end

    if delete then
        for k, _ in pairs(TWData) do
            if TWData[k].tweetId == TID then
                TWData = nil
            end
        end
        TriggerClientEvent('prp-phone:client:UpdateTweets', -1, TWData, nil, true)
    end
end)

RegisterNetEvent('prp-phone:server:UpdateTweets', function(NewTweets, TweetData)
    local src = source

    MySQL.insert('INSERT INTO phone_tweets (citizenid, firstName, lastName, message, date, url, picture, tweetid) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        TweetData.citizenid,
        TweetData.firstName,
        TweetData.lastName,
        TweetData.message,
        TweetData.time,
        TweetData.url:gsub('[%<>\"()\' $]', ''),
        TweetData.picture:gsub('[%<>\"()\' $]', ''),
        TweetData.tweetId
    })
    TriggerClientEvent('prp-phone:client:UpdateTweets', -1, src, NewTweets, TweetData, false)
end)

RegisterNetEvent('prp-phone:server:TransferMoney', function(citizenid, amount)
    local src = source
    local sender = QBCore.Functions.GetPlayer(src)

    local transferred, receiver = TransferBankMoney(sender, citizenid, amount)
    if transferred then
        if receiver ~= nil then
            local PhoneItem = receiver.Functions.GetItemByName('phone')
            if PhoneItem ~= nil then
                TriggerClientEvent('prp-phone:client:TransferMoney', receiver.PlayerData.source, amount, receiver.PlayerData.money.bank)
            end
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "This Citizen ID doesn't exist or the transfer is invalid!", 'error')
    end
end)

RegisterNetEvent('prp-phone:server:EditContact', function(newName, newNumber, newIban, oldName, oldNumber, _)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    if not context then return end

    MySQL.update(
        'UPDATE player_contacts SET name = ?, number = ?, iban = ? WHERE citizenid = ? AND name = ? AND number = ?',
        { newName, newNumber, newIban, context.dataCitizenid, oldName, oldNumber })

    local contacts = context.simContacts
    if type(contacts) ~= 'table' or next(contacts) == nil then
        contacts = LoadContactRows(context.dataCitizenid)
    end

    for _, contact in pairs(contacts) do
        if contact.name == oldName and contact.number == oldNumber then
            contact.name = tostring(newName)
            contact.number = tostring(newNumber)
            contact.iban = tostring(newIban)
            break
        end
    end
    SyncInstalledSimContacts(Player, contacts)
end)

RegisterNetEvent('prp-phone:server:RemoveContact', function(Name, Number)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    if not context then return end

    MySQL.query('DELETE FROM player_contacts WHERE name = ? AND number = ? AND citizenid = ?',
        { Name, Number, context.dataCitizenid })

    local contacts = context.simContacts
    if type(contacts) ~= 'table' or next(contacts) == nil then
        contacts = LoadContactRows(context.dataCitizenid)
    end

    local updatedContacts = {}
    for _, contact in pairs(contacts) do
        if not (contact.name == Name and contact.number == Number) then
            updatedContacts[#updatedContacts + 1] = contact
        end
    end
    SyncInstalledSimContacts(Player, updatedContacts)
end)

RegisterNetEvent('prp-phone:server:AddNewContact', function(name, number, iban)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    if not context then return end

    MySQL.insert('INSERT INTO player_contacts (citizenid, name, number, iban) VALUES (?, ?, ?, ?)', { context.dataCitizenid, tostring(name), tostring(number), tostring(iban) })

    local contacts = context.simContacts
    if type(contacts) ~= 'table' or next(contacts) == nil then
        contacts = LoadContactRows(context.dataCitizenid)
    end
    contacts[#contacts + 1] = {
        name = tostring(name),
        number = tostring(number),
        iban = tostring(iban)
    }
    SyncInstalledSimContacts(Player, contacts)
end)

RegisterNetEvent('prp-phone:server:UpdateMessages', function(ChatMessages, ChatNumber, _)
    local src = source
    local SenderData = QBCore.Functions.GetPlayer(src)
    if not SenderData then return end

    local senderContext = GetPhoneContext(SenderData, true)
    if not senderContext then
        Notify(src, 'Install a SIM card before sending messages.', 'error')
        return
    end

    local senderCitizenid = senderContext.dataCitizenid
    local senderNumber = tostring(senderContext.info.simNumber or SenderData.PlayerData.charinfo.phone or '')

    ChatNumber = NormalizePhoneNumber(ChatNumber)
    if not ChatNumber then return end

    local targetContext = GetPhoneContextByNumber(ChatNumber)
    local targetCitizenid = targetContext and targetContext.dataCitizenid or ('phone:' .. ChatNumber)
    local targetNumber = tostring((targetContext and targetContext.phoneNumber) or ChatNumber)
    local targetHadChat = SaveChatThread(targetCitizenid, senderNumber, ChatMessages)

    SaveChatThread(senderCitizenid, targetNumber, ChatMessages)

    if targetContext and targetContext.source and targetContext.source ~= src then
        TriggerClientEvent('prp-phone:client:UpdateMessages', targetContext.source, ChatMessages, senderNumber, not targetHadChat)
    end
end)

RegisterNetEvent('prp-phone:server:AddRecentCall', function(type, data)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    if not Ply or not data then return end

    local Hour = os.date('%H')
    local Minute = os.date('%M')
    local label = Hour .. ':' .. Minute

    local context = GetPhoneContext(Ply, true)
    local phoneKey = context and context.dataCitizenid or Ply.PlayerData.citizenid
    StoreRecentCall(phoneKey, data, label, type, false)
    TriggerClientEvent('prp-phone:client:AddRecentCall', src, data, label, type)
end)

RegisterNetEvent('prp-phone:server:CancelCall', function(ContactData)
    ClearSpeakerPhone(source)
    if not ContactData or not ContactData.TargetData then return end
    local targetContext = GetPhoneContextByNumber(ContactData.TargetData.number)
    if targetContext and targetContext.source then
        TriggerClientEvent('prp-phone:client:CancelCall', targetContext.source)
    end
end)

RegisterNetEvent('prp-phone:server:AnswerCall', function(CallData)
    if not CallData or not CallData.TargetData then return end
    local targetContext = GetPhoneContextByNumber(CallData.TargetData.number)
    if targetContext and targetContext.source then
        TriggerClientEvent('prp-phone:client:AnswerCall', targetContext.source)
    end
end)

RegisterNetEvent('prp-phone:server:SaveMetaData', function(MData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { Player.PlayerData.citizenid })
    local MetaData = json.decode(result[1].metadata)
    MetaData.phone = MData
    MySQL.update('UPDATE players SET metadata = ? WHERE citizenid = ?',
        { json.encode(MetaData), Player.PlayerData.citizenid })
    Player.Functions.SetMetaData('phone', MData)
end)

RegisterNetEvent('prp-phone:server:GiveContactDetails', function(PlayerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local SuggestionData = {
        name = {
            [1] = Player.PlayerData.charinfo.firstname,
            [2] = Player.PlayerData.charinfo.lastname
        },
        number = Player.PlayerData.charinfo.phone,
        bank = Player.PlayerData.citizenid
    }

    TriggerClientEvent('prp-phone:client:AddNewSuggestion', PlayerId, SuggestionData)
end)

RegisterNetEvent('prp-phone:server:AddTransaction', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    MySQL.insert('INSERT INTO crypto_transactions (citizenid, title, message) VALUES (?, ?, ?)', {
        Player.PlayerData.citizenid,
        data.TransactionTitle,
        data.TransactionMessage
    })
end)

RegisterNetEvent('prp-phone:server:InstallApplication', function(ApplicationData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.PlayerData.metadata['phonedata'].InstalledApps[ApplicationData.app] = ApplicationData
    Player.Functions.SetMetaData('phonedata', Player.PlayerData.metadata['phonedata'])

    -- TriggerClientEvent('prp-phone:RefreshPhone', src)
end)

RegisterNetEvent('prp-phone:server:RemoveInstallation', function(App)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.PlayerData.metadata['phonedata'].InstalledApps[App] = nil
    Player.Functions.SetMetaData('phonedata', Player.PlayerData.metadata['phonedata'])

    -- TriggerClientEvent('prp-phone:RefreshPhone', src)
end)

RegisterNetEvent('prp-phone:server:addImageToGallery', function(image)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    MySQL.insert('INSERT INTO phone_gallery (`citizenid`, `image`) VALUES (?, ?)', { dataCitizenid, image })
end)

RegisterNetEvent('prp-phone:server:getImageFromGallery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    local images = MySQL.query.await('SELECT * FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC', { dataCitizenid })
    TriggerClientEvent('prp-phone:refreshImages', src, images)
end)

RegisterNetEvent('prp-phone:server:RemoveImageFromGallery', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local image = data.image
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    MySQL.query('DELETE FROM phone_gallery WHERE citizenid = ? AND image = ?', { dataCitizenid, image })
end)

RegisterNetEvent('prp-phone:server:sendPing', function(data)
    local src = source
    if src == data then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot ping yourself', 'error')
    end
end)

AddEventHandler('playerDropped', function()
    local dropped = source
    ClearSpeakerPhone(dropped)

    for owner, session in pairs(SpeakerPhoneSessions) do
        if session.targets and session.targets[dropped] then
            session.targets[dropped] = nil
        end
        if owner == dropped then
            SpeakerPhoneSessions[owner] = nil
        end
    end
end)

-- Command

QBCore.Commands.Add('setmetadata', 'Set Player Metadata (God Only)', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if args[1] then
        if args[1] == 'trucker' then
            if args[2] then
                local newrep = Player.PlayerData.metadata['jobrep']
                newrep.trucker = tonumber(args[2])
                Player.Functions.SetMetaData('jobrep', newrep)
            end
        end
    end
end, 'god')

QBCore.Commands.Add('bill', 'Bill A Player', { { name = 'id', help = 'Player ID' }, { name = 'amount', help = 'Fine Amount' } }, false, function(source, args)
    local biller = QBCore.Functions.GetPlayer(source)
    local billed = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local amount = tonumber(args[2])
    if biller.PlayerData.job.name == 'police' or biller.PlayerData.job.name == 'ambulance' or biller.PlayerData.job.name == 'mechanic' then
        if billed ~= nil then
            if biller.PlayerData.citizenid ~= billed.PlayerData.citizenid then
                if amount and amount > 0 then
                    MySQL.insert(
                        'INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)',
                        { billed.PlayerData.citizenid, amount, biller.PlayerData.job.name,
                            biller.PlayerData.charinfo.firstname, biller.PlayerData.citizenid })
                    TriggerClientEvent('prp-phone:RefreshPhone', billed.PlayerData.source)
                    TriggerClientEvent('QBCore:Notify', source, 'Invoice Successfully Sent', 'success')
                    TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'New Invoice Received')
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Must Be A Valid Amount Above 0', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'You Cannot Bill Yourself', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'Player Not Online', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'No Access', 'error')
    end
end)
