local cam = nil
local charPeds = {}
local activeSlot = nil
local loadScreenCheckState = false
local QBCore = exports['qb-core']:GetCoreObject()
local cached_player_skins = {}
local characterSlots = Config.DefaultNumberOfCharacters or 5

local randommodels = { -- models possible to load when choosing empty slot
    'mp_m_freemode_01',
    'mp_f_freemode_01',
}

-- Main Thread

CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            TriggerEvent('prp-multicharacters:client:chooseChar')
            return
        end
    end
end)

-- Functions

local function loadModel(model)
    if type(model) == 'string' then
        model = joaat(model)
    end

    if not model or not IsModelInCdimage(model) then
        return nil
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    return model
end

local function sceneConfig()
    return Config.SelectionScene or {
        Interior = Config.Interior,
        HiddenCoords = Config.HiddenCoords,
        OverviewCam = Config.CamCoords,
        OverviewPoint = vector3(Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z + 0.7),
        OverviewFov = 50.0,
        FocusFov = 34.0,
        EmptyScenario = 'PROP_HUMAN_SEAT_CHAIR_DRINK',
        Seats = {
            {
                coords = Config.PedCoords,
                cam = Config.CamCoords,
                scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
            },
        },
    }
end

local function getSeat(slot)
    local scene = sceneConfig()
    if not scene.Seats or #scene.Seats == 0 then
        return {
            coords = Config.PedCoords,
            cam = Config.CamCoords,
            scenario = 'PROP_HUMAN_SEAT_CHAIR_SMOKING',
        }
    end

    local seatIndex = ((tonumber(slot) or 1) - 1) % #scene.Seats + 1
    return scene.Seats[seatIndex]
end

local function deletePreviewPed(slot)
    local ped = charPeds[slot]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
    end
    charPeds[slot] = nil
end

local function deletePreviewPeds()
    for slot in pairs(charPeds) do
        deletePreviewPed(slot)
    end
    charPeds = {}
end

local function destroySelectionCamera()
    if cam and DoesCamExist(cam) then
        SetCamActive(cam, false)
        DestroyCam(cam, true)
    end
    cam = nil
    RenderScriptCams(false, false, 1, true, true)
    ClearFocus()
end

local function restorePlayerPed()
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityCollision(playerPed, true, true)
end

local function hidePlayerPed()
    local scene = sceneConfig()
    local hiddenCoords = scene.HiddenCoords or Config.HiddenCoords
    local playerPed = PlayerPedId()

    SetEntityCoords(playerPed, hiddenCoords.x, hiddenCoords.y, hiddenCoords.z, false, false, false, false)
    SetEntityHeading(playerPed, hiddenCoords.w)
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityCollision(playerPed, false, false)
end

local function loadSelectionInterior()
    local scene = sceneConfig()
    local interiorCoords = scene.Interior or Config.Interior

    RequestCollisionAtCoord(interiorCoords.x, interiorCoords.y, interiorCoords.z)
    SetFocusPosAndVel(interiorCoords.x, interiorCoords.y, interiorCoords.z, 0.0, 0.0, 0.0)

    local interior = GetInteriorAtCoords(interiorCoords.x, interiorCoords.y, interiorCoords.z)
    if interior ~= 0 then
        LoadInterior(interior)
        local timeout = 0
        while not IsInteriorReady(interior) and timeout < 100 do
            Wait(50)
            timeout = timeout + 1
        end
    end
end

