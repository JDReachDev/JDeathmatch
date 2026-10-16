# Publishing JDeathmatch on the Steam Workshop

This folder contains everything needed to build and upload the addon.
It is excluded from the `.gma` package (see `ignore` in `addon.json`).

| File | Purpose |
|---|---|
| `publish.bat` | Double-click to build and upload (wraps `publish.ps1`). |
| `publish.ps1` | Build + create/update script. |
| `icon.jpg` | Workshop thumbnail. **Must be a 512x512 JPEG.** |
| `workshop_description.txt` | Description in Steam BBCode, ready to paste on the Workshop page. |
| `workshop_id.txt` | Created after the first upload. Its presence makes the script *update* instead of *create*. |
| `out/` | Build output (`jdeathmatch.gma`), ignored by git. |

## Requirements

- Garry's Mod installed (the script finds it through your Steam libraries, or pass `-GModPath`).
- Steam running and logged in with the account that will own the Workshop item.
- You must have accepted the Steam Workshop legal agreement once
  (<https://steamcommunity.com/sharedfiles/workshoplegalagreement>), otherwise the item stays hidden.

## 1. Set the addon properties

Edit [`../addon.json`](../addon.json):

```json
{
	"title": "JDeathmatch",
	"type": "gamemode",
	"tags": [ "fun" ],
	"ignore": [ "*.md", "examples/*", "publish/*", ".git*", "addon.json" ]
}
```

| Key | Allowed values |
|---|---|
| `title` | Workshop title. |
| `type` | **one** of: `gamemode`, `map`, `weapon`, `vehicle`, `npc`, `entity`, `tool`, `effects`, `model`, `servercontent` |
| `tags` | **up to two** of: `fun`, `roleplay`, `scenic`, `movie`, `realism`, `cartoon`, `water`, `comic`, `build` |
| `ignore` | Wildcard patterns of files that must not end up in the `.gma`. |

Notes:

- `gmad` only packs whitelisted file types (`.lua`, `.txt`, `.png`, `.jpg`, `.wav`, `.mp3`, `.ogg`, models, materials, maps...).
  Anything else makes the build fail: add it to `ignore`.
- Title and tags are read from `addon.json` on **every** upload, so change them there, not on the website.

## 2. Set the icon

Replace `icon.jpg` with your own image: **JPEG, exactly 512x512 pixels**, ideally under 1 MB.
The script checks the format before uploading.

## 3. Upload

First upload (creates the Workshop item):

```bat
publish\publish.bat
```

The script builds `publish/out/jdeathmatch.gma`, uploads it with the icon and saves the new ID to
`workshop_id.txt`. **Commit that file**, so anyone running the script later updates the same item.

Later updates:

```bat
publish\publish.bat -Changes "Fixed MOAB timer, new weapons"
```

Other options:

```bat
publish\publish.bat -BuildOnly                       :: only build the .gma (to test locally)
publish\publish.bat -Changes "New icon" -UpdateIcon   :: also replace the icon
publish\publish.bat -GModPath "D:\SteamLibrary\steamapps\common\GarrysMod"
```

## 4. Finish on the Workshop page

`gmpublish` cannot set everything. After the first upload open the item page
(`https://steamcommunity.com/sharedfiles/filedetails/?id=<ID>`) and:

1. **Edit title & description** → paste the content of `workshop_description.txt`.
2. **Add/edit images & videos** → screenshots (any size, 16:9 looks best) and YouTube videos.
3. **Visibility** → new items are *Hidden*: set *Public* (or *Friends-only* for testing).
4. **Add/remove required items** → link the weapon packs your `jdmw.txt` uses (e.g. M9K), so
   subscribers get them automatically.

## 5. Use it on a dedicated server

Add the Workshop ID to the server so clients download the addon (and its sounds) automatically:

```bat
srcds.exe -game garrysmod +host_workshop_collection <COLLECTION_ID> +gamemode jdeathmatch +map dm_lockdown
```

or put `resource.AddWorkshop("<ID>")` in a server-side Lua file (`garrysmod/lua/autorun/server/`).

## Manual commands (without the script)

```bat
"<GMod>\bin\gmad.exe" create -folder "<repo>" -out "publish\out\jdeathmatch.gma"
"<GMod>\bin\gmpublish.exe" create -addon "publish\out\jdeathmatch.gma" -icon "publish\icon.jpg"
"<GMod>\bin\gmpublish.exe" update -addon "publish\out\jdeathmatch.gma" -id <ID> -changes "message"
```
