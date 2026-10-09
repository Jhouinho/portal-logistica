#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Cria site IIS + App Pool no modelo validado em localhost:8088 (API+SPA mesmo origin).

.EXAMPLE
  .\tools\iis-install-site.ps1 -PhysicalPath 'C:\inetpub\portal\api' -Port 80 -SiteName Portal
  .\tools\iis-install-site.ps1 -PhysicalPath 'C:\inetpub\portal\api' -Port 443 -SiteName Portal -HostHeader 'portal.cliente.local'
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$PhysicalPath,
  [string]$SiteName = 'Portal',
  [string]$AppPoolName = 'PortalAppPool',
  [int]$Port = 80,
  [string]$HostHeader = '',
  [string]$Protocol = 'http'
)

$ErrorActionPreference = 'Stop'
Import-Module WebAdministration

if (-not (Test-Path -LiteralPath $PhysicalPath)) {
  throw "Pasta inexistente: $PhysicalPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $PhysicalPath 'Portal.Api.dll'))) {
  throw "Portal.Api.dll não encontrado em $PhysicalPath — corre publish-release.ps1 primeiro."
}

$ancm = 'C:\Program Files\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll'
if (-not (Test-Path $ancm)) {
  throw 'ASP.NET Core Hosting Bundle não instalado. Instala Microsoft.DotNet.HostingBundle.8 e iisreset.'
}

$dpKeys = Join-Path (Split-Path $PhysicalPath -Parent) 'dp-keys'
if (-not (Test-Path $dpKeys)) {
  # fallback ao lado da api
  $dpKeys = Join-Path $PhysicalPath '..\dp-keys'
}
$dpKeys = [System.IO.Path]::GetFullPath($dpKeys)
New-Item -ItemType Directory -Force -Path $dpKeys | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PhysicalPath 'logs') | Out-Null

if (Test-Path "IIS:\AppPools\$AppPoolName") {
  Write-Host "App Pool já existe: $AppPoolName"
} else {
  New-WebAppPool -Name $AppPoolName | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ''
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.identityType -Value ApplicationPoolIdentity

if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
  Write-Host "A remover site existente: $SiteName"
  Remove-Website -Name $SiteName
}

New-Website -Name $SiteName -Port $Port -PhysicalPath $PhysicalPath -ApplicationPool $AppPoolName -HostHeader $HostHeader | Out-Null

# Permissões App Pool
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
  "IIS AppPool\$AppPoolName", 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
foreach ($p in @($PhysicalPath, $dpKeys)) {
  $acl = Get-Acl $p
  $acl.AddAccessRule($rule)
  Set-Acl $p $acl
}

Start-Website -Name $SiteName
Write-Host "OK: site=$SiteName pool=$AppPoolName path=$PhysicalPath ${Protocol}://*:${Port}/$HostHeader" -ForegroundColor Green
Write-Host "Confirma appsettings.Production.json e KeysPath=$dpKeys"
Write-Host "Testa: ${Protocol}://localhost:$Port/health"
