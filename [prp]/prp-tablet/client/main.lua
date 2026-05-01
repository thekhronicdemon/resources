local QBCore = exports['qb-core']:GetCoreObject()
local TabletOpen = false

local function Trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function DefaultRacingState(message)
    return {
        success = false,
        message = message or 'RacePro unavailable.',
        tracks = {},
        personalTracks = {},
        publicRaces = {},
        hotTracks = {},
        popularTracks = {},
        newTracks = {},
        myHostedRace = nil,
        currentRace = nil,
        canCreateTracks = false,
        raceSetupAllowed = false,
        canManageAllTracks = false,
        profile = {
            nickname = 'Racer',
            rating = 0,
            totalRaces = 0,
        },
        dailyReward = {
            count = 0,
            goals = {},
            progressPercent = 0,
            secondsUntilReset = 0,
            resetLabel = '00:00:00',
        },
        lastRace = nil,
    }
end

local function CloseTablet()
    TabletOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeTablet' })
end

local function GetRacingSnapshot(cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    QBCore.Functions.TriggerCallback('qb-lapraces:server:GetTabletState', function(data)
        cb(data or DefaultRacingState('RacePro unavailable.'))
    end)
end

local function GetTabletSnapshot(cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:GetTabletData', function(data)
        cb(data or { success = false, message = 'Tablet unavailable.' })
    end)
end

local function BuildCombinedSnapshot(cb)
    GetTabletSnapshot(function(data)
        if not data or data.success == false then
            cb(data or { success = false, message = 'Tablet unavailable.' })
            return
        end

        GetRacingSnapshot(function(racing)
            data.racing = racing
            cb(data)
        end)
    end)
end

local function PushRacingUpdate()
    if not TabletOpen then return end

    GetRacingSnapshot(function(racing)
        SendNUIMessage({
            action = 'tabletRacingUpdate',
            racing = racing,
        })
    end)
end

local function OpenTablet()
    if TabletOpen then return end

    BuildCombinedSnapshot(function(data)
        if not data or data.success == false then
            QBCore.Functions.Notify(data and data.message or 'Tablet unavailable.', 'error')
            return
        end

        TabletOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openTablet',
            applications = Config.Apps or {},
            PlayerData = QBCore.Functions.GetPlayerData(),
            tabletData = data,
        })
    end)
end

local function PushTerminalResult(payload)
    SendNUIMessage({
        action = 'tabletTerminalResult',
        payload = payload or {},
    })
end

local function LaunchTabletHack(command, prepared)
    if GetResourceState('prp-hacks') ~= 'started' then
        PushTerminalResult({
            success = false,
            command = command,
            message = 'prp-hacks is offline.',
        })
        return
    end

    local ok, started = pcall(function()
        return exports['prp-hacks']:StartHack(prepared.hack.game, prepared.hack.options or {}, function(success)
            if not success then
                PushTerminalResult({
                    success = false,
                    command = command,
                    message = 'Hack failed. USB remains locked.',
                })
                return
            end

            QBCore.Functions.TriggerCallback('prp-tablet:server:CompleteTerminalHack', function(resp)
                PushTerminalResult({
                    success = resp and resp.success ~= false,
                    command = command,
                    message = resp and resp.message or 'USB unlocked.',
                    lines = resp and resp.lines or nil,
                    status = resp and resp.status or nil,
                })
            end, prepared.drive and prepared.drive.serial)
        end)
    end)

    if not ok or started == false then
        PushTerminalResult({
            success = false,
            command = command,
            message = 'Hack terminal is busy right now.',
        })
    end
end

local function GetClosestServerPlayer(radius)
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player == -1 or distance > (radius or 3.0) then return nil end
    return GetPlayerServerId(player)
end

local function ReplyWithFreshRacing(cb, successMessage, fallbackMessage)
    SetTimeout(250, function()
        GetRacingSnapshot(function(racing)
            if successMessage then
                racing.message = successMessage
            elseif racing.success == false and fallbackMessage then
                racing.message = fallbackMessage
            end
            cb(racing)
        end)
    end)
