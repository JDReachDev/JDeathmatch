# Shared helpers for publish.ps1 and preview_description.ps1 (dot-sourced)

$MaxDescription = 8000 # Workshop limit

# Weapons config as compact JSON, one weapon per line (fits the Workshop limit)
function Get-CompactWeaponConfig([string]$jsonPath) {
    $weapons = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $lines = foreach ($w in $weapons) {
        '  { "id": "' + $w.id + '", "name": "' + ($w.name -replace '"', "'") + '", "slot": ' + $w.slot +
            ', "ammo": ' + $w.ammo + ', "dmgmul": ' + ([string]$w.dmgmul).Replace(',', '.') + ' }'
    }
    return "[`n" + ($lines -join ",`n") + "`n]"
}

# Read a description file and fill its placeholders:
#   {{JDMW_CONFIG}}  -> examples/jdmw.txt as compact JSON
function Read-Description([string]$path, [string]$repoRoot) {
    if (!(Test-Path $path)) { throw "Missing $path." }
    $text = (Get-Content $path -Raw -Encoding UTF8).Trim() -replace "`r", ''
    if ($text.Contains('{{JDMW_CONFIG}}')) {
        $text = $text.Replace('{{JDMW_CONFIG}}', (Get-CompactWeaponConfig (Join-Path $repoRoot "examples\jdmw.txt")))
    }
    if ($text.Length -gt $MaxDescription) {
        throw "$(Split-Path $path -Leaf) is $($text.Length) characters, the Workshop limit is $MaxDescription."
    }
    return $text
}
