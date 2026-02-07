# IDTG Escort

A multi-framework FiveM escort script supporting escort/carry, force unescort, and vehicle placement actions.

## Features
- Multi-framework support (QBox, QBCore, ESX, Standalone)
- Auto framework detection
- Escort alive players and carry dead players
- Unified stop flow (`/unescort`) that works even if escort started via command/keybind/target
- Put escorted/carry target in nearest vehicle and take them out
- Built-in notifications (framework-aware + chat fallback)
- Optional `ox_target` integration

## Commands
- `/escort` - Start/stop escort for alive targets
- `/carry` - Start/stop carry for dead targets
- `/unescort` - Force stop escort/carry (escorter or target can use)
- `/putinvehicle` - Put escorted target in nearest vehicle
- `/takeoutvehicle` - Remove escorted target from vehicle
- `/escortdebug` - Print local debug state

## Default Keybinds
- Escort: `H`
- Carry: `G`
- Unescort: `U`
- Put in vehicle: `J`
- Take out vehicle: `K`

## Config Highlights (`config.lua`)
- `Config.ActionCooldown`
- `Config.MaxEscortDistance`
- `Config.VehicleSearchRadius`
- `Config.NotifyDuration`
- `Config.AllowCarryDead`
- `Config.AllowEscortAlive`
- `Config.CarryOnShoulder`
- `Config.Framework` (`auto`, `qbox`, `qbcore`, `esx`, `standalone`)

## Notes
- Vehicle actions require the two players to be in an active escort/carry pair.
- Notifications use framework-native APIs when available and fallback to chat messages.
- If `ox_target` is enabled, player target options include escort/carry, unescort, put in vehicle, and take out vehicle.
