# Publishing JDeathmatch on the Steam Workshop

This folder contains everything needed to build and upload the addon.
It is excluded from the `.gma` package (see `ignore` in `addon.json`).

| File | Purpose |
|---|---|
| `publish.bat` | Double-click to build, upload and push the description (wraps `publish.ps1`). |
| `publish.ps1` | Build + create/update + description script. |
| `preview_description.bat` | Double-click to preview the description as it will look on the Workshop. |
| `icon.jpg` | Workshop thumbnail. **Must be a 512x512 JPEG.** |
| `workshop_description.txt` | Workshop description in Steam BBCode. **Edit it here, not on the website**: every upload overwrites the page. |
| `workshop_id.txt` | Created after the first upload. Its presence makes the script *update* instead of *create*. |
| `collection_id.txt`, `collection_title.txt`, `collection_description.txt` | The example collection ("Pure Chaos") linked from the addon page. |
| `description.ps1` | Shared helpers (placeholders, length check) used by both scripts. |
| `steamcmd/` | Valve's SteamCMD, downloaded automatically on first use. Ignored by git. |
| `steam_user.txt` | Your Steam login name, saved on first use. Ignored by git. |
| `out/` | Build output (`jdeathmatch.gma`, description preview), ignored by git. |

## Why two tools

- `gmpublish` (ships with Garry's Mod) uploads the `.gma` and the icon, using the Steam client you are logged in to.
  It cannot set the description or the visibility.
- `SteamCMD` (official Valve tool) updates title, description and visibility of the item.
  On the first run it asks for your Steam **password and Steam Guard code** (typed by you, in the SteamCMD window);
  after that the login is cached and it runs without prompts.

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

Every upload also pushes the title (from `addon.json`) and the description (from `workshop_description.txt`).

Other options:

```bat
publish\publish.bat -BuildOnly                       :: only build the .gma (to test locally)
publish\publish.bat -Changes "New icon" -UpdateIcon   :: also replace the icon
publish\publish.bat -DescriptionOnly                  :: only push title + description, no upload
publish\publish.bat -DescriptionOnly -Visibility public   :: ...and make the item public
publish\publish.bat -SkipDescription -Changes "..."   :: upload without touching the description
publish\publish.bat -GModPath "D:\SteamLibrary\steamapps\common\GarrysMod"
```

`-Visibility` accepts `public`, `friends`, `private`, `unlisted`. New items start hidden.

## 4. Edit the description

1. Edit `workshop_description.txt` ([Steam BBCode](https://steamcommunity.com/comment/Recommendation/formattinghelp):
   `[h1]`, `[h2]`, `[b]`, `[i]`, `[list]`/`[*]`, `[table]`, `[url=...]`, `[code]`, `[img]`...).
2. Double-click `preview_description.bat` to see it with a Workshop-like look and check the length (max 8000 characters).
3. Run `publish.bat -DescriptionOnly` to push it without uploading a new version.

### Example collection

The addon page links to an example collection with the weapon packs and the config I play with.
Its title and description live in `collection_title.txt` and `collection_description.txt`; the
`{{JDMW_CONFIG}}` placeholder is replaced with [`../examples/jdmw.txt`](../examples/jdmw.txt) as compact JSON
(one weapon per line, to stay under 8000 characters). So to share a new config, update `examples/jdmw.txt` and:

```bat
publish\preview_description.bat -Collection   :: check it
publish\publish.bat -Collection               :: push title + description to the collection
```

Adding or removing the weapon packs in the collection is done on the collection page.

## 5. Finish on the Workshop page

A few things can only be done on the item page (`https://steamcommunity.com/sharedfiles/filedetails/?id=<ID>`):

1. **Add/edit images & videos** → screenshots (any size, 16:9 looks best) and YouTube videos.
2. **Add/remove required items** → link the weapon packs your `jdmw.txt` uses (e.g. M9K), so
   subscribers get them automatically.

## 6. Use it on a dedicated server

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
