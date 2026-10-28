# Produção — checklist DBA / backup / flag

| | |
| --- | --- |
| Projecto | Liliana & Seródio — Portal Mobile (Pedidos Internos) |
| Host IIS | `<IIS_HOST>` (inventário IT) |
| Site | `<IIS_SITE>` → `<IIS_APP_PATH>` · pool `<IIS_APP_POOL>` · binding no inventário |
| SQL | `<SQL_HOST>` · BD `<PHC_DB>` · autenticação conforme inventário |
| Commit/tag app alvo | **Preencher no dia** (release autorizado — não fixar hash neste doc) |
| Actualizado (modelo) | Preencher data de uso: _______________ |
| Âmbito deste ficheiro | Gates de backup, diagnóstico **[RO]** e decisão de flag — **sem** substituir o runbook de aplicação |
| Runbook de aplicação | [`prod-passo-a-passo-aplicar-pedidos-mobile.md`](./prod-passo-a-passo-aplicar-pedidos-mobile.md) |
| Índice curto | [`prod-aplicar-pedidos-mobile-simples.md`](./prod-aplicar-pedidos-mobile-simples.md) |

> Valores reais de ambiente: **inventário IT**, fora do Git.
>
> Não colar passwords nem connection strings completas neste documento.
>
> Rótulos: **[RO — leitura]** · **[WRITE — requer autorização]**.

---

## 0. Inventário IIS — **[RO — leitura]** (preencher após inventário autorizado)

| Item | Valor / evidência (preencher) |
| --- | --- |
| Path app | `<IIS_APP_PATH>` / observado: ________ |
| Ambiente ASP.NET | ________ (ex. Production em `web.config`) |
| Build actual vs release alvo | Hashes / bundle observados: ________ |
| WebDAV remove no `web.config` | True / False: ________ |
| `appsettings.Production.json` | Existe — **preservar** ☐ |
| Data Protection (`dp-keys`) | Existe — **preservar** ☐ |
| Flag em ficheiro/env | Secção `Portal:Cliente` presente? ________ |
| Runtime flag | Confirmado / default código: ________ |
| Pasta de backups IIS | Existe? path inventário: ________ |

---

## 1. Backup — obrigatório antes de qualquer SQL de escrita

Preencher **antes** de 098/099/100/097 em produção.

| # | Pergunta | Resposta | Quem / data |
| --- | --- | --- | --- |
| B1 | Backup **completo** da BD `<PHC_DB>` em `<SQL_HOST>`? | sim / não | |
| B2 | Data/hora do backup | | |
| B3 | Local (path/media) — sem segredos no Git | *(anotar no inventário interno)* | |
| B4 | Responsável | | |
| B5 | Procedimento de **restauro** conhecido? | | |
| B6 | Restauro já testado nesta infra? | sim / não / nunca | |
| B7 | Backup filesystem IIS (app + `appsettings.Production.json` + `dp-keys`)? | | |
| B8 | Janela de manutenção acordada? | | |

**GO parcial backup:** B1–B5 = sim. Sem isto → **NO-GO** para scripts de escrita.

### Comando SSMS (exemplo — DBA adapta paths) — **[WRITE — requer autorização]**

```sql
-- EXEMPLO apenas — DBA confirma path e política.
-- NÃO executar sem autorização e path válidos.
/*
BACKUP DATABASE [<PHC_DB>]
TO DISK = N'<BACKUP_SHARE>\<PHC_DB>_pre_pm_YYYYMMDD.bak'
WITH COPY_ONLY, COMPRESSION, STATS = 10;
*/
```

---

## 2. Diagnóstico SQL read-only — **[RO — leitura]** (G2)

No **SSMS** ligado a `<SQL_HOST>` → base `<PHC_DB>` (confirmar nome exacto no inventário).

Ordem:

1. `sql/103_precheck_sp_mobile_edebito_readonly.sql` (curto — TYPE/SP/`portal_app`)
2. `sql/102_diagnose_pedidos_mobile_uat_readonly.sql` — pelo menos secção **A** (objectos, colunas 098/099, grants indicativos)

**Proibido nesta secção:** 098, 099, 100, 097, qualquer `ALTER`/`GRANT`/`DROP`.

| # | Objecto / tema | Resultado (SIM/NÃO/parcial) | Notas | Quem / data |
| --- | --- | --- | --- | --- |
| D1 | `u_HcaPmPedido` | | | |
| D2 | `u_HcaPmPedidoLin` | | | |
| D3 | `HCA_PedidoMobileLinhaType` | | | |
| D4 | `sp_HCA_criar_pedido_mobile` | | | |
| D5 | Colunas 098 (`MotivoRejeicao`, `DecididoPor`, `DataDecisao`) | | | |
| D6 | Coluna 099 (`PrecoSubmissao`) | | | |
| D7 | TVP tem `edebito`? (pós-100) | | | |
| D8 | Login/user `portal_app` | | | |
| D9 | Grants efectivos `portal_app` (parecer DBA) | | | |
| D10 | Grants Kapps (`u_Kapps_*` / views) — falta SELECT? | | | |

Anexar output de **103** + **102 secção A** no inventário interno (não obrigatório no Git).

---

## 3. Decisão da flag `Portal:Cliente:PedidosInternosEnabled`

| Opção | Quando | Acção |
| --- | --- | --- |
| **A — Manter off (recomendado durante SQL + publish)** | Durante SQL + publish + WebDAV | Não mexer em config; default `false` |
| **B — Forçar `false` explícito** | Queres valor visível no ficheiro | Só após GO de publicação, em `appsettings.Production.json` (não via Git) |
| **C — Activar `true`** | SQL 098–100 OK (se aplicável) + app do release autorizado + WebDAV + smoke | Decisão de negócio **por escrito** |

| Campo | Valor (preencher no dia) |
| --- | --- |
| Decisão agora | A / B / C: ________ |
| Quem autoriza | ________ |
| Data | ________ |
| Activação C só depois de | backup + SQL leitura OK + publish autorizado + smoke |

**Regra:** não activar C neste checklist sem autorização de negócio.

---

## 4. Sequência futura — **[WRITE — requer autorização]** (ainda NÃO executar neste documento)

Só quando secções 1–2 estiverem GO e houver autorização escrita. Detalhe operacional: **runbook principal**.

1. Backup B1–B7
2. SQL escrita (ordem): `098` → `099` → `103` recheck → `100` → `097` **só se** D9/D10 / DBA indicar grants em falta
3. Backup filesystem IIS
4. Publicar release autorizado **preservando** `appsettings.Production.json` + `dp-keys` + WebDAV do pacote
5. Smoke HTTP (PUT sem auth → 401; com auth → 200 quando aplicável)
6. Só então decidir flag C se negócio pedir


---

## 5. Gates

| Gate | Critério | Estado (preencher) |
| --- | --- | --- |
| G0 Inventário IIS | Secção 0 | ☐ |
| G1 Backup BD | B1–B5 | ☐ |
| G2 Diagnóstico SQL 102A+103 | tabela §2 preenchida | ☐ |
| G3 Autorização escrita SQL | ticket/email | ☐ |
| G4 Publish (release autorizado) | após G1–G3 | ☐ |
| G5 Flag `true` | após smoke + negócio | ☐ |

**Produção não pronta** para escrita enquanto G1–G2 (e G3 para SQL WRITE) estiverem abertos.
