#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Inventario tecnico IIS do Portal Mobile - APENAS LEITURA (Etapa 15).

.DESCRIPTION
  Nao publica, nao reinicia App Pools/sites, nao altera ficheiros nem IIS.
  Nao imprime passwords, connection strings completas nem tokens.
  Valor efectivo runtime da flag PedidosInternosEnabled: NAO confirmado por inspeccao.
  Todo o texto relevante usa Write-Output (aparece em Tee-Object / redireccao).

.PARAMETER SiteName
  Nome exacto do site IIS de producao. Se omitido, lista sites e termina.

.PARAMETER OutFile
  Caminho opcional para gravar o relatorio completo (UTF8).

.EXAMPLE
  .\inventory-iis-prod-readonly.ps1 -SiteName 'Portal' -OutFile C:\inetpub\inventario-portal.txt
#>
[CmdletBinding()]
param(
  [string]$SiteName = '',
  [string]$OutFile = ''
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:LogLines = New-Object System.Collections.Generic.List[string]

function Write-Log([string]$Message) {
  $script:LogLines.Add($Message)
  Write-Output $Message
}

function Write-Section([string]$Title) {
  Write-Log ''
  Write-Log ("=== {0} ===" -f $Title)
}

function Get-PedidosInternosFlag([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return 'FILE_MISSING' }
  try {
    $j = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $j.Portal -or $null -eq $j.Portal.Cliente) { return 'SECTION_MISSING' }
    $v = $j.Portal.Cliente.PedidosInternosEnabled
    if ($null -eq $v) { return 'KEY_MISSING' }
    return [string]$v
  } catch {
    return ('PARSE_ERROR: {0}' -f $_.Exception.Message)
  }
}

function Show-FileHashRow([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return [pscustomobject]@{ File = $Path; Exists = $false; SHA256 = ''; Size = $null; LastWrite = $null }
  }
  $i = Get-Item -LiteralPath $Path
  $h = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return [pscustomobject]@{
    File      = $i.FullName
    Exists    = $true
    SHA256    = $h.Hash
    Size      = $i.Length
    LastWrite = $i.LastWriteTime
  }
}

function Write-ObjectBlock($Object) {
  if ($null -eq $Object) { return }
  $text = ($Object | Format-List | Out-String).TrimEnd()
  if (-not [string]::IsNullOrWhiteSpace($text)) { Write-Log $text }
}

function Write-TableBlock($Object) {
  if ($null -eq $Object) { return }
  $text = ($Object | Format-Table -AutoSize | Out-String).TrimEnd()
  if (-not [string]::IsNullOrWhiteSpace($text)) { Write-Log $text }
}

Write-Section 'HOST'
Write-Log (hostname)
Write-Log ([System.Environment]::OSVersion.VersionString)
try {
  $ci = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, CsName
  Write-ObjectBlock $ci
} catch {
  Write-Log '(Get-ComputerInfo indisponivel)'
}

Write-Section 'SITES IIS'
Import-Module WebAdministration -ErrorAction Stop
$sites = Get-Website | Select-Object Name, State, PhysicalPath, ApplicationPool,
  @{ n = 'Bindings'; e = {
      ($_.bindings.Collection | ForEach-Object {
        '{0} {1}' -f $_.protocol, $_.bindingInformation
      }) -join '; '
    }
  }
Write-ObjectBlock $sites

Write-Section 'APP POOLS'
$pools = Get-ChildItem IIS:\AppPools | ForEach-Object {
  [pscustomobject]@{
    Name                  = $_.Name
    State                 = (Get-WebAppPoolState -Name $_.Name).Value
    ManagedRuntimeVersion = $_.managedRuntimeVersion
    IdentityType          = $_.processModel.identityType
    UserName              = $_.processModel.userName
  }
}
Write-TableBlock $pools

if ([string]::IsNullOrWhiteSpace($SiteName)) {
  Write-Log ''
  Write-Log 'SiteName nao indicado. Volta a correr com -SiteName "NOME_DO_SITE".'
  Write-Log 'Exemplo: .\inventory-iis-prod-readonly.ps1 -SiteName "Portal" -OutFile C:\inetpub\inventario-portal.txt'
  if ($OutFile) {
    $script:LogLines | Set-Content -LiteralPath $OutFile -Encoding UTF8
    Write-Log ("Gravado: {0}" -f $OutFile)
  }
  return
}

$site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
if (-not $site) {
  Write-Log ("Site nao encontrado: {0}" -f $SiteName)
  if ($OutFile) { $script:LogLines | Set-Content -LiteralPath $OutFile -Encoding UTF8 }
  return
}

