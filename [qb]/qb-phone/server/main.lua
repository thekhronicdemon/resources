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

-- Functions

local function Notify(source, message, notifyType)
    TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
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

        if not existsOnline and not existsSaved and not existsInventory then
            return number
        end
    end

    return GenerateSimNumber()
end

local function NormalizeSimCardInfo(info)
    info = type(info) == 'table' and info or {}
    info.simNumber = info.simNumber or GenerateUniqueSimNumber()
    info.simSerial = info.simSerial or ('SIM-' .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(4))
    info.description = ('Phone number: %s'):format(info.simNumber)
    return info
end

local function GetPhoneItem(Player, requireSim)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return nil end

    local metadata = Player.PlayerData.metadata or {}
    local phonedata = metadata['phonedata'] or {}
    local activeSim = phonedata.ActiveSim or (Player.PlayerData.charinfo and Player.PlayerData.charinfo.phone)
    local fallback = nil
    local simFallback = nil
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name and item.name:lower() == 'phone' then
            if item.info and item.info.simNumber then
                if activeSim and tostring(item.info.simNumber) == tostring(activeSim) then
                    return item
                end
                simFallback = simFallback or item
            else
                fallback = fallback or item
            end
        end
    end

    if simFallback then return simFallback end
    if requireSim then return nil end
    return fallback
end

local function GetPhoneWithoutSim(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return nil end

    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name and item.name:lower() == 'phone' then
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
        if item and item.name and item.name:lower() == 'phone' and tonumber(item.slot) == slot then
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

local function CopyTable(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, data in pairs(value) do
        copy[key] = CopyTable(data)
    end

    return copy
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

    if changed and phone.slot then
        SetInventoryItemInfo(Player, phone.slot, info)
        phone.info = info
    end

    return info
end

local function GetPhoneContext(Player, requireSim)
    local phone = GetPhoneItem(Player, requireSim)
    if not phone then return nil end

    local info = EnsurePhoneDeviceInfo(Player, phone)
    if requireSim and not info.simNumber then return nil end

    local dataCitizenid = info.deviceOwnerCitizenid or Player.PlayerData.citizenid
    if info.simNumber then
        SetActivePhoneNumber(Player, info.simNumber)
    end

    return {
        phone = phone,
        info = info,
        dataCitizenid = dataCitizenid,
        simContacts = type(info.simContacts) == 'table' and info.simContacts or {},
        profile = GetCitizenProfile(dataCitizenid)
    }
end

local function SyncInstalledSimContacts(Player, contacts)
    local phone = GetPhoneItem(Player, true)
    if not phone then return end

    local info = EnsurePhoneDeviceInfo(Player, phone)
    info.simContacts = contacts or {}
    SetInventoryItemInfo(Player, phone.slot, info)
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
    local phoneInfo = EnsurePhoneDeviceInfo(Player, { info = CopyTable(phone.info) })

    if phoneInfo.simNumber then
        Notify(source, 'That phone already has a SIM card installed.', 'error')
        return
    end

    if not exports['qb-inventory']:RemoveItem(source, 'simcard', 1, simItem and simItem.slot, 'installed sim card') then
        Notify(source, 'Could not install the SIM card.', 'error')
        return
    end

    phone = GetPhoneBySlot(Player, phoneSlot)
    if not phone then
        exports['qb-inventory']:AddItem(source, 'simcard', 1, false, simInfo, 'failed sim install refund')
        Notify(source, 'Could not find a phone slot for the SIM card.', 'error')
        return
    end

    phoneInfo = EnsurePhoneDeviceInfo(Player, { info = CopyTable(phone.info) })
    phoneInfo.simNumber = simNumber
    phoneInfo.simSerial = simSerial
    phoneInfo.simContacts = simContacts
    phoneInfo.description = 'SIM: ' .. simNumber

    if not SetInventoryItemInfo(Player, phoneSlot, phoneInfo) then
        exports['qb-inventory']:AddItem(source, 'simcard', 1, false, simInfo, 'failed sim install refund')
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
    local Target = QBCore.Functions.GetPlayerByPhone(number)
    local retval = false
    if Target ~= nil then
        retval = true
    end
    return retval
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
            TriggerClientEvent('qb-phone:client:NewMailNotify', src, mailData)
        else
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0, json.encode(mailData.button) })
            TriggerClientEvent('qb-phone:client:NewMailNotify', src, mailData)
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

            TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
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

    TriggerClientEvent('qb-phone:client:UsePhone', source)
