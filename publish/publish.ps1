<#
.SYNOPSIS
    Builds JDeathmatch into a .gma and publishes / updates it on the Steam Workshop,
    including title, description and visibility.

.EXAMPLE
    .\publish.ps1 -BuildOnly
    .\publish.ps1 -Changes "Fixed MOAB timer"
    .\publish.ps1 -Changes "New icon" -UpdateIcon
    .\publish.ps1 -DescriptionOnly
    .\publish.ps1 -DescriptionOnly -Visibility public
    .\publish.ps1 -Collection
#>
param(
    # Changelog shown on the Workshop page (used when updating)
    [string]$Changes = "",
    # Only build the .gma, do not upload
    [switch]$BuildOnly,
    # Also replace the Workshop icon when updating
    [switch]$UpdateIcon,
    # Only push title + description (and visibility) from workshop_description.txt, no build/upload
    [switch]$DescriptionOnly,
    # Do not push the description after uploading the .gma
    [switch]$SkipDescription,
    # Only push collection_title.txt + collection_description.txt to the example collection (collection_id.txt)
    [switch]$Collection,
    # Also change visibility: public, friends, private, unlisted
    [ValidateSet("", "public", "friends", "private", "unlisted")]
    [string]$Visibility = "",
    # Steam account name for SteamCMD (saved in steam_user.txt, which is not committed)
    [string]$SteamUser = "",
    # Garry's Mod install folder (auto-detected from Steam if omitted)
    [string]$GModPath = ""
)

$ErrorActionPreference = "Stop"

$PublishDir      = $PSScriptRoot
$RepoRoot        = Split-Path $PublishDir -Parent
$OutDir          = Join-Path $PublishDir "out"
$GmaPath         = Join-Path $OutDir "jdeathmatch.gma"
$IconPath        = Join-Path $PublishDir "icon.jpg"
$IdFile          = Join-Path $PublishDir "workshop_id.txt"
$DescriptionFile = Join-Path $PublishDir "workshop_description.txt"
$CollectionIdFile          = Join-Path $PublishDir "collection_id.txt"
$CollectionDescriptionFile = Join-Path $PublishDir "collection_description.txt"
$CollectionTitleFile       = Join-Path $PublishDir "collection_title.txt"
$SteamUserFile   = Join-Path $PublishDir "steam_user.txt"
$SteamCmdDir     = Join-Path $PublishDir "steamcmd"
$SteamCmd        = Join-Path $SteamCmdDir "steamcmd.exe"
$GModAppId       = 4000

. (Join-Path $PublishDir "description.ps1")

function Find-GMod {
    if ($GModPath) { return $GModPath }

    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if (!$steam) { throw "Steam not found. Pass -GModPath 'X:\...\GarrysMod'." }

    $libraries = @($steam -replace '/', '\')
    $vdf = Join-Path $libraries[0] "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        Select-String -Path $vdf -Pattern '"path"\s+"(.+)"' | ForEach-Object {
            $libraries += $_.Matches[0].Groups[1].Value -replace '\\\\', '\'
        }
    }

    foreach ($lib in $libraries) {
        $candidate = Join-Path $lib "steamapps\common\GarrysMod"
        if (Test-Path (Join-Path $candidate "bin\gmad.exe")) { return $candidate }
    }
    throw "Garry's Mod not found in Steam libraries. Pass -GModPath 'X:\...\GarrysMod'."
}

function Test-Icon {
    if (!(Test-Path $IconPath)) { throw "Missing $IconPath (512x512 JPG)." }
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($IconPath)
    try {
        $isJpeg = $img.RawFormat.Equals([System.Drawing.Imaging.ImageFormat]::Jpeg)
        if (!$isJpeg -or $img.Width -ne 512 -or $img.Height -ne 512) {
            throw "icon.jpg must be a 512x512 JPEG (found $($img.Width)x$($img.Height), jpeg=$isJpeg)."
        }
    } finally { $img.Dispose() }
}

function Get-WorkshopId {
    if (Test-Path $IdFile) { return (Get-Content $IdFile -Raw).Trim() }
    return ""
}

# Run a native tool, show its output and return it as one string.
# (With "Stop", PowerShell 5.1 would abort on the first line a tool writes to stderr.)
function Invoke-Logged([string]$exe, [string[]]$arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $exe @arguments 2>&1 | ForEach-Object { "$_" } | Tee-Object -Variable lines | Out-Host
        $script:LastToolExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    return ($lines -join "`n")
}

