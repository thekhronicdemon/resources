local QBCore = exports['qb-core']:GetCoreObject()
local Countdown = 10
local ToFarCountdown = 10
local FinishedUITimeout = false

local RaceData = {
    InCreator = false,
    InRace = false,
    ClosestCheckpoint = 0,
}

local CreatorData = {
    RaceName = nil,
    Checkpoints = {},
    TireDistance = 3.0,
    ConfirmDelete = false,
}

local CurrentRaceData = {
    RaceId = nil,
    RaceName = nil,
    Checkpoints = {},
    Started = false,
    CurrentCheckpoint = nil,
    TotalLaps = 0,
    Lap = 0,
    StartDelay = 10,
    GhostCars = false,
    Racers = {},
    RaceTimeMs = 0,
    TotalTimeMs = 0,
    BestLapMs = 0,
    LastLapTimeMs = 0,
    LastLapDeltaMs = 0,
    StartedAtMs = 0,
    LapStartedAtMs = 0,
}

local SyncUiRaceTimers
local GetLocalCitizenId
local BuildLiveLeaderboard

local function HideRaceUi()
    SendNUIMessage({
        action = "Update",
        type = "creator",
        data = CreatorData,
        racedata = RaceData,
        active = false,
    })

    SendNUIMessage({
        action = "Update",
        type = "race",
        data = {},
        racedata = RaceData,
        active = false,
    })
end

-- Handlers

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        HideRaceUi()
        for k, _ in pairs(CreatorData.Checkpoints) do
            if CreatorData.Checkpoints[k].pileleft ~= nil then
                local coords = CreatorData.Checkpoints[k].offset.right
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[k].pileright = nil
            end
            if CreatorData.Checkpoints[k].pileright ~= nil then
                local coords = CreatorData.Checkpoints[k].offset.right
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[k].pileright = nil
            end
        end

        for k, _ in pairs(CurrentRaceData.Checkpoints) do
            if CurrentRaceData.Checkpoints[k] ~= nil then
                if CurrentRaceData.Checkpoints[k].pileleft ~= nil then
                    local coords = CurrentRaceData.Checkpoints[k].offset.right
                    local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                    DeleteObject(Obj)
                    ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                    CurrentRaceData.Checkpoints[k].pileright = nil
                end
                if CurrentRaceData.Checkpoints[k].pileright ~= nil then
                    local coords = CurrentRaceData.Checkpoints[k].offset.right
                    local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                    DeleteObject(Obj)
                    ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                    CurrentRaceData.Checkpoints[k].pileright = nil
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        for _ = 1, 8 do
            HideRaceUi()
            Wait(250)
        end
    end)
end)

-- Functions

local function DrawText3Ds(x, y, z, text, scale, drawBackground)
	scale = scale or 0.35
    if drawBackground == nil then
        drawBackground = true
    end

	SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x,y,z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    if drawBackground then
        local factor = (string.len(text)) / 370
        DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    end
    ClearDrawOrigin()
end

local function GetCheckpointLineHeight(distance)
    local dist = math.max(tonumber(distance) or 0, 0)
    return math.max(3.5, math.min(18.0, 3.5 + (dist * 0.06)))
end

local function GetClosestCheckpoint()
    local pos = GetEntityCoords(PlayerPedId(), true)
    local current = nil
    local dist = nil
    for id, _ in pairs(CreatorData.Checkpoints) do
        if current ~= nil then
            if #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z)) < dist then
                current = id
                dist = #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z))
            end
        else
            dist = #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z))
            current = id
        end
    end
    RaceData.ClosestCheckpoint = current
end

local function CreatorUI()
    CreateThread(function()
        while true do
            if RaceData.InCreator then
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = true,
                })
            else
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = false,
                })
                break
            end
            Wait(200)
        end
    end)
end

