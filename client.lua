-- =============================================================================
-- IDTG Escort Script - Enhanced with Animation System
-- =============================================================================
-- Version: 3.0.0
-- Description: Multi-framework escort script with full animation support
-- =============================================================================

-- State Variables
local isEscorting = false
local escortedPlayer = nil
local isBeingEscorted = false
local escortedBy = nil
local lastActionTime = 0
local stopRequestPending = false
local animationActive = false
local animationDictionary = nil
local escortedAnimationDictionary = nil

-- Animation Dictionaries for Different States
local ANIM_DICTS = {
    escort_start = 'random@arrests',
    escort_walk = 'random@arrests',
    escort_stop = 'random@arrests',
    escorted_loop = 'random@arrests@busted'
}

-- Animation Clips for Different Actions
local ANIM_CLIPS = {
    escort_start = 'generic_radio_enter',
    escort_walk = 'generic_radio_chatter',
    escort_stop = 'generic_radio_enter',
    escorted_loop = 'idle_a'
}

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

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

-- =============================================================================
-- ANIMATION SYSTEM
-- =============================================================================

-- Load animation dictionary with timeout protection
local function loadAnimationDictionary(dict)
    if not dict or dict == "" then
        Framework.Debug("Invalid animation dictionary provided")
        return false
    end
    
    -- Check if already loaded
    if HasAnimDictLoaded(dict) then
        return true
    end
    
    RequestAnimDict(dict)
    local timeout = 5000 -- 5 second timeout
    local startTime = GetGameTimer()
    
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        
        -- Timeout protection
        if GetGameTimer() - startTime > timeout then
            Framework.Debug("Failed to load animation dictionary: " .. dict)
            return false
        end
    end
    
    Framework.Debug("Successfully loaded animation dictionary: " .. dict)
    return true
end

-- Play animation on a ped with blending
local function playAnimation(ped, dict, anim, flag, blendIn, blendOut, duration)
    if not DoesEntityExist(ped) then
        return false
    end
    
    if not loadAnimationDictionary(dict) then
        Framework.Debug("Cannot play animation - dictionary not loaded: " .. dict)
        return false
    end
    
    -- Set animation blending for smooth transitions
    blendIn = blendIn or 0.3 -- Default 300ms blend in
    blendOut = blendOut or 0.3 -- Default 300ms blend out
    
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flag, 0, false, false, false)
    
    return true
end

-- Clear animation from a ped
local function clearAnimation(ped)
    if not DoesEntityExist(ped) then
        return
    end
    
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    ClearPedTasksImmediately(ped)
end

-- Stop animation and mark as inactive
local function stopAnimation(ped)
    if not animationActive or not animationDictionary then
        return
    end
    
    clearAnimation(ped)
    RemoveAnimDict(animationDictionary)
    animationActive = false
    animationDictionary = nil
end

local function stopEscortedAnimation(ped)
    if not escortedAnimationDictionary then
        return
    end

    clearAnimation(ped)
    RemoveAnimDict(escortedAnimationDictionary)
    escortedAnimationDictionary = nil
end

-- =============================================================================
-- ESCORT ANIMATION HANDLERS
-- =============================================================================

-- Play start animation when escort begins
local function playEscortStartAnimation(actorPed)
    if not DoesEntityExist(actorPed) then
        Framework.Debug("Cannot play start animation - invalid ped")
        return false
    end
    local dict = ANIM_DICTS.escort_start
    local anim = ANIM_CLIPS.escort_start

    animationDictionary = dict
    
    -- Play animation on the actor (escorting player)
    local success = playAnimation(
        actorPed,
        dict, 
        anim, 
        49, -- Flag: allow movement + upper body
        0.5, -- 500ms blend in for smooth start
        0.3, -- 300ms blend out
        1000 -- 1 second initial animation
    )
    
    if success then
        animationActive = true
        Framework.Debug("Started escort animation: " .. dict .. " @ " .. anim)

        return true
    end
    
    return false
end

local function playEscortedAliveAnimation(ped)
    if not DoesEntityExist(ped) then
        return
    end

    local dict = ANIM_DICTS.escorted_loop
    local anim = ANIM_CLIPS.escorted_loop

    if loadAnimationDictionary(dict) then
        escortedAnimationDictionary = dict
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 33, 0, false, false, false)
    end
end

-- Play walking animation while escorting is active
local function playEscortWalkAnimation(ped)
    if not DoesEntityExist(ped) or not animationActive then
        return
    end
    local dict = ANIM_DICTS.escort_walk
    local anim = ANIM_CLIPS.escort_walk

    -- Update animation dictionary if needed
    if animationDictionary ~= dict then
        if HasAnimDictLoaded(animationDictionary) then
            RemoveAnimDict(animationDictionary)
        end
        if loadAnimationDictionary(dict) then
            animationDictionary = dict
        end
    end
    
    -- Play walking animation with movement allowed
    playAnimation(
        ped, 
        dict, 
        anim, 
        49, -- Flag: allow movement
        0.3, -- 300ms blend in
        0.3, -- 300ms blend out
        -1 -- Loop indefinitely
    )
