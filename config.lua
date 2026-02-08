Config = {}

Config.DefaultEscortKey = 'H' -- Default escort keybind (can be changed by player in settings)
Config.DefaultUnescortKey = 'U' -- Stop escort even if started by command/keybind/target
Config.DefaultPutInVehicleKey = 'J' -- Put escorted target in vehicle
Config.DefaultTakeOutVehicleKey = 'K' -- Take escorted target out of vehicle
Config.DefaultKey = Config.DefaultEscortKey -- Backwards compatibility for older configs
Config.MaxEscortDistance = 2.5 -- Maximum distance to start escort
Config.VehicleSearchRadius = 5.0 -- Range used for finding closest vehicle when putting target in
Config.UseTarget = true -- Set to true if you want to use ox_target
Config.Debug = true -- Set to false to disable debug prints
Config.ActionCooldown = 5000 -- Cooldown between escort actions in milliseconds
Config.EscortCooldown = Config.ActionCooldown -- Backwards compatibility for older configs
Config.NotifyDuration = 5000 -- Notification duration in ms

-- Escort Options
Config.AllowEscortAlive = true -- Allow escorting alive players

-- Framework Options: 'qbox', 'qbcore', 'esx', 'standalone'
Config.Framework = 'auto' -- 'auto' will detect automatically

-- Animation Options
Config.Animations = {
    Escort = {
        Start = { dict = 'amb@world_human_drinking@coffee@male@base', clip = 'base', flag = 49, duration = 1000, blendIn = 0.5, blendOut = 0.3 },
        Walk = { dict = 'amb@world_human_drinking@coffee@male@base', clip = 'base', flag = 49, duration = -1, blendIn = 0.3, blendOut = 0.3 },
        Stop = { dict = 'amb@world_human_drinking@coffee@male@base', clip = 'base', flag = 49, duration = 1500, blendIn = 0.2, blendOut = 0.5 },
        EscortedLoop = { dict = 'mp_arresting', clip = 'idle', flag = 33, duration = -1, blendIn = 0.2, blendOut = 0.2 }
    },
    Vehicle = {
        EscorterPutIn = { dict = 'mini@repair', clip = 'base', flag = 49, duration = 1200, blendIn = 0.2, blendOut = 0.2 },
        EscorterTakeOut = { dict = 'mini@repair', clip = 'base', flag = 49, duration = 1200, blendIn = 0.2, blendOut = 0.2 },
        TargetPutIn = { dict = 'mp_arresting', clip = 'base', flag = 33, duration = 1200, blendIn = 0.2, blendOut = 0.2 },
        TargetTakeOut = { dict = 'mp_arresting', clip = 'base', flag = 33, duration = 1000, blendIn = 0.2, blendOut = 0.2 },
        EnterDelayMs = 1200,
        ExitDelayMs = 1000
    }
}