# Quote a string for a VDF (KeyValues) value.
# SteamCMD's parser has no escape sequences (\" breaks it), so straight quotes become typographic ones;
# the gamemode accepts them in jdmw.txt, so the config in a description can still be copied as is.
function ConvertTo-VdfString([string]$value) {
    $value = [regex]::Replace($value, '"([^"\n]*)"', ([char]0x201C + '$1' + [char]0x201D))
    $value = $value.Replace('"', [string][char]0x201D)
    return '"' + $value + '"'
}

function Install-SteamCmd {
    if (Test-Path $SteamCmd) { return }
    Write-Host "Downloading SteamCMD from Valve..."
    New-Item -ItemType Directory -Force $SteamCmdDir | Out-Null
    $zip = Join-Path $env:TEMP "steamcmd_$(Get-Random).zip"
    Invoke-WebRequest "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $SteamCmdDir -Force
    Remove-Item $zip
}

# Push title (optional), description and visibility with SteamCMD (gmpublish cannot do it).
# With $contentFolder it also uploads the .gma in that folder (fallback when gmpublish fails).
function Update-WorkshopMetadata([string]$workshopId, [string]$title, [string]$descriptionPath,
                                 [string]$contentFolder = "", [string]$changeNote = "",
                                 [string]$previewFile = "") {
    if (!$workshopId) { throw "No Workshop ID: upload the addon first (publish.bat) or write the ID in publish\workshop_id.txt." }
    $description = Read-Description $descriptionPath $RepoRoot

    $user = $SteamUser
    if (!$user -and (Test-Path $SteamUserFile)) { $user = (Get-Content $SteamUserFile -Raw).Trim() }
    if (!$user) { $user = Read-Host "Steam account name (login name, not the profile name)" }
    if (!$user) { throw "A Steam account name is required." }
    $user | Set-Content $SteamUserFile -NoNewline

    Install-SteamCmd

    $vdfLines = @(
        '"workshopitem"', '{',
        "    `"appid`" `"$GModAppId`"",
        "    `"publishedfileid`" `"$workshopId`""
    )
    if ($title) { $vdfLines += "    `"title`" $(ConvertTo-VdfString $title)" }
    $vdfLines += "    `"description`" $(ConvertTo-VdfString $description)"
    $visibilityCodes = @{ public = 0; friends = 1; private = 2; unlisted = 3 }
    if ($Visibility) { $vdfLines += "    `"visibility`" `"$($visibilityCodes[$Visibility])`"" }
    # Without "contentfolder" SteamCMD only updates the metadata, the .gma uploaded by gmpublish stays
    if ($contentFolder) { $vdfLines += "    `"contentfolder`" $(ConvertTo-VdfString $contentFolder)" }
    if ($changeNote)    { $vdfLines += "    `"changenote`" $(ConvertTo-VdfString $changeNote)" }
    if ($previewFile)   { $vdfLines += "    `"previewfile`" $(ConvertTo-VdfString $previewFile)" }
    $vdfLines += '}'

    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $vdfPath = Join-Path $OutDir "workshop_item.vdf"
    [System.IO.File]::WriteAllText($vdfPath, ($vdfLines -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

    # First login is interactive (password + Steam Guard typed by you in SteamCMD), then it is cached
    Write-Host "Logging in to SteamCMD as '$user' (type password / Steam Guard code if asked)..."
    & $SteamCmd +login $user +quit
    if ($LASTEXITCODE -ne 0) { throw "SteamCMD login failed." }

    Write-Host "Updating Workshop item $workshopId..."
    $text = Invoke-Logged $SteamCmd @("+login", $user, "+workshop_build_item", $vdfPath, "+quit")
    if ($text -match 'ERROR!' -or $text -notmatch 'Success') { throw "SteamCMD failed to update the Workshop item (see output above)." }
    Write-Host "Description updated: https://steamcommunity.com/sharedfiles/filedetails/?id=$workshopId" -ForegroundColor Green
}

# addon.json sanity check (title, type, tags)
$addon = Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json
if (!$addon.title -or !$addon.type) { throw "addon.json needs 'title' and 'type'." }
if (@($addon.tags).Count -gt 2) { throw "addon.json: Workshop allows at most 2 tags." }
Write-Host "Addon: $($addon.title) [$($addon.type)] tags: $(@($addon.tags) -join ', ')"

if ($Collection) {
    if (!(Test-Path $CollectionIdFile)) { throw "Missing $CollectionIdFile (ID of the example collection)." }
    $collectionTitle = if (Test-Path $CollectionTitleFile) { (Get-Content $CollectionTitleFile -Raw -Encoding UTF8).Trim() } else { "" }
    Update-WorkshopMetadata (Get-Content $CollectionIdFile -Raw).Trim() $collectionTitle $CollectionDescriptionFile
    return
}

if ($DescriptionOnly) {
    Update-WorkshopMetadata (Get-WorkshopId) $addon.title $DescriptionFile
    return
}

$gmod       = Find-GMod
$gmad       = Join-Path $gmod "bin\gmad.exe"
$gmpublish  = Join-Path $gmod "bin\gmpublish.exe"
Write-Host "Garry's Mod: $gmod"

# Validate the description before uploading anything
Read-Description $DescriptionFile $RepoRoot | Out-Null

# Build
New-Item -ItemType Directory -Force $OutDir | Out-Null
if (Test-Path $GmaPath) { Remove-Item $GmaPath }
Invoke-Logged $gmad @("create", "-folder", $RepoRoot, "-out", $GmaPath) | Out-Null
if ($script:LastToolExitCode -ne 0 -or !(Test-Path $GmaPath)) { throw "gmad failed." }
Write-Host "Built: $GmaPath" -ForegroundColor Green

if ($BuildOnly) { return }

Test-Icon
Write-Host "Steam must be running and logged in with the account that owns the addon."

$workshopId = Get-WorkshopId

if ($workshopId) {
    # Update existing Workshop item
    if (!$Changes) { $Changes = Read-Host "Changelog for this update" }
    $publishArgs = @("update", "-addon", $GmaPath, "-id", $workshopId, "-changes", $Changes)
    if ($UpdateIcon) { $publishArgs += @("-icon", $IconPath) }
    $log = Invoke-Logged $gmpublish $publishArgs
    if ($script:LastToolExitCode -ne 0 -or $log -match 'Update failed') {
        # gmpublish sometimes fails with "File not found": upload the .gma with SteamCMD instead
        # (this also pushes title and description, as a normal update does)
        Write-Warning "gmpublish update failed, uploading the .gma with SteamCMD instead."
        $contentDir = Join-Path $OutDir "content"
        if (Test-Path $contentDir) { Remove-Item $contentDir -Recurse -Force }
        New-Item -ItemType Directory -Force $contentDir | Out-Null
        Copy-Item $GmaPath $contentDir
        $preview = if ($UpdateIcon) { $IconPath } else { "" }
        Update-WorkshopMetadata $workshopId $addon.title $DescriptionFile $contentDir $Changes $preview
        return
    }
    Write-Host "Updated: https://steamcommunity.com/sharedfiles/filedetails/?id=$workshopId" -ForegroundColor Green
} else {
    # First upload: create the Workshop item and remember its ID
    $log = Invoke-Logged $gmpublish @("create", "-addon", $GmaPath, "-icon", $IconPath)
    if ($script:LastToolExitCode -ne 0) { throw "gmpublish create failed." }

    # gmpublish prints "Your new item ID is <id>" (the log also contains your SteamID, so be specific)
    $match = [regex]::Match($log, 'item ID is (\d+)|filedetails/\?id=(\d+)', 'IgnoreCase')
    if ($match.Success) {
        $workshopId = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        $workshopId | Set-Content $IdFile -NoNewline
        Write-Host "Created: https://steamcommunity.com/sharedfiles/filedetails/?id=$workshopId" -ForegroundColor Green
        Write-Host "Saved the ID to publish\workshop_id.txt - commit it so future runs update instead of creating."
    } else {
        Write-Warning "Could not read the Workshop ID from the output. Copy it from the Workshop URL into publish\workshop_id.txt, then run publish.bat -DescriptionOnly."
        return
    }
    Write-Host "New items are uploaded as HIDDEN: use -Visibility public (or set it on the page) when ready."
}

if (!$SkipDescription) {
    Update-WorkshopMetadata $workshopId $addon.title $DescriptionFile
}
