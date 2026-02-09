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
local escortWalkAnimPlaying = false

-- Default animation dictionaries/clips (overridden by Config.Animations when present)
local ANIM_DICTS = {
    escort_start = 'random@arrests',
    escort_walk = 'random@arrests',
    escort_stop = 'random@arrests',
    escorted_loop = 'random@arrests@busted'
}

local ANIM_CLIPS = {
    escort_start = 'generic_radio_enter',
    escort_walk = 'generic_radio_chatter',
    escort_stop = 'generic_radio_enter',
    escorted_loop = 'idle_a'
}

local function getEscortAnimConfig(key)
    local defaults = {
        escort_start = { dict = ANIM_DICTS.escort_start, clip = ANIM_CLIPS.escort_start, flag = 49, duration = 1000, blendIn = 0.5, blendOut = 0.3 },
        escort_walk = { dict = ANIM_DICTS.escort_walk, clip = ANIM_CLIPS.escort_walk, flag = 49, duration = -1, blendIn = 0.3, blendOut = 0.3 },
        escort_stop = { dict = ANIM_DICTS.escort_stop, clip = ANIM_CLIPS.escort_stop, flag = 49, duration = 1500, blendIn = 0.2, blendOut = 0.5 },
        escorted_loop = { dict = ANIM_DICTS.escorted_loop, clip = ANIM_CLIPS.escorted_loop, flag = 33, duration = -1, blendIn = 0.2, blendOut = 0.2 }
    }

    local cfg = Config.Animations and Config.Animations.Escort
    if not cfg then
        return defaults[key]
    end

    local map = {
        escort_start = cfg.Start,
        escort_walk = cfg.Walk,
        escort_stop = cfg.Stop,
        escorted_loop = cfg.EscortedLoop
    }

    local selected = map[key]
    if type(selected) ~= 'table' then
        return defaults[key]
    end

    local default = defaults[key]
    return {
        dict = selected.dict or default.dict,
        clip = selected.clip or default.clip,
        flag = selected.flag or default.flag,
        duration = selected.duration or default.duration,
        blendIn = selected.blendIn or default.blendIn,
        blendOut = selected.blendOut or default.blendOut
    }
end

local function getVehicleAnimConfig(action, role)
    local defaults = {
        escorter_putin = { dict = 'random@arrests', clip = 'generic_radio_enter', flag = 49, duration = 1200, blendIn = 0.2, blendOut = 0.2 },
        escorter_takeout = { dict = 'random@arrests', clip = 'generic_radio_chatter', flag = 49, duration = 1200, blendIn = 0.2, blendOut = 0.2 },
        target_putin = { dict = 'random@arrests@busted', clip = 'idle_a', flag = 33, duration = 1200, blendIn = 0.2, blendOut = 0.2 },
        target_takeout = { dict = 'random@arrests@busted', clip = 'idle_a', flag = 33, duration = 1000, blendIn = 0.2, blendOut = 0.2 }
    }

    local key = ('%s_%s'):format(role == 'target' and 'target' or 'escorter', action == 'takeout' and 'takeout' or 'putin')
    local cfg = Config.Animations and Config.Animations.Vehicle
    local selected = nil

    if cfg then
        local cfgMap = {
            escorter_putin = cfg.EscorterPutIn,
            escorter_takeout = cfg.EscorterTakeOut,
            target_putin = cfg.TargetPutIn,
            target_takeout = cfg.TargetTakeOut
        }
        selected = cfgMap[key]
    end

    local default = defaults[key]
    if type(selected) ~= 'table' then
        return default
    end

    return {
        dict = selected.dict or default.dict,
        clip = selected.clip or default.clip,
        flag = selected.flag or default.flag,
        duration = selected.duration or default.duration,
        blendIn = selected.blendIn or default.blendIn,
        blendOut = selected.blendOut or default.blendOut
    }
end

local function getVehicleActionDelay(action)
    local cfg = Config.Animations and Config.Animations.Vehicle
    if action == 'takeout' then
        return (cfg and cfg.ExitDelayMs) or 1000
    end

    return (cfg and cfg.EnterDelayMs) or 1200
end

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
    local cfg = getEscortAnimConfig('escort_start')
    animationDictionary = cfg.dict

    local success = playAnimation(
        actorPed,
        cfg.dict,
        cfg.clip,
        cfg.flag,
        cfg.blendIn,
        cfg.blendOut,
        cfg.duration
    )
    
    if success then
        animationActive = true
        escortWalkAnimPlaying = false
        Framework.Debug("Started escort animation: " .. cfg.dict .. " @ " .. cfg.clip)

        return true
    end
    
    return false
