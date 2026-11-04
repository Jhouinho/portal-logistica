# Produção — deploy Pedidos Mobile circuito balcão (1B + 2C)

| | |
| --- | --- |
| Projecto | Liliana & Seródio — Portal |
| Data referência | 2026-11-04 |
| Objectivo | Publicar simplificação PM (balcão) no IIS de produção |
| Estados / regras | [`portal-mobile-estados.md`](./portal-mobile-estados.md) |
| Runbook PM geral | [`prod-passo-a-passo-aplicar-pedidos-mobile.md`](./prod-passo-a-passo-aplicar-pedidos-mobile.md) |

> **Não** substituir `appsettings.Production.json` nem a pasta `dp-keys`.

---

## Circuito (negócio)

1. Cliente regista produtos e recolhe artigos.
2. Cliente submete pedido → fila `u_HcaPmPedido` (**sem** BO67 na submissão).
3. Cliente vai ao balcão com os artigos.
4. Operador valida / ajusta preços / rejeita ou **Valida** → cria dossier PHC `ndos=67`.
5. Faturação do dossier **no PHC CS** (fora do portal). Fim.

Removido da UI/API activa: Em separação → Pronto p/ levantamento → Concluir.

---

## Já feito neste servidor (não repetir às cegas)

Verificar antes de voltar a correr SQL/flag:

| Item | Estado esperado | Como confirmar |
| --- | --- | --- |
| Tabelas PM | `u_HcaPmPedido` / `u_HcaPmPedidoLin` | `OBJECT_ID` NOT NULL |
| Colunas 098/099 | `MotivoRejeicao`, `DecididoPor`, `DataDecisao`, `PrecoSubmissao` | `COL_LENGTH` NOT NULL |
| Grants | `096c` + `105` | staff lista sem erro SQL |
| Flag | `Portal:Cliente:PedidosInternosEnabled: true` | ler `appsettings.Production.json` |
| Picking hotfix | origem SQL NULL + fix newline/`--` | `/api/v1/picking-dossiers` → 200 (release ~1617+) |

Scripts SQL já aplicados (referência): `096`, `096b`, `096c`, `098`, `099`, `105`.

---

## Alterações de código a publicar

### Pedidos Mobile — balcão

| Área | Alteração |
| --- | --- |
| UI lista/detalhe | Tabs: Pendentes / Validados / Rejeitados / Todos; sem separação/levantamento |
| UI CTA | «Validar no balcão e criar dossier PHC» |
| Operador mobile | Mesmas tabs/acções; sem botões operacao |
| Mapper | Pós-BO → código/etiqueta **Validado** |
| API `POST …/operacao` | **400** (circuito balcão; faturação no PHC) |
| DTO flags | `podeMarcarProntoLevantamento` / `podeMarcarConcluido` = false |
| Docs | `portal-mobile-estados.md` |

Ficheiros principais:

- `src/frontend/src/features/pedidos-mobile/PedidosMobileListPage.tsx`
- `src/frontend/src/features/pedidos-mobile/PedidosMobileDetailPage.tsx`
- `src/frontend/src/features/operador/OperadorPedidoDetailView.tsx`
- `src/frontend/src/features/operador/operadorUi.tsx`
- `src/backend/src/Portal.Application/Cliente/ClientePedidoEstadoMapper.cs`
- `src/backend/src/Portal.Infrastructure/Cliente/StaffPmPedidosService.cs`
- `src/backend/src/Portal.Api/Controllers/StaffPmPedidosController.cs`
- `src/backend/src/Portal.Api/Errors/PortalExceptionHandler.cs` (Development com detalhe; **Production genérico**)

### Incluir no mesmo release (já em prod ou consolidar)

| Item | Nota |
| --- | --- |
| Hotfix `picking-dossiers` | `PickingDossiersOrigemSql` origem NULL + `\n` antes do CAST (evita `--` a engolir colunas) |
| Vite `allowedHosts` | Só relevante em `npm run dev` / túnel; **irrelevante no IIS** (SPA estático) |

---

## Passos no dia do deploy

### 1) Build (máquina de desenvolvimento)

```powershell
cd <REPO_LilianaSerodio>
.\tools\publish-release.ps1 -Zip
```

Artefacto: `releases\portal-YYYYMMDD-HHMM.zip` → copiar para `C:\Temp\` no servidor.

### 2) Publicar IIS (servidor)

Preservar Production.json; parar pool antes do robocopy (evitar ficheiros bloqueados):

```powershell
$pool='PortalAppPool'; $stamp='portal-YYYYMMDD-HHMM'  # ajustar
$src="C:\inetpub\portal\$stamp"; $dst='C:\inetpub\portal\api'
$bak="C:\inetpub\portal\backup-api-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$zip="C:\Temp\$stamp.zip"
Import-Module WebAdministration
if(Test-Path $src){Remove-Item $src -Recurse -Force}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip,$src)
Copy-Item "$dst\appsettings.Production.json" "$env:TEMP\appsettings.Production.json.bak" -Force
Stop-WebAppPool -Name $pool
do{Start-Sleep 1}while((Get-WebAppPoolState -Name $pool).Value -ne 'Stopped')
robocopy $dst $bak /E /NFL /NDL /NJH /NJS | Out-Null
robocopy $src $dst /E /XF appsettings.Production.json /XD logs
if(-not (Test-Path "$dst\appsettings.Production.json")){
  Copy-Item "$env:TEMP\appsettings.Production.json.bak" "$dst\appsettings.Production.json" -Force
}
Start-WebAppPool -Name $pool
Start-Sleep 4
```

Confirmar flag (se ainda não estiver):

```powershell
(Get-Content 'C:\inetpub\portal\api\appsettings.Production.json' -Raw | ConvertFrom-Json).Portal.Cliente.PedidosInternosEnabled
# Esperado: True
```

### 3) Smoke

| # | Teste | Esperado |
| --- | --- | --- |
| 1 | `GET /health` | 200 |
| 2 | `GET /api/v1/picking-dossiers?fechada=false&checkIn=false&page=1&pageSize=5` | 200 |
| 3 | Staff → Pedidos Mobile | Tabs Pendentes / Validados / Rejeitados / Todos |
| 4 | Detalhe pendente | Validar + preços + rejeitar; **sem** «Pronto p/ levantamento» |
| 5 | Cliente submete pedido (flag on) | Fila PM; sem BO67 até Validar |
| 6 | Validar no balcão | Cria BO67; estado **Validado** |
| 7 | 500 genérico | `detail` = «Ocorreu um erro…» (sem SQL na resposta) |

### 4) Rollback

- App: restaurar pasta `backup-api-*` + recycle pool.
- Flag emergência: `PedidosInternosEnabled: false` + recycle (sem republish).
- SQL: não é necessário reverter 096–105 para este deploy de UI/API.

---

## Fora de âmbito deste deploy

- Endpoint «faturar» no portal.
- Script `100` (edebito SP) — só se criação legado/SP o exigir; circuito interno 1B não depende dele para a fila.
- HTTPS permanente / QR produção — ver `prod-https-portal-passo-a-passo.md`.
