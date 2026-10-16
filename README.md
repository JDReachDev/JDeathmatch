# JDeathmatch (Garry's Mod)

`JDeathmatch` is a customizable free-for-all deathmatch gamemode for Garry's Mod featuring:

- a loadout menu with weapons defined in a JSON file
- a MOAB killstreak reward (a random super weapon for a limited time)
- a match win condition with slow-motion ending
- an end-of-match map vote (`dm_` and `ttt_` maps)
- a custom scoreboard

## Repository layout

The repository is a standard Garry's Mod addon:

```
addon.json                      # Workshop metadata (used by gmad)
gamemodes/jdeathmatch/
    jdeathmatch.txt             # gamemode definition + main menu settings
    icon24.png, logo.png
    gamemode/                   # Lua code (cl_* client, sv_* server, sh_* shared)
sound/                          # MOAB and victory sounds
examples/jdmw.txt               # example weapons config (not packed into the Workshop addon)
```

## Installation

1. Copy the whole repository folder into `garrysmod/addons/jdeathmatch/`
   (or copy `gamemodes/` and `sound/` directly into `garrysmod/`).
2. Start a map with the gamemode:
   - from the console: `gamemode jdeathmatch` then `map dm_lockdown`
   - or pick **JDeathmatch** from the gamemode list in the main menu.
3. The custom sounds are sent to clients automatically (`resource.AddFile`).
   On a dedicated server you need FastDL or the Workshop version for clients to download them.

To publish on the Steam Workshop (icon, title, tags, description, updates) see [`publish/README.md`](publish/README.md). To only build the package:

```bash
gmad create -folder "path/to/repo" -out jdeathmatch.gma
```

## Server settings (ConVars)

All settings are ConVars. They are replicated to clients and saved between restarts.
You can set them in three ways:

- in the **Start New Game** menu (gamemode settings panel)
- in `garrysmod/cfg/server.cfg` on a dedicated server
- live from the server console / RCON (most take effect on the next spawn)

| ConVar | Default | Description |
|---|---|---|
| `jdm_playerhealth` | `100` | Max and starting health of every player. |
| `jdm_playerwalkspeed` | `100` | Walk speed in percent (`100` = 265 units/s). |
| `jdm_playerrunspeed` | `100` | Sprint speed in percent (`100` = 410 units/s). |
| `jdm_gravity` | `100` | Player gravity in percent. Lower values = higher jumps. |
| `jdm_maxkills` | `30` | Kills needed to win the match. |
| `jdm_moabkills` | `25` | Kills needed to get the MOAB reward (once per player per map). |
| `jdm_moabtimer` | `30` | How many seconds the MOAB weapon is kept before it is removed. |
| `jdm_flashlight` | `1` | `1` = players can use the flashlight, `0` = disabled. |
| `jdm_farspawn` | `0` | `1` = spawn players at the spawn point farthest from enemies (beta). |

Example `server.cfg`:

```cfg
gamemode jdeathmatch

jdm_playerhealth 100
jdm_playerwalkspeed 100
jdm_playerrunspeed 100
jdm_gravity 100
jdm_maxkills 30
jdm_moabkills 25
jdm_moabtimer 30
jdm_flashlight 1
jdm_farspawn 0
```

> Keep `jdm_moabkills` lower than `jdm_maxkills`, otherwise nobody will ever get the MOAB.

## Weapons configuration (`data/jdmw.txt`)

The weapon list is read from:

```
garrysmod/data/jdmw.txt
```

If the file does not exist, a basic one with HL2 weapons is generated on first start.
A full example using M9K, Serious Sam 2, Quake 2 and Sanctum 2 weapons is in [`examples/jdmw.txt`](examples/jdmw.txt).

> **Warning:** if the file contains invalid JSON (or an empty list), it is **overwritten** with the default list.
> Keep a backup of your config and validate it (e.g. with any online JSON validator) before reloading.

### Format

The file is a JSON array. Each entry is one weapon:

