# PHC — Vistas e procedimentos armazenados do Portal Logístico

> **Emenda 2026-09-29:** catálogo 0B abaixo. Autorização/alocação evoluíram para **previsão** (`068`/`069`/`082`) — menções a teto `ST.stock` / RN-018 neste ficheiro são **históricas**. SoT: [`docs/PROJECT-STATE.md`](../docs/PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Princípio | **Leituras = vistas SQL** · **Escritas = procedimentos armazenados** · a API consome via **Dapper** |
| Nomenclatura | Vistas: `view_HCA_[descricao]` · Procedimentos: `sp_HCA_[descricao]` |
| Série de encomendas (MVP) | `ndos = 1` (`SerieEncomendasNdos`) |

> Scripts versionados nesta pasta. Aplicar na base PHC (UAT → Produção) **depois** de criar os campos `U_*` (`001_user_fields.md`).

---

## Convenção oficial de nomes

| Tipo | Padrão | Exemplos |
| --- | --- | --- |
| Vista | `view_HCA_[descricao]` | `view_HCA_encomendas_abertas` |
| Procedimento | `sp_HCA_[descricao]` | `sp_HCA_atualizar_linha_qtt_preco` |

**Não usar:** `vw_portal_*`, `view_portal_*`, `usp_portal_*`, `sp_portal_*`, `SP_HCA_*`.

---

## Modelo de acesso

```text
Interface React
    ↓
API .NET 8
    ↓
Dapper
    ↓
view_HCA_* (leitura)  |  sp_HCA_* (escrita)
    ↓
Tabelas PHC (US, BO, BI, ST, CL, …)
```

### Regras

1. A API **não** espalha consultas SQL diretas sobre `BO`, `BI`, `ST`, `CL` ou `US`.
2. Leituras operacionais → `SELECT` nas **vistas** `view_HCA_*`.
3. Escritas operacionais (negócio / logística) → execução dos **procedimentos** `sp_HCA_*`.
4. A lógica SQL crítica (restante, série, `usr*`, totais) concentra-se na base de dados — reforça a **RN-022**.
5. Auth MVP = ASP.NET Identity (`u_HcaLogi*`) + gate `US.u_usaPort` (ver [`auth-portal-identity.md`](../docs/auth-portal-identity.md)).

> A regra geral é: views para leitura e stored procedures para escrita. A stored procedure `sp_HCA_validar_login` é uma exceção técnica permitida para encapsular o lookup de `US` (usercode + `u_usaPort`) no login do portal, não representando uma escrita de negócio.

---

## Catálogo oficial — tabelas Identity (`u_HcaLogi*`)

| Tabela | Script | Doc |
| --- | --- | --- |
| `u_HcaLogiUsers`, `u_HcaLogiRoles`, `u_HcaLogiUserRoles`, `u_HcaLogiUserClaims`, `u_HcaLogiUserLogins`, `u_HcaLogiUserTokens`, `u_HcaLogiRoleClaims` | [`029`](./029_create_u_HcaLogi_identity_tables.sql) · validação [`029b`](./029b_validate_u_HcaLogi_identity_tables.sql) | [fase-0b-u-HcaLogi-identity-tables.md](../docs/fase-0b-u-HcaLogi-identity-tables.md) · [auth-portal-identity.md](../docs/auth-portal-identity.md) |

Campo PHC associado: `US.u_usaPort` — [`028`](./028_add_us_u_usaPort.sql).

---

## Catálogo oficial — vistas de leitura (MVP)

### 1. `view_HCA_encomendas_abertas`

**Objetivo:** listagem de encomendas em aberto (uma linha por documento, totais agregados).

**Script versionado:** [`012_create_view_HCA_encomendas_abertas.sql`](./012_create_view_HCA_encomendas_abertas.sql)  
**Validação:** [`013_validate_view_HCA_encomendas_abertas.sql`](./013_validate_view_HCA_encomendas_abertas.sql)  
**Guia passo a passo (UAT → Produção):** [`docs/fase-0b-view-HCA-encomendas-abertas.md`](../docs/fase-0b-view-HCA-encomendas-abertas.md)

**Regras obrigatórias:**

- `BO.fecho = 0` (usar `ISNULL(bo.fecho, 0) = 0`)
- Série = `ndos = 1`
- Existe linha com **restante > 0**
- Restante = `ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2`
- **0** em `u_qttorig` / `u_prcorig` = original ainda não preenchido (`NOT NULL` no PHC)
- Representante / vendedor / `vendnm`: fora de âmbito (sem filtro)

**Colunas (agregado por documento):**

| Coluna na vista | Origem / cálculo |
| --- | --- |
| `bostamp` | `BO.bostamp` |
| `obrano` | `BO.obrano` |
| `ndos` | `BO.ndos` |
| `nmdos` | `BO.nmdos` |
| `dataobra` | `BO.dataobra` |
| `ousrhora` | `BO.ousrhora` |
| `cliente_no` | `BO.no` |
| `cliente_estab` | `BO.estab` |
| `cliente_nome` | `LTRIM(RTRIM(BO.nome))` |
| `total_linhas` | `COUNT(bi.bistamp)` das linhas em aberto |
| `quantidade_original_total` | `SUM(ISNULL(NULLIF(u_qttorig, 0), qtt))` |
| `quantidade_atual_total` | `SUM(BI.qtt)` |
| `quantidade_fornecida_total` | `SUM(BI.qtt2)` |
| `quantidade_restante_total` | `SUM(ISNULL(NULLIF(u_qttorig, 0), qtt) - qtt2)` |
| `quantidade_autorizada_total` | `SUM(BI.u_qtdaut)` |

**SQL oficial** (script `012`):

```sql
CREATE OR ALTER VIEW dbo.view_HCA_encomendas_abertas
AS
SELECT
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,
    COUNT(bi.bistamp) AS total_linhas,
    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,
    SUM(bi.qtt) AS quantidade_atual_total,
    SUM(bi.qtt2) AS quantidade_fornecida_total,
    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,
    SUM(bi.u_qtdaut) AS quantidade_autorizada_total
FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fecho, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
GROUP BY
    bo.bostamp, bo.obrano, bo.ndos, bo.nmdos, bo.dataobra, bo.ousrhora,
    bo.no, bo.estab, bo.nome;
```

**Consumo na API:** `GET /encomendas/abertas` → Dapper lê `view_HCA_encomendas_abertas` (com filtros seguros sobre a vista).

---

### 2. `view_HCA_encomenda_linhas`

**Objetivo:** detalhe das linhas de uma encomenda.

**Script versionado:** [`014_create_view_HCA_encomenda_linhas.sql`](./014_create_view_HCA_encomenda_linhas.sql)  
**Validação:** [`015_validate_view_HCA_encomenda_linhas.sql`](./015_validate_view_HCA_encomenda_linhas.sql)  
**Guia passo a passo (UAT → Produção):** [`docs/fase-0b-view-HCA-encomenda-linhas.md`](../docs/fase-0b-view-HCA-encomenda-linhas.md)

**Deve expor (mínimo aprovado + detalhe MVP):**

| Coluna na vista | Origem / cálculo |
| --- | --- |
| `bostamp` / `bistamp` | `BI` |
| `obrano` / `ndos` / `nmdos` / `dataobra` / `ousrhora` / `fecho` | `BO` |
| `cliente_no` / `cliente_estab` / `cliente_nome` | `BO.no` / `estab` / `nome` |
| `ref` / `design` | `BI` |
| `quantidade_atual` | `BI.qtt` |
| `quantidade_fornecida` | `BI.qtt2` |
| `quantidade_original_campo` | `BI.u_qttorig` |
| `quantidade_original_considerada` | `ISNULL(NULLIF(u_qttorig, 0), qtt)` |
| `quantidade_por_satisfazer` | `ISNULL(NULLIF(u_qttorig, 0), qtt) - qtt2` |
| `preco_unitario` | `BI.edebito` (RN-021) |
| `preco_original_campo` | `BI.u_prcorig` |
| `quantidade_autorizada` / `_por` / `_em` | `u_qtdaut` / `u_qtdautur` / `u_qtdautdt` |
| `stock_disponivel` | `ST.stock` (RN-018), `LEFT JOIN` por `ref` |
| `usrinis` / `usrdata` / `usrhora` | Última alteração da linha |

**Filtro da vista:** `BO.ndos = 1` (sem filtrar `fecho` / restante — a API filtra por `bostamp`).

**SQL oficial** (script `014`):

```sql
CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bostamp,
    bi.bistamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fecho, 0) AS fecho,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,
    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,
    bi.edebito AS preco_unitario,
    bi.u_prcorig AS preco_original_campo,
    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,
    ISNULL(st.stock, 0) AS stock_disponivel,
    LTRIM(RTRIM(bi.usrinis)) AS usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1;
```

**Consumo na API:** `GET /encomendas/{boStamp}` → filtrar `WHERE bostamp = @boStamp`.

---

### 3. `view_HCA_rastreio_artigos`

**Objetivo:** agregação da procura por artigo (ecrã Rastreio).

**Script versionado:** [`016_create_view_HCA_rastreio_artigos.sql`](./016_create_view_HCA_rastreio_artigos.sql)  
**Validação:** [`017_validate_view_HCA_rastreio_artigos.sql`](./017_validate_view_HCA_rastreio_artigos.sql)  
**Guia:** [`docs/fase-0b-view-HCA-rastreio-artigos.md`](../docs/fase-0b-view-HCA-rastreio-artigos.md)

**Regras:** `ndos = 1`, documento aberto (`ISNULL(BO.fechada, 0) = 0`), restante `> 0`; stock = `ST.stock` (RN-018); `em_rutura` se stock ≤ 0.

**Colunas:** `ref`, `design`, `total_linhas`, `total_encomendas`, `quantidade_encomendada_total`, `quantidade_fornecida_total`, `quantidade_por_satisfazer_total`, `quantidade_autorizada_total`, `stock_disponivel`, `em_rutura`.

**Consumo na API:** `GET /artigos/procura-aberta`.

---

### 4. `view_HCA_artigo_encomendas`

**Objetivo:** encomendas/linhas abertas associadas a um artigo.

**Script versionado:** [`018_create_view_HCA_artigo_encomendas.sql`](./018_create_view_HCA_artigo_encomendas.sql)  
**Validação:** [`019_validate_view_HCA_artigo_encomendas.sql`](./019_validate_view_HCA_artigo_encomendas.sql)  
**Guia:** [`docs/fase-0b-view-HCA-artigo-encomendas.md`](../docs/fase-0b-view-HCA-artigo-encomendas.md)

**Regras:** mesmos filtros de abertura que o rastreio; uma linha por `BI`; stock por `ref`.

**Colunas principais:** `bistamp`, `bostamp`, `ref`, `design`, `obrano`, `dataobra`, `cliente_*`, `quantidade_pedida`, `quantidade_por_satisfazer`, `quantidade_autorizada`, `stock_disponivel`.

**Consumo na API:** `GET /artigos/{ref}/encomendas-abertas` → `WHERE ref = @ref`.

---

### 5. `view_HCA_cortes_quantidade`

> **Emenda 2026-09-30 — dois conceitos distintos:**  
> Esta vista implementa **corte de autorização** (`ndos=1`, `u_qttorig − u_qtdaut`).  
> **Não** é a regra de **«Quantidades não entregues»** (`ndos=66`, `fechada=1`, `SUM(BI.qtt − BI.qtt2) > 0` — ver [`docs/PROJECT-STATE.md`](../docs/PROJECT-STATE.md)).  
> A API `GET /api/v1/cortes-quantidade` **já não** consome esta vista (usa `PickingDossiersQuery`). A vista / scripts 043+ permanecem no repositório sem consumidor Portal activo.

**Objetivo (histórico / legado):** linhas em que, após pronta para picking **ou** documento fechado, a quantidade original encomendada ficou acima da autorizada (**corte de autorização**).

**Script versionado:** [`043_create_view_HCA_cortes_quantidade.sql`](./043_create_view_HCA_cortes_quantidade.sql)

**Regras (corte de autorização — vista):**

- `BO.ndos = 1`
- `BO3.u_pickrdy = 1` **ou** `BO.fechada = 1`
- `BI2.u_qttorig > 0` e `BI2.u_qtdaut >= 0` e `u_qttorig > u_qtdaut`
- `quantidade_nao_autorizada = u_qttorig − u_qtdaut`
- Cor efectiva: `COALESCE(BI.cor, BI.u_cor)` (ver `042`)

| Coluna | Origem |
| --- | --- |
| `bistamp` / `bostamp` / `obrano` / `dataobra` | BI / BO |
| `fecho` / `pronta_picking` | BO.fechada / BO3.u_pickrdy |
| `cliente_*` | BO |
| `ref` / `design` / `cor` / `unidade` | BI (+ `u_cor`) |
| `quantidade_original` | BI2.u_qttorig |
| `quantidade_autorizada` | BI2.u_qtdaut |
| `quantidade_nao_autorizada` | u_qttorig − u_qtdaut |
| `quantidade_fornecida` | BI.qtt2 |

### 6. `view_HCA_utilizadores`

**Objetivo:** dados mínimos da tabela `US` necessários ao login do portal.

**Script versionado:** [`010_create_view_HCA_utilizadores.sql`](./010_create_view_HCA_utilizadores.sql)  
**Guia passo a passo (UAT → Produção):** [`docs/fase-0b-view-HCA-utilizadores.md`](../docs/fase-0b-view-HCA-utilizadores.md)

**Mapeamento (campos reais PHC):**

| `US` | Alias na vista |
| --- | --- |
| `usstamp` | `userstamp` |
| `usercode` | `login` |
| `username` | `nome` |
| `iniciais` | `usrinis` |
| `u_portalph` | `portal_hash` |

**Filtros:**

- `ISNULL(us.inactivo, 0) = 0`
- `LTRIM(RTRIM(us.u_portalph)) <> ''`

**Notas:**

- A verificação do hash (PasswordHasher / PBKDF2) permanece na API; a vista fornece `portal_hash`.
- **Nunca** guardar a palavra-passe em texto simples.
- **Não** expor `portal_hash` em listagens da UI.
- Auth MVP = cookie/sessão após login válido (sem JWT / tokens / `U_PORTAL*`).

```sql
CREATE OR ALTER VIEW dbo.view_HCA_utilizadores
AS
SELECT
    us.usstamp AS userstamp,
    LTRIM(RTRIM(us.usercode)) AS login,
    LTRIM(RTRIM(us.username)) AS nome,
    LTRIM(RTRIM(us.iniciais)) AS usrinis,
    us.u_portalph AS portal_hash
FROM dbo.us us WITH (NOLOCK)
WHERE ISNULL(us.inactivo, 0) = 0
  AND LTRIM(RTRIM(us.u_portalph)) <> '';
```

---

## Catálogo oficial — procedimentos armazenados (MVP)

A API **não** faz `UPDATE`/`INSERT` direto em `BO`/`BI`/`US` para operações de negócio. Invoca procedimentos.

| Procedimento | Objetivo | Scripts |
| --- | --- | --- |
| `sp_HCA_validar_login` | Exceção técnica — `US` por usercode + `u_usaPort` | [`020`](./020_create_sp_HCA_validar_login.sql) · [`021`](./021_validate_sp_HCA_validar_login.sql) · [doc](../docs/fase-0b-sp-HCA-validar-login.md) |
| `sp_HCA_listar_utilizadores_admin` | Lista US activos (email, `u_usaPort`) para Admin | [`031`](./031_create_sp_HCA_listar_utilizadores_admin.sql) · [`031b`](./031b_validate_sp_HCA_listar_utilizadores_admin.sql) |
| `sp_HCA_actualizar_usa_port` | Actualiza `US.u_usaPort` por email | [`032`](./032_create_sp_HCA_actualizar_usa_port.sql) · [`032b`](./032b_validate_sp_HCA_actualizar_usa_port.sql) |
| *(dados)* role `Admin` | Seed `u_HcaLogiRoles` + vínculo ao Identity `sa` | [`033`](./033_seed_role_Admin.sql) · [`033b`](./033b_validate_role_Admin.sql) |
| `sp_HCA_atualizar_linha_qtt_preco` | RN-020/021 + `usr*` + totais | [`022`](./022_create_sp_HCA_atualizar_linha_qtt_preco.sql) · [`023`](./023_validate_sp_HCA_atualizar_linha_qtt_preco.sql) · [doc](../docs/fase-0b-sp-HCA-atualizar-linha-qtt-preco.md) |
| `sp_HCA_atualizar_qtd_autorizada` | `u_qtdaut*` + teto `ST.stock` | [`024`](./024_create_sp_HCA_atualizar_qtd_autorizada.sql) · [`025`](./025_validate_sp_HCA_atualizar_qtd_autorizada.sql) · [doc](../docs/fase-0b-sp-HCA-atualizar-qtd-autorizada.md) |
| `sp_HCA_alocacao_proporcional` | Apêndice B; `@simular` pré-visualiza | [`026`](./026_create_sp_HCA_alocacao_proporcional.sql) · [`027`](./027_validate_sp_HCA_alocacao_proporcional.sql) · [doc](../docs/fase-0b-sp-HCA-alocacao-proporcional.md) |
| `sp_HCA_marcar_fecho_picking_dossier` | Fecho/reabertura genérica `BO.fechada` (série parametrizada; tipicamente 66) | [`048`](./048_create_sp_HCA_marcar_fecho_picking_dossier.sql) |
| `sp_HCA_fechar_expedicao_dossier` | Fecho operacional ndos=65: `BO`+`BI.fechada=1` (sem faturação) | [`083`](./083_create_sp_HCA_fechar_expedicao_dossier.sql) · grant [`083b`](./083b_grant_sp_HCA_fecho_reabrir_expedicao.sql) |
| `sp_HCA_reabrir_expedicao_dossier` | Reabrir ndos=65: `BO`+`BI.fechada=0` | [`084`](./084_create_sp_HCA_reabrir_expedicao_dossier.sql) · grant [`083b`](./083b_grant_sp_HCA_fecho_reabrir_expedicao.sql) |

Hub: [`docs/fase-0b-sp-HCA.md`](../docs/fase-0b-sp-HCA.md)

### Regras a encapsular (inalteradas)

| Procedimento | Regras |
| --- | --- |
| `sp_HCA_validar_login` | Leitura controlada de `US` / hash; API verifica PasswordHasher |
| `sp_HCA_atualizar_linha_qtt_preco` | **RN-020/021**: sentinel **0**; `qtt` / `edebito`; `usr*` BI+BO; totais; **nunca** `ousr*` |
| `sp_HCA_atualizar_qtd_autorizada` | `u_qtdaut*`; 1.ª vez: `u_qttorig←qtt`, `qtt←auth`; ultrapassar restante OK; soma ≤ `ST.stock` (salvo confirmação) |
| `sp_HCA_alocacao_proporcional` | Transação; `disponivel = ST.stock`; Apêndice B |

### Assinaturas (fechadas na 0B)

```sql
-- Login (exceção técnica)
EXEC dbo.sp_HCA_validar_login @login = N'usercode';

-- Quantidade / preço
EXEC dbo.sp_HCA_atualizar_linha_qtt_preco
  @bistamp = N'...',
  @quantidade = 50,          -- opcional
  @preco = 9.50,             -- opcional (edebito)
  @usrinis = N'ANA',
  @qtt_anterior_esperado = NULL,
  @preco_anterior_esperado = NULL;

-- Quantidade autorizada
EXEC dbo.sp_HCA_atualizar_qtd_autorizada
  @bistamp = N'...',
  @quantidade_autorizada = 25,
  @usrlogin = N'ana.operadora',
  @valor_anterior_esperado = 10;

-- Alocação
EXEC dbo.sp_HCA_alocacao_proporcional
  @ref = N'A-001',
  @usrlogin = N'ana.operadora',
  @simular = 1;  -- 0 = gravar
```

### Totais BO (equiv. BOTOTS MVP)

O SP `sp_HCA_atualizar_linha_qtt_preco` assume colunas `BO.etotal` e `BO.eboiva`. **Confirmar na BD UAT** antes de gravar (script `023`, query 0). Se os nomes forem diferentes, ajustar o script versionado.

---

## Permissões SQL (conta da aplicação)

### `SELECT` nas vistas

- `view_HCA_encomendas_abertas`
- `view_HCA_encomenda_linhas`
- `view_HCA_rastreio_artigos`
- `view_HCA_artigo_encomendas`
- `view_HCA_utilizadores`

### `EXECUTE` nos procedimentos

- `sp_HCA_validar_login`
- `sp_HCA_listar_utilizadores_admin`
- `sp_HCA_actualizar_usa_port`
- `sp_HCA_atualizar_linha_qtt_preco`
- `sp_HCA_atualizar_qtd_autorizada`
- `sp_HCA_alocacao_proporcional`

| Objeto | Permissão da aplicação |
| --- | --- |
| `view_HCA_*` | `SELECT` |
| `sp_HCA_*` | `EXECUTE` |
| Tabelas base `BO`/`BI`/`ST`/`CL`/`US` | **Sem** `SELECT`/`UPDATE` direto pela aplicação (preferível); se inevitável em transição, restringir e migrar para vistas/procedimentos |

---

## Fase 0B / instalação

- [ ] Campos `U_*` criados (`001_user_fields.md`)
- [ ] Criar vistas `view_HCA_*` (catálogo acima)
- [ ] Criar procedimentos `sp_HCA_*` (catálogo acima)
- [ ] Validar `SELECT` nas `view_HCA_*`
- [ ] Validar `EXEC` nas `sp_HCA_*`
- [ ] Validar permissões SQL com a nomenclatura oficial
- [ ] Teste pontual: listar abertas; detalhe de linhas; atualizar quantidade/preço via procedimento

---

## O que não fazer

- Consultas Dapper `FROM bo` / `FROM bi` / `FROM st` / `FROM cl` / `FROM us` espalhadas na API
- Lógica de restante / série / `usr*` duplicada em C# quando deve viver na vista/procedimento
- Reintroduzir JWT ou tabelas `U_PORTAL*` no MVP
- Usar nomes antigos: `vw_portal_*`, `view_portal_*`, `usp_portal_*`, `sp_portal_*`, `SP_HCA_*`
