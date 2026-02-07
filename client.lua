local isEscorting = false
local escortedPlayer = nil
local isBeingEscorted = false
local escortedBy = nil
local targetIsDead = false
local lastActionTime = 0

local function getCooldownMs()
    return Config.ActionCooldown or Config.EscortCooldown or 5000
end

local function notify(message, type, duration)
    Framework.Client.Notify(message, type or 'inform', duration)
end

local function onCooldown()
    local currentTime = GetGameTimer()
    local remaining = getCooldownMs() - (currentTime - lastActionTime)

    if remaining > 0 then
        Framework.Debug(('Action on cooldown. Wait %s seconds'):format(math.ceil(remaining / 1000)))
        notify(('Action on cooldown (%ss)'):format(math.ceil(remaining / 1000)), 'error')
        return true
    end

    return false
end

local function stampCooldown()
    lastActionTime = GetGameTimer()
end

local function getTargetByMode(mode)
    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    if closestPlayer == -1 or distance > Config.MaxEscortDistance then
        Framework.Debug('No nearby player in range')
        notify('No nearby player in range', 'error')
        return nil
    end

    local isDead = Framework.Client.IsPlayerDead(closestPlayer)
    if mode == 'carry' and not isDead then
        Framework.Debug('Carry requires a dead player target')
        notify('Carry requires a dead player target', 'error')
        return nil
    end

    if mode == 'escort' and isDead then
        Framework.Debug('Escort requires a living player target')
        notify('Escort requires a living player target', 'error')
        return nil
    end

    return closestPlayer, isDead
end

local function getNearestTargetServerId(requireEscortedState)
    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    if closestPlayer == -1 or distance > Config.MaxEscortDistance then
        if requireEscortedState then
            return nil
        end

        notify('No nearby player in range', 'error')
        return nil
    end

    return GetPlayerServerId(closestPlayer)
end

local function requestStart(mode)
    if isEscorting or isBeingEscorted then
        notify('You are already in an escort/carry state', 'error')
        return
    end

    if onCooldown() then
        return
    end

    local targetPlayer, isDead = getTargetByMode(mode)
    if not targetPlayer then
        return
    end

    if isDead and not Config.AllowCarryDead then
        Framework.Debug('Carrying dead players is disabled')
        notify('Carrying dead players is disabled', 'error')
        return
    end

    if not isDead and not Config.AllowEscortAlive then
        Framework.Debug('Escorting alive players is disabled')
        notify('Escorting alive players is disabled', 'error')
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    TriggerServerEvent('escort:requestAction', targetServerId, mode)
    stampCooldown()
end

local function requestStop(targetServerId)
    TriggerServerEvent('escort:stopAction', targetServerId)
end

local function getKnownStopTargetServerId()
    if isEscorting and escortedPlayer then
        return GetPlayerServerId(escortedPlayer)
    end

    if isBeingEscorted and escortedBy then
        return GetPlayerServerId(escortedBy)
    end

    return nil
end

local function toggleMode(mode)
    if isEscorting or isBeingEscorted then
        requestStop(getKnownStopTargetServerId())
    else
        requestStart(mode)
    end
end

local function requestVehicleAction(action, targetServerId)
    if onCooldown() then
        return
    end

    if not targetServerId then
        targetServerId = getNearestTargetServerId(false)
    end

    if not targetServerId then
        return
    end

    TriggerServerEvent('escort:vehicleAction', targetServerId, action)
    stampCooldown()
end

RegisterCommand('escort', function()
    toggleMode('escort')
end, false)

RegisterCommand('carry', function()
    toggleMode('carry')
end, false)

RegisterCommand('unescort', function()
    local targetServerId = getKnownStopTargetServerId() or getNearestTargetServerId(true)
    requestStop(targetServerId)
end, false)

RegisterCommand('putinvehicle', function()
    requestVehicleAction('putin')
end, false)

RegisterCommand('takeoutvehicle', function()
    requestVehicleAction('takeout')
end, false)

RegisterKeyMapping('escort', 'Toggle Escort Player (alive target)', 'keyboard', Config.DefaultEscortKey or Config.DefaultKey or 'H')
RegisterKeyMapping('carry', 'Toggle Carry Player (dead target)', 'keyboard', Config.DefaultCarryKey or 'G')
RegisterKeyMapping('unescort', 'Stop escort/carry (self, target, or escorter)', 'keyboard', Config.DefaultUnescortKey or 'U')
RegisterKeyMapping('putinvehicle', 'Put nearby escorted player in nearest vehicle', 'keyboard', Config.DefaultPutInVehicleKey or 'J')
RegisterKeyMapping('takeoutvehicle', 'Take escorted player out of vehicle', 'keyboard', Config.DefaultTakeOutVehicleKey or 'K')

