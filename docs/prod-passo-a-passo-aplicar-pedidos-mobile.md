# Passo a passo — aplicar Pedidos Mobile em produção

| | |
| --- | --- |
| Projecto | Liliana & Seródio — Portal Mobile |
| Papel | **Fonte canónica** dos procedimentos de deployment dos Pedidos Mobile (PM) |
| Host IIS | `<IIS_HOST>` (inventário IT) |
| Site / path | `<IIS_SITE>` → `<IIS_APP_PATH>` · pool `<IIS_APP_POOL>` · binding HTTP actual no inventário |
| SQL | `<SQL_HOST>` · BD `<PHC_DB>` · autenticação conforme inventário IT |
| Release app | **Commit/tag explicitamente autorizado no dia do deployment** (não fixar hash neste documento) |
| Flag | **A — off** até smoke OK + autorização de negócio |
| Checklist paralelo | [`prod-checklist-dba-pedidos-internos-pos-inventario.md`](./prod-checklist-dba-pedidos-internos-pos-inventario.md) |
| HTTPS / QR | [`prod-https-portal-passo-a-passo.md`](./prod-https-portal-passo-a-passo.md) (actividade distinta do deploy PM) |
| Índice curto | [`prod-aplicar-pedidos-mobile-simples.md`](./prod-aplicar-pedidos-mobile-simples.md) |
| Entrega UAT (referência) | [`entrega-tecnica-pedidos-mobile-uat.md`](./entrega-tecnica-pedidos-mobile-uat.md) |

> **Valores de ambiente** (hosts, IPs, nomes de BD, paths IIS, utilizadores SQL): obter no **inventário IT autorizado**, mantido **fora do Git**. Não colar passwords, tokens nem connection strings completas neste documento.
>
> **Este documento é o runbook de aplicação.** Não executar passos de escrita sem autorização explícita no dia.
>
> Rótulos usados abaixo: **Leitura** · **Preparação** · **Execução — altera produção** · **Rollback**.

---

## Caminho curto (portal já instalado)

Se o site IIS do Portal já existe e a empresa ainda não opera pedidos internos, a sequência conceptual é:

| # | O quê | Detalhe obrigatório |
| --- | --- | --- |
| 1 | Backup BD + cópia datada da pasta app | Fase 0 (**Preparação**) |
| 2 | SSMS: diagnóstico RO; SQL de escrita só se GO | Fases 1–2 |
| 3 | Gerar release a partir do commit/tag **autorizado no dia** | Fase 3 |
| 4 | Publicar na pasta app **sem** tocar em `appsettings.Production.json` nem em `dp-keys` | Fase 4 (**Execução — altera produção**) |
| 5 | Smoke no browser + PUT sem auth → **401** (não 405); flag continua **off** | Fase 5 |
| 6 | Flag `true` só quando o negócio autorizar | Fase 6 |

**Não saltar:** preservar `Production.json` / `dp-keys`; publicar só artefacto do release autorizado (incl. WebDAV no `web.config` gerado); não activar a flag até haver decisão de negócio.

Para execução e rollback, usar **sempre** as fases abaixo — não improvisar a partir deste resumo.

---

## Estado ao retomar (preencher no dia)

| Gate | Estado (preencher) |
| --- | --- |
| G0 Inventário IIS | ☐ / DONE — data: ________ |
| G1 Backup BD | ☐ / DONE — data: ________ |
| Flag decisão A (off) | ☐ / DONE — data: ________ |
| G2 Diagnóstico SQL 103 + 102A | ☐ — começar aqui se pendente |
| G3 Autorização escrita SQL | ☐ |
| G4 Publish (release autorizado) | ☐ bloqueado até G2–G3 |
| G5 Flag `true` | ☐ bloqueado até smoke + negócio |

---

## Regras de ouro

