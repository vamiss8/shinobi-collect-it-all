# Prints whether the uploaded pictures have passed Roblox moderation: every asset id listed in
# src/client/Art.luau, and the game's icon. It asks Roblox's public thumbnail service, which
# needs no login, so the answer is what any player's game gets.
# Usage: powershell -File scripts/art-status.ps1              everything in Art.luau
#        powershell -File scripts/art-status.ps1 123 456      just these asset ids, such as
#                                                             the texture of an imported model
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# The game's universe id: Creator Hub shows it in the address of the game's page.
$universe = "10768898906"

$verdicts = @{
    Completed = "approved"
    Pending   = "in moderation"
    InReview  = "in moderation"
    Blocked   = "REJECTED"
    Error     = "error, ask again later"
}
function Verdict([string]$state) {
    if ($verdicts.ContainsKey($state)) { return $verdicts[$state] }
    return $state
}

# Every `name = 123456,` line of Art.luau that carries a real id (0 means "draw it").
$names = [ordered]@{}
if ($args.Count -gt 0) {
    foreach ($id in $args) { $names["$id"] = "asset" }
} else {
    $art = Get-Content (Join-Path $PSScriptRoot "..\src\client\Art.luau") -Raw
    foreach ($match in [regex]::Matches($art, '(?m)^\s*\[?"?([A-Za-z_][A-Za-z0-9_]*)"?\]?\s*=\s*(\d{6,})\s*,')) {
        $names[$match.Groups[2].Value] = $match.Groups[1].Value
    }
}

$ids = @($names.Keys)
for ($from = 0; $from -lt $ids.Count; $from += 50) {
    $last = [Math]::Min($from + 49, $ids.Count - 1)
    $batch = $ids[$from..$last] -join ","
    $url = "https://thumbnails.roblox.com/v1/assets?assetIds=$batch&size=420x420&format=Png&isCircular=false"
    foreach ($row in (Invoke-RestMethod $url).data) {
        $id = "$($row.targetId)"
        "{0,-18} {1,-18} {2}" -f $names[$id], $id, (Verdict $row.state)
    }
}

if ($args.Count -eq 0) {
    $url = "https://thumbnails.roblox.com/v1/games/icons?universeIds=$universe&size=512x512&format=Png&isCircular=false"
    foreach ($row in (Invoke-RestMethod $url).data) {
        "{0,-18} {1,-18} {2}" -f "game icon", $universe, (Verdict $row.state)
    }
}
