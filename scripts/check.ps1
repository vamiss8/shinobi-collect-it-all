# Runs every check that works without Roblox Studio: format, lint, types, unit tests.
# Usage: powershell -File scripts/check.ps1
$ErrorActionPreference = "Continue"
$env:Path += ";$env:USERPROFILE\.rokit\bin"
$failed = $false

Write-Host "== stylua =="
stylua --check src tests .lune
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host "== selene =="
selene src tests
if ($LASTEXITCODE -ne 0) { $failed = $true }

# The type checker ships inside the Luau Language Server extension for VS Code.
Write-Host "== types =="
$lsp = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\johnnymorganz.luau-lsp-*\bin\server.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
$defs = "$env:APPDATA\Code\User\globalStorage\johnnymorganz.luau-lsp\globalTypes.PluginSecurity.d.luau"
if ($lsp -and (Test-Path $defs)) {
    rojo sourcemap default.project.json -o sourcemap.json | Out-Null
    $out = & $lsp.FullName analyze --platform=roblox --sourcemap=sourcemap.json "--definitions=$defs" --ignore="src/server/Vendor/**" src 2>&1 |
        ForEach-Object { "$_" } | Where-Object { $_ -notmatch "^\[(INFO|WARN)\]" }
    if ($LASTEXITCODE -ne 0) { $failed = $true }
    $out | Select-Object -Unique
} else {
    Write-Host "skipped: Luau Language Server extension not found"
}

Write-Host "== tests =="
lune run test
if ($LASTEXITCODE -ne 0) { $failed = $true }

if ($failed) { Write-Host "CHECK FAILED"; exit 1 }
Write-Host "ALL CHECKS PASSED"