end

RegisterCommand(Config.OpenCommand or 'tablet', function()
    OpenTablet()
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        for _ = 1, 12 do
            if not TabletOpen then
                CloseTablet()
            end
            Wait(250)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CloseTablet()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CloseTablet()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CloseTablet()
end)

RegisterNetEvent('prp-tablet:client:UseTablet', function()
    OpenTablet()
end)

RegisterNetEvent('prp-tablet:client:MiningComplete', function(_, message, status)
    SendNUIMessage({
        action = 'tabletMiningComplete',
        message = message or 'Crypto reward received.',
        status = status or { activeMining = {} },
    })
    QBCore.Functions.Notify(message or 'Crypto reward received.', 'success')
end)

RegisterNetEvent('prp-phone:client:UpdateLapraces', function()
    PushRacingUpdate()
end)

RegisterNUICallback('CloseTablet', function(_, cb)
    CloseTablet()
    cb('ok')
end)

RegisterNUICallback('TabletRefresh', function(_, cb)
    BuildCombinedSnapshot(function(data)
        cb(data or { success = false, message = 'Tablet data unavailable.' })
    end)
end)

RegisterNUICallback('TabletStartCryptoMine', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:StartCryptoMine', function(resp)
        cb(resp or { success = false, message = 'Crypto rig failed to start.' })
    end)
end)

RegisterNUICallback('TabletStartUsbDepletion', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:StartUsbDepletion', function(resp)
        cb(resp or { success = false, message = 'USB depletion failed to start.' })
    end, data and data.serial)
end)

RegisterNUICallback('TabletRunTerminalCommand', function(data, cb)
    local command = Trim(data and data.command)
    if command == '' then
        cb({ success = false, message = 'No terminal command entered.' })
        return
    end

    QBCore.Functions.TriggerCallback('prp-tablet:server:PrepareTerminalHack', function(resp)
        if not resp or resp.success == false then
            cb(resp or { success = false, message = 'Terminal command failed.' })
            return
        end

        cb({
            success = true,
            pending = true,
            message = resp.message or 'Launching terminal hack...',
        })
        LaunchTabletHack(command, resp)
    end, command:gsub('^run%s+', ''))
end)

RegisterNUICallback('TabletGetRacingData', function(_, cb)
    GetRacingSnapshot(function(resp)
        cb(resp)
    end)
end)

RegisterNUICallback('TabletCreateRaceZone', function(data, cb)
    local raceName = Trim(data and data.name)
    if #raceName < 3 or #raceName > 24 then
        cb({ success = false, message = 'Track name must be 3-24 characters.' })
        return
    end

    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    QBCore.Functions.TriggerCallback('qb-lapraces:server:IsAuthorizedToCreateRaces', function(isAuthorized, isNameAvailable)
        if not isAuthorized then
            cb({ success = false, message = 'Track creation is locked right now.' })
            return
        end

        if not isNameAvailable then
            cb({ success = false, message = 'That track name is already taken.' })
            return
        end

        CloseTablet()
        Wait(50)
        TriggerServerEvent('qb-lapraces:server:CreateLapRace', raceName)
        QBCore.Functions.Notify('Race zone creator live. [7] add, [8] delete, [K] save, [9] cancel.', 'primary', 8000)
        cb({ success = true, message = 'Race zone creator loaded.' })
    end, raceName)
end)