local function DeleteCheckpoint()
    local NewCheckpoints = {}
    if RaceData.ClosestCheckpoint ~= 0 then
        if CreatorData.Checkpoints[RaceData.ClosestCheckpoint] ~= nil then
            if CreatorData.Checkpoints[RaceData.ClosestCheckpoint].blip ~= nil then
                RemoveBlip(CreatorData.Checkpoints[RaceData.ClosestCheckpoint].blip)
                CreatorData.Checkpoints[RaceData.ClosestCheckpoint].blip = nil
            end
            if CreatorData.Checkpoints[RaceData.ClosestCheckpoint].pileleft ~= nil then
                local coords = CreatorData.Checkpoints[RaceData.ClosestCheckpoint].offset.left
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[RaceData.ClosestCheckpoint].pileleft = nil
            end
            if CreatorData.Checkpoints[RaceData.ClosestCheckpoint].pileright ~= nil then
                local coords = CreatorData.Checkpoints[RaceData.ClosestCheckpoint].offset.right
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[RaceData.ClosestCheckpoint].pileright = nil
            end

            for id, data in pairs(CreatorData.Checkpoints) do
                if id ~= RaceData.ClosestCheckpoint then
                    NewCheckpoints[#NewCheckpoints+1] = data
                end
            end
            CreatorData.Checkpoints = NewCheckpoints
        else
            QBCore.Functions.Notify('You cant go to fast', 'error')
        end
    else
        QBCore.Functions.Notify('You cant go too fast', 'error')
    end
end

local function SaveRace()
    local RaceDistance = 0

    for k, v in pairs(CreatorData.Checkpoints) do
        if k + 1 <= #CreatorData.Checkpoints then
            local checkpointdistance = #(vector3(v.coords.x, v.coords.y, v.coords.z) - vector3(CreatorData.Checkpoints[k + 1].coords.x, CreatorData.Checkpoints[k + 1].coords.y, CreatorData.Checkpoints[k + 1].coords.z))
            RaceDistance = RaceDistance + checkpointdistance
        end
    end

    CreatorData.RaceDistance = RaceDistance

    TriggerServerEvent('qb-lapraces:server:SaveRace', CreatorData)

    QBCore.Functions.Notify('Race: '..CreatorData.RaceName..' is saved!', 'success')

    for id,_ in pairs(CreatorData.Checkpoints) do
        if CreatorData.Checkpoints[id].blip ~= nil then
            RemoveBlip(CreatorData.Checkpoints[id].blip)
            CreatorData.Checkpoints[id].blip = nil
        end
        if CreatorData.Checkpoints[id] ~= nil then
            if CreatorData.Checkpoints[id].pileleft ~= nil then
                local coords = CreatorData.Checkpoints[id].offset.left
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[id].pileleft = nil
            end
            if CreatorData.Checkpoints[id].pileright ~= nil then
                local coords = CreatorData.Checkpoints[id].offset.right
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[id].pileright = nil
            end
        end
    end

    RaceData.InCreator = false
    CreatorData.RaceName = nil
    CreatorData.Checkpoints = {}
end

local function AddCheckpoint()
    local PlayerPed = PlayerPedId()
    local PlayerPos = GetEntityCoords(PlayerPed)
    local PlayerVeh = GetVehiclePedIsIn(PlayerPed)
    local Offset = {
        left = {
            x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).x,
            y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).y,
            z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).z,
        },
        right = {
            x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).x,
            y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).y,
            z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).z,
        }
    }

    CreatorData.Checkpoints[#CreatorData.Checkpoints+1] = {
        coords = {
            x = PlayerPos.x,
            y = PlayerPos.y,
            z = PlayerPos.z,
        },
        offset = Offset,
    }


    for id, CheckpointData in pairs(CreatorData.Checkpoints) do
        if CheckpointData.blip ~= nil then
            RemoveBlip(CheckpointData.blip)
        end

        CheckpointData.blip = AddBlipForCoord(CheckpointData.coords.x, CheckpointData.coords.y, CheckpointData.coords.z)

        SetBlipSprite(CheckpointData.blip, 1)
        SetBlipDisplay(CheckpointData.blip, 4)
        SetBlipScale(CheckpointData.blip, 0.8)
        SetBlipAsShortRange(CheckpointData.blip, true)
        SetBlipColour(CheckpointData.blip, 26)
        ShowNumberOnBlip(CheckpointData.blip, id)
        SetBlipShowCone(CheckpointData.blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Checkpoint: "..id)
        EndTextCommandSetBlipName(CheckpointData.blip)
    end
end

local function CreatorLoop()
    CreateThread(function()
        while RaceData.InCreator do
            local PlayerPed = PlayerPedId()
            local PlayerVeh = GetVehiclePedIsIn(PlayerPed)

            if PlayerVeh ~= 0 then
                if IsControlJustPressed(0, 161) or IsDisabledControlJustPressed(0, 161) then
                    AddCheckpoint()
                end

                if IsControlJustPressed(0, 162) or IsDisabledControlJustPressed(0, 162) then
                    if CreatorData.Checkpoints ~= nil and next(CreatorData.Checkpoints) ~= nil then
                        DeleteCheckpoint()
                    else
                        QBCore.Functions.Notify('You have not placed any checkpoints yet..', 'error')
                    end
                end

                if IsControlJustPressed(0, 311) or IsDisabledControlJustPressed(0, 311) then
                    if CreatorData.Checkpoints ~= nil and #CreatorData.Checkpoints >= 2 then
                        SaveRace()
                    else
                        QBCore.Functions.Notify('You must have at least 10 checkpoints', 'error')
                    end
                end

                if IsControlJustPressed(0, 40) or IsDisabledControlJustPressed(0, 40) then
                    if CreatorData.TireDistance + 1.0 ~= 16.0 then
                        CreatorData.TireDistance = CreatorData.TireDistance + 1.0
                    else
                        QBCore.Functions.Notify('You can not go higher than 15')
                    end
                end

                if IsControlJustPressed(0, 39) or IsDisabledControlJustPressed(0, 39) then
                    if CreatorData.TireDistance - 1.0 ~= 1.0 then
                        CreatorData.TireDistance = CreatorData.TireDistance - 1.0
                    else
                        QBCore.Functions.Notify('You cannot go lower than 2')
                    end
                end
            else
                local coords = GetEntityCoords(PlayerPedId())
                DrawText3Ds(coords.x, coords.y, coords.z, 'You must be in a vehicle')
            end

            if IsControlJustPressed(0, 163) or IsDisabledControlJustPressed(0, 163) then
                if not CreatorData.ConfirmDelete then
                    CreatorData.ConfirmDelete = true
                    QBCore.Functions.Notify('Press [9] again to confirm', 'error', 5000)
                else
                    for _, CheckpointData in pairs(CreatorData.Checkpoints) do
                        if CheckpointData.blip ~= nil then
                            RemoveBlip(CheckpointData.blip)
                        end
                    end

                    for id,_ in pairs(CreatorData.Checkpoints) do
                        if CreatorData.Checkpoints[id].pileleft ~= nil then
                            local coords = CreatorData.Checkpoints[id].offset.left
                            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, `prop_offroad_tyres02`, 0, 0, 0)
                            DeleteObject(Obj)
                            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                            CreatorData.Checkpoints[id].pileleft = nil
                        end

                        if CreatorData.Checkpoints[id].pileright ~= nil then
                            local coords = CreatorData.Checkpoints[id].offset.right
                            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, `prop_offroad_tyres02`, 0, 0, 0)
                            DeleteObject(Obj)
                            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                            CreatorData.Checkpoints[id].pileright = nil
                        end
                    end

                    RaceData.InCreator = false
                    CreatorData.RaceName = nil
                    CreatorData.Checkpoints = {}
                    QBCore.Functions.Notify('Race-editor canceled!', 'error')
                    CreatorData.ConfirmDelete = false
                end
            end
            Wait(3)
        end
    end)
