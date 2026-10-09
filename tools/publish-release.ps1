#Requires -Version 5.1
<#
.SYNOPSIS
  Gera pasta de release (API + SPA em wwwroot) pronta a copiar para o IIS do cliente.
  NÃO inclui appsettings.Production.json (segredos).

.EXAMPLE
  .\tools\publish-release.ps1
  .\tools\publish-release.ps1 -OutDir "D:\releases\portal-2026-10-09" -Zip
#>
param(
  [string]$OutDir = "",
  [switch]$Zip
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -ErrorAction SilentlyContinue
# Script em tools\ → repo = parent
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
if (-not $OutDir) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
  $OutDir = Join-Path $repoRoot "releases\portal-$stamp"
}

$frontend = Join-Path $repoRoot 'src\frontend'
$backend = Join-Path $repoRoot 'src\backend'
$apiProj = Join-Path $backend 'src\Portal.Api\Portal.Api.csproj'

Write-Host "Repo: $repoRoot"
Write-Host "Out:  $OutDir"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "`n=== Frontend ===" -ForegroundColor Cyan
Set-Location -LiteralPath $frontend
if (Test-Path 'package-lock.json') { npm ci } else { npm install }
npm run build

Write-Host "`n=== API publish ===" -ForegroundColor Cyan
Set-Location -LiteralPath $backend
dotnet publish $apiProj -c Release -o $OutDir

$www = Join-Path $OutDir 'wwwroot'
New-Item -ItemType Directory -Force -Path $www | Out-Null
Copy-Item -Path (Join-Path $frontend 'dist\*') -Destination $www -Recurse -Force

# Garantir ASPNETCORE_ENVIRONMENT=Production no web.config
$wcPath = Join-Path $OutDir 'web.config'
if (Test-Path $wcPath) {
  $xml = [xml](Get-Content -LiteralPath $wcPath)
  $asp = $xml.configuration.location.'system.webServer'.aspNetCore
  if (-not $asp) { $asp = $xml.configuration.'system.webServer'.aspNetCore }
  if ($asp) {
    $asp.SetAttribute('stdoutLogEnabled', 'false')
    $existing = $asp.environmentVariables
    if ($existing) { [void]$asp.RemoveChild($existing) }
    $envVars = $xml.CreateElement('environmentVariables')
    $env = $xml.CreateElement('environmentVariable')
    $env.SetAttribute('name', 'ASPNETCORE_ENVIRONMENT')
    $env.SetAttribute('value', 'Production')
    [void]$envVars.AppendChild($env)
    [void]$asp.AppendChild($envVars)
    $xml.Save($wcPath)
  }
}

# Template de produção (sem password)
$template = @{
  Phc = @{
    ConnectionString = 'Server=SERVIDOR;Database=BD_PHC;User Id=portal_app;Password=***;TrustServerCertificate=True;Encrypt=True;'
    SerieEncomendasNdos = 1
    SeriePickingNdos = 66
    SerieSeparacaoNdos = 65
  }
  DataProtection = @{ KeysPath = 'C:\inetpub\portal\dp-keys' }
  Portal = @{ SpaBaseUrl = 'https://portal.cliente.local' }
  Cors = @{ Origins = @('https://portal.cliente.local') }
  AllowedHosts = 'portal.cliente.local'
} | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText(
  (Join-Path $OutDir 'appsettings.Production.TEMPLATE.json'),
  $template,
  [System.Text.UTF8Encoding]::new($false)
)

$readme = @"
# Portal Logística — release

1. Copiar esta pasta para o servidor, ex.: C:\inetpub\portal\api
2. Renomear appsettings.Production.TEMPLATE.json → appsettings.Production.json e preencher
3. Criar C:\inetpub\portal\dp-keys e dar Modify ao App Pool
4. Correr tools\iis-install-site.ps1 no servidor (ou criar site IIS manualmente)
5. Testar /health e login

Modelo: API + SPA no mesmo site (mesmo origin). Ver docs/PASSO_A_PASSO_PRODUCAO.md
"@
Set-Content -Path (Join-Path $OutDir 'LEIA-ME.txt') -Value $readme -Encoding UTF8

Write-Host "`nOK: $OutDir" -ForegroundColor Green
Write-Host "SPA: $(Test-Path (Join-Path $www 'index.html')) | DLL: $(Test-Path (Join-Path $OutDir 'Portal.Api.dll'))"

if ($Zip) {
  $zipPath = "$OutDir.zip"
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  Compress-Archive -Path (Join-Path $OutDir '*') -DestinationPath $zipPath
  Write-Host "ZIP: $zipPath" -ForegroundColor Green
}
