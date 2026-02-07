# IDTG Escort

A multi-framework FiveM escort script with force unescort and vehicle placement actions.

## Features
- Multi-framework support (QBox, QBCore, ESX, Standalone)
- Auto framework detection
- Escort system focused on living players only (carry removed)
- Unified stop flow (`/unescort`) for escorter or escorted target
- Put escorted target in nearest vehicle and take them out
- Built-in notifications (framework-aware + chat fallback)
- Optional `ox_target` integration

## Commands
- `/escort` - Start/stop escort for alive targets
- `/unescort` - Force stop escort (escorter or target can use)
- `/putinvehicle` - Put escorted target in nearest vehicle
- `/takeoutvehicle` - Remove escorted target from vehicle
- `/escortdebug` - Print local debug state

## Default Keybinds
- Escort: `H`
- Unescort: `U`
- Put in vehicle: `J`
- Take out vehicle: `K`

## Config Highlights (`config.lua`)
- `Config.ActionCooldown`
- `Config.MaxEscortDistance`
- `Config.VehicleSearchRadius`
- `Config.NotifyDuration`
- `Config.AllowEscortAlive`
- `Config.Framework` (`auto`, `qbox`, `qbcore`, `esx`, `standalone`)

## Notes
- Vehicle actions require the two players to be in an active escort pair.
- Notifications use framework-native APIs when available and fallback to chat messages.
- If `ox_target` is enabled, player target options include escort, unescort, put in vehicle, and take out vehicle.