end

local function RaceUI()
    CreateThread(function()
        while true do
            if CurrentRaceData.Checkpoints ~= nil and next(CurrentRaceData.Checkpoints) ~= nil then
                if CurrentRaceData.Started then
                    SyncUiRaceTimers()
                    CurrentRaceData.RaceTime = math.floor((CurrentRaceData.RaceTimeMs or 0) / 1000)
                    CurrentRaceData.TotalTime = math.floor((CurrentRaceData.TotalTimeMs or 0) / 1000)
                    CurrentRaceData.BestLap = math.floor((CurrentRaceData.BestLapMs or 0) / 1000)
                end
                local leaderboard, position, gapLeaderMs, gapAheadMs = BuildLiveLeaderboard()
                local checkpointIndex = CurrentRaceData.CurrentCheckpoint + 1
                if checkpointIndex > #CurrentRaceData.Checkpoints then
                    checkpointIndex = 1
                end
                local checkpointDistance = 0
                if CurrentRaceData.Checkpoints[checkpointIndex] then
                    local pos = GetEntityCoords(PlayerPedId())
                    local cpcoords = CurrentRaceData.Checkpoints[checkpointIndex].coords
                    checkpointDistance = math.floor(#(pos - vector3(cpcoords.x, cpcoords.y, cpcoords.z)))
                end
                if CurrentRaceData.Started then
                    SendNUIMessage({
                        action = "Update",
                        type = "race",
                        data = {
                            CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint,
                            TotalCheckpoints = #CurrentRaceData.Checkpoints,
                            TotalLaps = CurrentRaceData.TotalLaps,
                            CurrentLap = CurrentRaceData.Lap,
                            RaceStarted = CurrentRaceData.Started,
                            RaceName = CurrentRaceData.RaceName,
                            Time = CurrentRaceData.RaceTime,
                            TotalTime = CurrentRaceData.TotalTime,
                            BestLap = CurrentRaceData.BestLap,
                            CurrentLapTimeMs = CurrentRaceData.RaceTimeMs,
                            TotalTimeMs = CurrentRaceData.TotalTimeMs,
                            BestLapMs = CurrentRaceData.BestLapMs,
                            LastLapDeltaMs = CurrentRaceData.LastLapDeltaMs,
                            Position = position,
                            GapLeaderMs = gapLeaderMs,
                            GapAheadMs = gapAheadMs,
                            CheckpointDistance = checkpointDistance,
                            Leaderboard = leaderboard,
                        },
                        racedata = RaceData,
                        active = true,
                    })
                else
                    SendNUIMessage({
                        action = "Update",
                        type = "race",
                        data = {},
                        racedata = RaceData,
                        active = false,
                    })
                end
            else
                if not FinishedUITimeout then
                    FinishedUITimeout = true
                    SetTimeout(10000, function()
                        FinishedUITimeout = false
                        SendNUIMessage({
                            action = "Update",
                            type = "race",
                            data = {},
                            racedata = RaceData,
                            active = false,
                        })
                    end)
                end
                break
            end
            Wait(12)
        end
    end)
end

local function SetupRace(sRaceData, Laps)
    local settings = sRaceData.TabletSettings or {}

    HideRaceUi()

    RaceData.RaceId = sRaceData.RaceId
    CurrentRaceData = {
        RaceId = sRaceData.RaceId,
        Creator = sRaceData.Creator,
        RaceName = sRaceData.RaceName,
        Checkpoints = sRaceData.Checkpoints,
        Started = false,
        CurrentCheckpoint = 1,
        TotalLaps = Laps,
        Lap = 1,
        RaceTime = 0,
        TotalTime = 0,
        BestLap = 0,
        StartDelay = tonumber(settings.countdownSeconds) or 10,
        GhostCars = settings.ghostCars == true,
        Racers = sRaceData.Racers or {},
        RaceTimeMs = 0,
        TotalTimeMs = 0,
        BestLapMs = 0,
        LastLapTimeMs = 0,
        LastLapDeltaMs = 0,
        StartedAtMs = 0,
        LapStartedAtMs = 0,
    }

    for k, v in pairs(CurrentRaceData.Checkpoints) do
        ClearAreaOfObjects(v.offset.left.x, v.offset.left.y, v.offset.left.z, 50.0, 0)
        CurrentRaceData.Checkpoints[k].pileleft = CreateObject(`prop_offroad_tyres02`, v.offset.left.x, v.offset.left.y, v.offset.left.z, 0, 0, 0)
        PlaceObjectOnGroundProperly(CurrentRaceData.Checkpoints[k].pileleft)
        FreezeEntityPosition(CurrentRaceData.Checkpoints[k].pileleft, 1)
        SetEntityAsMissionEntity(CurrentRaceData.Checkpoints[k].pileleft, 1, 1)

        ClearAreaOfObjects(v.offset.right.x, v.offset.right.y, v.offset.right.z, 50.0, 0)
        CurrentRaceData.Checkpoints[k].pileright = CreateObject(`prop_offroad_tyres02`, v.offset.right.x, v.offset.right.y, v.offset.right.z, 0, 0, 0)
        PlaceObjectOnGroundProperly(CurrentRaceData.Checkpoints[k].pileright)
        FreezeEntityPosition(CurrentRaceData.Checkpoints[k].pileright, 1)
        SetEntityAsMissionEntity(CurrentRaceData.Checkpoints[k].pileright, 1, 1)

        CurrentRaceData.Checkpoints[k].blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
        SetBlipSprite(CurrentRaceData.Checkpoints[k].blip, 1)
        SetBlipDisplay(CurrentRaceData.Checkpoints[k].blip, 4)
        SetBlipScale(CurrentRaceData.Checkpoints[k].blip, 0.6)
        SetBlipAsShortRange(CurrentRaceData.Checkpoints[k].blip, true)
        SetBlipColour(CurrentRaceData.Checkpoints[k].blip, 26)
        ShowNumberOnBlip(CurrentRaceData.Checkpoints[k].blip, k)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Checkpoint: "..k)
        EndTextCommandSetBlipName(CurrentRaceData.Checkpoints[k].blip)
    end

    RaceUI()
end

local function StartGhostCollisionLoop()
    CreateThread(function()
        while RaceData.InRace and CurrentRaceData.GhostCars do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 then
                for _, player in ipairs(GetActivePlayers()) do
                    local otherPed = GetPlayerPed(player)
                    if otherPed ~= ped then
                        local otherVehicle = GetVehiclePedIsIn(otherPed, false)
                        if otherVehicle ~= 0 then
                            SetEntityNoCollisionEntity(vehicle, otherVehicle, true)
                            SetEntityNoCollisionEntity(otherVehicle, vehicle, true)
                        end
                    end
                end
            end

            Wait(250)
        end
    end)
end

local function showNonLoopParticle(dict, particleName, coords, scale)
    RequestNamedPtfxAsset(dict)
    while not HasNamedPtfxAssetLoaded(dict) do
        Wait(0)
    end
    UseParticleFxAssetNextCall(dict)
    local particleHandle = StartParticleFxLoopedAtCoord(particleName, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, scale, false, false, false)
    SetParticleFxLoopedColour(particleHandle, 0, 255, 0 ,0)
    return particleHandle
end

local function DoPilePfx()
    if CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint] ~= nil then
        local Timeout = 500
        local Size = 2.0
        local left = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.left, Size)
        local right = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.right, Size)

        SetTimeout(Timeout, function()
            StopParticleFxLooped(left, false)
            StopParticleFxLooped(right, false)
        end)
    end
