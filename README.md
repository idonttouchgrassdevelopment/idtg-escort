# IDTG Escort

A multi-framework FiveM escort script focused on player escorting (vehicle placement can be disabled).

## Features
- Multi-framework support (QBox, QBCore, ESX, Standalone)
- Auto framework detection
- Escort system focused on living players only (carry removed)
- Escorter-controlled stop flow via `/escort` toggle
- Escorts are blocked while either player is entering or inside a vehicle
- Optional escorted target vehicle in/out actions (disabled by default)
- Configurable escort + vehicle in/out animations with action delays
- `ox_target` vehicle third-eye option to put an escorted target into a selected car
- Built-in notifications (framework-aware + chat fallback)
- Optional `ox_target` integration (players + vehicles)

## Commands
- `/escort` - Start/stop escort for alive targets
- `/putinvehicle` - Put escorted target in nearest vehicle
- `/takeoutvehicle` - Remove escorted target from vehicle
- `/escortdebug` - Print local debug state

## Default Keybinds
- Escort: `H`
- Put in vehicle: `J`
- Take out vehicle: `K`

## Config Highlights (`config.lua`)
- `Config.ActionCooldown`
- `Config.MaxEscortDistance`
- `Config.VehicleSearchRadius`
- `Config.NotifyDuration`
- `Config.AllowEscortAlive`
- `Config.AllowVehicleEscort`
- `Config.Framework` (`auto`, `qbox`, `qbcore`, `esx`, `standalone`)
- `Config.Animations` (escort animation clips, vehicle put in/out clips, enter/exit delays)

## Notes
- Vehicle actions require the two players to be in an active escort pair and `Config.AllowVehicleEscort = true`.
- Notifications use framework-native APIs when available and fallback to chat messages.
- If `ox_target` is enabled, player target options include escort, put in vehicle, and take out vehicle.
- If `ox_target` is enabled, vehicle target options include putting your currently escorted target into the specific vehicle you third-eye.