1. **Não** substituir `<IIS_APP_PATH>\appsettings.Production.json`.
2. **Não** apagar / sobrescrever a pasta de Data Protection (`dp-keys` no inventário; tipicamente ao lado da app).
3. **Não** activar `Portal:Cliente:PedidosInternosEnabled` neste runbook (fica off até à Fase 6).
4. **Não** correr `090_seed_clone_encomendas_teste.sql` em produção.
5. **Não** assumir que UAT = produção (BDs e hosts distintos).
6. Publicação: só artefactos do release gerado a partir do **commit/tag autorizado no dia** (ou commit posterior que o IT/Dev confirme incluir o mesmo conteúdo necessário — WebDAV, circuito PM, etc.).
7. Se algo falhar a meio do SQL: **parar** → restauro do backup → não “continuar a tentar” scripts parcialmente.

---

## Fase 0 — Preparação no dia (**Preparação**, 15–30 min)

| # | Acção | Quem | Done |
| --- | --- | --- | --- |
| 0.1 | Confirmar RDP a `<IIS_HOST>` + SSMS a `<SQL_HOST>` | IT | ☐ |
| 0.2 | Confirmar que o backup BD ainda é válido / fazer **novo** backup se > janela acordada | DBA | ☐ |
| 0.3 | Anotar data/hora/local do backup (checklist B2–B3) — **fora do Git** se incluir paths sensíveis | DBA | ☐ |
| 0.4 | Backup filesystem da pasta `<IIS_APP_PATH>` (cópia datada sob a pasta de backups do inventário) | IT | ☐ |
| 0.5 | Confirmar que `dp-keys` e `appsettings.Production.json` estão na cópia | IT | ☐ |
| 0.6 | Máquina de **build**: clone/checkout do **commit/tag autorizado**, .NET 8 SDK, Node 20+ | Dev | ☐ |
| 0.7 | Autorização escrita para SQL 098→099→100 (+ 097 **só se** G2 o exigir) | Gestor/IT | ☐ |
| 0.8 | Janela de manutenção comunicada | IT | ☐ |

**Release autorizado (preencher no dia — não inventar):**

| Campo | Valor |
| --- | --- |
| Commit ou tag | _______________ |
| Quem autorizou | _______________ |
| Data | _______________ |

---

## Fase 1 — Diagnóstico SQL read-only (G2) — **Leitura**

No SSMS: servidor `<SQL_HOST>`, base **`<PHC_DB>`** seleccionada.

| # | Script | Escrita? | Critério GO |
| --- | --- | --- | --- |
| 1.1 | `sql/103_precheck_sp_mobile_edebito_readonly.sql` | Não | TYPE + SP existem; `portal_app` existe (ou plano explícito); sem execuções bloqueantes |
| 1.2 | `sql/102_diagnose_pedidos_mobile_uat_readonly.sql` (secção **A** no mínimo) | Não | Baseline mobile presente; ver se 098/099/100 já estão ou não |

**Interpretação rápida**

| Se G2 mostrar… | Então… |
| --- | --- |
| Sem `u_HcaPmPedido` / SP mobile | **NO-GO** desta fatia — falta baseline mobile (fora deste runbook) |
| Baseline OK, **sem** colunas 098/099, TVP **sem** `edebito` | Caminho normal → Fase 2 (aplicar 098→099→100) |
| Colunas 098/099 já existem e TVP já tem `edebito` | **Não** reaplicar 098–100 às cegas — só publish app + WebDAV |
| `portal_app` ausente | Resolver user/grants **antes** ou **com** plano DBA — não publicar app a depender de SP sem EXECUTE |
| Grants Kapps / `portal_app` em falta (parecer DBA) | Planear `sql/097_grant_kapps_portal_app.sql` como passo **condicional** na Fase 2.5 |

Preencher tabela §2 do checklist DBA. Só avançar com G2 + G3.

---

## Fase 2 — SQL de escrita — **Execução — altera produção** (só com G2 GO + autorização)

Ordem **obrigatória** para os scripts de schema/SP. Um script de cada vez. Verificar Messages sem erro antes do seguinte.