end

local function SetupPiles()
    for k, v in pairs(CreatorData.Checkpoints) do
        if CreatorData.Checkpoints[k].pileleft == nil then
            ClearAreaOfObjects(v.offset.left.x, v.offset.left.y, v.offset.left.z, 50.0, 0)
            CreatorData.Checkpoints[k].pileleft = CreateObject(`prop_offroad_tyres02`, v.offset.left.x, v.offset.left.y, v.offset.left.z, 0, 0, 0)
            PlaceObjectOnGroundProperly(CreatorData.Checkpoints[k].pileleft)
            FreezeEntityPosition(CreatorData.Checkpoints[k].pileleft, 1)
            SetEntityAsMissionEntity(CreatorData.Checkpoints[k].pileleft, 1, 1)
        end

        if CreatorData.Checkpoints[k].pileright == nil then
            ClearAreaOfObjects(v.offset.right.x, v.offset.right.y, v.offset.right.z, 50.0, 0)
            CreatorData.Checkpoints[k].pileright = CreateObject(`prop_offroad_tyres02`, v.offset.right.x, v.offset.right.y, v.offset.right.z, 0, 0, 0)
            PlaceObjectOnGroundProperly(CreatorData.Checkpoints[k].pileright)
            FreezeEntityPosition(CreatorData.Checkpoints[k].pileleft, 1)
            SetEntityAsMissionEntity(CreatorData.Checkpoints[k].pileleft, 1, 1)
        end
    end
