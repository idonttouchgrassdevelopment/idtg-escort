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
