# TF2 Friendly

A SourceMod plugin for Team Fortress 2 that allows players to become "friendly" - unable to deal or receive damage from other players.

## Features

- Players can toggle friendly mode with a simple command
- Friendly players become translucent (optional)
- Automatic health/ammo regeneration for friendly players
- Spawn-only restriction option
- Cooldown system to prevent spam
- SOAP Tournament support
- Multi-language support

## Installation

1. Download the plugin files
2. Place `friendly.smx` in your `addons/sourcemod/plugins/` directory
3. Place `friendly.phrases.txt` in your `addons/sourcemod/translations/` directory
4. Restart your server or use `sm plugins load friendly`

## Commands

| Command | Description | Access |
|---------|-------------|--------|
| `sm_friendly` | Toggle friendly mode on/off | All players |

## Configuration Variables

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_friendly_enable` | `1` | Enable/disable the plugin |
| `sm_friendly_cooldown` | `3` | Command cooldown in seconds (0 = no cooldown) |
| `sm_friendly_translucid` | `1` | Make friendly players translucent |
| `sm_friendly_jump` | `1` | Allow friendly players to jump |
| `sm_friendly_regen` | `1` | Enable health/ammo regeneration for friendly players |
| `sm_friendly_onlyspawn` | `0` | Restrict friendly command to spawn areas only |
| `sm_friendly_advertise` | `1` | Show info message when attacking friendly players |

## Usage

1. Players type `!friendly` or `/friendly` in chat
2. They become immune to damage and cannot deal damage
3. Friendly players appear translucent (if enabled)
4. Type the command again to disable friendly mode
5. Friendly mode is automatically disabled on death/respawn

## Notes

- Friendly players cannot damage others and cannot be damaged
- The plugin automatically handles damage from/to non-player entities (sentries, fall damage, etc.)
- Configuration file is automatically generated in `cfg/sourcemod/`
- Supports SOAP Tournament mode (friendly disabled during matches)
