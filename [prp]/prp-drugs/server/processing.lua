local QBCore = exports['qb-core']:GetCoreObject()

local function notify(src, message, kind)
    exports['prp-drugs']:Notify(src, message, kind)
end

local function weightedQuality(items, required)
    local remaining, totalQuality, consumed = required, 0.0, {}
    for _, item in ipairs(items) do
        if remaining <= 0 then break end
        local take = math.min(item.amount, remaining)
        local info = PRPDrugs.DecodeInfo(item)
        local quality = tonumber(info.quality or info.yield or info.genetics) or 50
        totalQuality = totalQuality + quality * take
        consumed[#consumed + 1] = { slot = item.slot, amount = take, info = info }
        remaining = remaining - take
    end
    if remaining > 0 then return nil end
    return PRPDrugs.Round(totalQuality / required, 1), consumed
end

local function restoreSlots(Player, itemName, consumed, reason)
    for _, entry in ipairs(consumed or {}) do
        exports['prp-drugs']:AddItem(Player, itemName, entry.amount, entry.info, reason)
    end
end

local function consumeSlots(Player, itemName, consumed, reason)
    local removed = {}
    for _, entry in ipairs(consumed) do
        if not exports['prp-drugs']:RemoveItem(Player, itemName, entry.amount, entry.slot, reason) then
            restoreSlots(Player, itemName, removed, reason .. '-rollback')
            return false
        end
        removed[#removed + 1] = entry
    end
    return true
end

RegisterNetEvent('prp-drugs:server:bagBud', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local budItems = exports['prp-drugs']:GetItemsByName(Player, Config.Items.Bud)
    local quality, consumed = weightedQuality(budItems, Config.Processing.BudsPerBag)
    local bag = exports['prp-drugs']:GetItemByName(Player, Config.Items.EmptyBag)
    if not quality then return notify(src, 'You need a weed bud.', 'error') end
    if not bag then return notify(src, 'You need an empty weed bag.', 'error') end

    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.EmptyBag, 1, bag.slot, 'prp-drugs-bag') then return end
    if not consumeSlots(Player, Config.Items.Bud, consumed, 'prp-drugs-bag') then
        exports['prp-drugs']:AddItem(Player, Config.Items.EmptyBag, 1, false, 'prp-drugs-bag-rollback')
        return
    end

    local info = PRPDrugs.BuildInfo(quality, {
        contents = Config.Processing.BudsPerBag,
        description = ('Bagged %s | %.1f%% quality'):format(PRPDrugs.GetStrain(quality), quality),
    })
    if not exports['prp-drugs']:AddItem(Player, Config.Items.Bagged, 1, info, 'prp-drugs-bag') then
        restoreSlots(Player, Config.Items.Bud, consumed, 'prp-drugs-bag-rollback')
        exports['prp-drugs']:AddItem(Player, Config.Items.EmptyBag, 1, false, 'prp-drugs-bag-rollback')
        return notify(src, 'Your inventory is full.', 'error')
    end
    notify(src, ('Packed a %.1f%% %s baggy.'):format(quality, info.strain), 'success')
end)

RegisterNetEvent('prp-drugs:server:rollJoint', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local budItems = exports['prp-drugs']:GetItemsByName(Player, Config.Items.Bud)
    local quality, consumed = weightedQuality(budItems, Config.Processing.BudsPerJoint)
    local paper = exports['prp-drugs']:GetItemByName(Player, Config.Items.RollingPaper)
    if not quality then return notify(src, 'You need a weed bud.', 'error') end
    if not paper then return notify(src, 'You need rolling paper.', 'error') end

    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.RollingPaper, 1, paper.slot, 'prp-drugs-joint') then return end
    if not consumeSlots(Player, Config.Items.Bud, consumed, 'prp-drugs-joint') then
        exports['prp-drugs']:AddItem(Player, Config.Items.RollingPaper, 1, false, 'prp-drugs-joint-rollback')
        return
    end

    local info = PRPDrugs.BuildInfo(quality, {
        description = ('%s joint | %.1f%% potency'):format(PRPDrugs.GetStrain(quality), quality),
        potency = quality,
    })
    if not exports['prp-drugs']:AddItem(Player, Config.Items.Joint, 1, info, 'prp-drugs-joint') then
        restoreSlots(Player, Config.Items.Bud, consumed, 'prp-drugs-joint-rollback')
        exports['prp-drugs']:AddItem(Player, Config.Items.RollingPaper, 1, false, 'prp-drugs-joint-rollback')
        return notify(src, 'Your inventory is full.', 'error')
    end
    notify(src, ('Rolled a %.1f%% %s joint.'):format(quality, info.strain), 'success')
end)

RegisterNetEvent('prp-drugs:server:unbagWeed', function(slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = exports['prp-drugs']:GetItemBySlot(Player, tonumber(slot))
    if not item or item.name ~= Config.Items.Bagged then return end
    local info = PRPDrugs.DecodeInfo(item)

    if not exports['prp-drugs']:RemoveItem(Player, Config.Items.Bagged, 1, item.slot, 'prp-drugs-unbag') then return end
    if not exports['prp-drugs']:AddItem(Player, Config.Items.Bud, tonumber(info.contents) or 1, info, 'prp-drugs-unbag') then
        exports['prp-drugs']:AddItem(Player, Config.Items.Bagged, 1, info, 'prp-drugs-unbag-rollback')
        return notify(src, 'Your inventory is full.', 'error')
    end
    notify(src, 'Removed the weed from the bag. The empty bag was destroyed.', 'success')
end)

RegisterNetEvent('prp-drugs:server:pressBrick', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local pressCoords = vector3(Config.Press.coords.x, Config.Press.coords.y, Config.Press.coords.z)
    if #(coords - pressCoords) > 5.0 then return end

    local budItems = exports['prp-drugs']:GetItemsByName(Player, Config.Items.Bud)
    local quality, consumed = weightedQuality(budItems, Config.Press.BudsRequired)
    if not quality then
        return notify(src, ('You need %s loose buds. Bagged weed cannot be pressed.'):format(Config.Press.BudsRequired), 'error')
    end

    if not consumeSlots(Player, Config.Items.Bud, consumed, 'prp-drugs-brick') then return end
    local info = PRPDrugs.BuildInfo(quality, {
        budCount = Config.Press.BudsRequired,
        description = ('Pressed %s brick | %.1f%% quality | %s buds'):format(
            PRPDrugs.GetStrain(quality), quality, Config.Press.BudsRequired
        ),
    })

    if not exports['prp-drugs']:AddItem(Player, Config.Items.Brick, 1, info, 'prp-drugs-brick') then
        restoreSlots(Player, Config.Items.Bud, consumed, 'prp-drugs-brick-rollback')
        return notify(src, 'Your inventory is full.', 'error')
    end
    notify(src, ('Pressed a %.1f%% %s brick.'):format(quality, info.strain), 'success')
end)
