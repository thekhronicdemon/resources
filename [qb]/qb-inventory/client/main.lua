QBCore = exports['qb-core']:GetCoreObject()
PlayerData = nil
local hotbarShown = false

local function HasQbTarget()
    return GetResourceState('qb-target') == 'started'
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    GetDrops()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    PlayerData = nil
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('qb-inventory:client:createDrop', function(dropId, coords)
    if not dropId or not coords then return end
    if Drops and Drops[dropId] and DoesEntityExist(Drops[dropId].entity) then return end

    local model = Config.ItemDropObject or `bkr_prop_duffel_bag_01a`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    local obj = CreateObject(model, coords.x, coords.y, coords.z - 0.97, false, true, true)
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    if not Drops then Drops = {} end
    Drops[dropId] = Drops[dropId] or {}
    Drops[dropId].entity = obj
    Drops[dropId].coords = coords

    if HasQbTarget() then
        exports['qb-target']:AddTargetEntity(obj, {
            options = {
                {
                    icon = 'fas fa-box-open',
                    label = 'Open Drop',
                    action = function()
                        TriggerServerEvent('qb-inventory:server:openInventory', dropId, {
                            label = 'Drop',
                            maxweight = Config.DropSize.maxweight,
                            slots = Config.DropSize.slots
                        })
                        CurrentDrop = dropId
                    end
                }
            },
            distance = 2.0
        })
    end
end)

RegisterNetEvent('qb-inventory:client:removeDropObject', function(dropId)
    if not dropId or not Drops or not Drops[dropId] then return end

    local obj = Drops[dropId].entity
    if obj and DoesEntityExist(obj) then
        if HasQbTarget() then
            exports['qb-target']:RemoveTargetEntity(obj)
        end
        DeleteEntity(obj)
    end

    Drops[dropId] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
    end
end)

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function ComponentMatches(savedComponent, componentHash)
    if savedComponent == componentHash then return true end
    if type(savedComponent) == 'string' and joaat(savedComponent) == componentHash then return true end
    if type(componentHash) == 'string' and joaat(componentHash) == savedComponent then return true end
    return false
end

local function FormatWeaponAttachments(itemdata)
    if not itemdata or type(itemdata.info) ~= 'table' or not itemdata.info.attachments or #itemdata.info.attachments == 0 then
        return {}
    end
    local attachments = {}
    local weaponName = itemdata.name
    local WeaponAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    if not WeaponAttachments then return {} end
    for attachmentType, weapons in pairs(WeaponAttachments) do
        local componentHash = weapons[weaponName]
        if componentHash then
            for _, attachmentData in pairs(itemdata.info.attachments) do
                if ComponentMatches(attachmentData.component, componentHash) then
                    local itemInfo = QBCore.Shared.Items[attachmentType]
                    attachments[#attachments + 1] = {
                        attachment = attachmentType,
                        component = componentHash,
                        label = itemInfo and itemInfo.label or attachmentType,
                        image = itemInfo and itemInfo.image or (attachmentType .. '.png')
                    }
                end
            end
        end
    end
    return attachments
end

local function HasWeaponAttachment(itemdata, componentHash)
    if not itemdata or type(itemdata.info) ~= 'table' or not itemdata.info.attachments then return false end
    for _, attachmentData in pairs(itemdata.info.attachments) do
        if ComponentMatches(attachmentData.component, componentHash) then return true end
    end
    return false
end

local function FormatAvailableWeaponAttachments(itemdata)
    local available = {}
    if not itemdata or not itemdata.name then return available end

    local WeaponAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    if not WeaponAttachments or not PlayerData or type(PlayerData.items) ~= 'table' then return available end

    for _, invItem in pairs(PlayerData.items) do
        if invItem and invItem.name and WeaponAttachments[invItem.name] then
            local componentHash = WeaponAttachments[invItem.name][itemdata.name]
            if componentHash and not HasWeaponAttachment(itemdata, componentHash) then
                local itemInfo = QBCore.Shared.Items[invItem.name]
                available[#available + 1] = {
                    attachment = invItem.name,
                    component = componentHash,
                    label = itemInfo and itemInfo.label or invItem.label or invItem.name,
                    image = itemInfo and itemInfo.image or invItem.image or (invItem.name .. '.png'),
                    amount = invItem.amount or 1,
                    slot = invItem.slot
                }
            end
        end
    end

    return available