end

local function GetMaxDistance(OffsetCoords)
    local Distance = #(vector3(OffsetCoords.left.x, OffsetCoords.left.y, OffsetCoords.left.z) - vector3(OffsetCoords.right.x, OffsetCoords.right.y, OffsetCoords.right.z))
    local Retval = 7.5
    if Distance > 20.0 then
        Retval = 12.5
    end
    return Retval
end

local function SecondsToClock(seconds)
    seconds = tonumber(seconds)
    local retval
    if seconds <= 0 then
        retval = "00:00:00";
    else
        local hours = string.format("%02.f", math.floor(seconds/3600));
        local mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
        local secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
        retval = hours..":"..mins..":"..secs
    end
    return retval
end

SyncUiRaceTimers = function()
    if not CurrentRaceData.Started or not CurrentRaceData.StartedAtMs or CurrentRaceData.StartedAtMs <= 0 then
        return
    end

    local now = GetGameTimer()
    CurrentRaceData.TotalTimeMs = math.max(now - (CurrentRaceData.StartedAtMs or now), 0)
    CurrentRaceData.RaceTimeMs = math.max(now - (CurrentRaceData.LapStartedAtMs or now), 0)
end

GetLocalCitizenId = function()
    local playerData = QBCore.Functions.GetPlayerData() or {}
    return playerData.citizenid
end