| Ordem | Ficheiro | O que faz | Pós-check |
| --- | --- | --- | --- |
| 2.1 | `sql/098_alter_u_HcaPmPedido_decisao_staff.sql` | Colunas decisão staff + índice | `COL_LENGTH` / 102 A2b |
| 2.2 | `sql/099_alter_u_HcaPmPedidoLin_preco_submissao.sql` | `PrecoSubmissao` + backfill + grant | Coluna existe |
| 2.3 | `sql/103_precheck_sp_mobile_edebito_readonly.sql` | Recheck antes do DROP TVP (**Leitura**) | Sem sessões a usar o TYPE |
| 2.4 | `sql/100_alter_sp_HCA_criar_pedido_mobile_edebito_opcional.sql` | Recria TVP+SP com `edebito` opcional | 103: coluna `edebito` no TYPE; EXECUTE a `portal_app` |
| 2.5 | `sql/097_grant_kapps_portal_app.sql` | **Só se** G2/DBA indicar grants Kapps/`portal_app` em falta | Parecer DBA — **não** é passo universal |

**Proibido:** `090_seed_*`, packs não relacionados, alterar flag na BD.

Se 2.4 falhar a meio: parar → restauro backup BD → reavaliar (não aplicar 100 outra vez sobre estado desconhecido).

---

## Fase 3 — Gerar release na máquina de build — **Preparação**

```powershell
cd <REPO_ROOT>
git rev-parse HEAD
# Confirmar que HEAD (ou tag checked-out) = release autorizado no dia (Fase 0)

.\tools\publish-release.ps1 -OutDir "$env:TEMP\portal-release-prod-$(Get-Date -Format 'yyyyMMdd-HHmm')"
```

Verificar no OutDir:

| Check | Esperado |
| --- | --- |
| `Portal.Api.dll` / `Portal.Infrastructure.dll` | Existem |
| `wwwroot\index.html` + `assets\index-*.js` | Existem |
| `web.config` | `ASPNETCORE_ENVIRONMENT=Production` + removes WebDAV / WebDAVModule |
| `appsettings.Production.json` | **Ausente** no pacote (normal — segredos ficam no servidor) |
| TEMPLATE / LEIA-ME | Presentes |

### Evidência da release (preencher / arquivar fora do Git se necessário)

| Artefacto | SHA256 (máquina de build) |
| --- | --- |
| `Portal.Api.dll` | _______________ |
| `Portal.Infrastructure.dll` | _______________ |
| `web.config` | _______________ |
| Commit/tag | _______________ |

Copiar a pasta (ou zip) para o servidor (USB/RDP/partilha).

---

## Fase 4 — Publicar no IIS — **Execução — altera produção**

Path actual: `<IIS_APP_PATH>` no host `<IIS_HOST>`.

### 4.1 Antes de copiar — **Preparação**

| # | Acção | Done |
| --- | --- | --- |
| 4.1.1 | Confirmar backup filesystem (Fase 0.4) | ☐ |
| 4.1.2 | Guardar à parte (fora da pasta a sobrescrever): `appsettings.Production.json` | ☐ |
| 4.1.3 | **Não** tocar na pasta `dp-keys` | ☐ |
| 4.1.4 | Opcional: `Stop-WebAppPool -Name <IIS_APP_POOL>` (só se política IT permitir downtime curto) | ☐ |

### 4.2 Cópia (robocopy recomendado)

Exemplo (ajusta `$src` e paths do inventário):

```powershell
$src = '<RELEASE_PACKAGE_PATH>'   # pasta gerada na Fase 3
$dst = '<IIS_APP_PATH>'
$bak = '<IIS_BACKUP_ROOT>\api-backup-$(Get-Date -Format ''yyyyMMdd-HHmmss'')'

New-Item -ItemType Directory -Force -Path (Split-Path $bak) | Out-Null
robocopy $dst $bak /E /NFL /NDL /NJH /NJS

# Copiar release SEM apagar Production.json nem pastas locais sensíveis
robocopy $src $dst /E /XF appsettings.Production.json /XD logs

# Se o robocopy tiver removido/ausentado Production.json por engano:
# Copy-Item <backup>\appsettings.Production.json $dst -Force
```

Confirmar depois:

```powershell
Test-Path '<IIS_APP_PATH>\appsettings.Production.json'
Test-Path '<DP_KEYS_PATH>'
Select-String -Path '<IIS_APP_PATH>\web.config' -Pattern 'WebDAV|ASPNETCORE_ENVIRONMENT'
```

Esperado: Production.json **True**; dp-keys **True**; WebDAV remove presente; env Production.

### 4.3 Arranque — **Execução — altera produção**

