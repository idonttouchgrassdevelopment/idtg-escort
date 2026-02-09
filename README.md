# IDTG Escort

A multi-framework FiveM escort script focused on player escorting (vehicle placement can be disabled).

## Features
- Multi-framework support (QBox, QBCore, ESX, Standalone)
- Auto framework detection
- Escort system with living-player escort plus `/carry` support for downed/dead targets
- Escorter-controlled stop flow via `/escort` toggle
- Escorts are blocked while either player is entering or inside a vehicle
- Optional escorted target vehicle in/out actions (disabled by default)
- Direct vehicle takeout action (no escort state required)
- Trunk system: enter/exit trunk yourself, plus put nearby players in/out of a selected unlocked trunk
- Configurable escort, carry (fireman carry-style), and vehicle in/out animations with action delays
- `ox_target` vehicle third-eye option to put an escorted target into a selected car
- Built-in notifications (framework-aware + chat fallback)
- Optional `ox_target` integration (players + vehicles)

## Commands
- `/escort` - Start/stop escort for alive targets
- `/carry` - Start/stop carry (allows downed/dead targets)
- `/putinvehicle` - Put escorted target in nearest vehicle
- `/takeoutvehicle` - Remove escorted target from vehicle
- `/takeoutvehicledirect` - Remove nearby target from vehicle without escorting first
- `/toggletrunk` - Enter or exit the nearest unlocked trunk
- `/putintrunk` - Put nearby target in a selected unlocked trunk
- `/takeouttrunk` - Remove nearby target from a selected unlocked trunk
- `/escortdebug` - Print local debug state

## Default Keybinds
- Escort: `H`
- Put in vehicle: `J`
- Take out vehicle: `K`
- Direct take out (no escort): `L`
- Enter/exit trunk: `;`
- Put in trunk: `N`
- Take out trunk: `M`

## Config Highlights (`config.lua`)
- `Config.ActionCooldown`
- `Config.MaxEscortDistance`
- `Config.VehicleSearchRadius`
- `Config.NotifyDuration`
- `Config.AllowEscortAlive`
- `Config.AllowVehicleEscort`
- `Config.AllowDirectVehicleTakeout`
- `Config.AllowTrunkActions`
- `Config.Framework` (`auto`, `qbox`, `qbcore`, `esx`, `standalone`)
- `Config.Animations` (escort clips, carry clips, vehicle put in/out clips, enter/exit delays)

## Notes
- Escorted vehicle actions require an active escort pair and `Config.AllowVehicleEscort = true`.
- Direct takeout does not require escorting, but still requires target/vehicle proximity and can be disabled with `Config.AllowDirectVehicleTakeout`.
- Trunk actions require the selected vehicle to be unlocked and `Config.AllowTrunkActions = true`.
- Notifications use framework-native APIs when available and fallback to chat messages.
- If `ox_target` is enabled, player target options include escort, put in vehicle, and take out vehicle.
- If `ox_target` is enabled, vehicle target options include putting your currently escorted target into the specific vehicle you third-eye.

## Quick Validation
- `python3 scripts/check_lua_syntax.py` - Best-effort Lua syntax check. Uses `luac`, `lua`, `luajit`, or Python `luaparser` when available; otherwise reports a warning and skips.
