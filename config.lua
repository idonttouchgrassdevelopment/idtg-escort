Config = {}

Config.DefaultKey = 'H' -- Default keybind (can be changed by player in settings)
Config.MaxEscortDistance = 2.5 -- Maximum distance to start escort
Config.UseTarget = true -- Set to true if you want to use ox_target
Config.Debug = true -- Set to false to disable debug prints
Config.EscortCooldown = 5000 -- Cooldown between escort actions in milliseconds (5000 = 5 seconds)

-- Carry and Escort Options
Config.AllowCarryDead = true -- Allow carrying dead players
Config.AllowEscortAlive = true -- Allow escorting alive players
Config.CarryOnShoulder = true -- Carry dead on shoulder (true) or drag (false)
Config.RagdollDuration = 60000 -- Duration for ragdoll (in milliseconds)

-- Framework Options: 'qbox', 'qbcore', 'esx', 'standalone'
Config.Framework = 'auto' -- 'auto' will detect automatically
