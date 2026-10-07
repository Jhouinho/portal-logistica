# Discovery da Base de Dados PHC CS

> **HISTÓRICO / SUPERSEDED como estado actual (2026-09-29).**  
> 0A confirmada e 0B executada em UAT; capacidade operacional = **previsão**, não `ST.stock` (RN-018 neste doc é histórica).  
> SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md). Auth actual: [`auth-portal-identity.md`](./auth-portal-identity.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística e B2B |
| Fonte de verdade histórica | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Ambiente alvo | Base de dados PHC CS (SQL Server) do cliente |
| Estado | **Fase 0A confirmada** (histórico); 0B **feita em UAT** — ver PROJECT-STATE |

---

## Objetivo

Registar a estrutura das tabelas PHC e preparar objetos de acesso do portal: campos `U_*`, **vistas de leitura** e **procedimentos armazenados de escrita**.

| Subfase | Conteúdo | Estado |
| --- | --- | --- |
| **0A** | Discovery estrutural (Enciclopédia + regras) | **Confirmada** |
| **0B** | Campos + `view_HCA_*` / `sp_HCA_*` + SQL + `ndos=1` + utilizador piloto | Pendente — **bloqueia Sprint 1** |

Critérios: [ARCHITECTURE.md — Fase 0A/0B](../ARCHITECTURE.md#fase-0a--0b--discovery-e-preparação-do-ambiente) · [`sql/002_views_and_procedures.md`](../sql/002_views_and_procedures.md).

Campos Cash & Carry (`BO.u_cc*`) são **opcionais** na 0B — **não bloqueiam** GO nem go-live do MVP.  
Um portal Cash & Carry futuro **pode usar um modelo de autenticação diferente**, a definir mais tarde.  
**Não criar** tabelas `U_PORTALUSER` / `U_PORTALREFRESH` / `U_PORTALCFG` no MVP.  
**Não criar** `U_PORTALAUDIT` no MVP (melhoria futura).  
**Não criar** `CL.u_portalactive` no MVP — possível futuro Fase 2 (Portal Cliente B2B).

### 0A — Já fechado (conhecimento PHC)

Com base na Enciclopédia PHC (`kb-manual-tecnico`):

- campos nativos padrão de `BO`/`BI`/`ST`/`CL` usados pelo MVP;
- preço unitário da linha = **`BI.edebito`**;
- recálculo de totais / líquidos ao alterar preço ou quantidade;
- campos `usr*` / `ousr*` de auditoria nativa;
- identidade MVP = tabela nativa **`US`** + cookie/sessão (`u_portalph`).

### 0B — Ainda exige trabalho na BD do cliente

- Confirmar tabela `US`
- Confirmar campo de login em `US`
- Confirmar campo de nome em `US`
- Confirmar campo de iniciais / fonte para `usrinis` (ex.: `usrinis`, `iniciais`, login)
- Criar **apenas** `US.u_portalph`
- **Não** criar `U_PORTALAUDIT` / `u_portalperfil` / ativo / falhas / lockuntil
- Criar campos `U_*` obrigatórios em **BI** (sem campos novos em `CL` no MVP)
- Criar vistas `view_HCA_*` — ver `sql/002_views_and_procedures.md`
- Criar procedimentos `sp_HCA_*` (escrita)
- Validar `SELECT` nas `view_HCA_*` e `EXEC` nas `sp_HCA_*`
- Confirmar `BI.edebito`, `ST.stock`
- Confirmar `SerieEncomendasNdos = 1` (valor em appsettings; sem `U_PORTALCFG`)
- Arranque: pelo menos um utilizador `US` com hash via PHC; validar login com cookie
- Documentar mapeamento `US` → `usrinis` após validação
- Conceder leitura/execução à conta SQL da aplicação (sem SQL direto a tabelas base)

---

## Tabelas PHC analisadas

| Tabela | Papel no portal |
| --- | --- |
| `US` | Utilizadores PHC — identidade do portal (campos `u_portal*`) |
| `BO` | Cabeçalho de dossiers / encomendas |
| `BI` | Linhas de dossiers / encomendas |
| `ST` | Stocks e serviços (disponibilidade) |
| `CL` | Clientes (registo RN-017 + filtros) |
| `TS` | Configuração / tipos de séries de dossiers (`ndos`) |
| `U_PORTALAUDIT` | **Não criar** no MVP (futuro) |

---

## Tabela US (identidade)

Utilizadores nativos PHC. O portal autentica contra esta tabela; **não** cria `U_PORTALUSER`.  
Ciclo de vida (criar / password): **apenas no PHC**.

| Coluna física esperada | Significado de negócio | Estado | Notas |
| --- | --- | --- | --- |
| `usstamp` | Stamp do utilizador | **Confirmado (cliente)** | Alias vista: `userstamp` |
| `usercode` | Código / login | **Confirmado (cliente)** | Alias vista: `login` |
| `username` | Nome apresentado | **Confirmado (cliente)** | Alias vista: `nome` |
| `iniciais` | Iniciais | **Confirmado (cliente)** | Alias vista: `usrinis` (mapeamento `US` → `usrinis`) |
| `inactivo` | Utilizador inativo | **Confirmado (cliente)** | Vista: `ISNULL(inactivo, 0) = 0` |
| `u_portalph` | Hash da password do portal | **Criado** `varchar(254) NOT NULL` | Alias vista: `portal_hash`; login se `LTRIM(RTRIM(u_portalph)) <> ''` |
| `u_portalperfil` | Operador · Supervisor · Administrador | **Não criar** (futuro) | |
| `u_portalativo` | Flag de acesso | **Não criar** (futuro / RN-019) | |
| `u_portalfalhas` | Contador falhas (RN-019) | **Não criar** (RN-019 futuro) | |
| `u_portallockuntil` | Fim do bloqueio (RN-019) | **Não criar** (RN-019 futuro) | |

### SQL de inspeção

```sql
SELECT TOP 20 *
FROM us WITH (NOLOCK);

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'us'
ORDER BY ORDINAL_POSITION;

-- Após criar os campos:
SELECT TOP 20 /* login/nome conforme discovery */,
  /* não criar no MVP: u_portalperfil, u_portalativo, u_portalfalhas, u_portallockuntil */
  CASE WHEN u_portalph IS NULL OR LTRIM(RTRIM(u_portalph)) = '' THEN 0 ELSE 1 END AS tem_hash_portal
FROM us WITH (NOLOCK);
```

---

## Tabela BO

Cabeçalho de dossiers internos (encomendas no MVP; Cash & Carry como série futura opcional).

| Coluna física esperada | Significado de negócio | Estado | Notas |
| --- | --- | --- | --- |
| `bostamp` | Identificador único do documento | **Confirmado (0A)** | Chave lógica; join com `BI`; *verificação* 0B |
| `ndos` | Nº interno da série / tipo de dossier | **Confirmado (0A)** / valor **0B** | Filtrar série encomendas via appsettings (`SerieEncomendasNdos`); série Cash & Carry só no futuro |
| `nmdos` | Nome da série | **Confirmado (0A)** | Apresentação UI |
| `obrano` | Número do documento | **Confirmado (0A)** | Nº de encomenda na UI |
| `dataobra` | Data do documento | **Confirmado (0A)** | Filtros e corte de planeamento |
| `ousrhora` | Hora de criação / introdução | **Confirmado (0A)** | Usar no corte semanal; *verificação* tipagem 0B |
| `no` | Número de cliente | **Confirmado (0A)** | |
| `estab` | Estabelecimento do cliente | **Confirmado (0A)** | |
| `nome` | Nome do cliente | **Confirmado (0A)** | |
| `vendnm` / `vendedor` | Representante | **Fora de âmbito** | **Não usado** pelo portal |
| `fecho` | Documento fechado (`0` = aberto) | **Confirmado (0A)** | Encomendas abertas: `ISNULL(fecho,0)=0` |

### SQL de inspeção

```sql
SELECT TOP 20 *
FROM bo WITH (NOLOCK);

SELECT TOP 0 *
FROM bo WITH (NOLOCK);
-- Usar o resultado de TOP 0 / INFORMATION_SCHEMA para inventário de colunas
```

```sql
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'bo'
ORDER BY ORDINAL_POSITION;
```

---

## Tabela BI

Linhas de dossiers (quantidades, preço, autorização e auditoria de ajustes).

| Coluna física esperada | Significado de negócio | Confirmado? | Notas |
| --- | --- | --- | --- |
| `bistamp` | Identificador único da linha | **PHC** | Chave para PATCH |
| `bostamp` | Ligação ao cabeçalho `BO` | **PHC** | |
| `ref` | Código do artigo | **PHC** | Rastreio de artigos |
| `design` | Descrição do artigo | **PHC** | |
| `qtt` | Quantidade da linha (**RN-020**) — qtd a fornecer | **PHC** | Ajustável; **não** define o restante |
| `qtt2` | Quantidade fornecida | **PHC** | Só leitura |
| `edebito` | **Preço unitário €** (**RN-021**) | **PHC** | *Pr.Unit.€* (Enciclopédia) |
| `ettdeb` | **Total da linha (€)** | **PHC** | Confirmado UAT Liliana — campo usado pelo SP `022` |
| `etiliquido` | Valor líquido da linha (€) | **Não existe nesta BD** | Discovery 2026-08-10 — não usar |
| `u_qttorig` | Qtd original — **base do restante** | **Criado** `numeric(16,2) NOT NULL` | Restante = `ISNULL(NULLIF(u_qttorig, 0), qtt) - qtt2`; **0** = ainda não preenchido |
| `u_prcorig` | Preço original (1.ª alteração) | **Criado** `numeric(16,2) NOT NULL` | RN-021; **0** = ainda não preenchido |
| `u_qtdaut` | Quantidade autorizada a expedir | **Criado** `numeric(16,2) NOT NULL` | **0** = ainda sem autorização |
| `u_qtdautur` | Quem alterou autorização | **Criado** `varchar(100) NOT NULL` | |
| `u_qtdautdt` | Quando alterou autorização | **Criado** `datetime NOT NULL` | |
| `usrinis` | Última alteração (utilizador) | **PHC** | Camada 1 auditoria |
| `usrdata` | Última alteração (data) | **PHC** | |
| `usrhora` | Última alteração (hora) | **PHC** | |

> **Legenda:** **PHC** = modelo padrão Enciclopédia; **A criar** = campo `U_*`; *verificação pontual* na BD cliente valida existência/tipagem.

### Auditoria nativa BO / BI

| Coluna | Tabela | Uso | Estado |
| --- | --- | --- | --- |
| `usrinis` | `BO`, `BI` | Última alteração | **PHC** |
| `usrdata` | `BO`, `BI` | Data | **PHC** |
| `usrhora` | `BO`, `BI` | Hora | **PHC** |
| `ousrinis` / `ousrdata` / `ousrhora` | `BO`, `BI` | Criação — nunca alterar | **PHC** |

| Tema | Decisão |
| --- | --- |
| Length típico `usrinis` | Habitualmente **C(3)** — *verificação pontual* confirma |
| Formato | Iniciais PHC / derivado do utilizador `US` |
| Mapeamento `US` → `usrinis` | Acordo operacional — campo **`iniciais`** (vista `view_HCA_utilizadores`) |
| `ousr*` | **Nunca** atualizar pelo portal |

### Preço unitário — Discovery (**concluído** — Enciclopédia PHC)

Fontes: *Como colocar preço unitário read-only nas linhas de dossier* (`edebito` = Pr.Unit.€); *U_bodebito*; *Botots*.

| Item | Conclusão |
| --- | --- |
| Campo físico | **`BI.edebito`** |
| Impacto no recálculo de totais | **Sim** — alterar só o unitário sem recalcular deixa totais inconsistentes |
| Atualizar líquidos/ilíquidos | **Linha:** `BI.ettdeb` (confirmado UAT). `etiliquido` **inexistente** nesta BD. Totais `BO` — pendente discovery `023a` |
| Comportamento após UPDATE directo | Desktop/listagens usam totais gravados; sem recálculo, valores ficam desalinhados até `BOTOTS` / reabertura com cálculo |
| Data | 2026-08-10 (equipa projeto / Enciclopédia) |

**Implicação RN-021:** o portal atualiza `edebito` **e** recalcula linha + cabeçalho; depois `usr*`. Não basta `UPDATE ... SET edebito=...`.

### SQL de inspeção (*verificação pontual*)

```sql
SELECT TOP 20 *
FROM bi WITH (NOLOCK);

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'bi'
ORDER BY ORDINAL_POSITION;
```

```sql
-- Linhas em aberto + preço + restante por quantidade original
SELECT TOP 50
  bi.bistamp, bi.bostamp, bi.ref, bi.design, bi.qtt, bi.qtt2,
  bi.u_qttorig,
  bi.edebito, bi.ettdeb, bi.etiliquido,
  (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer
FROM bi WITH (NOLOCK)
INNER JOIN bo WITH (NOLOCK) ON bo.bostamp = bi.bostamp
WHERE ISNULL(bo.fecho, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
```

---

## Tabela ST

Stocks e serviços — disponibilidade para alocação e KPIs (**RN-018**).

| Coluna física esperada | Significado de negócio | Estado | Notas |
| --- | --- | --- | --- |
| `ref` | Código do artigo | **Confirmado (0A)** | |
| `design` | Descrição | **Confirmado (0A)** | |
| `stock` | Stock atual = **stock disponível no MVP** | **Confirmado (0A)** | **RN-018:** `StockDisponivel = ST.stock` |
| `qttcli` | Quantidade em encomendas de clientes | **Confirmado (0A)** | Existe no PHC; **não entra** no cálculo do MVP |
| `qttfor` | Quantidade em encomendas a fornecedores | **Confirmado (0A)** | Existe no PHC; **não entra** no cálculo do MVP |

### SQL de inspeção

```sql
SELECT TOP 20 *
FROM st WITH (NOLOCK);

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'st'
ORDER BY ORDINAL_POSITION;
```

---

## Tabela CL

Clientes — filtros operacionais e validação de registo **RN-017**.

| Coluna física esperada | Significado de negócio | Estado | Notas |
| --- | --- | --- | --- |
| `no` | Número de cliente | **Confirmado (0A)** | |
| `estab` | Estabelecimento | **Confirmado (0A)** | |
| `nome` | Nome | **Confirmado (0A)** | |
| `ncont` | NIF / nº contribuinte | **Confirmado (0A)** | Obrigatório para RN-017 |
| `tlmvl` | Telemóvel | **Confirmado (0A)** | Prioridade 1 na validação de registo |
| `telefone` | Telefone | **Confirmado (0A)** | Alternativa se `tlmvl` vazio/nulo |
| `u_portalactive` | Conta portal ativa (clientes) | **Fora do MVP** | `CL.u_portalactive` poderá ser considerado na Fase 2, caso seja necessário controlar quais clientes têm acesso ao Portal Cliente B2B. **Não faz parte do MVP** do Portal Logístico. |

**Não existe** `u_portalmobile`. Validação RN-017 (Fase 2) usa apenas `ncont` + `tlmvl` / `telefone` — **sem** exigir `u_portalactive`. No MVP, `CL` = só leitura (sem campos `U_*` novos).

### SQL de inspeção

```sql
SELECT TOP 20 *
FROM cl WITH (NOLOCK);

SELECT TOP 20 no, estab, nome, ncont, tlmvl, telefone
FROM cl WITH (NOLOCK);

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'cl'
ORDER BY ORDINAL_POSITION;
```

```sql
-- Prova de conceito RN-017 (substituir parâmetros)
-- Normalizar telemóvel no código (NormalizePhoneNumber) antes de comparar
DECLARE @nif varchar(20) = '123456789';
DECLARE @telemovel_normalizado varchar(20) = '912345678'; -- já sem espaços / +351

SELECT no, estab, nome, ncont, tlmvl, telefone
FROM cl WITH (NOLOCK)
WHERE LTRIM(RTRIM(ncont)) = LTRIM(RTRIM(@nif));
-- Comparação de telemóvel: aplicar NormalizePhoneNumber a tlmvl/telefone no código da API
-- Campos u_cc* (Cash & Carry) são OPCIONAIS na Fase 0B — não bloqueiam GO/MVP
```

---

## Tabela TS

Tipos / séries de dossiers — origem dos valores `ndos` e nomes de série.

| Coluna física esperada | Significado de negócio | Confirmado? | Notas |
| --- | --- | --- | --- |
| `ndos` | Nº interno da série | Pendente | Confirmar nome da tabela/colunas na BD local |
| Nome da série | Descrição apresentada no PHC | Pendente | Pode ser `nmdos` ou equivalente em TS |
| Ativo / inativo | Se a série está disponível | Pendente | |

> Em algumas instalações PHC a configuração de séries pode residir em tabelas auxiliares além de `TS`. Confirmar no dicionário de dados e na config de dossiers.

### SQL de inspeção

```sql
SELECT TOP 20 *
FROM ts WITH (NOLOCK);

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ts'
ORDER BY ORDINAL_POSITION;
```

```sql
-- Séries usadas em BO (ajuda a descobrir ndos reais)
SELECT bo.ndos, bo.nmdos, COUNT(*) AS documentos
FROM bo WITH (NOLOCK)
GROUP BY bo.ndos, bo.nmdos
ORDER BY bo.ndos;
```

---

## Exemplos SQL de discovery (obrigatórios)

Executar na BD de UAT / cópia do cliente:

```sql
SELECT TOP 20 * FROM US WITH (NOLOCK);
SELECT TOP 20 * FROM BO WITH (NOLOCK);
SELECT TOP 20 * FROM BI WITH (NOLOCK);
SELECT TOP 20 * FROM ST WITH (NOLOCK);
SELECT TOP 20 * FROM CL WITH (NOLOCK);
```

Inventário de colunas:

```sql
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('us', 'bo', 'bi', 'st', 'cl', 'ts')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
```

---

## Checklist de validação

| # | Item | Estado |
| --- | --- | --- |
| 1–17 | Campos padrão BO/BI/ST/CL (`bostamp`, `qtt`, `stock`, `ncont`, …) | **Fechado PHC** — *verificação pontual* opcional |
| 17b | Colunas identificação `US` (`usercode`, `username`, `iniciais`, `usstamp`, `inactivo`) | **Confirmado (cliente)** |
| 17c | Confirmar `US.u_portalph` (`varchar(254) NOT NULL`) | **Criado no PHC** — validar hash piloto |
| 17d | **Não** criar `U_PORTALAUDIT` / perfil / lockout | Confirmado |
| 17e | **Não** criar `U_PORTALUSER` / `U_PORTALREFRESH` / `U_PORTALCFG` | **Regra MVP** |
| 17f | **Não** criar `CL.u_portalactive` no MVP | **Regra MVP** (possível futuro Fase 2) |
| 17g | Campos `U_*` BI (`u_qttorig`, `u_prcorig`, `u_qtdaut*`) | **Criados no PHC** — tipagem `NOT NULL` + sentinel **0** |
| 17h | Criar `view_HCA_utilizadores` (script `010`) | **Feito UAT** (2026-08-10) · Prod só no fim da implementação |
| 17i | Criar `view_HCA_encomendas_abertas` (scripts `012`/`013`) | **Feito UAT** (2026-08-10) · Prod só no fim da implementação |
| 17j | Criar `view_HCA_encomenda_linhas` (scripts `014`/`015`) | **Feito UAT** (2026-08-10) · Prod só no fim da implementação |
| 17k | Criar `view_HCA_rastreio_artigos` (scripts `016`/`017`) | **Feito UAT** (2026-08-10) · Prod só no fim da implementação |
| 17l | Criar `view_HCA_artigo_encomendas` (scripts `018`/`019`) | **Feito UAT** (2026-08-10) · Prod só no fim da implementação |
| 18 | Confirmar `SerieEncomendasNdos = 1` (appsettings) | **Pendente cliente** |
| 19 | `SerieCashCarryNdos` | Opcional |
| 20 | Campo físico preço unitário `BI` | **`edebito`** — fechado PHC |
| 21 | Registar em Descobertas finais | **Feito** |
| 21b | Impacto recálculo de totais | **Sim** — fechado PHC |
| 21c | Atualizar líquidos/ilíquidos | **Sim** — fechado PHC |
| 21d | Comportamento após alteração directa | **Totais desalinhados sem recálculo** — fechado PHC |
| 22–27 | `usr*` BO/BI | **Fechado PHC** |
| 28–29 | Length/formato `usrinis` | **PHC típico C(3)** — *verificação pontual* length |
| 30 | Mapeamento `US` → `usrinis` | **`US.iniciais`** (vista `view_HCA_utilizadores`) |
| 31 | Não alterar `ousr*` | **Fechado** (regra) |
| 32 | Utilizador piloto com hash + login cookie | **Pendente 0B** |

---

## Descobertas finais

| Tema | Valor confirmado | Data | Responsável |
| --- | --- | --- | --- |
| Servidor / nome da BD | *(verificação pontual)* | | |
| Gama PHC | *(verificação pontual)* | | |
| Colunas `US` (login/nome) | `usercode` / `username` | 2026-08-10 | Cliente |
| Mapeamento `US` → `usrinis` | `US.iniciais` → vista `usrinis` | 2026-08-10 | Cliente |
| Vista login | `view_HCA_utilizadores` (script `010`) | 2026-08-10 | **Feito UAT** · Prod diferido |
| Vista encomendas abertas | `view_HCA_encomendas_abertas` (scripts `012`/`013`) | 2026-08-10 | **Feito UAT** · Prod diferido |
| Vista linhas encomenda | `view_HCA_encomenda_linhas` (scripts `014`/`015`) | 2026-08-10 | **Feito UAT** · Prod diferido |
| Vista rastreio artigos | `view_HCA_rastreio_artigos` (scripts `016`/`017`) | 2026-08-10 | **Feito UAT** · Prod diferido |
| Vista artigo encomendas | `view_HCA_artigo_encomendas` (scripts `018`/`019`) | 2026-08-10 | **Feito UAT** · Prod diferido |
| Campo fecho BO (UAT) | Físico **`fechada`** (docs lógicos: `fecho`) | 2026-08-10 | Confirmado nos scripts UAT |
| `ST.stock` | Stock disponível MVP | 2026-08-10 | RN-018 |
| Regra RN-018 | `StockDisponivel = ST.stock` | Decisão negócio | |
| Identidade MVP | `US` + cookie/sessão (`u_portalph`; sem JWT) | 2026-08-10 | Decisão aprovada |

### Conclusão do discovery

| Campo | Conteúdo |
| --- | --- |
| Resultado | **Discovery estrutural concluída** via Enciclopédia PHC |
| Preço / totais | Fechados: `edebito` + recálculo linha/cabeçalho obrigatório |
| Bloqueadores para desenvolvimento | Discovery `US` + `u_portalph` + campos BI + `SerieEncomendasNdos=1` + utilizador piloto + mapeamento `usrinis` + login cookie |
| Próxima ação | *Verificação pontual* SQL no cliente; criar campos; GO Sprint 1 |

---

*Alinhado com ARCHITECTURE.md. Preço unitário e totais fechados por documentação PHC oficial. Identidade MVP: US + cookie/sessão.*