BuildLiveLeaderboard = function()
    local leaderboard = {}
    local localCitizenId = GetLocalCitizenId()
    local localTotalTime = math.floor(tonumber(CurrentRaceData.TotalTimeMs) or 0)
    local localLapTime = math.floor(tonumber(CurrentRaceData.RaceTimeMs) or 0)
    local foundLocal = false

    for citizenId, racer in pairs(CurrentRaceData.Racers or {}) do
        local entry = {
            citizenId = racer.CitizenId or citizenId,
            name = racer.Name or citizenId,
            checkpoint = tonumber(racer.Checkpoint) or 0,
            lap = tonumber(racer.Lap) or 1,
            finished = racer.Finished == true,
            totalTimeMs = math.max(tonumber(racer.TotalTimeMs) or 0, 0),
            lapTimeMs = math.max(tonumber(racer.LapTimeMs) or 0, 0),
        }

        if entry.citizenId == localCitizenId then
            entry.checkpoint = tonumber(CurrentRaceData.CurrentCheckpoint) or entry.checkpoint
            entry.lap = tonumber(CurrentRaceData.Lap) or entry.lap
            entry.totalTimeMs = localTotalTime
            entry.lapTimeMs = localLapTime
            foundLocal = true
        end

        leaderboard[#leaderboard + 1] = entry
    end

    if localCitizenId and not foundLocal and RaceData.InRace then
        leaderboard[#leaderboard + 1] = {
            citizenId = localCitizenId,
            name = 'You',
            checkpoint = tonumber(CurrentRaceData.CurrentCheckpoint) or 0,
            lap = tonumber(CurrentRaceData.Lap) or 1,
            finished = false,
            totalTimeMs = localTotalTime,
            lapTimeMs = localLapTime,
        }
    end

    table.sort(leaderboard, function(a, b)
        if a.finished ~= b.finished then
            return a.finished and not b.finished
        end
        if (a.lap or 0) ~= (b.lap or 0) then
            return (a.lap or 0) > (b.lap or 0)
        end
        if (a.checkpoint or 0) ~= (b.checkpoint or 0) then
            return (a.checkpoint or 0) > (b.checkpoint or 0)
        end
        return (a.totalTimeMs or 0) < (b.totalTimeMs or 0)
    end)

    local myPosition = 1
    local gapLeaderMs = 0
    local gapAheadMs = 0
    local leaderTime = leaderboard[1] and leaderboard[1].totalTimeMs or localTotalTime

    for index, entry in ipairs(leaderboard) do
        entry.position = index
        entry.deltaLeaderMs = math.max((entry.totalTimeMs or 0) - (leaderTime or 0), 0)
        entry.isPlayer = entry.citizenId == localCitizenId
        if entry.isPlayer then
            myPosition = index
            gapLeaderMs = math.max((entry.totalTimeMs or 0) - (leaderTime or 0), 0)
            if index > 1 then
                gapAheadMs = math.max((entry.totalTimeMs or 0) - (leaderboard[index - 1].totalTimeMs or 0), 0)
            end
        end
    end

    return leaderboard, myPosition, gapLeaderMs, gapAheadMs
end

local function FinishRace()
    TriggerServerEvent('qb-lapraces:server:FinishPlayer', CurrentRaceData, CurrentRaceData.TotalTime, CurrentRaceData.TotalLaps, CurrentRaceData.BestLap)
    if CurrentRaceData.BestLap ~= 0 then
        QBCore.Functions.Notify('Race finished in '..SecondsToClock(CurrentRaceData.TotalTime)..', with the best lap: '..SecondsToClock(CurrentRaceData.BestLap))
    else
        QBCore.Functions.Notify('Race finished in '..SecondsToClock(CurrentRaceData.TotalTime))
    end
    for k, _ in pairs(CurrentRaceData.Checkpoints) do
        if CurrentRaceData.Checkpoints[k].blip ~= nil then
            RemoveBlip(CurrentRaceData.Checkpoints[k].blip)
            CurrentRaceData.Checkpoints[k].blip = nil
        end
        if CurrentRaceData.Checkpoints[k].pileleft ~= nil then
            local coords = CurrentRaceData.Checkpoints[k].offset.left
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            CurrentRaceData.Checkpoints[k].pileleft = nil
        end
        if CurrentRaceData.Checkpoints[k].pileright ~= nil then
            local coords = CurrentRaceData.Checkpoints[k].offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            CurrentRaceData.Checkpoints[k].pileright = nil
        end
    end
    CurrentRaceData.RaceName = nil
    CurrentRaceData.Checkpoints = {}
    CurrentRaceData.Started = false
    CurrentRaceData.CurrentCheckpoint = 0
    CurrentRaceData.TotalLaps = 0
    CurrentRaceData.Lap = 0
    CurrentRaceData.RaceTime = 0
    CurrentRaceData.TotalTime = 0
    CurrentRaceData.BestLap = 0
    CurrentRaceData.StartDelay = 10
    CurrentRaceData.GhostCars = false
    CurrentRaceData.Racers = {}
    CurrentRaceData.RaceTimeMs = 0
    CurrentRaceData.TotalTimeMs = 0
    CurrentRaceData.BestLapMs = 0
    CurrentRaceData.LastLapTimeMs = 0
    CurrentRaceData.LastLapDeltaMs = 0
    CurrentRaceData.StartedAtMs = 0
    CurrentRaceData.LapStartedAtMs = 0
    CurrentRaceData.RaceId = nil
    RaceData.InRace = false
end

local function Info()
    local PlayerPed = PlayerPedId()
    local plyVeh = GetVehiclePedIsIn(PlayerPed, false)
    local IsDriver = GetPedInVehicleSeat(plyVeh, -1) == PlayerPed
    local returnValue = plyVeh ~= 0 and plyVeh ~= nil and IsDriver
    return returnValue, plyVeh
end

local function IsInRace()
    local retval = false
    if RaceData.InRace then
        retval = true
    end
    return retval
end

local function IsInEditor()
    local retval = false
    if RaceData.InCreator then
        retval = true
    end
    return retval
end

exports('IsInEditor', IsInEditor)
exports('IsInRace', IsInRace)

-- Events

RegisterNetEvent('qb-lapraces:client:StartRaceEditor', function(RaceName)
    if not RaceData.InCreator then
        CreatorData.RaceName = RaceName
        RaceData.InCreator = true
        CreatorUI()
        CreatorLoop()
    else
        QBCore.Functions.Notify('You are already making a race.', 'error')
    end
end)

RegisterNetEvent('qb-lapraces:client:UpdateRaceRacerData', function(RaceId, aRaceData)
    if (CurrentRaceData.RaceId ~= nil) and CurrentRaceData.RaceId == RaceId then
        CurrentRaceData.Racers = aRaceData.Racers
    end
end)

RegisterNetEvent('qb-lapraces:client:JoinRace', function(Data, Laps)
    if not RaceData.InRace then
        RaceData.InRace = true
        SetupRace(Data, Laps)
        TriggerServerEvent('qb-lapraces:server:UpdateRaceState', CurrentRaceData.RaceId, false, true)
    else
        QBCore.Functions.Notify('Youre already in a race..', 'error')
    end
end)

RegisterNetEvent('qb-lapraces:client:LeaveRace', function(_)
    QBCore.Functions.Notify('You have completed the race!')
    for k, _ in pairs(CurrentRaceData.Checkpoints) do
        if CurrentRaceData.Checkpoints[k].blip ~= nil then
            RemoveBlip(CurrentRaceData.Checkpoints[k].blip)
            CurrentRaceData.Checkpoints[k].blip = nil
        end
        if CurrentRaceData.Checkpoints[k].pileleft ~= nil then
            local coords = CurrentRaceData.Checkpoints[k].offset.left
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            CurrentRaceData.Checkpoints[k].pileleft = nil
        end
        if CurrentRaceData.Checkpoints[k].pileright ~= nil then
            local coords = CurrentRaceData.Checkpoints[k].offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            CurrentRaceData.Checkpoints[k].pileright = nil
        end
    end
    CurrentRaceData.RaceName = nil
    CurrentRaceData.Checkpoints = {}
    CurrentRaceData.Started = false
    CurrentRaceData.CurrentCheckpoint = 0
    CurrentRaceData.TotalLaps = 0
    CurrentRaceData.Lap = 0
    CurrentRaceData.RaceTime = 0
    CurrentRaceData.TotalTime = 0
    CurrentRaceData.BestLap = 0
    CurrentRaceData.StartDelay = 10
    CurrentRaceData.GhostCars = false
    CurrentRaceData.Racers = {}
    CurrentRaceData.RaceTimeMs = 0
    CurrentRaceData.TotalTimeMs = 0
    CurrentRaceData.BestLapMs = 0
    CurrentRaceData.LastLapTimeMs = 0
    CurrentRaceData.LastLapDeltaMs = 0
    CurrentRaceData.StartedAtMs = 0
    CurrentRaceData.LapStartedAtMs = 0
    CurrentRaceData.RaceId = nil
    RaceData.InRace = false
    FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), false), false)
