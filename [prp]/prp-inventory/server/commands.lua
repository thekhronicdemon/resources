-- Commands

local function FindPlayerInventoryItemBySlot(Player, slot)
    if not Player or type(Player.PlayerData.items) ~= 'table' then return nil end

    slot = tonumber(slot)
    if not slot then return nil end

    local directItem = Player.PlayerData.items[slot] or Player.PlayerData.items[tostring(slot)]
    if directItem and tonumber(directItem.slot) == slot then
        return directItem
    end

    for _, item in pairs(Player.PlayerData.items) do
        if item and tonumber(item.slot) == slot then
            return item
        end
    end

    return nil
end

QBCore.Commands.Add('giveitem', 'Give An Item (Admin Only)', {
    { name = 'id', help = 'Player ID' },
    { name = 'item', help = 'Name of the item (not a label)' },
    { name = 'amount', help = 'Amount of items' }
}, false, function(source, args)
    local id = tonumber(args[1])
    local player = QBCore.Functions.GetPlayer(id)
    local amount = tonumber(args[3]) or 1
    local itemData = QBCore.Shared.Items[tostring(args[2]):lower()]
    if player then
        if itemData then
            local info = {}
            if itemData['name'] == 'id_card' then
                info.citizenid = player.PlayerData.citizenid
                info.firstname = player.PlayerData.charinfo.firstname
                info.lastname = player.PlayerData.charinfo.lastname
                info.birthdate = player.PlayerData.charinfo.birthdate
                info.gender = player.PlayerData.charinfo.gender
                info.nationality = player.PlayerData.charinfo.nationality
            elseif itemData['name'] == 'driver_license' then
                info.firstname = player.PlayerData.charinfo.firstname
                info.lastname = player.PlayerData.charinfo.lastname
                info.birthdate = player.PlayerData.charinfo.birthdate
                info.type = 'Class C Driver License'
            elseif itemData['type'] == 'weapon' then
                amount = 1
                info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                info.quality = 100
            elseif itemData['name'] == 'harness' then
                info.uses = 20
            elseif itemData['name'] == 'markedbills' then
                info.worth = math.random(5000, 10000)
            elseif itemData['name'] == 'printerdocument' then
                info.url = 'https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png'
            end

            if AddItem(id, itemData['name'], amount, false, info, 'give item command') then
                QBCore.Functions.Notify(source, Lang:t('notify.yhg') .. GetPlayerName(id) .. ' ' .. amount .. ' ' .. itemData['name'], 'success')
                TriggerClientEvent('qb-inventory:client:ItemBox', id, itemData, 'add', amount)
                if Player(id).state.inv_busy then
                    TriggerClientEvent('qb-inventory:client:updateInventory', id)
                end
            else
                QBCore.Functions.Notify(source, Lang:t('notify.cgitem'), 'error')
            end
        else
            QBCore.Functions.Notify(source, Lang:t('notify.idne'), 'error')
        end
    else
        QBCore.Functions.Notify(source, Lang:t('notify.pdne'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('clearinv', 'Clear player inventory', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid ID', 'error')
        return
    end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end

    -- clear inventory
    Target.Functions.ClearInventory()

    -- 🔥 force update to client
    TriggerClientEvent('qb-inventory:client:updateInventory', targetId)

    TriggerClientEvent('QBCore:Notify', src, 'Inventory cleared', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Your inventory was cleared', 'error')

end, 'admin')

QBCore.Commands.Add('hotbar', 'Toggle Hotbar', {}, false, function(source)
    if Player(source).state.inv_busy then return end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return end
    local metadata = type(QBPlayer.PlayerData.metadata) == 'table' and QBPlayer.PlayerData.metadata or {}
    if metadata['isdead'] or metadata['inlaststand'] or metadata['ishandcuffed'] then return end

    local quickslots = type(metadata.quickslots) == 'table' and metadata.quickslots or {}
    local hotbarItems = {}
    for i = 1, 4 do
        local itemSlot = tonumber(quickslots[tostring(i)] or quickslots[i])
        local item = itemSlot and FindPlayerInventoryItemBySlot(QBPlayer, itemSlot) or nil
        hotbarItems[tostring(i)] = item
    end

    TriggerClientEvent('qb-inventory:client:hotbar', source, hotbarItems)
end, false)

QBCore.Commands.Add('inventory', 'Open Inventory', {}, false, function(source)
    if Player(source).state.inv_busy then return end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return end
    if QBPlayer.PlayerData.metadata['isdead'] or QBPlayer.PlayerData.metadata['inlaststand'] or QBPlayer.PlayerData.metadata['ishandcuffed'] then return end

    QBCore.Functions.TriggerClientCallback('qb-inventory:client:vehicleCheck', source, function(inventory, class)
        if not inventory then
            return OpenInventory(source)
        end

        if inventory:find('trunk-') then
            OpenInventory(source, inventory, {
                slots = VehicleStorage[class] and VehicleStorage[class].trunkSlots or VehicleStorage.default.trunkSlots,
                maxweight = VehicleStorage[class] and VehicleStorage[class].trunkWeight or VehicleStorage.default.trunkWeight
            })
            return
        elseif inventory:find('glovebox-') then
            OpenInventory(source, inventory, {
                slots = VehicleStorage[class] and VehicleStorage[class].gloveboxSlots or VehicleStorage.default.gloveboxSlots,
                maxweight = VehicleStorage[class] and VehicleStorage[class].gloveboxWeight or VehicleStorage.default.gloveboxWeight
            })
            return
        elseif inventory:find('drop-') then
            OpenDrop(source, inventory)
            return
        end
    end)
end, false)