local function setSelectionCamera(camCoords, lookAtCoords, fov)
    local nextCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamCoord(nextCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(nextCam, -8.0, 0.0, camCoords.w or 0.0, 2)
    SetCamFov(nextCam, fov or 45.0)

    if lookAtCoords then
        PointCamAtCoord(nextCam, lookAtCoords.x, lookAtCoords.y, lookAtCoords.z)
    end

    if cam and DoesCamExist(cam) then
        local oldCam = cam
        SetCamActiveWithInterp(nextCam, oldCam, 850, true, true)
        cam = nextCam
        CreateThread(function()
            Wait(900)
            if oldCam and DoesCamExist(oldCam) then
                DestroyCam(oldCam, false)
            end
        end)
    else
        cam = nextCam
        SetCamActive(cam, true)
    end

    RenderScriptCams(true, true, 650, true, true)
end

local function focusSceneCamera(slot)
    local scene = sceneConfig()

    if slot then
        local seat = getSeat(slot)
        local seatCoords = seat.coords
        local focusPoint = vector3(seatCoords.x, seatCoords.y, seatCoords.z + 0.72)
        setSelectionCamera(seat.cam or scene.OverviewCam or Config.CamCoords, focusPoint, seat.fov or scene.FocusFov or 34.0)
        return
    end

    setSelectionCamera(
        scene.OverviewCam or Config.CamCoords,
        scene.OverviewPoint or vector3(Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z + 0.7),
        scene.OverviewFov or 50.0
    )
end

local function playSeatScenario(ped, seat, hasCharacter)
    local scene = sceneConfig()
    local scenario = seat.scenario

    if not hasCharacter then
        scenario = seat.emptyScenario or scene.EmptyScenario or scenario
    end

    if scenario then
        ClearPedTasksImmediately(ped)
        TaskStartScenarioAtPosition(ped, scenario, seat.coords.x, seat.coords.y, seat.coords.z, seat.coords.w, -1, true, true)
        CreateThread(function()
            Wait(1200)
            if not DoesEntityExist(ped) or IsPedUsingScenario(ped, scenario) then
                return
            end

            local fallbackScenario = scene.FallbackScenario or 'PROP_HUMAN_SEAT_CHAIR'
            TaskStartScenarioAtPosition(ped, fallbackScenario, seat.coords.x, seat.coords.y, seat.coords.z, seat.coords.w, -1, true, true)
        end)
    end
end

local function decodeSkinData(data)
    if not data or data == '' then
        return nil
    end

    if type(data) == 'table' then
        return data
    end

    local ok, decoded = pcall(json.decode, data)
    if ok then
        return decoded
    end

    return nil
end

local function initializePedModel(slot, model, data, hasCharacter)
    slot = tonumber(slot) or 1

    CreateThread(function()
        deletePreviewPed(slot)

        if not model or model == 0 then
            model = randommodels[((slot - 1) % #randommodels) + 1]
        end

        model = loadModel(model)
        if not model then
            return
        end

        local seat = getSeat(slot)
        local coords = seat.coords
        local ped = CreatePed(2, model, coords.x, coords.y, coords.z, coords.w, false, true)

        charPeds[slot] = ped
        SetEntityAsMissionEntity(ped, true, true)
        SetEntityHeading(ped, coords.w)
        SetPedDefaultComponentVariation(ped)
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        SetEntityCollision(ped, true, true)
        PlaceObjectOnGroundProperly(ped)

        if data then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', data, ped)
            Wait(150)
            SetEntityVisible(ped, true, false)
            SetEntityAlpha(ped, 255, false)
        end

        playSeatScenario(ped, seat, hasCharacter)
        SetModelAsNoLongerNeeded(model)
    end)
end

local function getCachedSkin(cData)
    if not cData or not cData.citizenid then
        return nil, nil
    end

    if not cached_player_skins[cData.citizenid] then
        local tempModel = promise.new()
        local tempData = promise.new()

        QBCore.Functions.TriggerCallback('prp-multicharacters:server:getSkin', function(model, data)
            tempModel:resolve(model)
            tempData:resolve(data)
        end, cData.citizenid)

        cached_player_skins[cData.citizenid] = {
            model = Citizen.Await(tempModel),
            data = Citizen.Await(tempData),
        }
    end

    return cached_player_skins[cData.citizenid].model, cached_player_skins[cData.citizenid].data
end

local function spawnCharacterPed(slot, cData)
    if not cData then
        initializePedModel(slot, nil, nil, false)
        return
    end

    local model, data = getCachedSkin(cData)
    if type(model) == 'string' and tonumber(model) then
        model = tonumber(model)
    end
    initializePedModel(slot, model, decodeSkinData(data), true)
end

local function spawnCharacterPeds(characters)
    CreateThread(function()
        deletePreviewPeds()

        local charactersBySlot = {}
        for _, cData in pairs(characters or {}) do
            local cid = tonumber(cData.cid)
            if cid then
                charactersBySlot[cid] = cData
            end
        end

        local maxSlots = characterSlots or Config.DefaultNumberOfCharacters or 5
        for slot = 1, maxSlots do
            spawnCharacterPed(slot, charactersBySlot[slot])
            Wait(75)
        end

        if activeSlot then
            focusSceneCamera(activeSlot)
        else
            focusSceneCamera()
        end
    end)
end

local function skyCam(bool)
    if bool then
        TriggerEvent('qb-weathersync:client:DisableSync')
        loadSelectionInterior()
        hidePlayerPed()
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(0.35)
        focusSceneCamera()
    else
        SetTimecycleModifier('default')
        deletePreviewPeds()
        destroySelectionCamera()
        restorePlayerPed()
        TriggerEvent('qb-weathersync:client:EnableSync')
    end
end

local function openCharMenu(bool)
    bool = bool == true

    if not bool then
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = 'ui',
            toggle = false,
        })
        skyCam(false)
        return
    end

    QBCore.Functions.TriggerCallback('prp-multicharacters:server:GetNumberOfCharacters', function(result, countries)
        local translations = {}
        for k in pairs(Lang.fallback and Lang.fallback.phrases or Lang.phrases) do
            if k:sub(0, ('ui.'):len()) then
                translations[k:sub(('ui.'):len() + 1)] = Lang:t(k)
            end
        end

        characterSlots = result or Config.DefaultNumberOfCharacters or 5
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'ui',
            customNationality = Config.customNationality,
            toggle = true,
            nChar = characterSlots,
            enableDeleteButton = Config.EnableDeleteButton,
            translations = translations,
            countries = countries,
        })
        skyCam(true)
        if not loadScreenCheckState then
            ShutdownLoadingScreenNui()
            loadScreenCheckState = true
        end
    end)