if Config.UseTarget then
    CreateThread(function()
        Wait(1000)

        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:addGlobalPlayer({
                {
                    name = 'escort_player',
                    icon = 'fa-solid fa-user-group',
                    label = 'Escort/Carry',
                    distance = Config.MaxEscortDistance,
                    onSelect = function(data)
                        local targetId = NetworkGetPlayerIndexFromPed(data.entity)
                        if targetId == -1 then
                            return
                        end

                        local targetServerId = GetPlayerServerId(targetId)

                        if isEscorting or isBeingEscorted then
                            requestStop(targetServerId)
                            return
                        end

                        if onCooldown() then
                            return
                        end

                        local targetDeadState = IsPedDeadOrDying(data.entity, true) or IsEntityDead(data.entity)
                        if targetDeadState and not Config.AllowCarryDead then
                            notify('Carrying dead players is disabled', 'error')
                            return
                        end

                        if (not targetDeadState) and not Config.AllowEscortAlive then
                            notify('Escorting alive players is disabled', 'error')
                            return
                        end

                        local mode = targetDeadState and 'carry' or 'escort'
                        TriggerServerEvent('escort:requestAction', targetServerId, mode)
                        stampCooldown()
                    end,
                    canInteract = function()
                        return true
                    end
                },
                {
                    name = 'escort_unescort_player',
                    icon = 'fa-solid fa-user-xmark',
                    label = 'Unescort / Release',
                    distance = Config.MaxEscortDistance,
                    onSelect = function(data)
                        local targetId = NetworkGetPlayerIndexFromPed(data.entity)
                        local targetServerId

                        if targetId ~= -1 then
                            targetServerId = GetPlayerServerId(targetId)
                        end

                        requestStop(targetServerId)
                    end,
                    canInteract = function()
                        return true
                    end
                },
                {
                    name = 'escort_put_vehicle',
                    icon = 'fa-solid fa-right-to-bracket',
                    label = 'Put In Vehicle',
                    distance = Config.MaxEscortDistance,
                    onSelect = function(data)
                        local targetId = NetworkGetPlayerIndexFromPed(data.entity)
                        if targetId == -1 then
                            return
                        end

                        requestVehicleAction('putin', GetPlayerServerId(targetId))
                    end,
                    canInteract = function()
                        return true
                    end
                },
                {
                    name = 'escort_takeout_vehicle',
                    icon = 'fa-solid fa-right-from-bracket',
                    label = 'Take Out Vehicle',
                    distance = Config.MaxEscortDistance,
                    onSelect = function(data)
                        local targetId = NetworkGetPlayerIndexFromPed(data.entity)
                        if targetId == -1 then
                            return
                        end

                        requestVehicleAction('takeout', GetPlayerServerId(targetId))
                    end,
                    canInteract = function()
                        return true
                    end
                }
            })
        end
    end)
end

RegisterNetEvent('escort:start', function(targetId)
    local targetPlayer = GetPlayerFromServerId(targetId)
    if targetPlayer == -1 or targetPlayer == nil then
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not DoesEntityExist(targetPed) then
        return
    end

    targetIsDead = IsPedDeadOrDying(targetPed, true) or IsEntityDead(targetPed)
    escortedPlayer = targetPlayer
    isEscorting = true

    CreateThread(function()
        while isEscorting do
            Wait(500)

            local myPed = PlayerPedId()
            local ped = GetPlayerPed(escortedPlayer)
            if not DoesEntityExist(myPed) or not DoesEntityExist(ped) then
                if escortedPlayer then
                    TriggerServerEvent('escort:stopAction', GetPlayerServerId(escortedPlayer))
                end
                break
            end
        end
    end)
end)

