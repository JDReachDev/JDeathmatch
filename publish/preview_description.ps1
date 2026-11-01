<#
.SYNOPSIS
    Renders workshop_description.txt (Steam BBCode) to out/description_preview.html
    with a Workshop-like look, and opens it in the browser.

.EXAMPLE
    .\preview_description.ps1
    .\preview_description.ps1 -NoOpen
#>
param(
    # Preview collection_description.txt (the example collection) instead of the addon page
    [switch]$Collection,
    # Only write the HTML, do not open it
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

$PublishDir      = $PSScriptRoot
$RepoRoot        = Split-Path $PublishDir -Parent
$IconPath        = Join-Path $PublishDir "icon.jpg"
$OutDir          = Join-Path $PublishDir "out"

. (Join-Path $PublishDir "description.ps1")
Add-Type -AssemblyName System.Web

if ($Collection) {
    $DescriptionFile = Join-Path $PublishDir "collection_description.txt"
    $HtmlPath        = Join-Path $OutDir "collection_preview.html"
    $title           = (Get-Content (Join-Path $PublishDir "collection_title.txt") -Raw -Encoding UTF8).Trim()
} else {
    $DescriptionFile = Join-Path $PublishDir "workshop_description.txt"
    $HtmlPath        = Join-Path $OutDir "description_preview.html"
    $title           = (Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json).title
}

# Fill placeholders ({{JDMW_CONFIG}}), they count towards the limit too
$raw = (Get-Content $DescriptionFile -Raw -Encoding UTF8).Trim() -replace "`r", ''
$bbcode = $raw.Replace('{{JDMW_CONFIG}}', (Get-CompactWeaponConfig (Join-Path $RepoRoot "examples\jdmw.txt")))

# Escape HTML first, then turn BBCode tags into HTML
$html = [System.Web.HttpUtility]::HtmlEncode($bbcode)

$simpleTags = @{
    'h1' = 'h1'; 'h2' = 'h2'; 'h3' = 'h3'; 'b' = 'b'; 'i' = 'i'; 'u' = 'u'; 'strike' = 's'
    'table' = 'table'; 'tr' = 'tr'; 'th' = 'th'; 'td' = 'td'; 'code' = 'pre'; 'quote' = 'blockquote'
    'list' = 'ul'; 'olist' = 'ol'; 'spoiler' = 'span class="spoiler"'
}
foreach ($tag in $simpleTags.Keys) {
    $open = $simpleTags[$tag]
    $close = $open.Split(' ')[0]
    $html = $html -replace "\[$tag\]", "<$open>" -replace "\[/$tag\]", "</$close>"
}
$html = $html -replace '\[\*\]', '<li>'
$html = $html -replace '\[hr\]\s*(\[/hr\])?', '<hr>'
$html = $html -replace '\[url=([^\]]+)\](.*?)\[/url\]', '<a href="$1">$2</a>'
$html = $html -replace '\[url\](.*?)\[/url\]', '<a href="$1">$1</a>'
$html = $html -replace '\[img\](.*?)\[/img\]', '<img src="$1">'

# Line breaks like Steam, but not right after block tags
$html = $html -replace "`r", ''
$html = $html -replace '(</?(h1|h2|h3|ul|ol|li|table|tr|th|td|hr|pre|blockquote)[^>]*>)\n', '$1'
$html = $html -replace "\n", "<br>`n"

$length = $bbcode.Length
$lengthClass = if ($length -gt $MaxDescription) { 'over' } else { 'ok' }
# Embed the icon, so the preview works wherever the HTML is opened
$iconUri = "data:image/jpeg;base64," + [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($IconPath))

$page = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Workshop preview</title>
<style>
  body { margin: 0; background: #1b2838; color: #acb2b8; font: 14px/1.5 Arial, Helvetica, sans-serif; }
  .page { max-width: 960px; margin: 0 auto; padding: 24px 16px; }
  .head { display: flex; gap: 16px; align-items: center; margin-bottom: 16px; }
  .head img { width: 96px; height: 96px; border-radius: 3px; }
  .head h1 { color: #fff; font-size: 26px; font-weight: normal; margin: 0; }
  .meta { font-size: 12px; }
  .meta .ok { color: #8bc53f; } .meta .over { color: #ff6464; font-weight: bold; }
  .desc { background: rgba(0,0,0,.2); padding: 16px; border-radius: 3px; overflow-wrap: anywhere; }
  .desc h1 { color: #5aa9d6; font-size: 20px; font-weight: normal; margin: 8px 0; }
  .desc h2 { color: #5aa9d6; font-size: 16px; font-weight: normal; margin: 8px 0; }
  .desc h3 { color: #5aa9d6; font-size: 14px; margin: 6px 0; }
  .desc b { color: #e5e5e5; }
  .desc a { color: #fff; text-decoration: none; } .desc a:hover { color: #66c0f4; }
  .desc table { border-collapse: collapse; margin: 6px 0; max-width: 100%; display: block; overflow-x: auto; }
  .desc th, .desc td { border: 1px solid #4c5a69; padding: 4px 8px; text-align: left; }
  .desc th { color: #e5e5e5; }
  .desc pre { background: #101822; padding: 8px; white-space: normal; font: 12px/1.4 Consolas, monospace; }
  .desc blockquote { border-left: 3px solid #4c5a69; margin: 6px 0; padding-left: 10px; }
  .desc .spoiler { background: #000; color: #000; } .desc .spoiler:hover { color: #acb2b8; }
  .desc img { max-width: 100%; }
  .desc hr { border: 0; border-top: 1px solid #4c5a69; }
</style>
</head>
<body>
<div class="page">
  <div class="head">
    <img src="$iconUri" alt="">
    <div>
      <h1>$([System.Web.HttpUtility]::HtmlEncode($title))</h1>
      <div class="meta">Description length: <span class="$lengthClass">$length / $MaxDescription</span> characters</div>
    </div>
  </div>
  <div class="desc">
$html
  </div>
</div>
</body>
</html>
"@

New-Item -ItemType Directory -Force $OutDir | Out-Null
[System.IO.File]::WriteAllText($HtmlPath, $page, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Preview: $HtmlPath ($length / $MaxDescription characters)"
if ($length -gt $MaxDescription) { Write-Warning "The description is over the Workshop limit." }
if (!$NoOpen) { Start-Process $HtmlPath }
