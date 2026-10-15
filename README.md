# JDeathmatch (Garry's Mod)

`JDeathmatch` e una modalita Deathmatch custom per Garry's Mod con:
- selezione loadout armi
- sistema MOAB su killstreak
- round con condizione di vittoria
- votazione mappa a fine match (solo mappe `dm_` e `ttt_`)

## Requisiti

- Garry's Mod aggiornato
- Server con supporto gamemode custom
- File armi in `data/jdmw.txt`

## Struttura del repository

Il repository e un addon standard di Garry's Mod:

```
addon.json                      # metadati per pubblicare sul Workshop (gmad)
gamemodes/jdeathmatch/
    jdeathmatch.txt             # definizione gamemode + impostazioni menu
    icon24.png, logo.png
    gamemode/                   # codice Lua (cl_*, sv_*, sh_*)
sound/                          # suoni MOAB e vittoria
examples/jdmw.txt               # esempio di config armi (non incluso nel Workshop)
```

## Installazione

1. Copia l'intera cartella del repository in:
   - `garrysmod/addons/jdeathmatch/`
   (in alternativa copia `gamemodes/` e `sound/` dentro `garrysmod/`)
2. I suoni in `sound/` vengono inviati ai client automaticamente (`resource.AddFile`);
   su server dedicati serve un FastDL o il Workshop.
3. Avvia la mappa con la modalita:
   - `gamemode jdeathmatch`
   - oppure selezionala dal menu delle modalita.

Per pubblicare sul Workshop: `gmad create -folder <repo> -out jdeathmatch.gma`.

## Configurazione (ConVar)

Le principali ConVar disponibili:

- `jdm_playerhealth` (default: `100`)
- `jdm_playerwalkspeed` (default: `100`)
- `jdm_playerrunspeed` (default: `100`)
- `jdm_gravity` (default: `100`)
- `jdm_maxkills` (default: `30`)
- `jdm_moabkills` (default: `25`)
- `jdm_moabtimer` (default: `30`)
- `jdm_flashlight` (default: `1`)
- `jdm_farspawn` (default: `0`)

Esempio configurazione rapida server:

```cfg
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

## Sistema armi (`data/jdmw.txt`)

La modalita legge la lista armi da:
- `garrysmod/data/jdmw.txt`

Se il file non esiste (o e invalido), `JDeathmatch` ne genera automaticamente uno base al primo avvio.

Per usare un file armi personalizzato:
- crea o sostituisci `garrysmod/data/jdmw.txt` prima di avviare il server
- se stai preparando l'addon in locale, trovi un esempio completo in `examples/jdmw.txt` (copialo in `data/`), ma il runtime usa solo `data/jdmw.txt`
- dopo una modifica a caldo, usa `jdm_reloadWeaponsConfig` da admin/console server

Formato JSON atteso (esempio):

```json
[
  { "id": "weapon_ar2", "name": "AR2", "slot": 1, "ammo": 120, "dmgmul": 1.0 },
  { "id": "weapon_pistol", "name": "Pistol", "slot": 2, "ammo": 60, "dmgmul": 1.0 },
  { "id": "weapon_frag", "name": "Grenade", "slot": 3, "ammo": 1, "dmgmul": 1.0 },
  { "id": "weapon_stunstick", "name": "Melee", "slot": 4, "ammo": 0, "dmgmul": 1.0 },
  { "id": "weapon_rpg", "name": "MOAB RPG", "slot": 666, "ammo": 3, "dmgmul": 1.0 }
]
```

Note:
- slot validi normali: `1`, `2`, `3`, `4`
- slot MOAB: `666`
- `id` deve essere un classname arma valido

## Gameplay

- Al primo ingresso il player e in spettatore finche non salva il loadout.
- Il menu armi si apre con `Q`.
- Raggiunta la soglia `jdm_moabkills`, il player riceve un'arma MOAB casuale per `jdm_moabtimer` secondi.
- Raggiunta la soglia `jdm_maxkills`, il round termina, i player vengono freezati e parte il voto mappa.
- Il map vote considera solo mappe con prefisso `dm_` o `ttt_`.

## Comandi utili

- Ricaricare configurazione armi:
  - `jdm_reloadWeaponsConfig`
  - solo admin in-game oppure console server

## Troubleshooting

- **Le armi non compaiono nel menu**
  - Controlla che `garrysmod/data/jdmw.txt` esista e sia JSON valido.
- **Il suono MOAB non si sente**
  - Verifica `sound/jdm_moabSound.wav`; in assenza usa fallback automatico.
- **Nessuna mappa in vote**
  - Assicurati di avere mappe `dm_*.bsp` o `ttt_*.bsp` installate.

## Note compatibilita

- Pensato per sessioni deathmatch pure.
- Alcuni addon che modificano spawn, loadout o `PlayerSpawn` potrebbero interferire.

## Crediti

- Autore: `JDReach`
- Modalita: `JDeathmatch`