RegisterNetEvent('escort:beingEscorted', function(escorterId)
    local escorterPlayer = GetPlayerFromServerId(escorterId)
    if escorterPlayer == -1 then
        return
    end

    escortedBy = escorterPlayer
    isBeingEscorted = true

    local myPed = PlayerPedId()
    if IsPedDeadOrDying(myPed, true) or IsEntityDead(myPed) then
        SetPedToRagdoll(myPed, Config.RagdollDuration or 60000, Config.RagdollDuration or 60000, false, false, false, false)
    end

    CreateThread(function()
        while isBeingEscorted do
            Wait(0)

            local escorterPed = GetPlayerPed(escortedBy)
            local me = PlayerPedId()

            if not DoesEntityExist(escorterPed) or not DoesEntityExist(me) then
                TriggerServerEvent('escort:stopAction')
                break
            end

            if not IsEntityAttachedToEntity(me, escorterPed) then
                local dead = IsPedDeadOrDying(me, true) or IsEntityDead(me)
                if dead then
                    SetPedToRagdoll(me, Config.RagdollDuration or 60000, Config.RagdollDuration or 60000, false, false, false, false)

                    if Config.CarryOnShoulder then
                        AttachEntityToEntity(me, escorterPed, 11816, 0.5, 0.5, 0.0, 305.28, 161.04, 0.0, false, false, false, false, 2, true)
                    else
                        AttachEntityToEntity(me, escorterPed, 11816, 0.30, 0.30, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    end
                else
                    AttachEntityToEntity(me, escorterPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end
            end
        end
    end)
end)

RegisterNetEvent('escort:vehicle', function(action)
    local myPed = PlayerPedId()

    if action == 'putin' then
        local coords = GetEntityCoords(myPed)
        local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, Config.VehicleSearchRadius or 5.0, 0, 71)
        if vehicle == 0 or not DoesEntityExist(vehicle) then
            notify('No nearby vehicle found', 'error')
            return
        end

        local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
        local seatFound = false
        for seat = maxSeats - 1, -1, -1 do
            if IsVehicleSeatFree(vehicle, seat) then
                DetachEntity(myPed, true, false)
                ClearPedTasksImmediately(myPed)
                SetPedIntoVehicle(myPed, vehicle, seat)
                seatFound = true
                break
            end
        end

        if not seatFound then
            notify('No free seat in vehicle', 'error')
            return
        end

        notify('Placed in vehicle', 'success')
        return
    end

    if action == 'takeout' then
        local vehicle = GetVehiclePedIsIn(myPed, false)
        if vehicle == 0 then
            notify('Target is not in a vehicle', 'error')
            return
        end

        TaskLeaveVehicle(myPed, vehicle, 16)
        Wait(300)
        ClearPedTasks(myPed)
        notify('Removed from vehicle', 'success')
    end
end)

RegisterNetEvent('escort:stop', function()
    if isEscorting and escortedPlayer then
        local targetPed = GetPlayerPed(escortedPlayer)
        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            if targetIsDead then
                StopPedRagdoll(targetPed)
            end
            ClearPedTasksImmediately(targetPed)
        end
    end

    if isBeingEscorted then
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            StopPedRagdoll(myPed)
            ClearPedTasksImmediately(myPed)
        end
    end

    isEscorting = false
    escortedPlayer = nil
    isBeingEscorted = false
    escortedBy = nil
    targetIsDead = false
end)

RegisterNetEvent('escort:notify', function(message, messageType, duration)
    notify(message, messageType, duration)
end)

TriggerEvent('chat:addSuggestion', '/escort', 'Escort or release a nearby living player')
TriggerEvent('chat:addSuggestion', '/carry', 'Carry or release a nearby dead player')
TriggerEvent('chat:addSuggestion', '/unescort', 'Force stop escort/carry (works for escorter or target)')
TriggerEvent('chat:addSuggestion', '/putinvehicle', 'Put nearby escorted/carry target into nearest vehicle')
TriggerEvent('chat:addSuggestion', '/takeoutvehicle', 'Take nearby escorted/carry target out of vehicle')

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    if isEscorting and escortedPlayer then
        local targetPed = GetPlayerPed(escortedPlayer)
        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            if targetIsDead then
                StopPedRagdoll(targetPed)
            end
            ClearPedTasksImmediately(targetPed)
        end
    end

    if isBeingEscorted then
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            StopPedRagdoll(myPed)
            ClearPedTasksImmediately(myPed)
        end
    end
end)

RegisterCommand('escortdebug', function()
    print('=== ESCORT DEBUG ===')
    print('Is Escorting: ' .. tostring(isEscorting))
    print('Escorted Player: ' .. tostring(escortedPlayer))
    print('Is Being Escorted: ' .. tostring(isBeingEscorted))
    print('Escorted By: ' .. tostring(escortedBy))
    print('Last Action Time: ' .. tostring(lastActionTime))

    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    print('Closest Player Index: ' .. tostring(closestPlayer))
    print('Distance: ' .. tostring(distance))
    print('===================')
end, false)