end

local function BuildWeaponModData(itemdata, message)
    return {
        WeaponData = itemdata,
        AttachmentData = FormatWeaponAttachments(itemdata),
        Attachments = FormatWeaponAttachments(itemdata),
        AvailableAttachments = FormatAvailableWeaponAttachments(itemdata),
        message = message
    }
end

local DeviceAttachmentItems = {
    phone = {
        simcard = true
    },
    tablet = {
        crypto_usb = true,
        cryptostick = true,
        command_usb = true
    }
}

local function IsDeviceAttachmentTarget(itemdata)
    return itemdata and itemdata.name and DeviceAttachmentItems[itemdata.name] ~= nil
end

local function FormatDeviceAttachments(itemdata)
    if not IsDeviceAttachmentTarget(itemdata) then return {} end

    local info = type(itemdata.info) == 'table' and itemdata.info or {}
    if itemdata.name == 'phone' and info.simNumber then
        local itemInfo = QBCore.Shared.Items['simcard']
        return {
            {
                attachment = 'simcard',
                label = itemInfo and itemInfo.label or 'SIM Card',
                image = itemInfo and itemInfo.image or 'simcard.png',
                detail = info.simNumber,
                removable = true,
                deviceSlot = tonumber(info.simSlot) or 1
            }
        }
    end

    if itemdata.name == 'tablet' then
        local attachments = {}

        if type(info.commandUsb) == 'table' then
            attachments[#attachments + 1] = {
                attachment = ('command_usb|%s'):format(tostring(info.commandUsb.serial or 'module')),
                label = info.commandUsb.label or 'Command USB',
                image = info.commandUsb.image or 'usb_device.png',
                detail = 'Installed',
                removable = true,
                deviceSlot = tonumber(info.commandUsb.deviceSlot) or 1
            }
        end

        local drives = {}
        if type(info.cryptoDrives) == 'table' then
            drives = info.cryptoDrives
        elseif type(info.cryptoDrive) == 'table' then
            drives = { info.cryptoDrive }
        end

        for _, drive in pairs(drives) do
            if type(drive) == 'table' then
                attachments[#attachments + 1] = {
                    attachment = ('%s|%s'):format(drive.item or 'cryptostick', tostring(drive.serial or drive.code or 'drive')),
                    label = drive.label or 'Crypto Drive',
                    image = drive.image or 'cryptostick.png',
                    detail = drive.commandName or drive.code or 'Inserted',
                    removable = true,
                    deviceSlot = tonumber(drive.deviceSlot)
                }
            end
        end

        return attachments
    end

    return {}
end

local function FormatAvailableDeviceAttachments(itemdata)
    local available = {}
    if not IsDeviceAttachmentTarget(itemdata) or not PlayerData or type(PlayerData.items) ~= 'table' then return available end

    local info = type(itemdata.info) == 'table' and itemdata.info or {}
    if itemdata.name == 'phone' and info.simNumber then return available end

    local allowed = DeviceAttachmentItems[itemdata.name] or {}
    local commandInstalled = itemdata.name == 'tablet' and type(info.commandUsb) == 'table'
    for _, invItem in pairs(PlayerData.items) do
        if invItem and invItem.name and allowed[invItem.name] then
            if commandInstalled and invItem.name == 'command_usb' then
                goto continue
            end
            local itemInfo = QBCore.Shared.Items[invItem.name]
            available[#available + 1] = {
                attachment = invItem.name,
                label = itemInfo and itemInfo.label or invItem.label or invItem.name,
                image = itemInfo and itemInfo.image or invItem.image or (invItem.name .. '.png'),
                amount = invItem.amount or 1,
                slot = invItem.slot
            }
        end
        ::continue::
    end

    return available
end