end)

RegisterNetEvent('qb-lapraces:client:RaceCountdown', function()
    TriggerServerEvent('qb-lapraces:server:UpdateRaceState', CurrentRaceData.RaceId, true, false)
    if CurrentRaceData.RaceId ~= nil then
        local raceCountdown = math.max(tonumber(CurrentRaceData.StartDelay) or 10, 1)
        Countdown = raceCountdown
        while Countdown ~= 0 do
            if CurrentRaceData.RaceName ~= nil then
                if Countdown == raceCountdown then
                    QBCore.Functions.Notify('The race will start in '..raceCountdown..' seconds', 'error', 2500)
                    PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", 0, 0, 1)
                elseif Countdown <= 5 then
                    QBCore.Functions.Notify(Countdown, 'error', 500)
                    PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", 0, 0, 1)
                end
                Countdown = Countdown - 1
                FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), true), true)
            else
                break
            end
            Wait(1000)
        end
        if CurrentRaceData.RaceName ~= nil then
            SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
            QBCore.Functions.Notify('GO!', 'success', 1000)
            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].blip, 1.0)
            FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), true), false)
            DoPilePfx()
            CurrentRaceData.StartedAtMs = GetGameTimer()
            CurrentRaceData.LapStartedAtMs = CurrentRaceData.StartedAtMs
            CurrentRaceData.RaceTimeMs = 0
            CurrentRaceData.TotalTimeMs = 0
            CurrentRaceData.BestLapMs = 0
            CurrentRaceData.LastLapTimeMs = 0
            CurrentRaceData.LastLapDeltaMs = 0
            CurrentRaceData.Started = true
            if CurrentRaceData.GhostCars then
                StartGhostCollisionLoop()
            end
            Countdown = 10
        else
            FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), true), false)
            Countdown = 10
        end
    else
        QBCore.Functions.Notify('You are not currently in a race..', 'error')
    end
end)

RegisterNetEvent('qb-lapraces:client:PlayerFinishs', function(RaceId, Place, FinisherData)
    if CurrentRaceData.RaceId ~= nil then
        if CurrentRaceData.RaceId == RaceId then
            QBCore.Functions.Notify(FinisherData.PlayerData.charinfo.firstname..' is finished on spot: '..Place, 'error', 3500)
        end
    end
end)

RegisterNetEvent('qb-lapraces:client:WaitingDistanceCheck', function()
    Wait(1000)
    CreateThread(function()
        while true do
            if not CurrentRaceData.Started then
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                if CurrentRaceData.Checkpoints[1] ~= nil then
                    local cpcoords = CurrentRaceData.Checkpoints[1].coords
                    local dist = #(pos - vector3(cpcoords.x, cpcoords.y, cpcoords.z))
                    if dist > 115.0 then
                        if ToFarCountdown ~= 0 then
                            ToFarCountdown = ToFarCountdown - 1
                            QBCore.Functions.Notify('Go back to the start or you will be kicked from the race: '..ToFarCountdown..'s', 'error', 500)
                        else
                            TriggerServerEvent('qb-lapraces:server:LeaveRace', CurrentRaceData)
                            ToFarCountdown = 10
                            break
                        end
                        Wait(1000)
                    else
                        if ToFarCountdown ~= 10 then
                            ToFarCountdown = 10
                        end
                    end
                end
            else
                break
            end
            Wait(3)
        end
    end)
end)

-- Threads

CreateThread(function()
    while true do
        if RaceData.InCreator then
            local PlayerPed = PlayerPedId()
            local PlayerVeh = GetVehiclePedIsIn(PlayerPed)

            if PlayerVeh ~= 0 then
                local Offset = {
                    left = {
                        x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).x,
                        y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).y,
                        z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).z,
                    },
                    right = {
                        x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).x,
                        y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).y,
                        z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).z,
                    }
                }

                DrawText3Ds(Offset.left.x, Offset.left.y, Offset.left.z, 'Checkpoint L')
                DrawText3Ds(Offset.right.x, Offset.right.y, Offset.right.z, 'Checkpoint R')
            end
        end
        Wait(3)
    end
end)