RegisterNUICallback('TabletHostRace', function(data, cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    local raceId = data and data.raceId
    if not raceId then
        cb({ success = false, message = 'Choose a track first.' })
        return
    end

    local laps = math.max(1, math.min(math.floor(tonumber(data.laps) or 1), tonumber(Config.Racing.MaxLaps) or 20))
    local password = Trim(data and data.password)
    local maxPasswordLength = tonumber(Config.Racing.MaxPasswordLength) or 24
    if #password > maxPasswordLength then
        cb({ success = false, message = ('Race code must stay under %d characters.'):format(maxPasswordLength) })
        return
    end

    TriggerServerEvent('qb-lapraces:server:SetupRace', raceId, laps, {
        password = password,
        buyIn = tonumber(data and data.buyIn) or 0,
        hostJackpot = tonumber(data and data.hostJackpot) or 0,
        countdownSeconds = tonumber(data and data.countdownSeconds) or 10,
        maxPlayers = tonumber(data and data.maxPlayers) or 10,
        ghostCars = data and data.ghostCars == true,
    })

    ReplyWithFreshRacing(cb, password ~= '' and 'Private race hosted.' or 'Race hosted.', 'Could not host race.')
end)

RegisterNUICallback('TabletJoinRace', function(data, cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    local raceId = data and data.raceId
    if not raceId then
        cb({ success = false, message = 'Race not found.' })
        return
    end

    TriggerServerEvent('qb-lapraces:server:JoinRace', {
        RaceId = raceId,
        Password = Trim(data and data.password),
    })
    ReplyWithFreshRacing(cb, 'Race joined.', 'Could not join race.')
end)

RegisterNUICallback('TabletJoinPrivateRace', function(data, cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    local password = Trim(data and data.password)
    if password == '' then
        cb({ success = false, message = 'Enter a private race code.' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-lapraces:server:GetPrivateRaceByPassword', function(resp)
        if not resp or resp.success == false or not resp.race then
            cb(resp or { success = false, message = 'No private race matched that code.' })
            return
        end

        TriggerServerEvent('qb-lapraces:server:JoinRace', {
            RaceId = resp.race.raceId,
            Password = password,
        })
        ReplyWithFreshRacing(cb, 'Private race joined.', 'Could not join private race.')
    end, password)
end)

RegisterNUICallback('TabletLeaveRace', function(_, cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    GetRacingSnapshot(function(racing)
        local currentRace = racing.currentRace
        if not currentRace or not currentRace.raceId then
            cb({ success = false, message = 'You are not in a hosted race.' })
            return
        end

        TriggerServerEvent('qb-lapraces:server:LeaveRace', {
            RaceId = currentRace.raceId,
            RaceName = currentRace.name,
        })
        ReplyWithFreshRacing(cb, 'Race left.', 'Could not leave race.')
    end)
end)

RegisterNUICallback('TabletStartHostedRace', function(data, cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    local raceId = data and data.raceId
    if not raceId then
        cb({ success = false, message = 'No hosted race selected.' })
        return
    end

    TriggerServerEvent('qb-lapraces:server:StartRace', raceId)
    ReplyWithFreshRacing(cb, 'Hosted race started.', 'Could not start hosted race.')
end)

RegisterNUICallback('TabletCancelHostedRace', function(data, cb)
    if GetResourceState('qb-lapraces') ~= 'started' then
        cb(DefaultRacingState('RacePro offline.'))
        return
    end

    local raceId = data and data.raceId
    if not raceId then
        cb({ success = false, message = 'No hosted race selected.' })
        return
    end

    TriggerServerEvent('qb-lapraces:server:CancelRace', raceId)
    ReplyWithFreshRacing(cb, 'Hosted race closed.', 'Could not close hosted race.')
end)

RegisterNUICallback('TabletRenameTrack', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-lapraces:server:RenameTrack', function(resp)
        cb(resp or { success = false, message = 'Could not rename track.' })
    end, data and data.raceId, data and data.name)
end)

RegisterNUICallback('TabletDeleteTrack', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-lapraces:server:DeleteTrack', function(resp)
        cb(resp or { success = false, message = 'Could not delete track.' })
    end, data and data.raceId)
end)

RegisterNUICallback('TabletUpdateRaceProfile', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-lapraces:server:UpdateRaceProfile', function(resp)
        cb(resp or { success = false, message = 'Could not update nickname.' })
    end, data and data.nickname)
end)

RegisterNUICallback('TabletClaimDailyReward', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-lapraces:server:ClaimDailyReward', function(resp)
        if not resp or resp.success == false then
            cb(resp or { success = false, message = 'Could not claim reward.' })
            return
        end

        ReplyWithFreshRacing(cb, resp.message or 'Reward claimed.', 'Could not refresh reward state.')
    end, data and data.tier)
end)

RegisterNUICallback('TabletGetBusinessData', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:GetBusinessData', function(resp)
        cb(resp or { success = false, message = 'Business data unavailable.', employees = {} })
    end)
end)

RegisterNUICallback('TabletToggleDuty', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:ToggleDuty', function(resp)
        cb(resp or { success = false, message = 'Could not update duty.' })
    end)
end)