local function BuildDeviceAttachmentData(itemdata, message)
    local installed = FormatDeviceAttachments(itemdata)
    local available = FormatAvailableDeviceAttachments(itemdata)
    local note = message

    if not note then
        if itemdata and itemdata.name == 'phone' then
            note = 'Install a SIM card to activate this phone number.'
        elseif itemdata and itemdata.name == 'tablet' then
            note = 'Install a Command USB for terminal access and load crypto USBs into the tablet.'
        end
    end

    return {
        DeviceData = itemdata,
        Attachments = installed,
        AvailableAttachments = available,
        message = note
    }
end

local function AddAvailableDeviceAttachment(payload, deviceData, invItem)
    if not payload or not IsDeviceAttachmentTarget(deviceData) or not invItem or not invItem.name then return end

    local info = type(deviceData.info) == 'table' and deviceData.info or {}
    if deviceData.name == 'phone' and info.simNumber then return end

    local allowed = DeviceAttachmentItems[deviceData.name] or {}
    if not allowed[invItem.name] then return end
    if deviceData.name == 'tablet' and type(info.commandUsb) == 'table' and invItem.name == 'command_usb' then return end

    payload.AvailableAttachments = payload.AvailableAttachments or {}
    for _, existing in pairs(payload.AvailableAttachments) do
        if existing and existing.slot == invItem.slot and existing.attachment == invItem.name then
            return
        end
    end

    local itemInfo = QBCore.Shared.Items[invItem.name]
    payload.AvailableAttachments[#payload.AvailableAttachments + 1] = {
        attachment = invItem.name,
        label = itemInfo and itemInfo.label or invItem.label or invItem.name,
        image = itemInfo and itemInfo.image or invItem.image or (invItem.name .. '.png'),
        amount = invItem.amount or 1,
        slot = invItem.slot,
        detail = invItem.info and (invItem.info.simNumber or invItem.info.serial or invItem.info.serie)
    }
end

local function GetPlayerItemBySlot(slot)
    if not PlayerData or type(PlayerData.items) ~= 'table' or not slot then return nil end

    slot = tonumber(slot)
    if not slot then return nil end
    local directItem = PlayerData.items[slot] or PlayerData.items[tostring(slot)]
    if directItem and tonumber(directItem.slot) == slot then
        return directItem
    end

    for _, item in pairs(PlayerData.items) do
        if item and tonumber(item.slot) == slot then
            return item
        end
    end

    return nil
end

local function GetQuickSlotItem(slot)
    if not PlayerData or type(PlayerData.metadata) ~= 'table' then return nil end
    local quickslots = PlayerData.metadata.quickslots
    if type(quickslots) ~= 'table' then return nil end

    local itemSlot = tonumber(quickslots[tostring(slot)] or quickslots[slot])
    if not itemSlot then return nil end
    return GetPlayerItemBySlot(itemSlot)
end

function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    if PlayerData and type(PlayerData.items) == "table" then
        for _, itemData in pairs(PlayerData.items) do
            if isTable then
                for k, v in pairs(items) do
                    if itemData and itemData.name == (isArray and v or k) and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                        count = count + 1
                        if count == totalItems then
                            return true
                        end
                    end
                end
            else
                if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                    return true
                end
            end
        end
    end

    return false
end

exports('HasItem', HasItem)

RegisterNetEvent('qb-inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable + 1] = {
                item = items[k].name,
                label = QBCore.Shared.Items[items[k].name]['label'],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = 'requiredItem',
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('qb-inventory:client:hotbar', function(items)
    hotbarShown = not hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = hotbarShown,
        items = items
    })
end)

RegisterNetEvent('qb-inventory:client:closeInv', function()
    SendNUIMessage({ action = 'close' })
end)

RegisterNetEvent('qb-inventory:client:updateInventory', function(serverItems)
    PlayerData = QBCore.Functions.GetPlayerData()
    local items = {}

    if type(serverItems) == 'table' then
        items = serverItems
        if PlayerData then
            PlayerData.items = serverItems
        end
    elseif PlayerData and type(PlayerData.items) == "table" then
        items = PlayerData.items
    end

    SendNUIMessage({
        action = 'update',
        inventory = items,
        equipment = PlayerData and PlayerData.metadata and PlayerData.metadata.equipment or nil,
        quickslots = PlayerData and PlayerData.metadata and PlayerData.metadata.quickslots or nil
    })
end)