$AppRoot = $site.physicalPath.TrimEnd('\')
$PoolName = $site.applicationPool
Write-Section 'SITE ESCOLHIDO'
Write-Log ("SiteName={0}" -f $SiteName)
Write-Log ("AppRoot={0}" -f $AppRoot)
Write-Log ("Pool={0}" -f $PoolName)
Write-Log ("State={0}" -f $site.State)

Write-Section 'web.config (trechos)'
$wc = Join-Path $AppRoot 'web.config'
if (Test-Path -LiteralPath $wc) {
  Select-String -LiteralPath $wc -Pattern 'ASPNETCORE_ENVIRONMENT|environmentVariable|WebDAV|aspNetCore|processPath|arguments' |
    ForEach-Object { Write-Log $_.Line.Trim() }
  Write-ObjectBlock (Show-FileHashRow $wc)
  $wcRaw = Get-Content -LiteralPath $wc -Raw
  Write-Log ("WebDAV_handlers_remove={0}" -f ($wcRaw -match 'remove\s+name\s*=\s*"WebDAV"'))
  Write-Log ("WebDAVModule_remove={0}" -f ($wcRaw -match 'remove\s+name\s*=\s*"WebDAVModule"'))
} else {
  Write-Log 'MISSING web.config'
}

Write-Section 'HASHES ARTEFACTOS'
$index = Join-Path $AppRoot 'wwwroot\index.html'
$rows = @(
  (Show-FileHashRow (Join-Path $AppRoot 'Portal.Api.dll')),
  (Show-FileHashRow (Join-Path $AppRoot 'Portal.Infrastructure.dll')),
  (Show-FileHashRow $index),
  (Show-FileHashRow $wc)
)
Write-TableBlock $rows

if (Test-Path -LiteralPath $index) {
  $html = Get-Content -LiteralPath $index -Raw -Encoding UTF8
  $m = [regex]::Match($html, 'assets/index-[^"\s>]+\.js')
  if ($m.Success) {
    $ref = $m.Value
    Write-Log ("index_js_ref={0}" -f $ref)
    $js = Join-Path $AppRoot ('wwwroot\' + ($ref -replace '/', '\'))
    Write-ObjectBlock (Show-FileHashRow $js)
  } else {
    Write-Log 'Nenhuma referencia assets/index-*.js em index.html'
  }
}

Write-Section 'FLAG PedidosInternosEnabled'
$flagApp = Get-PedidosInternosFlag (Join-Path $AppRoot 'appsettings.json')
$flagProd = Get-PedidosInternosFlag (Join-Path $AppRoot 'appsettings.Production.json')
Write-Log ("appsettings.json={0}" -f $flagApp)
Write-Log ("appsettings.Production.json={0}" -f $flagProd)

try {
  $envVars = Get-WebConfigurationProperty -PSPath ("IIS:\AppPools\{0}" -f $PoolName) `
    -Filter 'environmentVariables' -Name '.' -ErrorAction SilentlyContinue
  if ($envVars -and $envVars.Collection) {
    $matched = $envVars.Collection |
      Where-Object { $_.name -match 'Portal__Cliente__PedidosInternosEnabled|ASPNETCORE_ENVIRONMENT' } |
      Select-Object name, value
    if ($matched) {
      Write-TableBlock $matched
    } else {
      Write-Log '(App Pool env: sem Portal__Cliente__PedidosInternosEnabled nem ASPNETCORE_ENVIRONMENT)'
    }
  } else {
    Write-Log '(sem environmentVariables no App Pool, ou filtro indisponivel)'
  }
} catch {
  Write-Log ('(App Pool env: {0})' -f $_.Exception.Message)
}

Write-Log 'Runtime_efectivo_flag=NAO_CONFIRMADO_por_inspeccao_ficheiros'

Write-Section 'PRESERVAR / SQL META (sem segredos)'
$prodJson = Join-Path $AppRoot 'appsettings.Production.json'
if (Test-Path -LiteralPath $prodJson) {
  Write-ObjectBlock (Show-FileHashRow $prodJson)
  try {
    $pj = Get-Content -LiteralPath $prodJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $keys = $null
    if ($pj.DataProtection) { $keys = $pj.DataProtection.KeysPath }
    if ($keys) {
      Write-Log ("DataProtection.KeysPath={0}" -f $keys)
      Write-Log ("DataProtection.KeysPath.Exists={0}" -f (Test-Path -LiteralPath $keys))
    } else {
      Write-Log 'DataProtection.KeysPath=KEY_MISSING'
    }
    $cs = $null
    if ($pj.Phc) { $cs = [string]$pj.Phc.ConnectionString }
    if ($cs) {
      $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $cs
      $auth = if ($b.IntegratedSecurity) { 'Integrated' } else { 'SqlUser' }
      Write-Log ("SqlServer={0}" -f $b.DataSource)
      Write-Log ("Database={0}" -f $b.InitialCatalog)
      Write-Log ("Auth={0}" -f $auth)
      Write-Log ("UserId_present={0}" -f [bool]$b.UserID)
    } else {
      Write-Log 'Phc.ConnectionString=ausente_neste_ficheiro'
    }
  } catch {
    Write-Log ('Parse Production.json: {0}' -f $_.Exception.Message)
  }
} else {
  Write-Log 'appsettings.Production.json MISSING'
}

$extras = Get-ChildItem -LiteralPath $AppRoot -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'TEMPLATE|LEIA-ME|\.bak$' } |
  Select-Object Name, Length, LastWriteTime
Write-TableBlock $extras

Write-Section 'BACKUPS (heuristica local)'
$parent = Split-Path -Parent $AppRoot
$candidates = @(
  (Join-Path $parent 'backups'),
  'C:\Backups',
  'D:\Backups'
)
$anyBackup = $false
foreach ($dir in $candidates) {
  if (Test-Path -LiteralPath $dir) {
    $anyBackup = $true
    Write-Log ("DIR {0}" -f $dir)
    $items = Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 10 Name, Mode, LastWriteTime, Length
    Write-TableBlock $items
  }
}
if (-not $anyBackup) {
  Write-Log 'Nenhuma pasta de backups encontrada nas heurísticas (confirmar com IT).'
}

Write-Log ''
Write-Log 'FIM inventario read-only.'

if ($OutFile) {
  $script:LogLines | Set-Content -LiteralPath $OutFile -Encoding UTF8
  Write-Log ("Gravado: {0}" -f $OutFile)
}
