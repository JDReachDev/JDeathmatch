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

## Installazione

1. Copia la cartella della modalita sul server in:
   - `garrysmod/gamemodes/jdeathmatch/`
2. Verifica che il file `jdeathmatch.txt` sia nella root della gamemode.
3. Assicurati che i file Lua siano in `garrysmod/gamemodes/jdeathmatch/gamemode/`.
4. (Opzionale) Inserisci il suono MOAB in:
   - `garrysmod/sound/jdm_moabSound.wav`
5. Avvia la mappa con la modalita:
   - `gamemode jdeathmatch`
   - oppure selezionala dal menu delle modalita.

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
- se stai preparando l'addon in locale, puoi tenere una copia in `backup/jdmw.txt` ma il runtime usa solo `data/jdmw.txt`
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