RegisterNUICallback('TabletBusinessHireClosest', function(_, cb)
    local targetId = GetClosestServerPlayer(3.0)
    if not targetId then
        cb({ success = false, message = 'No one nearby.' })
        return
    end

    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessHireClosest', function(resp)
        cb(resp or { success = false, message = 'Could not hire that player.' })
    end, targetId)
end)

RegisterNUICallback('TabletBusinessHireCitizen', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessHireCitizen', function(resp)
        cb(resp or { success = false, message = 'Could not hire that citizen.' })
    end, data and data.citizenid)
end)

RegisterNUICallback('TabletBusinessFireMember', function(data, cb)
    if not data or not data.citizenid then
        cb({ success = false, message = 'No employee selected.' })
        return
    end

    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessFireMember', function(resp)
        cb(resp or { success = false, message = 'Could not fire that employee.' })
    end, data.citizenid)
end)

RegisterNUICallback('TabletBusinessAdjustMoney', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessAdjustMoney', function(resp)
        cb(resp or { success = false, message = 'Could not change business money.' })
    end, data and data.action, data and data.amount)
end)

RegisterNUICallback('TabletBusinessSendMessage', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessSendMessage', function(resp)
        cb(resp or { success = false, message = 'Could not send message.' })
    end, data)
end)

RegisterNUICallback('TabletBusinessEditMessage', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessEditMessage', function(resp)
        cb(resp or { success = false, message = 'Could not edit message.' })
    end, data)
end)

RegisterNUICallback('TabletBusinessDeleteMessage', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:BusinessDeleteMessage', function(resp)
        cb(resp or { success = false, message = 'Could not delete message.' })
    end, data and data.id)
end)

RegisterNUICallback('TabletSetWaypoint', function(data, cb)
    local x = tonumber(data and data.x)
    local y = tonumber(data and data.y)
    if not x or not y then
        cb({ success = false, message = 'No waypoint available.' })
        return
    end

    SetNewWaypoint(x, y)
    cb({ success = true, message = 'Waypoint set.' })
end)

RegisterNUICallback('TabletGetAdsData', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:GetAdsData', function(resp)
        cb(resp or { success = false, message = 'Ads unavailable.', items = {} })
    end)
end)

RegisterNUICallback('TabletCreateAdvertisement', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:CreateAdvertisement', function(resp)
        cb(resp or { success = false, message = 'Could not post ad.', items = {} })
    end, data)
end)

RegisterNUICallback('TabletDeleteAdvertisement', function(data, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:DeleteAdvertisement', function(resp)
        cb(resp or { success = false, message = 'Could not delete ad.', items = {} })
    end, data and data.id)
end)

RegisterNUICallback('TabletGetAdminData', function(_, cb)
    QBCore.Functions.TriggerCallback('prp-tablet:server:GetAdminData', function(resp)
        cb(resp or { success = false, message = 'Admin data unavailable.' })
    end)
end)

CreateThread(function()
    for _ = 1, 8 do
        CloseTablet()
        Wait(250)
    end
end)
