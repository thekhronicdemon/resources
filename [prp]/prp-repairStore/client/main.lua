local QBCore = exports[Config.Core]:GetCoreObject()

local inMenu = false
local currentVehicle = nil
local originalProps = nil
local cam = nil
local camPreset = 'diagonal'
local manualCamAngle = 0.0
local camPitch = 1.4
local camDistance = 5.5
local camManualRotating = false
local closingMenu = false
local destroyingCam = false
local previewSnapshot = nil
local purchasedPreview = false
local storeAccess = nil

local function IsVehicleAlreadyRepaired(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return true
    end

    local engine = GetVehicleEngineHealth(vehicle) or 0.0
    local body = GetVehicleBodyHealth(vehicle) or 0.0
    local petrolTank = GetVehiclePetrolTankHealth(vehicle) or 0.0
    local dirt = GetVehicleDirtLevel(vehicle) or 0.0

    return engine >= 995.0 and body >= 995.0 and petrolTank >= 995.0 and dirt <= 0.5
end



local function ApplyStoreDiscount(price)
    price = tonumber(price) or 0

    if storeAccess and storeAccess.isMechanic then
        local discount = tonumber(storeAccess.discountPercent) or 75
        return math.floor(price * ((100 - discount) / 100))
    end

    return price
end

local function IsModeAllowed(mode)
    if not storeAccess or not storeAccess.allowedModes then return true end
    return storeAccess.allowedModes[mode] == true
end

local function DiscountItems(items)
    for _, item in ipairs(items or {}) do
        for _, opt in ipairs(item.options or {}) do
            opt.originalPrice = opt.price or 0
            opt.price = ApplyStoreDiscount(opt.price or 0)
        end
    end

    return items
end


local function Notify(msg, msgType)
    QBCore.Functions.Notify(msg, msgType or 'primary')
end

local function GetClosestVehicleToPlayer(radius)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end

    local coords = GetEntityCoords(ped)
    veh = GetClosestVehicle(coords.x, coords.y, coords.z, radius or Config.Interaction.VehicleSearchRadius, 0, 71)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end

    return nil
end

local function CanControlVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local tries = 0
    while not NetworkHasControlOfEntity(vehicle) and tries < 50 do
        NetworkRequestControlOfEntity(vehicle)
        Wait(10)
        tries = tries + 1
    end
    return NetworkHasControlOfEntity(vehicle)
end

local function SetKit(vehicle)
    SetVehicleModKit(vehicle, 0)
end

local function CaptureProps(vehicle)
    local primary, secondary = GetVehicleColours(vehicle)
    local pearlescent, wheelColour = GetVehicleExtraColours(vehicle)

    local props = {
        plate = GetVehicleNumberPlateText(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        primaryColour = primary,
        secondaryColour = secondary,
        pearlescent = pearlescent,
        wheelColour = wheelColour,
        windowTint = GetVehicleWindowTint(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        wheelType = GetVehicleWheelType(vehicle),
        mods = {},
        toggles = {}
    }

    for i = 0, 49 do
        props.mods[tostring(i)] = GetVehicleMod(vehicle, i)
    end

    props.toggles['18'] = IsToggleModOn(vehicle, 18)
    props.toggles['22'] = IsToggleModOn(vehicle, 22)

    return props
end

local function ApplyProps(vehicle, props)
    if not vehicle or not props then return end

    SetKit(vehicle)

    SetVehicleColours(vehicle, props.primaryColour or 0, props.secondaryColour or 0)
    SetVehicleExtraColours(vehicle, props.pearlescent or 0, props.wheelColour or 0)
    SetVehicleWindowTint(vehicle, props.windowTint or 0)
    SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex or 0)
    SetVehicleWheelType(vehicle, props.wheelType or 0)

    if props.mods then
        for k, v in pairs(props.mods) do
            SetVehicleMod(vehicle, tonumber(k), tonumber(v), false)
        end
    end

    if props.toggles then
        for k, v in pairs(props.toggles) do
            ToggleVehicleMod(vehicle, tonumber(k), v == true)
        end
    end

    SetVehicleEngineHealth(vehicle, props.engineHealth or 1000.0)
    SetVehicleBodyHealth(vehicle, props.bodyHealth or 1000.0)
    SetVehicleDirtLevel(vehicle, props.dirtLevel or 0.0)
end

local function SaveMods()
    if Config.SaveOwnedVehicleMods and currentVehicle then
        TriggerServerEvent('prp-repairStore:server:saveMods', GetVehicleNumberPlateText(currentVehicle), CaptureProps(currentVehicle))
    end
end

local function DestroyCam()
    if destroyingCam then return end
    destroyingCam = true

    if cam then
        SetCamActive(cam, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end

    CreateThread(function()
        Wait(250)
        destroyingCam = false
    end)
end

local function PresetOffset(preset)
    -- GTA entity offsets: x left/right, y forward/back, z up/down.
    -- Positive y = front of vehicle. Negative y = rear.
    if preset == 'front' then return vector3(0.0, 5.8, 1.2), 5.8 end
    if preset == 'rear' then return vector3(0.0, -5.8, 1.2), 5.8 end
    if preset == 'side' then return vector3(5.8, 0.0, 1.3), 5.8 end
    if preset == 'frontTop' then return vector3(0.0, 5.5, 2.2), 5.5 end
    if preset == 'top' then return vector3(3.0, 3.5, 3.2), 6.0 end
    return vector3(4.2, 4.2, 1.6), 6.0
end

local function RotateOffset(offset, angleDeg)
    if math.abs(angleDeg) < 0.01 then return offset end

    local rad = math.rad(angleDeg)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)

    return vector3(
        offset.x * cosA - offset.y * sinA,
        offset.x * sinA + offset.y * cosA,
        offset.z
    )
end

local function UpdateCamera()
    if not cam or not currentVehicle then return end

    local offset, defaultDistance = PresetOffset(camPreset)
    local scaled = RotateOffset(offset, manualCamAngle)

    local length2d = math.sqrt((scaled.x * scaled.x) + (scaled.y * scaled.y))
    if length2d > 0.01 then
        local scale = camDistance / length2d
        scaled = vector3(scaled.x * scale, scaled.y * scale, camPitch)
    end

    local camCoords = GetOffsetFromEntityInWorldCoords(currentVehicle, scaled.x, scaled.y, scaled.z)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(cam, currentVehicle, 0.0, 0.0, 0.55, true)
end

local function StartCam(preset)
    camPreset = preset or 'diagonal'
    manualCamAngle = 0.0
    local _, dist = PresetOffset(camPreset)
    camDistance = dist or 5.5
    camPitch = camPreset == 'top' and 3.2 or camPreset == 'frontTop' and 2.2 or 1.4

    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 250, true, true)
    end

    UpdateCamera()
end

local function BuildModCategory(vehicle, item)
    SetKit(vehicle)
    local max = GetNumVehicleMods(vehicle, item.modType)
    if max <= 0 then return nil end

    local options = {
        { label = 'Stock', value = -1, price = item.price or 0 }
    }

    for i = 0, max - 1 do
        options[#options + 1] = {
            label = item.label .. ' ' .. (i + 1),
            value = i,
            price = item.price or 0
        }
    end

    return {
        id = item.id,
        label = item.label,
        kind = 'mod',
        modType = item.modType,
        current = GetVehicleMod(vehicle, item.modType),
        options = options,
        camera = item.camera or 'diagonal'
    }
end

local function BuildToggle(vehicle, item)
    return {
        id = item.id,
        label = item.label,
        kind = 'toggle',
        toggle = item.toggle,
        current = IsToggleModOn(vehicle, item.toggle) and 1 or 0,
        options = {
            { label = 'Off', value = 0, price = 0 },
            { label = 'On', value = 1, price = item.price or 0 }
        },
        camera = item.camera or 'diagonal'
    }
end

local function ColourOptions(price)
    local opts = {}
    for _, c in ipairs(Config.Colours) do
        opts[#opts + 1] = { label = c.label, value = c.id, price = price or 500 }
    end
    return opts
end

local function SimpleOptions(list, price)
    local opts = {}
    for _, c in ipairs(list) do
        opts[#opts + 1] = { label = c.label, value = c.id, price = price or 0 }
    end
    return opts
end

local function BuildWheelCategories(vehicle)
    local items = {}
    local originalWheelType = GetVehicleWheelType(vehicle)
    local originalFrontWheel = GetVehicleMod(vehicle, 23)
    local originalBackWheel = GetVehicleMod(vehicle, 24)

    for _, wt in ipairs(Config.WheelTypes) do
        SetVehicleWheelType(vehicle, wt.id)
        SetKit(vehicle)

        local max = GetNumVehicleMods(vehicle, 23)

        if max and max > 0 then
            local options = {
                { label = 'Stock', value = -1, price = Config.WheelPrice or 700 }
            }

            for i = 0, max - 1 do
                options[#options + 1] = {
                    label = wt.label .. ' Wheel ' .. (i + 1),
                    value = i,
                    price = Config.WheelPrice or 700
                }
            end

            items[#items + 1] = {
                id = 'wheels_' .. wt.id,
                label = 'Wheels: ' .. wt.label,
                kind = 'wheelMod',
                wheelType = wt.id,
                modType = 23,
                current = (originalWheelType == wt.id and originalFrontWheel or -999),
                options = options,
                camera = 'side'
            }
        end
    end

    SetVehicleWheelType(vehicle, originalWheelType)
    SetVehicleMod(vehicle, 23, originalFrontWheel, false)
    SetVehicleMod(vehicle, 24, originalBackWheel, false)

    return items
end


local function BuildLiveryOptions(vehicle)
    SetKit(vehicle)

    local items = {}

    -- Standard mod-kit livery slot
    local modMax = GetNumVehicleMods(vehicle, 48)
    if modMax and modMax > 0 then
        local options = {
            { label = 'Stock', value = -1, price = 600 }
        }

        for i = 0, modMax - 1 do
            options[#options + 1] = {
                label = 'Livery ' .. (i + 1),
                value = i,
                price = 600
            }
        end

        items[#items + 1] = {
            id = 'mod_livery',
            label = 'Mod Kit Liveries',
            kind = 'mod',
            modType = 48,
            current = GetVehicleMod(vehicle, 48),
            options = options
        }
    end

    -- Native vehicle livery slot. Some GTA/add-on vehicles use this instead of mod 48.
    local nativeMax = GetVehicleLiveryCount(vehicle)
    if nativeMax and nativeMax > 0 then
        local options = {}

        for i = 0, nativeMax - 1 do
            options[#options + 1] = {
                label = 'Livery ' .. (i + 1),
                value = i,
                price = 600
            }
        end

        items[#items + 1] = {
            id = 'native_livery',
            label = 'Vehicle Liveries',
            kind = 'nativeLivery',
            current = GetVehicleLivery(vehicle),
            options = options
        }
    end

    return items
end


local function BuildOptions(vehicle, mode)
    SetKit(vehicle)

    local items = {}

    if mode == 'livery' then
        return BuildLiveryOptions(vehicle)
    end

    if mode == 'customize' then
        for _, item in ipairs(Config.CosmeticMods) do
            local built = BuildModCategory(vehicle, item)
            if built then items[#items + 1] = built end
        end

        local primary, secondary = GetVehicleColours(vehicle)
        local pearl, wheelColour = GetVehicleExtraColours(vehicle)

        for _, item in ipairs(Config.VisualMods) do
            local built = nil

            if item.toggle ~= nil then
                built = BuildToggle(vehicle, item)
            elseif item.kind == 'primaryColour' then
                built = { id = item.id, label = item.label, kind = item.kind, current = primary, options = ColourOptions(item.price), camera = item.camera }
            elseif item.kind == 'secondaryColour' then
                built = { id = item.id, label = item.label, kind = item.kind, current = secondary, options = ColourOptions(item.price), camera = item.camera }
            elseif item.kind == 'pearlescent' then
                built = { id = item.id, label = item.label, kind = item.kind, current = pearl, options = ColourOptions(item.price), camera = item.camera }
            elseif item.kind == 'wheelColour' then
                built = { id = item.id, label = item.label, kind = item.kind, current = wheelColour, options = ColourOptions(item.price), camera = item.camera }
            elseif item.kind == 'windowTint' then
                built = { id = item.id, label = item.label, kind = item.kind, current = GetVehicleWindowTint(vehicle), options = SimpleOptions(Config.WindowTints, item.price), camera = item.camera }
            elseif item.kind == 'plateIndex' then
                built = { id = item.id, label = item.label, kind = item.kind, current = GetVehicleNumberPlateTextIndex(vehicle), options = SimpleOptions(Config.PlateIndexes, item.price), camera = item.camera }
            end

            if built then items[#items + 1] = built end
        end

        local wheelItems = BuildWheelCategories(vehicle)
        for _, item in ipairs(wheelItems) do
            items[#items + 1] = item
        end
    else
        for _, item in ipairs(Config.EngineMods) do
            local built = nil
            if item.modType ~= nil then
                built = BuildModCategory(vehicle, item)
            elseif item.toggle ~= nil then
                built = BuildToggle(vehicle, item)
            end
            if built then items[#items + 1] = built end
        end
    end

    return items
end


local function GetItemCurrentValue(item)
    if not currentVehicle or not item then return nil end

    SetKit(currentVehicle)

    if item.kind == 'mod' then
        return GetVehicleMod(currentVehicle, tonumber(item.modType))
    elseif item.kind == 'toggle' then
        return IsToggleModOn(currentVehicle, tonumber(item.toggle)) and 1 or 0
    elseif item.kind == 'primaryColour' then
        local primary = GetVehicleColours(currentVehicle)
        return primary
    elseif item.kind == 'secondaryColour' then
        local _, secondary = GetVehicleColours(currentVehicle)
        return secondary
    elseif item.kind == 'pearlescent' then
        local pearl = GetVehicleExtraColours(currentVehicle)
        return pearl
    elseif item.kind == 'wheelColour' then
        local _, wheel = GetVehicleExtraColours(currentVehicle)
        return wheel
    elseif item.kind == 'windowTint' then
        return GetVehicleWindowTint(currentVehicle)
    elseif item.kind == 'plateIndex' then
        return GetVehicleNumberPlateTextIndex(currentVehicle)
    elseif item.kind == 'wheelMod' then
        return {
            wheelType = GetVehicleWheelType(currentVehicle),
            frontWheel = GetVehicleMod(currentVehicle, 23),
            backWheel = GetVehicleMod(currentVehicle, 24)
        }
    elseif item.kind == 'nativeLivery' then
        return GetVehicleLivery(currentVehicle)
    end

    return nil
end

local function RestoreSinglePreview()
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        previewSnapshot = nil
        purchasedPreview = false
        return
    end

    if not previewSnapshot or purchasedPreview then
        previewSnapshot = nil
        purchasedPreview = false
        return
    end

    local item = previewSnapshot.item
    local value = previewSnapshot.value

    if item and value ~= nil then
        SetKit(currentVehicle)

        if item.kind == 'mod' then
            SetVehicleMod(currentVehicle, tonumber(item.modType), tonumber(value), false)
        elseif item.kind == 'toggle' then
            ToggleVehicleMod(currentVehicle, tonumber(item.toggle), tonumber(value) == 1)
        elseif item.kind == 'primaryColour' then
            local _, secondary = GetVehicleColours(currentVehicle)
            SetVehicleColours(currentVehicle, tonumber(value), secondary)
        elseif item.kind == 'secondaryColour' then
            local primary = GetVehicleColours(currentVehicle)
            SetVehicleColours(currentVehicle, primary, tonumber(value))
        elseif item.kind == 'pearlescent' then
            local _, wheel = GetVehicleExtraColours(currentVehicle)
            SetVehicleExtraColours(currentVehicle, tonumber(value), wheel)
        elseif item.kind == 'wheelColour' then
            local pearl = GetVehicleExtraColours(currentVehicle)
            SetVehicleExtraColours(currentVehicle, pearl, tonumber(value))
        elseif item.kind == 'windowTint' then
            SetVehicleWindowTint(currentVehicle, tonumber(value))
        elseif item.kind == 'plateIndex' then
            SetVehicleNumberPlateTextIndex(currentVehicle, tonumber(value))
        elseif item.kind == 'wheelMod' and type(value) == 'table' then
            SetVehicleWheelType(currentVehicle, tonumber(value.wheelType) or 0)
            SetKit(currentVehicle)
            SetVehicleMod(currentVehicle, 23, tonumber(value.frontWheel) or -1, false)
            SetVehicleMod(currentVehicle, 24, tonumber(value.backWheel) or -1, false)
        elseif item.kind == 'nativeLivery' then
            SetVehicleLivery(currentVehicle, tonumber(value))
        end
    end

    previewSnapshot = nil
    purchasedPreview = false
end

local function StartSinglePreview(item)
    if not item then return end

    -- If player hovers another option/category, restore the old unpaid preview first.
    RestoreSinglePreview()

    previewSnapshot = {
        item = item,
        value = GetItemCurrentValue(item)
    }
    purchasedPreview = false
end


local function ApplyPreview(item, value)
    if not currentVehicle or not item then return end

    SetKit(currentVehicle)

    if item.kind == 'mod' then
        SetVehicleMod(currentVehicle, tonumber(item.modType), tonumber(value), false)
    elseif item.kind == 'toggle' then
        ToggleVehicleMod(currentVehicle, tonumber(item.toggle), tonumber(value) == 1)
    elseif item.kind == 'primaryColour' then
        local _, sec = GetVehicleColours(currentVehicle)
        SetVehicleColours(currentVehicle, tonumber(value), sec)
    elseif item.kind == 'secondaryColour' then
        local pri = GetVehicleColours(currentVehicle)
        SetVehicleColours(currentVehicle, pri, tonumber(value))
    elseif item.kind == 'pearlescent' then
        local _, wheel = GetVehicleExtraColours(currentVehicle)
        SetVehicleExtraColours(currentVehicle, tonumber(value), wheel)
    elseif item.kind == 'wheelColour' then
        local pearl = GetVehicleExtraColours(currentVehicle)
        SetVehicleExtraColours(currentVehicle, pearl, tonumber(value))
    elseif item.kind == 'windowTint' then
        SetVehicleWindowTint(currentVehicle, tonumber(value))
    elseif item.kind == 'plateIndex' then
        SetVehicleNumberPlateTextIndex(currentVehicle, tonumber(value))
    elseif item.kind == 'wheelMod' then
        SetVehicleWheelType(currentVehicle, tonumber(item.wheelType))
        SetKit(currentVehicle)
        SetVehicleMod(currentVehicle, 23, tonumber(value), false)
        SetVehicleMod(currentVehicle, 24, tonumber(value), false)
    elseif item.kind == 'nativeLivery' then
        SetVehicleLivery(currentVehicle, tonumber(value))
    end
end

local function CloseMenu(cancel)
    if closingMenu then return end
    closingMenu = true

    RestoreSinglePreview()

    if currentVehicle and DoesEntityExist(currentVehicle) and Config.Interaction.FreezeVehicleInMenu then
        FreezeEntityPosition(currentVehicle, false)
    end

    if Config.Interaction.FreezePlayerInMenu then
        FreezeEntityPosition(PlayerPedId(), false)
    end

    DestroyCam()

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    inMenu = false
    currentVehicle = nil
    originalProps = nil
    storeAccess = nil

    SendNUIMessage({ action = 'close' })

    CreateThread(function()
        Wait(500)
        closingMenu = false
    end)
end

local function OpenChoiceMenu(vehicle)
    if inMenu then return end

    if not vehicle or vehicle == 0 then
        Notify('No vehicle nearby.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('prp-repairStore:server:canUseStore', function(canUse, reason, access)
        if not canUse then
            Notify(reason or 'Repair store unavailable.', 'error')
            return
        end

        storeAccess = access or {
            isMechanic = false,
            discountPercent = 0,
            allowedModes = {
                repair = true,
                customize = true,
                livery = true,
                engine = true
            }
        }

        if not CanControlVehicle(vehicle) then
            Notify('Could not get control of vehicle.', 'error')
            return
        end

        currentVehicle = vehicle
        originalProps = CaptureProps(vehicle)

        if Config.Interaction.FreezeVehicleInMenu then
            FreezeEntityPosition(vehicle, true)
        end

        closingMenu = false
        inMenu = true
        StartCam('diagonal')

        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = 'openChoice',
            repairPrice = ApplyStoreDiscount(Config.Payment.RepairPrice),
            showRepair = IsModeAllowed('repair') and currentVehicle ~= nil and not IsVehicleAlreadyRepaired(currentVehicle),
            allowedModes = storeAccess.allowedModes,
            isMechanic = storeAccess.isMechanic,
            discountPercent = storeAccess.discountPercent or 0
        })
    end)
end

local function StartRepair()
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        Notify('No vehicle found.', 'error')
        return
    end

    if IsVehicleAlreadyRepaired(currentVehicle) then
        Notify('Vehicle is already repaired.', 'primary')
        return
    end

    local repairVehicle = currentVehicle

    QBCore.Functions.TriggerCallback('prp-repairStore:server:pay', function(success, reason)
        if not success then
            Notify(reason or 'Payment failed.', 'error')
            return
        end

        if not repairVehicle or not DoesEntityExist(repairVehicle) then
            Notify('Vehicle no longer exists.', 'error')
            CloseMenu(true)
            return
        end

        -- Safest repair flow: no progressbar, no scenario loop, no waiting thread.
        -- Just set the vehicle to a fixed state.
        SetVehicleFixed(repairVehicle)
        SetVehicleDeformationFixed(repairVehicle)
        SetVehicleUndriveable(repairVehicle, false)
        SetVehicleEngineHealth(repairVehicle, Config.Repair.EngineHealth or 1000.0)
        SetVehicleBodyHealth(repairVehicle, Config.Repair.BodyHealth or 1000.0)
        SetVehiclePetrolTankHealth(repairVehicle, 1000.0)
        SetVehicleDirtLevel(repairVehicle, Config.Repair.DirtLevel or 0.0)
        SetVehicleEngineOn(repairVehicle, true, true, false)

        currentVehicle = repairVehicle
        SaveMods()
        Notify('Vehicle repaired.', 'success')
        CloseMenu(false)
    end, Config.Payment.RepairPrice)
end

local function OpenSubMenu(mode)
    if not currentVehicle then return end

    if not IsModeAllowed(mode) then
        Notify('You cannot use this section while on-duty mechanic.', 'error')
        return
    end

    local title = 'Customize'
    if mode == 'engine' then
        title = 'Engine Modify'
    elseif mode == 'livery' then
        title = 'Liveries'
    end

    SendNUIMessage({
        action = 'openMods',
        title = title,
        mode = mode,
        items = DiscountItems(BuildOptions(currentVehicle, mode))
    })
end

CreateThread(function()
    for _, loc in ipairs(Config.Locations) do
        exports[Config.Target]:AddCircleZone('prp_repair_store_' .. loc.id, loc.coords, loc.radius or 5.0, {
            name = 'prp_repair_store_' .. loc.id,
            debugPoly = Config.Debug,
            useZ = true,
        }, {
            options = {
                {
                    icon = Config.TargetSettings.Icon,
                    label = loc.label or Config.TargetSettings.Label,
                    action = function()
                        local veh = GetClosestVehicleToPlayer(Config.Interaction.VehicleSearchRadius)
                        OpenChoiceMenu(veh)
                    end,
                }
            },
            distance = Config.TargetSettings.Distance
        })
    end
end)

RegisterNUICallback('choice', function(data, cb)
    if data.choice == 'repair' then
        if not IsModeAllowed('repair') then
            Notify('Mechanics cannot use store repair while on duty.', 'error')
            cb({ ok = true })
            return
        end
        StartRepair()
    elseif data.choice == 'customize' then
        OpenSubMenu('customize')
    elseif data.choice == 'livery' then
        OpenSubMenu('livery')
    elseif data.choice == 'engine' then
        if not IsModeAllowed('engine') then
            Notify('Mechanics cannot use engine modify while on duty.', 'error')
            cb({ ok = true })
            return
        end
        OpenSubMenu('engine')
    end

    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    if data.item and data.item.camera then
        StartCam(data.item.camera)
    end

    StartSinglePreview(data.item)
    ApplyPreview(data.item, data.value)
    cb({ ok = true })
end)

RegisterNUICallback('camera', function(data, cb)
    StartCam(data.preset or 'diagonal')
    cb({ ok = true })
end)

RegisterNUICallback('camMove', function(data, cb)
    if cam and currentVehicle and DoesEntityExist(currentVehicle) then
        local dx = tonumber(data.dx) or 0.0
        local dy = tonumber(data.dy) or 0.0

        manualCamAngle = manualCamAngle + (dx * 0.22)
        camPitch = math.max(0.7, math.min(4.2, camPitch - (dy * 0.010)))

        UpdateCamera()
    end

    cb({ ok = true })
end)

RegisterNUICallback('camZoom', function(data, cb)
    if cam and currentVehicle and DoesEntityExist(currentVehicle) then
        local delta = tonumber(data.delta) or 0.0
        camDistance = math.max(2.2, math.min(10.0, camDistance + (delta * 0.002)))
        UpdateCamera()
    end

    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    local price = tonumber(data.price) or 0

    QBCore.Functions.TriggerCallback('prp-repairStore:server:payPurchase', function(success, reason)
        if not success then
            if originalProps then ApplyProps(currentVehicle, originalProps) end
            Notify(reason or 'Payment failed.', 'error')
            cb({ ok = false })
            return
        end

        purchasedPreview = true
        ApplyPreview(data.item, data.value)
        previewSnapshot = nil
        purchasedPreview = false
        originalProps = CaptureProps(currentVehicle)
        SaveMods()
        Notify('Purchased.', 'success')
        cb({ ok = true })
    end, price)
end)

RegisterNUICallback('back', function(_, cb)
    -- Safe back: only restore unpaid hovered preview, not the whole vehicle.
    RestoreSinglePreview()

    SendNUIMessage({
        action = 'openChoice',
        repairPrice = ApplyStoreDiscount(Config.Payment.RepairPrice),
        showRepair = IsModeAllowed('repair') and currentVehicle ~= nil and not IsVehicleAlreadyRepaired(currentVehicle),
        allowedModes = storeAccess and storeAccess.allowedModes or nil,
        isMechanic = storeAccess and storeAccess.isMechanic or false,
        discountPercent = storeAccess and storeAccess.discountPercent or 0
    })

    cb({ ok = true })
end)

RegisterNUICallback('close', function(data, cb)
    CloseMenu(data and data.cancel == true)
    cb({ ok = true })
end)

RegisterCommand('prprepairstore', function()
    local veh = GetClosestVehicleToPlayer(Config.Interaction.VehicleSearchRadius)
    OpenChoiceMenu(veh)
end, false)

CreateThread(function()
    while true do
        if inMenu then
            Wait(0)

            if Config.Interaction.DisableVehicleControlsInMenu then
                DisableControlAction(0, 75, true) -- exit vehicle
                DisableControlAction(0, 76, true) -- handbrake
                DisableControlAction(0, 71, true) -- vehicle accelerate
                DisableControlAction(0, 72, true) -- vehicle brake
                DisableControlAction(0, 59, true) -- vehicle move left/right
                DisableControlAction(0, 60, true) -- vehicle move up/down

                if Config.DisableControlsInMenu then
                    for _, control in ipairs(Config.DisableControlsInMenu) do
                        DisableControlAction(0, control, true)
                    end
                end
            end

            DisableControlAction(0, 177, true) -- ESC handled by NUI only
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if currentVehicle and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, false)
    end

    DestroyCam()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