RegisterNetEvent('qb-inventory:client:ItemBox', function(itemData, type, amount)
    SendNUIMessage({
        action = 'itemBox',
        item = itemData,
        type = type,
        amount = amount
    })
end)

RegisterNetEvent('qb-inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = 'RobMoney',
        TargetId = TargetId,
    })
end)

RegisterNetEvent('qb-inventory:client:openInventory', function(items, other, metadata)
    PlayerData = QBCore.Functions.GetPlayerData()
    local playerMetadata = metadata or (PlayerData and PlayerData.metadata) or {}
    if metadata and PlayerData then
        PlayerData.metadata = metadata
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        inventory = items,
        slots = Config.MaxSlots,
        maxweight = Config.MaxWeight,
        other = other,
        quickslots = playerMetadata.quickslots or {},
        equipment = playerMetadata.equipment or {
            hat = nil,
            backpack = nil,
            armour = nil,
            jacket = nil,
            shirt = nil,
            pants = nil,
            shoes = nil
        }
    })
end)

RegisterNetEvent('qb-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('AttemptPurchase', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:attemptPurchase', function(canPurchase)
        cb(canPurchase)
    end, data)
end)

RegisterNUICallback('SellShopItem', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:sellShopItem', function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('CloseInventory', function(data, cb)
    SetNuiFocus(false, false)

    local invName = data.name or ''
    if invName ~= '' and invName:find('trunk-') then
        CloseTrunk()
    end

    if CurrentDrop then
        TriggerServerEvent('qb-inventory:server:closeInventory', CurrentDrop)
        CurrentDrop = nil
    else
        TriggerServerEvent('qb-inventory:server:closeInventory', invName)
    end

    cb('ok')
end)

RegisterNUICallback('UseItem', function(data, cb)
    if not data or not data.item then
        cb(false)
        return
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('qb-inventory:server:useItem', data.item)
    cb('ok')
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('qb-inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback('EquipItem', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:equipItem', function(result)
        if result and result.equipment and PlayerData and PlayerData.metadata then
            PlayerData.metadata.equipment = result.equipment
        end
        if result and result.inventory and PlayerData then
            PlayerData.items = result.inventory
        end
        if result and result.quickslots and PlayerData and PlayerData.metadata then
            PlayerData.metadata.quickslots = result.quickslots
        end
        cb(result or { success = false })
    end, data.equipmentSlot, data.itemSlot)
end)

RegisterNUICallback('UnequipItem', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:unequipItem', function(result)
        if result and result.equipment and PlayerData and PlayerData.metadata then
            PlayerData.metadata.equipment = result.equipment
        end
        if result and result.inventory and PlayerData then
            PlayerData.items = result.inventory
        end
        if result and result.quickslots and PlayerData and PlayerData.metadata then
            PlayerData.metadata.quickslots = result.quickslots
        end
        cb(result or { success = false })
    end, data.equipmentSlot)
end)

RegisterNUICallback('ApplyArmorPlate', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:applyArmorPlate', function(result)
        if result and result.equipment and PlayerData and PlayerData.metadata then
            PlayerData.metadata.equipment = result.equipment
        end
        if result and result.inventory and PlayerData then
            PlayerData.items = result.inventory
        end
        if result and result.quickslots and PlayerData and PlayerData.metadata then
            PlayerData.metadata.quickslots = result.quickslots
        end
        cb(result or { success = false })
    end, data.itemSlot)
end)

RegisterNUICallback('SetQuickSlot', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:setQuickSlot', function(result)
        if result and result.quickslots and PlayerData and PlayerData.metadata then
            PlayerData.metadata.quickslots = result.quickslots
        end
        cb(result or { success = false })
    end, data.quickSlot, data.itemSlot)
end)