end)

QBCore.Functions.CreateUseableItem('simcard', function(source, item)
    InstallSimCard(source, item)
end)

-- Callbacks

QBCore.Functions.CreateCallback("qb-phone:server:GetInvoices", function(source, cb)
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

QBCore.Functions.CreateCallback('qb-phone:server:GetCallState', function(_, cb, ContactData)
    local Target = QBCore.Functions.GetPlayerByPhone(ContactData.number)
    if Target ~= nil then
        if Calls[Target.PlayerData.citizenid] ~= nil then
            if Calls[Target.PlayerData.citizenid].inCall then
                cb(false, true)
            else
                cb(true, true)
            end
        else
            cb(true, true)
        end
    else
        cb(false, false)
    end
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetPhoneData', function(source, cb)
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

    local messages = MySQL.query.await('SELECT * FROM phone_messages WHERE citizenid = ?', { dataCitizenid })
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

QBCore.Functions.CreateCallback('qb-phone:server:PayInvoice', function(source, cb, society, amount, invoiceId, sendercitizenid)
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
                    exports['qb-phone']:sendNewMailToOffline(sendercitizenid, invoiceMailData)
                end
                TriggerEvent("qb-phone:server:paidInvoice", source, invoiceId)
                exports['qb-banking']:AddMoney(society, amount, 'Phone invoice')
                cb(true)
                return
            end
        end
    end
    cb(false)
end)

QBCore.Functions.CreateCallback('qb-phone:server:DeclineInvoice', function(source, cb, _, _, invoiceId)
    local Ply = QBCore.Functions.GetPlayer(source)
    if Ply then
        local exists = MySQL.query.await('select count(1) as count FROM phone_invoices WHERE id = ? and citizenid = ? and candecline = ?', { invoiceId, Ply.PlayerData.citizenid, 1 })

        if exists[1] and exists[1]["count"] == 1 then
            TriggerEvent("qb-phone:server:declinedInvoice", source, invoiceId)
            MySQL.query('DELETE FROM phone_invoices WHERE id = ? and citizenid = ? and candecline = ?', { invoiceId, Ply.PlayerData.citizenid, 1 })
            cb(true)
            return
        end
    end

    cb(false)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetContactPictures', function(_, cb, Chats)
    for _, v in pairs(Chats) do
        local query = '%' .. v.number .. '%'
        local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
        if result[1] ~= nil then
            local MetaData = json.decode(result[1].metadata)

            if MetaData.phone.profilepicture ~= nil then
                v.picture = MetaData.phone.profilepicture
            else
                v.picture = 'default'
            end
        end
    end
    SetTimeout(100, function()
        cb(Chats)
    end)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetContactPicture', function(_, cb, Chat)
    local query = '%' .. Chat.number .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
    local MetaData = json.decode(result[1].metadata)
    if MetaData.phone.profilepicture ~= nil then
        Chat.picture = MetaData.phone.profilepicture
    else
        Chat.picture = 'default'
    end
    SetTimeout(100, function()
        cb(Chat)
    end)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetPicture', function(_, cb, number)
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

QBCore.Functions.CreateCallback('qb-phone:server:FetchResult', function(_, cb, search)
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

QBCore.Functions.CreateCallback('qb-phone:server:GetVehicleSearchResults', function(_, cb, search)
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

QBCore.Functions.CreateCallback('qb-phone:server:ScanPlate', function(source, cb, plate)
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

QBCore.Functions.CreateCallback('qb-phone:server:HasPhone', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player ~= nil then
        local requireSim = Config.SimCards and Config.SimCards.RequireSim
        cb(GetPhoneItem(Player, requireSim) ~= nil)
        return
    end

    cb(false)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetTabletStatus', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local tablet = GetTabletItem(Player)
    local info = tablet and type(tablet.info) == 'table' and tablet.info or {}

    cb({
        cryptoDrive = info.cryptoDrive,
        activeMining = GetTabletMiningJobs(source)
    })
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetCryptoShopItems', function(_, cb)
    cb(Config.CryptoShopItems or {})
end)

QBCore.Functions.CreateCallback('qb-phone:server:BuyCryptoShopItem', function(source, cb, itemName)
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
        cb({ success = false, message = 'Not enough Qbit.' })
        return
    end

    if not Player.Functions.RemoveMoney('crypto', price, 'crypto shop purchase') then
        cb({ success = false, message = 'Payment failed.' })
        return
    end

    if not exports['qb-inventory']:AddItem(src, shopItem.item, amount, false, shopItem.info or {}, 'crypto shop purchase') then
        Player.Functions.AddMoney('crypto', price, 'crypto shop refund')
        cb({ success = false, message = 'Your inventory is full.' })
        return
    end

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[shopItem.item], 'add')
    AddCryptoTransaction(Player.PlayerData.citizenid, 'Crypto Shop', ('Purchased %sx %s for %.2f Qbit.'):format(amount, shopItem.label or shopItem.item, price))
    cb({ success = true, message = ('Purchased %sx %s.'):format(amount, shopItem.label or shopItem.item) })
end)

QBCore.Functions.CreateCallback('qb-phone:server:StartTabletCryptoMine', function(source, cb)
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
        local message = ('Crypto rig paid out %.6f Qbit.'):format(reward)
        AddCryptoTransaction(Target.PlayerData.citizenid, 'Tablet Rig', message)
        TriggerClientEvent('qb-phone:client:TabletMiningComplete', src, reward, message, GetTabletMiningJobs(src))
        TriggerClientEvent('qb-phone:client:AddTransaction', src, Target, {}, message, 'Tablet Rig')
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

QBCore.Functions.CreateCallback('qb-phone:server:GetBusinessControlData', function(source, cb)
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

QBCore.Functions.CreateCallback('qb-phone:server:BusinessHireClosest', function(source, cb, targetId)
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

QBCore.Functions.CreateCallback('qb-phone:server:BusinessFireMember', function(source, cb, citizenid)
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

QBCore.Functions.CreateCallback('qb-phone:server:GangHireClosest', function(source, cb, targetId)
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

QBCore.Functions.CreateCallback('qb-phone:server:GangFireClosest', function(source, cb, targetId)
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

QBCore.Functions.CreateCallback('qb-phone:server:CanTransferMoney', function(source, cb, amount, iban)
    -- strip bad characters from bank transfers
    local newAmount = tostring(amount)
    local newiban = tostring(iban)
    for _, v in pairs(bannedCharacters) do
        newAmount = string.gsub(newAmount, '%' .. v, '')
        newiban = string.gsub(newiban, '%' .. v, '')
    end
    iban = newiban
    amount = tonumber(newAmount)

    local Player = QBCore.Functions.GetPlayer(source)
    if (Player.PlayerData.money.bank - amount) >= 0 then
        local query = '%"account":"' .. iban .. '"%'
        local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
        if result[1] ~= nil then
            local Reciever = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)
            Player.Functions.RemoveMoney('bank', amount)
            if Reciever ~= nil then
                Reciever.Functions.AddMoney('bank', amount)
            else
                local RecieverMoney = json.decode(result[1].money)
                RecieverMoney.bank = (RecieverMoney.bank + amount)
                MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(RecieverMoney), result[1].citizenid })
            end
            cb(true)
        else
            cb(false)
        end
    end
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetCurrentLawyers', function(_, cb)
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

QBCore.Functions.CreateCallback('qb-phone:server:GetWebhook', function(_, cb)
    if WebHook ~= '' then
        cb(WebHook)
    else
        print('Set your webhook to ensure that your camera will work!!!!!! Set this on line 9 of the server sided script!!!!!')
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('qb-phone:server:UploadToFivemerr', function(source, cb)
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

RegisterNetEvent('qb-phone:server:AddAdvert', function(msg, url)
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
    TriggerClientEvent('qb-phone:client:UpdateAdverts', -1, Adverts, '@' .. Player.PlayerData.charinfo.firstname .. '' .. Player.PlayerData.charinfo.lastname)
end)

RegisterNetEvent('qb-phone:server:DeleteAdvert', function()
    local Player = QBCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid
    Adverts[citizenid] = nil
    TriggerClientEvent('qb-phone:client:UpdateAdvertsDel', -1, Adverts)
end)

RegisterNetEvent('qb-phone:server:SetCallState', function(bool)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    if Calls[Ply.PlayerData.citizenid] ~= nil then
        Calls[Ply.PlayerData.citizenid].inCall = bool
    else
        Calls[Ply.PlayerData.citizenid] = {}
        Calls[Ply.PlayerData.citizenid].inCall = bool
    end
end)

RegisterNetEvent('qb-phone:server:RemoveMail', function(MailId)
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
        TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:sendNewMail', function(mailData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if mailData.button == nil then
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0 })
    else
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', { Player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, GenerateMailId(), 0, json.encode(mailData.button) })
    end
    TriggerClientEvent('qb-phone:client:NewMailNotify', src, mailData)
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

        TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:sendNewEventMail', function(citizenid, mailData)
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
        TriggerClientEvent('qb-phone:client:UpdateMails', Player.PlayerData.source, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:ClearButtonData', function(mailId)
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
        TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:MentionedPlayer', function(firstName, lastName, TweetMessage)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(v)
        if Player ~= nil then
            if (Player.PlayerData.charinfo.firstname == firstName and Player.PlayerData.charinfo.lastname == lastName) then
                QBPhone.SetPhoneAlerts(Player.PlayerData.citizenid, 'twitter')
                QBPhone.AddMentionedTweet(Player.PlayerData.citizenid, TweetMessage)
                TriggerClientEvent('qb-phone:client:GetMentioned', Player.PlayerData.source, TweetMessage, AppAlerts[Player.PlayerData.citizenid]['twitter'])
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

RegisterNetEvent('qb-phone:server:CallContact', function(TargetData, CallId, AnonymousCall)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayerByPhone(TargetData.number)
    if Target ~= nil then
        TriggerClientEvent('qb-phone:client:GetCalled', Target.PlayerData.source, Ply.PlayerData.charinfo.phone, CallId, AnonymousCall)
    end
end)

RegisterNetEvent('qb-phone:server:BillingEmail', function(data, paid)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local target = QBCore.Functions.GetPlayer(v)
        if target.PlayerData.job.name == data.society then
            if paid then
                local name = '' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.firstname .. ' ' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.lastname .. ''
                TriggerClientEvent('qb-phone:client:BillingEmail', target.PlayerData.source, data, true, name)
            else
                local name = '' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.firstname .. ' ' .. QBCore.Functions.GetPlayer(source).PlayerData.charinfo.lastname .. ''
                TriggerClientEvent('qb-phone:client:BillingEmail', target.PlayerData.source, data, false, name)
            end
        end
    end
end)

RegisterNetEvent('qb-phone:server:UpdateHashtags', function(Handle, messageData)
    if Hashtags[Handle] ~= nil and next(Hashtags[Handle]) ~= nil then
        Hashtags[Handle].messages[#Hashtags[Handle].messages + 1] = messageData
    else
        Hashtags[Handle] = {
            hashtag = Handle,
            messages = {}
        }
        Hashtags[Handle].messages[#Hashtags[Handle].messages + 1] = messageData
    end
    TriggerClientEvent('qb-phone:client:UpdateHashtags', -1, Handle, messageData)
end)

RegisterNetEvent('qb-phone:server:SetPhoneAlerts', function(app, alerts)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local CitizenId = context and context.dataCitizenid or Player.PlayerData.citizenid
    QBPhone.SetPhoneAlerts(CitizenId, app, alerts)
end)

RegisterNetEvent('qb-phone:server:DeleteTweet', function(tweetId)
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
        TriggerClientEvent('qb-phone:client:UpdateTweets', -1, TWData, nil, true)
    end
end)

RegisterNetEvent('qb-phone:server:UpdateTweets', function(NewTweets, TweetData)
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
    TriggerClientEvent('qb-phone:client:UpdateTweets', -1, src, NewTweets, TweetData, false)
end)

RegisterNetEvent('qb-phone:server:TransferMoney', function(iban, amount)
    local src = source
    local sender = QBCore.Functions.GetPlayer(src)

    local query = '%' .. iban .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
    if result[1] ~= nil then
        local reciever = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)

        if reciever ~= nil then
            local PhoneItem = reciever.Functions.GetItemByName('phone')
            reciever.Functions.AddMoney('bank', amount, 'phone-transfered-from-' .. sender.PlayerData.citizenid)
            sender.Functions.RemoveMoney('bank', amount, 'phone-transfered-to-' .. reciever.PlayerData.citizenid)

            if PhoneItem ~= nil then
                TriggerClientEvent('qb-phone:client:TransferMoney', reciever.PlayerData.source, amount,
                    reciever.PlayerData.money.bank)
            end
        else
            local moneyInfo = json.decode(result[1].money)
            moneyInfo.bank = QBCore.Shared.Round(moneyInfo.bank + amount)
            MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?',
                { json.encode(moneyInfo), result[1].citizenid })
            sender.Functions.RemoveMoney('bank', amount, 'phone-transfered')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "This account number doesn't exist!", 'error')
    end
end)

RegisterNetEvent('qb-phone:server:EditContact', function(newName, newNumber, newIban, oldName, oldNumber, _)
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

RegisterNetEvent('qb-phone:server:RemoveContact', function(Name, Number)
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

RegisterNetEvent('qb-phone:server:AddNewContact', function(name, number, iban)
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

RegisterNetEvent('qb-phone:server:UpdateMessages', function(ChatMessages, ChatNumber, _)
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
    local query = '%' .. ChatNumber .. '%'
    local PlayerRows = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', { query })
    if PlayerRows[1] ~= nil then
        local TargetData = QBCore.Functions.GetPlayerByCitizenId(PlayerRows[1].citizenid)
        if TargetData ~= nil then
            local targetContext = GetPhoneContext(TargetData, true)
            local targetCitizenid = targetContext and targetContext.dataCitizenid or TargetData.PlayerData.citizenid
            local targetNumber = tostring((targetContext and targetContext.info.simNumber) or TargetData.PlayerData.charinfo.phone or ChatNumber)
            local Chat = MySQL.query.await('SELECT * FROM phone_messages WHERE citizenid = ? AND number = ?', { senderCitizenid, ChatNumber })
            if Chat[1] ~= nil then
                -- Update for target
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', { json.encode(ChatMessages), targetCitizenid, senderNumber })
                -- Update for sender
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', { json.encode(ChatMessages), senderCitizenid, targetNumber })
                -- Send notification & Update messages for target
                TriggerClientEvent('qb-phone:client:UpdateMessages', TargetData.PlayerData.source, ChatMessages, senderNumber, false)
            else
                -- Insert for target
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', { targetCitizenid, senderNumber, json.encode(ChatMessages) })
                -- Insert for sender
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', { senderCitizenid, targetNumber, json.encode(ChatMessages) })
                -- Send notification & Update messages for target
                TriggerClientEvent('qb-phone:client:UpdateMessages', TargetData.PlayerData.source, ChatMessages, senderNumber, true)
            end
        else
            local targetCharinfo = json.decode(PlayerRows[1].charinfo) or {}
            local targetNumber = tostring(targetCharinfo.phone or ChatNumber)
            local Chat = MySQL.query.await('SELECT * FROM phone_messages WHERE citizenid = ? AND number = ?', { senderCitizenid, ChatNumber })
            if Chat[1] ~= nil then
                -- Update for target
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', { json.encode(ChatMessages), PlayerRows[1].citizenid, senderNumber })
                -- Update for sender
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', { json.encode(ChatMessages), senderCitizenid, targetNumber })
            else
                -- Insert for target
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', { PlayerRows[1].citizenid, senderNumber, json.encode(ChatMessages) })
                -- Insert for sender
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', { senderCitizenid, targetNumber, json.encode(ChatMessages) })
            end
        end
    end
end)

RegisterNetEvent('qb-phone:server:AddRecentCall', function(type, data)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local Hour = os.date('%H')
    local Minute = os.date('%M')
    local label = Hour .. ':' .. Minute
    TriggerClientEvent('qb-phone:client:AddRecentCall', src, data, label, type)
    local Trgt = QBCore.Functions.GetPlayerByPhone(data.number)
    if Trgt ~= nil then
        TriggerClientEvent('qb-phone:client:AddRecentCall', Trgt.PlayerData.source, {
            name = Ply.PlayerData.charinfo.firstname .. ' ' .. Ply.PlayerData.charinfo.lastname,
            number = Ply.PlayerData.charinfo.phone,
            anonymous = data.anonymous
        }, label, 'outgoing')
    end
end)

RegisterNetEvent('qb-phone:server:CancelCall', function(ContactData)
    local Ply = QBCore.Functions.GetPlayerByPhone(ContactData.TargetData.number)
    if Ply ~= nil then
        TriggerClientEvent('qb-phone:client:CancelCall', Ply.PlayerData.source)
    end
end)

RegisterNetEvent('qb-phone:server:AnswerCall', function(CallData)
    local Ply = QBCore.Functions.GetPlayerByPhone(CallData.TargetData.number)
    if Ply ~= nil then
        TriggerClientEvent('qb-phone:client:AnswerCall', Ply.PlayerData.source)
    end
end)

RegisterNetEvent('qb-phone:server:SaveMetaData', function(MData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { Player.PlayerData.citizenid })
    local MetaData = json.decode(result[1].metadata)
    MetaData.phone = MData
    MySQL.update('UPDATE players SET metadata = ? WHERE citizenid = ?',
        { json.encode(MetaData), Player.PlayerData.citizenid })
    Player.Functions.SetMetaData('phone', MData)
end)

RegisterNetEvent('qb-phone:server:GiveContactDetails', function(PlayerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local SuggestionData = {
        name = {
            [1] = Player.PlayerData.charinfo.firstname,
            [2] = Player.PlayerData.charinfo.lastname
        },
        number = Player.PlayerData.charinfo.phone,
        bank = Player.PlayerData.charinfo.account
    }

    TriggerClientEvent('qb-phone:client:AddNewSuggestion', PlayerId, SuggestionData)
end)

RegisterNetEvent('qb-phone:server:AddTransaction', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    MySQL.insert('INSERT INTO crypto_transactions (citizenid, title, message) VALUES (?, ?, ?)', {
        Player.PlayerData.citizenid,
        data.TransactionTitle,
        data.TransactionMessage
    })
end)

RegisterNetEvent('qb-phone:server:InstallApplication', function(ApplicationData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.PlayerData.metadata['phonedata'].InstalledApps[ApplicationData.app] = ApplicationData
    Player.Functions.SetMetaData('phonedata', Player.PlayerData.metadata['phonedata'])

    -- TriggerClientEvent('qb-phone:RefreshPhone', src)
end)

RegisterNetEvent('qb-phone:server:RemoveInstallation', function(App)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.PlayerData.metadata['phonedata'].InstalledApps[App] = nil
    Player.Functions.SetMetaData('phonedata', Player.PlayerData.metadata['phonedata'])

    -- TriggerClientEvent('qb-phone:RefreshPhone', src)
end)

RegisterNetEvent('qb-phone:server:addImageToGallery', function(image)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    MySQL.insert('INSERT INTO phone_gallery (`citizenid`, `image`) VALUES (?, ?)', { dataCitizenid, image })
end)

RegisterNetEvent('qb-phone:server:getImageFromGallery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    local images = MySQL.query.await('SELECT * FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC', { dataCitizenid })
    TriggerClientEvent('qb-phone:refreshImages', src, images)
end)

RegisterNetEvent('qb-phone:server:RemoveImageFromGallery', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local image = data.image
    if not Player then return end

    local context = GetPhoneContext(Player, true)
    local dataCitizenid = context and context.dataCitizenid or Player.PlayerData.citizenid
    MySQL.query('DELETE FROM phone_gallery WHERE citizenid = ? AND image = ?', { dataCitizenid, image })
end)

RegisterNetEvent('qb-phone:server:sendPing', function(data)
    local src = source
    if src == data then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot ping yourself', 'error')
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
                    TriggerClientEvent('qb-phone:RefreshPhone', billed.PlayerData.source)
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
