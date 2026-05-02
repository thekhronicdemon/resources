local QBCore = exports[Config.CoreName]:GetCoreObject()

local pickaxeEquipped = false
local pickaxeSlot = nil
local pickaxeProp = nil
local mining = false
local spotCooldowns = {}

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end
    end
    return hash
end

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end
    end
end

local function DeletePickaxeProp()
    if pickaxeProp and DoesEntityExist(pickaxeProp) then
        DeleteEntity(pickaxeProp)
    end
    pickaxeProp = nil
end

local function AttachPickaxe()
    DeletePickaxeProp()

    local ped = PlayerPedId()
    local model = LoadModel(Config.PickaxeProp)
    pickaxeProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)

    -- Right hand attach. Tweak offsets here if you want the pickaxe angled differently.
    AttachEntityToEntity(
        pickaxeProp,
        ped,
        GetPedBoneIndex(ped, 57005),
        0.12, -0.02, -0.02,
        -80.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(model)
end

local function SetPickaxeEquipped(state, slot)
    pickaxeEquipped = state
    pickaxeSlot = state and slot or nil

    if pickaxeEquipped then
        AttachPickaxe()
        QBCore.Functions.Notify('Pickaxe equipped. Walk into a mining circle and press E.', 'success')
    else
        DeletePickaxeProp()
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify('Pickaxe unequipped.', 'primary')
    end
end

RegisterNetEvent('prp-mining:client:TogglePickaxe', function(slot)
    SetPickaxeEquipped(not pickaxeEquipped, slot)
end)

RegisterNetEvent('prp-mining:client:ForceUnequipPickaxe', function()
    if pickaxeEquipped then
        SetPickaxeEquipped(false)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DeletePickaxeProp()
end)

local function DrawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function CanUseSpot(index)
    local now = GetGameTimer()
    return not spotCooldowns[index] or now >= spotCooldowns[index]
end

local function StartMining(index)
    if mining then return end

    if not pickaxeEquipped or not pickaxeSlot then
        QBCore.Functions.Notify('You need to equip a pickaxe first.', 'error')
        return
    end

    if not CanUseSpot(index) then
        QBCore.Functions.Notify('This rock was just mined. Try again in a moment.', 'error')
        return
    end

    mining = true
    TriggerServerEvent('prp-mining:server:StartMining', index, pickaxeSlot)
end

RegisterNetEvent('prp-mining:client:StartMiningAnim', function(index, token)
    local ped = PlayerPedId()
    local animDict = 'amb@world_human_hammering@male@base'
    local animName = 'base'

    AttachPickaxe()
    LoadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0.0, false, false, false)

    QBCore.Functions.Progressbar('prp_mining', 'Mining...', Config.MiningTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(ped)
        mining = false
        spotCooldowns[index] = GetGameTimer() + (Config.CooldownPerSpot * 1000)
        TriggerServerEvent('prp-mining:server:FinishMining', token, true)
    end, function()
        ClearPedTasks(ped)
        mining = false
        spotCooldowns[index] = GetGameTimer() + (Config.CooldownPerSpot * 1000)
        TriggerServerEvent('prp-mining:server:FinishMining', token, false)
        QBCore.Functions.Notify('Mining cancelled.', 'error')
    end)
end)

RegisterNetEvent('prp-mining:client:MiningRejected', function(msg)
    mining = false
    QBCore.Functions.Notify(msg or 'You cannot mine right now.', 'error')
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for i, spot in ipairs(Config.MiningSpots) do
            local dist = #(coords - spot)

            if dist <= Config.Marker.drawDistance then
                sleep = 0
                DrawMarker(
                    Config.Marker.type,
                    spot.x, spot.y, spot.z - 0.98,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z,
                    Config.Marker.colour.r, Config.Marker.colour.g, Config.Marker.colour.b, Config.Marker.colour.a,
                    false, true, 2, false, nil, nil, false
                )

                if dist <= Config.Marker.interactDistance then
                    DrawText3D(vector3(spot.x, spot.y, spot.z + 0.35), '[E] Mine')

                    if IsControlJustReleased(0, 38) then -- E
                        StartMining(i)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