RegisterNUICallback('DropItem', function(data, cb)
    local item = data.item or data
    local amount = tonumber(data.amount) or 1
    local slot = tonumber(data.slot) or tonumber(data.fromSlot) or (item and tonumber(item.slot))

    if not item or not item.name or not slot then
        cb(false)
        return
    end

    QBCore.Functions.TriggerCallback('qb-inventory:server:dropItem', function(success)
        cb(success and 'ok' or false)
    end, item, amount, slot)
end)

RegisterNUICallback('GiveItem', function(data, cb)
    local item = data.item
    local amount = tonumber(data.amount) or 1
    local slot = tonumber(data.slot) or (item and tonumber(item.slot))
    local info = data.info or (item and item.info) or {}
    local itemName = item and item.name or nil

    if not itemName or not slot then
        cb(false)
        return
    end

    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player == -1 or distance > 3.0 then
        QBCore.Functions.Notify(Lang:t('notify.nonb'), 'error')
        cb(false)
        return
    end

    local playerId = GetPlayerServerId(player)
    if playerId == GetPlayerServerId(PlayerId()) then
        QBCore.Functions.Notify(Lang:t('notify.gsitem'), 'error')
        cb(false)
        return
    end

    QBCore.Functions.TriggerCallback('qb-inventory:server:giveItem', function(success)
        cb(success)
    end, playerId, itemName, amount, slot, info)
end)

RegisterNUICallback('GetWeaponData', function(cData, cb)
    local itemData = cData.ItemData
    local currentItem = itemData and GetPlayerItemBySlot(itemData.slot)
    if currentItem then
        itemData = currentItem
    end
    cb(BuildWeaponModData(itemData))
end)

RegisterNUICallback('GetDeviceData', function(cData, cb)
    local itemData = cData.ItemData
    local currentItem = itemData and GetPlayerItemBySlot(itemData.slot)
    if currentItem then
        itemData = currentItem
    end
    cb(BuildDeviceAttachmentData(itemData))
end)

