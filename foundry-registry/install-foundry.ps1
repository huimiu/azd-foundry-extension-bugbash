#!/usr/bin/env pwsh
# Installs the Foundry feature-branch test extensions from this folder.
# It localizes the artifact paths to wherever this folder currently lives,
# registers a 'foundrytest' file source, and installs the microsoft.foundry
# meta-package (which pulls in all 7 azure.ai.* extensions from the same source).
$ErrorActionPreference = "Stop"

$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$reg   = Join-Path $root "registry.json"
$local = Join-Path $root "registry.local.json"

Write-Host "Localizing artifact paths to: $root"
$json = Get-Content $reg -Raw | ConvertFrom-Json
foreach ($e in $json.extensions) {
  foreach ($v in $e.versions) {
    if ($null -ne $v.artifacts) {
      foreach ($p in $v.artifacts.PSObject.Properties) {
        $u = $p.Value.url
        if ($u -and $u -notmatch '^https?://' -and -not [System.IO.Path]::IsPathRooted($u)) {
          $p.Value.url = (Join-Path $root ($u -replace '/', '\'))
        }
      }
    }
  }
}
$json | ConvertTo-Json -Depth 60 | Set-Content -Path $local -Encoding utf8

Write-Host "Registering 'foundrytest' extension source..."
azd extension source remove foundrytest 2>$null | Out-Null
azd extension source add -n foundrytest -t file -l $local

Write-Host "Installing microsoft.foundry (and its 7 dependencies)..."
azd extension install microsoft.foundry --source foundrytest

Write-Host ""
Write-Host "Done. Verify with:  azd extension list"