end

local function playEscortedAliveAnimation(ped)
    if not DoesEntityExist(ped) then
        return
    end

    local cfg = getEscortAnimConfig('escorted_loop')

    if loadAnimationDictionary(cfg.dict) then
        escortedAnimationDictionary = cfg.dict
        TaskPlayAnim(ped, cfg.dict, cfg.clip, 8.0, -8.0, cfg.duration, cfg.flag, 0, false, false, false)
    end
end

-- Play walking animation while escorting is active
local function playEscortWalkAnimation(ped)
    if not DoesEntityExist(ped) or not animationActive then
        return
    end

    local cfg = getEscortAnimConfig('escort_walk')

    if IsEntityPlayingAnim(ped, cfg.dict, cfg.clip, 3) then
        escortWalkAnimPlaying = true
        return
    end

    if animationDictionary ~= cfg.dict then
        if animationDictionary and HasAnimDictLoaded(animationDictionary) then
            RemoveAnimDict(animationDictionary)
        end
        if loadAnimationDictionary(cfg.dict) then
            animationDictionary = cfg.dict
        end
    end

    playAnimation(
        ped,
        cfg.dict,
        cfg.clip,
        cfg.flag,
        cfg.blendIn,
        cfg.blendOut,
        cfg.duration
    )

    escortWalkAnimPlaying = true
end