RegisterNUICallback('ApplyDeviceAttachment', function(data, cb)
    local DeviceData = data.DeviceData
    local AttachmentData = data.AttachmentData

    if not DeviceData or not AttachmentData then
        cb({ success = false, message = 'No device attachment selected' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-inventory:server:applyDeviceAttachment', function(result)
        if result and result.success and result.DeviceData then
            PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData and result.Inventory then
                PlayerData.items = result.Inventory
            elseif PlayerData and PlayerData.items then
                PlayerData.items[result.DeviceData.slot] = result.DeviceData
                if result.removedSlot and PlayerData.items[result.removedSlot] then
                    local amount = tonumber(PlayerData.items[result.removedSlot].amount) or 1
                    if amount <= 1 then
                        PlayerData.items[result.removedSlot] = nil
                    else
                        PlayerData.items[result.removedSlot].amount = amount - 1
                    end
                end
            end

            local payload = BuildDeviceAttachmentData(result.DeviceData, result.message)
            payload.success = true
            payload.Inventory = result.Inventory or (PlayerData and PlayerData.items) or {}
            payload.removedSlot = result.removedSlot
            payload.removedItem = result.removedItem
            SendNUIMessage({
                action = 'update',
                inventory = payload.Inventory
            })
            cb(payload)
        else
            cb(result or { success = false, message = 'Cannot install this item' })
        end
    end, DeviceData, AttachmentData)
end)

RegisterNUICallback('RemoveDeviceAttachment', function(data, cb)
    local DeviceData = data.DeviceData
    local AttachmentData = data.AttachmentData

    if not DeviceData or not AttachmentData then
        cb({ success = false, message = 'No device attachment selected' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-inventory:server:removeDeviceAttachment', function(result)
        if result and result.success and result.DeviceData then
            PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData and result.Inventory then
                PlayerData.items = result.Inventory
            elseif PlayerData and PlayerData.items and result.DeviceData.slot then
                PlayerData.items[result.DeviceData.slot] = result.DeviceData
            end
            if PlayerData and PlayerData.items and result.AddedItem and result.AddedItem.slot then
                PlayerData.items[result.AddedItem.slot] = result.AddedItem
            end

            local payload = BuildDeviceAttachmentData(result.DeviceData, result.message)
            AddAvailableDeviceAttachment(payload, result.DeviceData, result.AddedItem)
            payload.success = true
            payload.Inventory = result.Inventory or (PlayerData and PlayerData.items) or {}
            payload.AddedItem = result.AddedItem
            SendNUIMessage({
                action = 'update',
                inventory = payload.Inventory
            })
            cb(payload)
        else
            if result and result.message then
                QBCore.Functions.Notify(result.message, 'error')
            end
            cb(result or { success = false, message = 'Could not remove this item' })
        end
    end, DeviceData, AttachmentData)
end)

RegisterNUICallback('ApplyAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local AttachmentData = data.AttachmentData

    if not WeaponData or not AttachmentData then
        cb({ success = false, message = 'No weapon mod selected' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-inventory:server:applyWeaponAttachment', function(result)
        if result and result.success and result.WeaponData then
            if GetSelectedPedWeapon(ped) == joaat(result.WeaponData.name) and result.component then
                GiveWeaponComponentToPed(ped, joaat(result.WeaponData.name), result.component)
            end

            PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData and PlayerData.items then
                PlayerData.items[result.WeaponData.slot] = result.WeaponData
                if AttachmentData.slot and PlayerData.items[AttachmentData.slot] then
                    local amount = tonumber(PlayerData.items[AttachmentData.slot].amount) or 1
                    if amount <= 1 then
                        PlayerData.items[AttachmentData.slot] = nil
                    else
                        PlayerData.items[AttachmentData.slot].amount = amount - 1
                    end
                end
            end

            local payload = BuildWeaponModData(result.WeaponData, result.message)
            payload.success = true
            payload.component = result.component
            cb(payload)
        else
            cb(result or { success = false, message = 'Cannot apply this mod' })
        end
    end, WeaponData, AttachmentData)
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    if not WeaponData or not data.AttachmentData or not allAttachments[data.AttachmentData.attachment] then
        cb({ success = false, message = 'No weapon mod selected' })
        return
    end

    local Attachment = allAttachments[data.AttachmentData.attachment][WeaponData.name]
    if not Attachment then
        cb({ success = false, message = 'This mod is not installed' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-inventory:server:removeWeaponAttachment', function(result)
        if result and result.success and result.WeaponData then
            if GetSelectedPedWeapon(ped) == joaat(WeaponData.name) then
                RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), Attachment)
            end

            PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData and PlayerData.items and result.WeaponData.slot then
                PlayerData.items[result.WeaponData.slot] = result.WeaponData
            end

            local payload = BuildWeaponModData(result.WeaponData, result.message)
            payload.success = true
            cb(payload)
        else
            cb(result or { success = false, message = 'Could not remove this mod' })
        end
    end, WeaponData, data.AttachmentData)
end)

RegisterCommand('openInv', function()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    ExecuteCommand('inventory')
end, false)

RegisterCommand('toggleHotbar', function()
    ExecuteCommand('hotbar')
end, false)

for i = 1, 4 do
    RegisterCommand('slot_' .. i, function()
        local itemData = GetQuickSlotItem(i)
        if not itemData then
            QBCore.Functions.Notify('Nothing in hotbar slot ' .. i, 'error')
            return
        end
        if itemData.type == "weapon" and HoldingDrop then
            return QBCore.Functions.Notify("Your already holding a bag, Go Drop it!", "error", 5500)
        end
        TriggerServerEvent('qb-inventory:server:useItem', itemData)
    end, false)
    RegisterKeyMapping('slot_' .. i, Lang:t('inf_mapping.use_item') .. i, 'keyboard', tostring(i))
end

RegisterKeyMapping('openInv', Lang:t('inf_mapping.opn_inv'), 'keyboard', Config.Keybinds.Open)
RegisterKeyMapping('toggleHotbar', Lang:t('inf_mapping.tog_slots'), 'keyboard', Config.Keybinds.Hotbar)