```powershell
Start-WebAppPool -Name <IIS_APP_POOL>   # se tinhas parado
# NÃO iisreset a menos que IT exija
```

### 4.4 Hashes (evidência)

No servidor, comparar com a tabela da Fase 3:

```powershell
Get-FileHash '<IIS_APP_PATH>\Portal.Api.dll' -Algorithm SHA256
Get-FileHash '<IIS_APP_PATH>\Portal.Infrastructure.dll' -Algorithm SHA256
Get-FileHash '<IIS_APP_PATH>\web.config' -Algorithm SHA256
```

---

## Fase 5 — Smoke (flag ainda off) — **Leitura** / validação

Com flag **off**, o circuito de fila interna staff não deve estar activo para clientes. Mesmo assim validar:

| # | Teste | Esperado |
| --- | --- | --- |
| 5.1 | Abrir portal no browser (URL de prod do inventário) | SPA carrega |
| 5.2 | Login staff / cliente (contas reais de prod — cuidado) | OK |
| 5.3 | PUT preço **sem** auth (se endpoint exposto) | **401** (prova WebDAV não engole com 405) |
| 5.4 | Fluxos críticos **já existentes** (encomendas, não pedidos internos) | Sem regressão óbvia |
| 5.5 | Event Viewer / `logs\stdout` se falha arranque | Sem crash de config |

Pedidos internos end-to-end (aprovar/rejeitar/preço) → **só** depois de G5 (flag `true`) e autorização de negócio.

HTTPS / câmara QR no telemóvel: ver [`prod-https-portal-passo-a-passo.md`](./prod-https-portal-passo-a-passo.md) — **não** bloqueia o publish PM, mas bloqueia QR móvel até estar resolvido.

---

## Fase 6 — Flag (mais tarde, opcional) — **Execução — altera produção**

Só com smoke OK + decisão de negócio:

1. Em `appsettings.Production.json` no servidor, secção:

```json
"Portal": {
  "Cliente": {
    "PedidosInternosEnabled": true
  }
}
```

2. Reciclar só o App Pool: `Restart-WebAppPool -Name <IIS_APP_POOL>` (ou Stop/Start).
3. Confirmar valor (inventário / leitura só desta chave).
4. Testes funcionais staff (aprovar / rejeitar / PUT preço autenticado → 200).

Para **desligar** de emergência: pôr `false` + reciclar pool (sem republish).

---

## Fase 7 — Rollback

| Cenário | Acção |
| --- | --- |
| App má / 500 após publish | Parar pool → restaurar pasta app do backup filesystem → Start pool; **não** mexer em `dp-keys` se o backup os tiver correctamente |
| SQL falhou / dados incorrectos | Restauro BD a partir do backup da Fase 0/1 (DBA) |
| WebDAV 405 | Confirmar `web.config` do **mesmo** release autorizado; não “inventar” removes à mão sem diff |
| Flag problemática | `PedidosInternosEnabled: false` + recycle |

Exemplo de restauro filesystem (ajusta paths do inventário):

```powershell
# Rollback — Execução — altera produção
robocopy '<IIS_BACKUP_ROOT>\api-backup-XXXX' '<IIS_APP_PATH>' /E
Restart-WebAppPool -Name <IIS_APP_POOL>
```

---

## Resumo visual

```text
[Retomar]
   │
   ▼
Fase 0 Prep + backup fresco se preciso
   │
   ▼
Fase 1  103 + 102A  (só leitura)     ← G2
   │
   ▼ GO?
Fase 2  098 → 099 → 103 → 100 → (097 só se grants em falta)
   │
   ▼
Fase 3  publish-release.ps1 (release autorizado no dia)
   │
   ▼
Fase 4  robocopy p/ <IIS_APP_PATH>
        (preservar Production.json + dp-keys)
   │
   ▼
Fase 5  Smoke (flag OFF)
   │
   ▼
Fase 6  Flag true  (só com negócio)
```

---

## Contactos / preenchimento no dia

| Papel | Nome | Contacto |
| --- | --- | --- |
| IT / IIS | | |
| DBA | | |
| Negócio (flag) | | |
| Execução app | | |

Data de execução: _______________

Resultado final: GO / NO-GO / rollback ________________