-- Play stop animation when escort ends
local function playEscortStopAnimation(ped)
    if not DoesEntityExist(ped) then
        return
    end
    
    if not animationActive or not animationDictionary then
        -- No active animation, just clear tasks
        clearAnimation(ped)
        escortWalkAnimPlaying = false
        return
    end
    local cfg = getEscortAnimConfig('escort_stop')

    local success = playAnimation(
        ped,
        cfg.dict,
        cfg.clip,
        cfg.flag,
        cfg.blendIn,
        cfg.blendOut,
        cfg.duration
    )
    
    if success then
        Framework.Debug("Playing stop animation: " .. cfg.dict .. " @ " .. cfg.clip)
        escortWalkAnimPlaying = false
        
        -- Wait for animation to complete, then clear
        CreateThread(function()
            Wait(cfg.duration > 0 and cfg.duration or 1200)
            
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
        escortWalkAnimPlaying = false
    end
end

-- =============================================================================
-- TARGET SELECTION
-- =============================================================================

local function getEscortTarget(allowDeadTargets)
    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    if closestPlayer == -1 or distance > Config.MaxEscortDistance then
        Framework.Debug('No nearby player in range')
        notify('No nearby player in range', 'error')
        return nil
    end
    local isDead = Framework.Client.IsPlayerDead(closestPlayer)
    if isDead and not allowDeadTargets then
        notify('Escort requires a living player target', 'error')
        return nil
    end

    return closestPlayer
end

local function isPedInVehicle(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    return IsPedInAnyVehicle(ped, false)
end


local function blockVehicleEntryWhileEscorting()
    if not isEscorting then
        return
    end

    DisableControlAction(0, 23, true) -- INPUT_ENTER
    DisableControlAction(0, 75, true) -- INPUT_VEH_EXIT (prevents shuffle/enter edge cases)

    if IsDisabledControlJustPressed(0, 23) then
        notify('You cannot enter a vehicle while escorting someone', 'error')
    end
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

local function requestStart(commandMode)
    local allowDeadTargets = commandMode == 'carry'
    if isEscorting or isBeingEscorted then
        notify('You are already in an escort state', 'error')
        return
    end

    if onCooldown() then
        return
    end

    if isPedInVehicle(PlayerPedId()) then
        notify('You cannot escort while inside a vehicle', 'error')
        return
    end

    local targetPlayer = getEscortTarget(allowDeadTargets)
    if not targetPlayer then
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if isPedInVehicle(targetPed) then
        notify('Target cannot be escorted while inside a vehicle', 'error')
        return
    end

    if not Config.AllowEscortAlive and not allowDeadTargets then
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

    if not isEscorting then
        notify('You are not escorting anyone', 'error')
        return
    end

    stopRequestPending = true
    TriggerServerEvent('escort:stopAction')

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

local function toggleEscort(commandMode)
    if isEscorting then
        requestStop(getKnownStopTargetServerId())
    elseif isBeingEscorted then
        notify('Only the escorter can stop escorting', 'error')
    else
        requestStart(commandMode)
    end
end

local function requestVehicleAction(action, targetServerId, vehicleNetId)
    if not Config.AllowVehicleEscort then
        notify('Vehicle escort actions are disabled', 'error')
        return
    end

    if onCooldown() then
        return
    end

    if not targetServerId then
        targetServerId = getNearestTargetServerId(false)
    end

    if not targetServerId then
        return
    end

    TriggerServerEvent('escort:vehicleAction', targetServerId, action, vehicleNetId)
    stampCooldown()
end

-- =============================================================================
-- COMMANDS AND KEYBINDS
-- =============================================================================

RegisterCommand('escort', function()
    toggleEscort('escort')
end, false)

RegisterCommand('carry', function()
    toggleEscort('carry')
end, false)

RegisterCommand('putinvehicle', function()
    requestVehicleAction('putin')
end, false)

RegisterCommand('takeoutvehicle', function()
    requestVehicleAction('takeout')
end, false)

RegisterCommand('escort:keybindToggle', function()
    toggleEscort()
end, false)

RegisterKeyMapping('escort:keybindToggle', 'Toggle Escort Player (alive target)', 'keyboard', Config.DefaultEscortKey or Config.DefaultKey or 'H')
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

                        if isEscorting then
                            requestStop(targetServerId)
                            return
                        elseif isBeingEscorted then
                            notify('Only the escorter can stop escorting', 'error')
                            return
                        end

                        if onCooldown() then
                            return
                        end

                        if isPedInVehicle(PlayerPedId()) then
                            notify('You cannot escort while inside a vehicle', 'error')
                            return
                        end

                        local targetDeadState = IsPedDeadOrDying(data.entity, true) or IsEntityDead(data.entity)
                        if targetDeadState then
                            notify('Escort requires a living player target', 'error')
                            return
                        end

                        if isPedInVehicle(data.entity) then
                            notify('Target cannot be escorted while inside a vehicle', 'error')
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
                        return Config.AllowVehicleEscort
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
                        return Config.AllowVehicleEscort
                    end
                }
            })

            exports.ox_target:addGlobalVehicle({
                {
                    name = 'escort_put_vehicle_selected',
                    icon = 'fa-solid fa-car-side',
                    label = 'Put Escorted In This Vehicle',
                    distance = 3.0,
                    onSelect = function(data)
                        if not isEscorting or not escortedPlayer then
                            notify('You must escort someone first', 'error')
                            return
                        end

                        local targetServerId = GetPlayerServerId(escortedPlayer)
                        if not targetServerId or targetServerId <= 0 then
                            notify('Escorted player is not available', 'error')
                            return
                        end

                        local vehicle = data.entity
                        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
                            notify('Invalid vehicle selected', 'error')
                            return
                        end

                        requestVehicleAction('putin', targetServerId, VehToNet(vehicle))
                    end,
                    canInteract = function(entity)
                        return Config.AllowVehicleEscort and isEscorting and escortedPlayer ~= nil and entity and entity ~= 0 and DoesEntityExist(entity)
                    end
                },
                {
                    name = 'escort_takeout_vehicle_selected',
                    icon = 'fa-solid fa-door-open',
                    label = 'Take Escorted Out Of This Vehicle',
                    distance = 3.0,
                    onSelect = function(data)
                        if not isEscorting or not escortedPlayer then
                            notify('You must escort someone first', 'error')
                            return
                        end

                        local targetServerId = GetPlayerServerId(escortedPlayer)
                        if not targetServerId or targetServerId <= 0 then
                            notify('Escorted player is not available', 'error')
                            return
                        end

                        requestVehicleAction('takeout', targetServerId, VehToNet(data.entity))
                    end,
                    canInteract = function(entity)
                        if not isEscorting or not escortedPlayer then
                            return false
                        end

                        if not entity or entity == 0 or not DoesEntityExist(entity) then
                            return false
                        end

                        local escortedPed = GetPlayerPed(escortedPlayer)
                        if not DoesEntityExist(escortedPed) then
                            return false
                        end

                        return GetVehiclePedIsIn(escortedPed, false) == entity
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
            Wait(250)

            local myPed = PlayerPedId()
            local ped = escortedPlayer and GetPlayerPed(escortedPlayer) or 0

            if not DoesEntityExist(myPed) or ped == 0 or not DoesEntityExist(ped) then
                if escortedPlayer then
                    TriggerServerEvent('escort:stopAction')
                end
                break
            end

            if IsPedInAnyVehicle(myPed, false) then
                notify('Escort stopped because you entered a vehicle', 'error')
                TriggerServerEvent('escort:stopAction')
                break
            end

            if animationActive then
                if not escortWalkAnimPlaying then
                    playEscortWalkAnimation(myPed)
                else
                    local walkCfg = getEscortAnimConfig('escort_walk')
                    if not IsEntityPlayingAnim(myPed, walkCfg.dict, walkCfg.clip, 3) then
                        escortWalkAnimPlaying = false
                    end
                end
            end
        end
    end)

    CreateThread(function()
        while isEscorting do
            Wait(0)
            blockVehicleEntryWhileEscorting()
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
        local nextAnimRefresh = 0

        while isBeingEscorted do
            Wait(100)

            local escorterPed = escortedBy and GetPlayerPed(escortedBy) or 0
            local me = PlayerPedId()

            if escorterPed == 0 or not DoesEntityExist(escorterPed) or not DoesEntityExist(me) then
                TriggerServerEvent('escort:stopAction')
                break
            end

            local escortedCfg = getEscortAnimConfig('escorted_loop')
            if not IsEntityAttachedToEntity(me, escorterPed) then
                AttachEntityToEntity(me, escorterPed, 11816, 0.35, 0.45, 0.0, 0.0, 0.0, 15.0, false, true, false, true, 2, true)
                playEscortedAliveAnimation(me)
                nextAnimRefresh = GetGameTimer() + 800
            elseif GetGameTimer() >= nextAnimRefresh and not IsEntityPlayingAnim(me, escortedCfg.dict, escortedCfg.clip, 3) then
                playEscortedAliveAnimation(me)
                nextAnimRefresh = GetGameTimer() + 800
            end
        end
    end)
end)

RegisterNetEvent('escort:vehicleAnimation', function(action)
    local myPed = PlayerPedId()
    if not DoesEntityExist(myPed) then
        return
    end

    local cfg = getVehicleAnimConfig(action, 'escorter')
    playAnimation(myPed, cfg.dict, cfg.clip, cfg.flag, cfg.blendIn, cfg.blendOut, cfg.duration)
end)

-- Event: Vehicle actions
RegisterNetEvent('escort:vehicle', function(action, vehicleNetId)
    local myPed = PlayerPedId()

    if animationActive then
        stopAnimation(myPed)
    end

    local targetAnimCfg = getVehicleAnimConfig(action, 'target')
    playAnimation(myPed, targetAnimCfg.dict, targetAnimCfg.clip, targetAnimCfg.flag, targetAnimCfg.blendIn, targetAnimCfg.blendOut, targetAnimCfg.duration)
    Wait(getVehicleActionDelay(action))

    if action == 'putin' then
        -- Stop the local attach loop immediately so we do not reattach while entering a vehicle
        isBeingEscorted = false
        escortedBy = nil

        local vehicle = 0
        if vehicleNetId then
            vehicle = NetToVeh(vehicleNetId)
        end

        if vehicle == 0 or not DoesEntityExist(vehicle) then
            local coords = GetEntityCoords(myPed)
            vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, Config.VehicleSearchRadius or 5.0, 0, 71)
        end

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
        -- Ensure attach loop is disabled while being removed from vehicle.
        isBeingEscorted = false
        escortedBy = nil

        local currentVehicle = GetVehiclePedIsIn(myPed, false)
        if currentVehicle == 0 then
            notify('Target is not in a vehicle', 'error')
            return
        end

        if vehicleNetId then
            local selectedVehicle = NetToVeh(vehicleNetId)
            if selectedVehicle ~= 0 and DoesEntityExist(selectedVehicle) and currentVehicle ~= selectedVehicle then
                notify('Target is not in the selected vehicle', 'error')
                return
            end
        end

        TaskLeaveVehicle(myPed, currentVehicle, 16)
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
            if not IsPedInAnyVehicle(targetPed, false) then
                ClearPedTasksImmediately(targetPed)
            end
        end
    end

    -- Handle target (being escorted) side
    if isBeingEscorted then
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            stopEscortedAnimation(myPed)
            if not IsPedInAnyVehicle(myPed, false) then
                ClearPedTasksImmediately(myPed)
            end
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
    escortWalkAnimPlaying = false
    
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
TriggerEvent('chat:addSuggestion', '/carry', 'Carry or release a nearby player (including downed/dead)')
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