```json
[
  { "id": "weapon_ar2",       "name": "AR2",      "slot": 1,   "ammo": 120, "dmgmul": 1.0 },
  { "id": "weapon_smg1",      "name": "SMG",      "slot": 1,   "ammo": 90,  "dmgmul": 0.8 },
  { "id": "weapon_pistol",    "name": "Pistol",   "slot": 2,   "ammo": 60,  "dmgmul": 1.0 },
  { "id": "weapon_frag",      "name": "Grenade",  "slot": 3,   "ammo": 1,   "dmgmul": 1.0 },
  { "id": "weapon_stunstick", "name": "Melee",    "slot": 4,   "ammo": 0,   "dmgmul": 1.0 },
  { "id": "weapon_rpg",       "name": "MOAB RPG", "slot": 666, "ammo": 3,   "dmgmul": 1.0 }
]
```

| Field | Required | Description |
|---|---|---|
| `id` | yes | Weapon class name (e.g. `weapon_ar2`, `m9k_deagle`). Find it in the spawn menu: right click a weapon → *Copy to clipboard*. |
| `name` | yes | Name shown in the loadout menu and in the MOAB announcement. |
| `slot` | yes | Where the weapon appears (see below). |
| `ammo` | no | Total ammo given on spawn. The clip is filled first, the rest goes to the reserve. `0` = keep the weapon's default ammo. |
| `dmgmul` | no | Damage multiplier for that weapon (`1` = normal, `0.5` = half, `2` = double). Applied to every hit. |

### Slots

| Slot | Menu label | Notes |
|---|---|---|
| `1` | Primary | Main weapons. |
| `2` | Secondary | Pistols / sidearms. |
| `3` | Specials | Grenades, explosives, gadgets. Slot 3 weapons are also selectable in slot 4, so players can pick two specials. |
| `4` | Specials | Weapons that should appear only in the second special slot. |
| `666` | — | **MOAB weapons.** Not selectable. One is given at random when a player reaches `jdm_moabkills`. |

If a player saves an empty loadout, they receive the first weapon of the list.

### Using weapons from other addons

Any SWEP works, as long as the weapon addon is installed **on the server and on every client**
(on a dedicated server, put the weapon packs in a Workshop collection for your players).

### Reloading the config without restarting

After editing `data/jdmw.txt`, run from the server console (or in-game as admin):

```
jdm_reloadWeaponsConfig
```

The new list is sent to all connected players; new loadouts apply on their next spawn.

## Gameplay

- On first join the player is a spectator until they save a loadout.
- Press `Q` to open/close the loadout menu. Changes apply on the next spawn.
- Hold `Tab` for the scoreboard (kills, deaths, K/D, MOAB status, progress to win).
- At `jdm_moabkills` kills the player becomes the **Annihilator** and gets a random MOAB weapon for `jdm_moabtimer` seconds.
- At `jdm_maxkills` kills the match ends: slow motion, everyone spectates the winner, then a map vote opens.
- The map vote lists every installed map starting with `dm_` or `ttt_`. If nobody votes, a random one is chosen.

## Commands

| Command | Who | Description |
|---|---|---|
| `jdm_reloadWeaponsConfig` | admin / server console | Reload `data/jdmw.txt` and push it to clients. |

## Troubleshooting

- **The loadout menu is empty / weapons are missing**
  - Check that `garrysmod/data/jdmw.txt` exists and is valid JSON.
  - Check that every `id` is an installed weapon class and that `slot` is a number.
- **I get an ERROR model or nothing when spawning**
  - The weapon addon is not installed on the server or on the client.
- **The MOAB / victory sound does not play**
  - Clients must download `sound/jdm_moabsound.wav` and `sound/jdm_winsound.wav` (FastDL or Workshop). A fallback HL2 sound is used if missing.
- **No maps in the vote**
  - Install maps whose name starts with `dm_` or `ttt_`.

## Compatibility

- Designed for pure free-for-all deathmatch.
- Other addons that change spawning, loadouts or `PlayerSpawn` may interfere.

## Credits

- Author: `JDReach`
- Gamemode: `JDeathmatch`