CreateThread(function()
    while true do

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        if CurrentRaceData.RaceName ~= nil then
            if CurrentRaceData.Started then
                SyncUiRaceTimers()
                local cp
                if CurrentRaceData.CurrentCheckpoint + 1 > #CurrentRaceData.Checkpoints then
                    cp = 1
                else
                    cp = CurrentRaceData.CurrentCheckpoint + 1
                end
                local data = CurrentRaceData.Checkpoints[cp]
                local CheckpointDistance = #(pos - vector3(data.coords.x, data.coords.y, data.coords.z))
                local MaxDistance = GetMaxDistance(CurrentRaceData.Checkpoints[cp].offset)
                local lineHeight = GetCheckpointLineHeight(CheckpointDistance)
                local lineTop = data.coords.z + lineHeight

                DrawLine(data.coords.x, data.coords.y, lineTop, data.coords.x, data.coords.y, data.coords.z + 1.5, 244, 225, 84, 220)
                DrawText3Ds(data.coords.x, data.coords.y, lineTop + 0.85, ('%sM'):format(math.floor(CheckpointDistance)), 0.42, false)

                if CheckpointDistance < MaxDistance then
                    if CurrentRaceData.TotalLaps == 0 then
                        if CurrentRaceData.CurrentCheckpoint + 1 < #CurrentRaceData.Checkpoints then
                            CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                            SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
                            TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false, CurrentRaceData.TotalTimeMs, CurrentRaceData.RaceTimeMs)
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].blip, 0.6)
                            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].blip, 1.0)
                        else
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                            CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                            TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, true, CurrentRaceData.TotalTimeMs, CurrentRaceData.RaceTimeMs)
                            FinishRace()
                        end
                    else
                        if CurrentRaceData.CurrentCheckpoint + 1 > #CurrentRaceData.Checkpoints then
                            if CurrentRaceData.Lap + 1 > CurrentRaceData.TotalLaps then
                                DoPilePfx()
                                PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                                CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, true, CurrentRaceData.TotalTimeMs, CurrentRaceData.RaceTimeMs)
                                FinishRace()
                            else
                                DoPilePfx()
                                PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                                local now = GetGameTimer()
                                local lapDurationMs = math.max(now - (CurrentRaceData.LapStartedAtMs or now), 0)
                                if CurrentRaceData.BestLapMs == 0 or lapDurationMs < CurrentRaceData.BestLapMs then
                                    CurrentRaceData.BestLapMs = lapDurationMs
                                end
                                if CurrentRaceData.LastLapTimeMs and CurrentRaceData.LastLapTimeMs > 0 then
                                    CurrentRaceData.LastLapDeltaMs = lapDurationMs - CurrentRaceData.LastLapTimeMs
                                end
                                CurrentRaceData.LastLapTimeMs = lapDurationMs
                                CurrentRaceData.LapStartedAtMs = now
                                CurrentRaceData.RaceTimeMs = 0
                                if CurrentRaceData.RaceTime < CurrentRaceData.BestLap then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                elseif CurrentRaceData.BestLap == 0 then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                end
                                CurrentRaceData.RaceTime = 0
                                CurrentRaceData.Lap = CurrentRaceData.Lap + 1
                                CurrentRaceData.CurrentCheckpoint = 1
                                SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false, CurrentRaceData.TotalTimeMs, CurrentRaceData.RaceTimeMs)
                            end
                        else
                            CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                            if CurrentRaceData.CurrentCheckpoint ~= #CurrentRaceData.Checkpoints then
                                SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false, CurrentRaceData.TotalTimeMs, CurrentRaceData.RaceTimeMs)
                                SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].blip, 0.6)
                                SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].blip, 1.0)
                            else
                                SetNewWaypoint(CurrentRaceData.Checkpoints[1].coords.x, CurrentRaceData.Checkpoints[1].coords.y)
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false, CurrentRaceData.TotalTimeMs, CurrentRaceData.RaceTimeMs)
                                SetBlipScale(CurrentRaceData.Checkpoints[#CurrentRaceData.Checkpoints].blip, 0.6)
                                SetBlipScale(CurrentRaceData.Checkpoints[1].blip, 1.0)
                            end
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                        end
                    end
                end
            else
                local data = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint]
                local CheckpointDistance = #(pos - vector3(data.coords.x, data.coords.y, data.coords.z))
                local lineHeight = GetCheckpointLineHeight(CheckpointDistance)
                local lineTop = data.coords.z + lineHeight
                DrawLine(data.coords.x, data.coords.y, lineTop, data.coords.x, data.coords.y, data.coords.z + 1.5, 244, 225, 84, 220)
                DrawText3Ds(data.coords.x, data.coords.y, lineTop + 0.85, ('START %sM'):format(math.floor(CheckpointDistance)), 0.42, false)
                DrawMarker(4, data.coords.x, data.coords.y, data.coords.z + 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.9, 1.5, 1.5, 255, 255, 255, 255, 0, 1, 0, 0, 0, 0, 0)
            end
        else
            Wait(1000)
        end

        Wait(3)
    end
end)

CreateThread(function()
    while true do
        if RaceData.InCreator then
            GetClosestCheckpoint()
            SetupPiles()
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local Driver, plyVeh = Info()
        if Driver then
            if GetVehicleCurrentGear(plyVeh) < 3 and GetVehicleCurrentRpm(plyVeh) == 1.0 and math.ceil(GetEntitySpeed(plyVeh) * 2.236936) > 50 then
              while GetVehicleCurrentRpm(plyVeh) > 0.6 do
                  SetVehicleCurrentRpm(plyVeh, 0.3)
                  Wait(1)
              end
              Wait(800)
            end
        end
        Wait(500)
    end
end)