end

-- Play stop animation when escort ends
local function playEscortStopAnimation(ped)
    if not DoesEntityExist(ped) then
        return
    end
    
    if not animationActive or not animationDictionary then
        -- No active animation, just clear tasks
        clearAnimation(ped)
        return
    end
    local dict = ANIM_DICTS.escort_stop
    local anim = ANIM_CLIPS.escort_stop

    -- Play stop/release animation
    local success = playAnimation(
        ped, 
        dict, 
        anim, 
        49, -- Flag: allow movement
        0.2, -- 200ms blend in for quick release
        0.5, -- 500ms blend out for smooth stop
        1500 -- 1.5 second release animation
    )
    
    if success then
        Framework.Debug("Playing stop animation: " .. dict .. " @ " .. anim)
        
        -- Wait for animation to complete, then clear
        CreateThread(function()
            Wait(1500)
            
            -- Clear animation and dictionary
            if animationDictionary then
                RemoveAnimDict(animationDictionary)
            end
            
            clearAnimation(ped)
            animationActive = false
            animationDictionary = nil
        end)
    else
        -- Animation failed, just clear immediately
        if animationDictionary then
            RemoveAnimDict(animationDictionary)
        end
        clearAnimation(ped)
        animationActive = false
        animationDictionary = nil
    end
end

-- =============================================================================
-- TARGET SELECTION
-- =============================================================================

local function getEscortTarget()
    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    if closestPlayer == -1 or distance > Config.MaxEscortDistance then
        Framework.Debug('No nearby player in range')
        notify('No nearby player in range', 'error')
        return nil
    end
    local isDead = Framework.Client.IsPlayerDead(closestPlayer)
    if isDead then
        notify('Escort requires a living player target', 'error')
        return nil
    end

    return closestPlayer
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

-- =============================================================================
-- ESCORT REQUEST HANDLING
-- =============================================================================

local function requestStart()
    if isEscorting or isBeingEscorted then
        notify('You are already in an escort state', 'error')
        return
    end

    if onCooldown() then
        return
    end

    local targetPlayer = getEscortTarget()
    if not targetPlayer then
        return
    end

    if not Config.AllowEscortAlive then
        Framework.Debug('Escorting alive players is disabled')
        notify('Escorting alive players is disabled', 'error')
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    TriggerServerEvent('escort:requestAction', targetServerId, 'escort')
    stampCooldown()
end

local function requestStop(targetServerId)
    if stopRequestPending then
        return
    end

    if not isEscorting and not isBeingEscorted then
        notify('You are not escorting anyone', 'error')
        return
    end

    stopRequestPending = true
    TriggerServerEvent('escort:stopAction', targetServerId)

    CreateThread(function()
        Wait(2000)
        stopRequestPending = false
    end)
end

local function getKnownStopTargetServerId()
    if isEscorting and escortedPlayer then
        local targetServerId = GetPlayerServerId(escortedPlayer)
        if targetServerId and targetServerId > 0 then
            return targetServerId
        end

        return nil
    end

    if isBeingEscorted and escortedBy then
        local targetServerId = GetPlayerServerId(escortedBy)
        if targetServerId and targetServerId > 0 then
            return targetServerId
        end

        return nil
    end

    return nil
end

local function toggleEscort()
    if isEscorting or isBeingEscorted then
        requestStop(getKnownStopTargetServerId())
    else
        requestStart()
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

-- =============================================================================
-- COMMANDS AND KEYBINDS
-- =============================================================================