end

-- Events

RegisterNetEvent('prp-multicharacters:client:closeNUIdefault', function() -- This event is only for no starting apartments
    deletePreviewPeds()
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    Wait(2000)
    SetEntityCoords(PlayerPedId(), Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    Wait(500)
    openCharMenu(false)
    SetEntityVisible(PlayerPedId(), true)
    SetEntityCollision(PlayerPedId(), true, true)
    Wait(500)
    DoScreenFadeIn(250)
    TriggerEvent('qb-weathersync:client:EnableSync')
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end)

RegisterNetEvent('prp-multicharacters:client:closeNUI', function()
    openCharMenu(false)
end)

RegisterNetEvent('prp-multicharacters:client:chooseChar', function()
    SetNuiFocus(false, false)
    DoScreenFadeOut(10)
    Wait(1000)
    deletePreviewPeds()
    loadSelectionInterior()
    hidePlayerPed()
    Wait(1500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    openCharMenu(true)
end)

RegisterNetEvent('prp-multicharacters:client:spawnLastLocation', function(coords, cData)
    deletePreviewPeds()
    destroySelectionCamera()
    restorePlayerPed()

    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result then
            TriggerEvent('apartments:client:SetHomeBlip', result.type)
            local ped = PlayerPedId()
            SetEntityCoords(ped, coords.x, coords.y, coords.z)
            SetEntityHeading(ped, coords.w)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true)
            SetEntityCollision(ped, true, true)
            local PlayerData = QBCore.Functions.GetPlayerData()
            local insideMeta = PlayerData.metadata['inside']
            DoScreenFadeOut(500)

            if insideMeta.house then
                TriggerEvent('qb-houses:client:LastLocationHouse', insideMeta.house)
            elseif insideMeta.apartment.apartmentType and insideMeta.apartment.apartmentId then
                TriggerEvent('qb-apartments:client:LastLocationHouse', insideMeta.apartment.apartmentType, insideMeta.apartment.apartmentId)
            else
                SetEntityCoords(ped, coords.x, coords.y, coords.z)
                SetEntityHeading(ped, coords.w)
                FreezeEntityPosition(ped, false)
                SetEntityVisible(ped, true)
                SetEntityCollision(ped, true, true)
            end

            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            Wait(2000)
            DoScreenFadeIn(250)
        end
    end, cData.citizenid)
end)

RegisterNetEvent('qb-multicharacter:client:closeNUIdefault', function()
    TriggerEvent('prp-multicharacters:client:closeNUIdefault')
end)

RegisterNetEvent('qb-multicharacter:client:closeNUI', function()
    TriggerEvent('prp-multicharacters:client:closeNUI')
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    TriggerEvent('prp-multicharacters:client:chooseChar')
end)

RegisterNetEvent('qb-multicharacter:client:spawnLastLocation', function(coords, cData)
    TriggerEvent('prp-multicharacters:client:spawnLastLocation', coords, cData)
end)

-- NUI Callbacks

RegisterNUICallback('closeUI', function(data, cb)
    local cData = data.cData
    if not cData then
        cb('ok')
        return
    end

    DoScreenFadeOut(10)
    TriggerServerEvent('prp-multicharacters:server:loadUserData', cData)
    openCharMenu(false)

    cb('ok')
end)

RegisterNUICallback('disconnectButton', function(_, cb)
    openCharMenu(false)
    TriggerServerEvent('prp-multicharacters:server:disconnect')
    cb('ok')
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local cData = data.cData
    DoScreenFadeOut(10)
    TriggerServerEvent('prp-multicharacters:server:loadUserData', cData)
    openCharMenu(false)
    cb('ok')
end)

RegisterNUICallback('cDataPed', function(nData, cb)
    local cData = nData.cData
    local slot = tonumber(nData.slot) or (cData and tonumber(cData.cid)) or activeSlot or 1

    activeSlot = slot

    if not charPeds[slot] then
        spawnCharacterPed(slot, cData)
    end

    focusSceneCamera(slot)
    cb('ok')
end)

RegisterNUICallback('setupCharacters', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-multicharacters:server:setupCharacters', function(result)
        cached_player_skins = {}
        SendNUIMessage({
            action = 'setupCharacters',
            characters = result
        })
        spawnCharacterPeds(result)
        cb('ok')
    end)
end)

RegisterNUICallback('removeBlur', function(_, cb)
    SetTimecycleModifier('default')
    cb('ok')
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    local cData = data
    DoScreenFadeOut(150)
    if cData.gender == Lang:t('ui.male') then
        cData.gender = 0
    elseif cData.gender == Lang:t('ui.female') then
        cData.gender = 1
    end
    TriggerServerEvent('prp-multicharacters:server:createCharacter', cData)
    Wait(500)
    cb('ok')
end)

RegisterNUICallback('removeCharacter', function(data, cb)
    TriggerServerEvent('prp-multicharacters:server:deleteCharacter', data.citizenid)
    deletePreviewPeds()
    TriggerEvent('prp-multicharacters:client:chooseChar')
    cb('ok')
end)
