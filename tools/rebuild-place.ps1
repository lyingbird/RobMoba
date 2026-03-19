Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $repoRoot "roblox_vibecoding.rbxlx"

Write-Host "[rebuild-place] Building clean place from repo..."
rojo build -o $outputPath
Write-Host "[rebuild-place] Wrote $outputPath"
Write-Host "[rebuild-place] Open this file in Roblox Studio, then run 'rojo serve' from the repo root."
