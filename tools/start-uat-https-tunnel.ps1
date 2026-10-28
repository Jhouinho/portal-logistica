<#
.SYNOPSIS
  Expõe o PortalLocal UAT em HTTPS público (certificado Cloudflare),
  para testar no telemóvel o mesmo comportamento de produção (câmara QR sem instalar nada).

.DESCRIPTION
  Requer: cloudflared (winget install Cloudflare.cloudflared) e site PortalLocal em :8088.
  O URL muda a cada arranque (quick tunnel). Em appsettings.Production.json deve existir
  AllowedHosts com *.trycloudflare.com.

  AVISO DE SEGURANÇA: o hostname *.trycloudflare.com é público e temporário. Quem conhecer
  o URL pode tentar aceder à app através do túnel. Isto NÃO substitui autenticação da
  aplicação nem AllowedHosts corretos. Usar apenas em UAT com autorização explícita de IT —
  não é publicação permanente nem produção. Parar com Ctrl+C após os testes.

.PARAMETER Origin
  Origem HTTP local a expor (predefinido: PortalLocal em 127.0.0.1:8088).

.PARAMETER ProductionJsonPath
  Caminho de appsettings.Production.json para verificar AllowedHosts (só aviso; não altera o ficheiro).

.EXAMPLE
  .\tools\start-uat-https-tunnel.ps1

.EXAMPLE
  .\tools\start-uat-https-tunnel.ps1 -ProductionJsonPath 'D:\outro\appsettings.Production.json'
#>
[CmdletBinding()]
param(
  [string]$Origin = 'http://127.0.0.1:8088',
  [string]$ProductionJsonPath = 'C:\inetpub\portal-local\api\appsettings.Production.json'
)

$ErrorActionPreference = 'Stop'
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
  [System.Environment]::GetEnvironmentVariable('Path', 'User')

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
  throw 'cloudflared não encontrado. Instale: winget install --id Cloudflare.cloudflared -e'
}

# Validar caminho do Production.json (não imprimir conteúdo nem segredos)
if ([string]::IsNullOrWhiteSpace($ProductionJsonPath)) {
  Write-Warning 'ProductionJsonPath vazio — a verificação de AllowedHosts foi omitida.'
}
elseif (-not (Test-Path -LiteralPath $ProductionJsonPath)) {
  Write-Warning "Ficheiro appsettings.Production.json não encontrado: $ProductionJsonPath. Verifique AllowedHosts (*.trycloudflare.com) manualmente e reinicie o App Pool se alterar."
}
else {
  # Apenas procura o padrão AllowedHosts; não regista o resto do JSON
  $raw = Get-Content -LiteralPath $ProductionJsonPath -Raw
  if ($raw -notmatch '\*\.trycloudflare\.com') {
    Write-Warning "Adicione '*.trycloudflare.com' a AllowedHosts em $ProductionJsonPath e reinicie o App Pool."
  }
}

Write-Host @"

=== AVISO DE SEGURANÇA (túnel UAT) ===
- O URL https://….trycloudflare.com é PÚBLICO e TEMPORÁRIO.
- Qualquer pessoa que conheça o URL pode tentar aceder à aplicação através do túnel.
- Autenticação da app + AllowedHosts corretos continuam obrigatórios; o URL não é controlo de acesso.
- É necessária autorização explícita de IT antes de iniciar.
- Destinado a testes UAT autorizados — NÃO é publicação permanente nem produção.
- Quando terminar: Ctrl+C para interromper o túnel.

Portal UAT via túnel HTTPS (cenário tipo produção para câmara QR)
Origin: $Origin
ProductionJsonPath: $ProductionJsonPath

1) Copie o URL https://….trycloudflare.com que aparecer abaixo
2) Abra-o no Safari/Chrome do telemóvel (dados móveis ou Wi‑Fi)
3) Login → Novo pedido → Ler QR Code → autorizar câmara
4) Ctrl+C para parar o túnel

"@ -ForegroundColor Cyan

cloudflared tunnel --url $Origin --no-autoupdate