RegisterCommand('escort', function()
    toggleEscort()
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
RegisterKeyMapping('unescort', 'Stop escort (self, target, or escorter)', 'keyboard', Config.DefaultUnescortKey or 'U')
RegisterKeyMapping('putinvehicle', 'Put nearby escorted player in nearest vehicle', 'keyboard', Config.DefaultPutInVehicleKey or 'J')
RegisterKeyMapping('takeoutvehicle', 'Take escorted player out of vehicle', 'keyboard', Config.DefaultTakeOutVehicleKey or 'K')

-- =============================================================================
-- OX_TARGET INTEGRATION
-- =============================================================================

if Config.UseTarget then
    CreateThread(function()
        Wait(1000)

        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:addGlobalPlayer({
                {
                    name = 'escort_player',
                    icon = 'fa-solid fa-user-group',
                    label = 'Escort',
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
                        if targetDeadState then
                            notify('Escort requires a living player target', 'error')
                            return
                        end

                        if not Config.AllowEscortAlive then
                            notify('Escorting alive players is disabled', 'error')
                            return
                        end

                        TriggerServerEvent('escort:requestAction', targetServerId, 'escort')
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

-- =============================================================================
-- ESCORT EVENT HANDLERS
-- =============================================================================

-- Event: Start escorting (escorter side)
RegisterNetEvent('escort:start', function(targetId)
    local targetPlayer = GetPlayerFromServerId(targetId)
    if targetPlayer == -1 or targetPlayer == nil then
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not DoesEntityExist(targetPed) then
        return
    end

    escortedPlayer = targetPlayer
    isEscorting = true
    stopRequestPending = false

    playEscortStartAnimation(PlayerPedId())

    Framework.Debug('Started escorting player: ' .. targetId)

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

            if animationActive then
                playEscortWalkAnimation(myPed)
            end
        end
    end)
end)

-- Event: Being escorted (target side) - ENHANCED WITH ANIMATIONS
RegisterNetEvent('escort:beingEscorted', function(escorterId)
    local escorterPlayer = GetPlayerFromServerId(escorterId)
    if escorterPlayer == -1 then
        return
    end

    escortedBy = escorterPlayer
    isBeingEscorted = true
    stopRequestPending = false

    local myPed = PlayerPedId()
    -- Main escort loop
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
                AttachEntityToEntity(me, escorterPed, 11816, 0.35, 0.45, 0.0, 0.0, 0.0, 15.0, false, false, false, false, 2, true)
                playEscortedAliveAnimation(me)
            elseif not IsEntityPlayingAnim(me, ANIM_DICTS.escorted_loop, ANIM_CLIPS.escorted_loop, 3) then
                playEscortedAliveAnimation(me)
            end
        end
    end)
end)

RegisterNetEvent('escort:vehicleAnimation', function(action)
    local myPed = PlayerPedId()
    if not DoesEntityExist(myPed) then
        return
    end

    local dict = 'random@arrests'
    local anim = action == 'putin' and 'generic_radio_enter' or 'generic_radio_chatter'

    playAnimation(myPed, dict, anim, 49, 0.2, 0.2, 1200)
end)

-- Event: Vehicle actions
RegisterNetEvent('escort:vehicle', function(action)
    local myPed = PlayerPedId()

    -- Stop animation before vehicle action
    if animationActive then
        stopAnimation(myPed)
    end

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

-- Event: Stop escort - ENHANCED WITH STOP ANIMATION
RegisterNetEvent('escort:stop', function()
    stopRequestPending = false

    local myPed = PlayerPedId()

    -- Handle escorter side
    if isEscorting and escortedPlayer then
        local targetPed = GetPlayerPed(escortedPlayer)
        playEscortStopAnimation(myPed)

        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            ClearPedTasksImmediately(targetPed)
        end
    end

    -- Handle target (being escorted) side
    if isBeingEscorted then
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            stopEscortedAnimation(myPed)
            ClearPedTasksImmediately(myPed)
        end
    end

    -- Reset state
    isEscorting = false
    escortedPlayer = nil
    isBeingEscorted = false
    escortedBy = nil
    -- Reset animation state
    animationActive = false
    animationDictionary = nil
    escortedAnimationDictionary = nil
    
    Framework.Debug('Escort stopped')
end)

-- Event: Notification
RegisterNetEvent('escort:notify', function(message, messageType, duration)
    notify(message, messageType, duration)
end)

-- =============================================================================
-- CHAT SUGGESTIONS
-- =============================================================================

TriggerEvent('chat:addSuggestion', '/escort', 'Escort or release a nearby living player')
TriggerEvent('chat:addSuggestion', '/unescort', 'Force stop escort (works for escorter or target)')
TriggerEvent('chat:addSuggestion', '/putinvehicle', 'Put nearby escorted target into nearest vehicle')
TriggerEvent('chat:addSuggestion', '/takeoutvehicle', 'Take nearby escorted target out of vehicle')

-- =============================================================================
-- RESOURCE STOP HANDLER - CLEANUP ANIMATIONS
-- =============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    local myPed = PlayerPedId()

    -- Cleanup escorter side
    if isEscorting and escortedPlayer then
        local targetPed = GetPlayerPed(escortedPlayer)
        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            ClearPedTasksImmediately(targetPed)
            
            -- Stop any active animations
            if animationActive and animationDictionary then
                RemoveAnimDict(animationDictionary)
            end
        end
    end

    -- Cleanup target side
    if isBeingEscorted then
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            stopEscortedAnimation(myPed)
            ClearPedTasksImmediately(myPed)
            
            -- Stop any active animations
            if animationActive and animationDictionary then
                RemoveAnimDict(animationDictionary)
            end
        end
    end
end)

-- =============================================================================
-- DEBUG COMMAND
-- =============================================================================

RegisterCommand('escortdebug', function()
    print('=== ESCORT DEBUG ===')
    print('Is Escorting: ' .. tostring(isEscorting))
    print('Escorted Player: ' .. tostring(escortedPlayer))
    print('Is Being Escorted: ' .. tostring(isBeingEscorted))
    print('Escorted By: ' .. tostring(escortedBy))
    print('Last Action Time: ' .. tostring(lastActionTime))
    print('Animation Active: ' .. tostring(animationActive))
    print('Animation Dictionary: ' .. tostring(animationDictionary))

    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    print('Closest Player Index: ' .. tostring(closestPlayer))
    print('Distance: ' .. tostring(distance))
    print('===================')
end, false)
