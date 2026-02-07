# FiveM Escort Script

A multi-framework escort script for FiveM that allows players to escort other players (dead or alive).

## Features
- ✅ Multi-Framework Support (QBox, QBCore, ESX, Standalone)
- ✅ Auto Framework Detection
- ✅ **Dead and Alive Player Support**
- ✅ **Intelligent Carry/Escort Mechanics** (ragdoll for dead, attachment for alive)
- ✅ Customizable escort/carry keybinds through FiveM settings
- ✅ `/escort` and `/carry` command support
- ✅ Optional ox_target integration
- ✅ Distance checking
- ✅ Bridge system for easy framework handling
- ✅ Debug mode for troubleshooting
- ✅ Configurable allow/deny for dead and alive carrying

## Supported Frameworks
- QBox (qbx_core)
- QBCore (qb-core)
- ESX (es_extended)
- Standalone (no framework)

## Installation

1. Download and extract the `escort-script` folder to your FiveM server's `resources` folder
2. Add `ensure escort-script` to your `server.cfg`
3. Restart your server

## File Structure
```
escort-script/
├── fxmanifest.lua
├── config.lua
├── client.lua
├── server.lua
├── bridge/
│   ├── shared.lua
│   ├── client.lua
│   └── server.lua
└── README.md
```

## Configuration

Open `config.lua` to customize:

```lua
Config.DefaultEscortKey = 'H' -- Default escort keybind
Config.DefaultCarryKey = 'G' -- Default carry keybind
Config.MaxEscortDistance = 2.5 -- Maximum distance to escort
Config.UseTarget = false -- Enable ox_target integration
Config.Debug = true -- Enable debug prints
Config.ActionCooldown = 5000 -- Cooldown for escort/carry start/stop in milliseconds
Config.Framework = 'auto' -- Auto-detect or specify: 'qbox', 'qbcore', 'esx', 'standalone'

-- Carry and Escort Options
Config.AllowCarryDead = true -- Allow carrying dead players (will ragdoll them)
Config.AllowEscortAlive = true -- Allow escorting alive players
Config.CarryOnShoulder = true -- Carry dead on shoulder (true) or drag (false)
Config.RagdollDuration = 60000 -- Duration for ragdoll in milliseconds (60000 = 60 seconds)
```

### New v2.1.0 Features:
- **Dead Player Carrying**: Dead players are automatically ragdolled and attached to your shoulder
- **Alive Player Escorting**: Alive players are attached and follow your movement
- **Toggle Permissions**: Control whether dead/alive players can be escorted via config
- **Improved Cleanup**: Proper ragdoll cleanup when escort ends

## Usage

### How It Works:
The script automatically detects whether a player is dead or alive and adjusts behavior accordingly:

**Dead Players (Carrying):**
- Player is ragdolled when escort starts
- Player is attached to your shoulder
- Useful for reviving players (carry them to a medic)
- Ragdoll automatically stops when escort ends

**Alive Players (Escorting):**
- Player is attached to you and follows your movement
- Player remains in normal state
- Useful for escorting suspects or guiding players

### For Players:

**Using Keybind:**
1. Stand near another player (within 2.5 units by default)
2. Press your escort keybind (default: H) to start/stop escorting alive players
3. Press your carry keybind (default: G) to start/stop carrying dead players

**Changing Keybind:**
1. Press ESC
2. Go to Settings → Key Bindings → FiveM
3. Find "Toggle Escort Player"
4. Click and press your desired key

**Using Command:**
- Type `/escort` for alive escort
- Type `/carry` for dead carry

**Using Target System (if enabled):**
- Look at a player and select "Escort/Release" from the target menu

## Debug Commands

### `/escortdebug`
Displays current escort status and nearby player information:
- Framework detected
- Current escort state
- Closest player and distance
- Server IDs

## Troubleshooting

1. **Script not working:**
   - Check F8 console for errors
   - Ensure you're within the max escort distance
   - Run `/escortdebug` to check status

2. **Framework not detected:**
   - Verify your framework resource is started
   - Check server console for framework detection message
   - Manually set `Config.Framework` in config.lua

3. **Players not attaching:**
   - Check both client and server console for debug messages
   - Ensure both players are online and in-game
   - Verify server IDs are being passed correctly

## Bridge System

The bridge system automatically handles framework-specific functions:
- Player data retrieval
- Notifications (optional)
- Player validation
- Name retrieval
- Logging

You can extend the bridge by modifying files in the `bridge/` folder.

## License

Free to use and modify for your FiveM server.

## Support

For issues or questions:
1. Enable debug mode in config
2. Run `/escortdebug` command
3. Check F8 console and server console for error messages
