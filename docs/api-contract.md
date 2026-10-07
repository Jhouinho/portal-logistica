# Contrato da API — Portal Liliana & Seródio

> **Emenda operacional 2026-09-30:** estado actual → [`PROJECT-STATE.md`](./PROJECT-STATE.md) + [`business-flows.md`](./business-flows.md).  
> Autorização/alocação usam **previsão de entrada** (sem teto `ST.stock`; RN-018 histórico **não** aplica).  
> SignalR = **invalidação** (`OperacoesHub` + `TvHub`); sem payload de negócio.  
> Painel TV: `GET /painel/centro-estados` e `GET /painel/tv-kapps-resumo` (anónimos).  
> Separado (`picking-dossiers`): campos aditivos `quantidadeDocumento` / `quantidadeExpedida` / `quantidadePendenteEntrega` (`SUM(BI.qtt|qtt2|qtt−qtt2)`). Não redefinem `quantidadeTotal` / `quantidadePorSatisfazer`.  
> UI «Voltar ao Separado» = `POST /picking-dossiers/{boStamp}/reverter-check-in` (só `u_chkin`).  
> **«Quantidades não entregues»:** `GET /cortes-quantidade` lista dossiers `ndos=66` fechados com `SUM(qtt−qtt2)>0` (campos Documento / Expedida / Pendente). Vista `view_HCA_cortes_quantidade` = legado sem consumidor activo.  
> **Fecho operacional Em Expedição:** `PATCH /separacao-dossiers/{boStamp}/fechada` — `{fechada:true}` fecha BO+BI (SP 083); `{fechada:false}` reabre BO+BI (SP 084). Sem faturação.
> **Morada de entrega:** campo JSON `moradaEntrega` ← `BO2.u_mEntrega` (texto corrido; null se vazio). JOIN `BO.bostamp = BO2.bo2stamp` no documento apresentado. Sem fallback para `BO.morada`/`CL`/`BI2`.
>
> **Método de expedição:** campo JSON `metodoExpedicao` ← `BO3.u_modExp`. Query opcional `metodoExpedicao` nas listas (`/encomendas/abertas`, `/picking-dossiers`, `/separacao-dossiers`, `/artigos/procura-aberta`): valor PHC exacto, `nao_definido` (vazio), ou omitido = Todos. Filtro em memória antes da paginação / antes do `GroupBy` (procura).
>
> **Emenda 2026-10-07 — Picking / REGRA B:** campo JSON `temQtt66` (lista + detalhe); cancel/desmarcar Picking bloqueado se `SUM(66.BI.qtt)>0` (`SeriePickingNdos`). Distinguir **encomenda aberta** (vista) de **Em Picking** (`u_pickrdy` + remaining por SUM66). Detalhe: [`PROJECT-STATE.md`](./PROJECT-STATE.md), [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md) §32.
>
> **Emenda 2026-10-07 — Pendentes de Picagem:** `GET /pendentes-picagem` (+ `/por-referencia`, `/{boStamp}/linhas`). Encomendas `ndos=1` abertas com `u_pickrdy=1` que **já iniciaram** o Picking (nível encomenda: ∃ `Picked>0` ∨ `SUM66>0`); Pending híbrido por linha; paginação 1A (`page` / `pageSize` / `totalItems`). **≠** Em Picking. Detalhe: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Base URL | `/api/v1` |
| Autenticação | Cookie Identity (`u_HcaLogiUsers`) + gate `US.u_usaPort` — **sem** Bearer nas APIs de negócio |
| Formato | JSON (`application/json`) |
| Erros | Problem Details (RFC 7807) + mensagens de negócio em português |
| Fonte operacional | [`PROJECT-STATE.md`](./PROJECT-STATE.md); baseline: [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Idioma das respostas de negócio | Português de Portugal |
| MVP | Auth Identity + cookie · Role Admin · Gestão utilizadores portal · Diagnóstico (opcional) · Painel / Centro / TV · Encomendas · Qtt/Preço (RN-020/021) · Autorização (previsão) · Artigos / Alocação · Previsões · Check-in · Separado (entrega parcial) · Em Expedição (fecho operacional) · Quantidades não entregues · Pendentes de Picagem · SignalR |
| Fora do MVP | JWT Bearer nas APIs · RN-019 · Outros perfis além de Admin · SMTP convites · `U_PORTALAUDIT` · Cash & Carry · Portal Cliente (Fase 2) |
| Actualizado | 2026-10-07 |

Convenções:

- Utilizador autenticado = cookie Identity válida + `US` activo com `u_usaPort = 1`
- Administração de utilizadores / toggle Admin: apenas role Identity `Admin`
- Datas em ISO 8601; fuso de negócio: `Europe/Lisbon`
- Sem `accessToken` / `refreshToken` / `expiresAt` na UI (`isAdmin` vem de `/auth/me` e login)
- **Dados PHC:** leituras via `view_HCA_*`; escritas de negócio via `sp_HCA_*` (Dapper) — ver [`sql/002_views_and_procedures.md`](../sql/002_views_and_procedures.md)
- **Exceção técnica:** `sp_HCA_validar_login` resolve `US` por **usercode** (`u_usaPort`) e devolve o email para localizar a conta Identity
- **Disponibilidade operacional** (campo API ainda chamado `stockDisponivel` / `quantidadeDisponivel` por legado) = **Previsto − Alocado** da previsão aberta (Ref + Cor); pode ser negativa; **não** é `ST.stock`

---

## Autenticação

### POST `/auth/login`

Autentica com `US.usercode` + password Identity. Estabelece cookie de sessão.

**Autorização:** anónimo

**Request**

```json
{
  "login": "sa",
  "password": "********"
}
```

**Response 200** (+ Set-Cookie)

```json
{
  "utilizador": {
    "login": "sa",
    "nome": "Administrador",
    "isAdmin": true
  }
}
```

**Erros**

| HTTP | Condição |
| --- | --- |
| 400 | Login/password em falta |
| 401 | Credenciais inválidas, lockout, sem Identity, ou sem `u_usaPort` |

Ver também [`auth-portal-identity.md`](./auth-portal-identity.md).

---

### POST `/auth/definir-password`

Define a palavra-passe no 1.º acesso (ou reenvio de convite) com o token Identity `ResetPassword` (Base64Url na query do SPA).

**Autorização:** anónimo

**Request**

```json
{
  "email": "utilizador@empresa.pt",
  "token": "…",
  "password": "********",
  "confirmPassword": "********"
}
```

**Response 204**

**Erros:** 400 (token inválido/expirado, password fraca, confirmação diferente)

---

### POST `/auth/logout`

Limpa cookie / sessão no servidor.

**Autorização:** autenticado (ou idempotente se já anónimo)

**Request:** sem corpo (ou vazio)

**Response 204** — sem corpo (+ limpar cookie)

---

### GET `/auth/me`

Devolve o utilizador da sessão atual.

**Autorização:** autenticado (cookie)

**Response 200**

```json
{
  "login": "ana.operadora",
  "nome": "Ana Silva",
  "isAdmin": false
}
```

---

> **Não existe** `POST /auth/refresh` no MVP.

---

## Administração de utilizadores (role `Admin`)

Base: `/admin/utilizadores` — `[Authorize(Roles = "Admin")]`.  
Não cria fichas `US`; apenas gere `u_usaPort`, contas Identity e role `Admin`.

Scripts SQL: [`031`](../sql/031_create_sp_HCA_listar_utilizadores_admin.sql) · [`032`](../sql/032_create_sp_HCA_actualizar_usa_port.sql) · seed role [`033`](../sql/033_seed_role_Admin.sql) — ver [`auth-portal-identity.md`](./auth-portal-identity.md).

### GET `/admin/utilizadores`

Lista `US` activos com email + estado portal/Identity.

**Response 200** (array)

```json
[
  {
    "userstamp": "…",
    "login": "sa",
    "nome": "Administrador",
    "usrinis": "SA",
    "email": "joao.lopes@hcaraujo.pt",
    "usaPort": true,
    "temContaIdentity": true,
    "temPassword": true,
    "isAdmin": true
  }
]
```

### POST `/admin/utilizadores/acesso`

Body: `{ "email": "…" }`  
Activa `u_usaPort`, cria Identity sem password se necessário, devolve convite.

**Response 200**

```json
{
  "email": "utilizador@empresa.pt",
  "login": "user1",
  "definirPasswordUrl": "http://localhost:5173/definir-password?email=…&token=…",
  "token": "…"
}
```

### POST `/admin/utilizadores/revogar`

Body: `{ "email": "…" }` → `u_usaPort = 0` e lockout Identity. **204**

### POST `/admin/utilizadores/reset-password`

Body: `{ "email": "…" }`  
Remove a password Identity actual (se existir) e devolve um novo `definirPasswordUrl`.  
Até o utilizador completar `/definir-password`, o login com a password antiga falha.

**Response 200** — igual a `POST …/acesso` (`email`, `login`, `definirPasswordUrl`, `token`).

### POST `/admin/utilizadores/reenviar-convite`

Alias de `POST …/reset-password` (mesmo comportamento).

### POST `/admin/utilizadores/admin` · DELETE `/admin/utilizadores/admin`

Body: `{ "email": "…" }` — atribui / remove role `Admin`. Impede remover o último Admin. **204**

---

## Encomendas

### GET `/encomendas/abertas`

Lista encomendas em aberto da série configurada (`SerieEncomendasNdos` — appsettings).

**Autorização:** autenticado

**Query**

| Parâmetro | Tipo | Descrição |
| --- | --- | --- |
| `dataDe` | date | |
| `dataAte` | date | |
| `horaDe` | time | |
| `horaAte` | time | |
| `clienteNo` | number | |
| `clienteNoContem` | string | Contém no nº de cliente |
| `artigoRef` | string | Contém em `ref` / `design` (lista) |
| `artigoCor` | string | Contém na cor da linha |
| `estadoPlaneamento` | enum | `DentroDoPlaneamento` · `AposCorte` · `Todos` |
| `metodoExpedicao` | string | Opcional. Valor PHC exacto (`BO3.u_modExp`); `nao_definido` = vazio; omitido/`Todos` = sem filtro. Aplicado **antes** da paginação. |
| `prontaPicking` | bool | `false` = Encomendas; `true` = Em Picking (só `pronta_picking=1` **e** ainda há linha por separar: `BI.qtt > SUM(66.BI.qtt)` por `obistamp`) |
| `pickStatus` | number | Opcional. Estado efectivo Kapps/`u_pickstat` (0–3). |
| `page` | number | default 1 |
| `pageSize` | number | default 50 (máx. 200) |
| `sort` | string | ex.: `dataobra:desc` |

**Critério de aberto (servidor)** — *encomenda aberta* (vista / lista sem filtro Picking)

- `bo.ndos = SerieEncomendasNdos`
- `ISNULL(bo.fecho,0) = 0` (**fechada = 0**)
- existe linha com `ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) > bi.qtt2`

Este critério **não** define permanência em Em Picking.

**Filtro Em Picking (`prontaPicking=true`)** — adicional à vista; **não** altera `u_pickrdy`:

```text
pronta_picking = 1  (u_pickrdy)
AND EXISTS pelo menos uma linha onde:
  BI.qtt > ISNULL(SUM(66.BI.qtt), 0)
  com 66.BI.obistamp = 1.BI.bistamp
  e bo66.ndos = SeriePickingNdos
```

(todos os 66 ligados; **sem** filtrar `fechada` / `u_chkin`; **documentos 65 não entram**)

#### Distinção (não confundir)

| Conceito | Critério |
| --- | --- |
| **Encomenda aberta** | Vista/endpoint: fechada=0 + linha com `u_qttorig` (ou `qtt`) `> qtt2` |
| **Em Picking** | `u_pickrdy=1` **e** ainda há quantidade por separar: `BI.qtt > SUM(66.BI.qtt)` |
| **Quantidade materializada em 66 (`temQtt66`)** | `EXISTS` linha com `SUM(66.BI.qtt) > 0` — indicador da **REGRA B** (cancel/desmarcar), **não** a regra de permanência na lista |

**Quantidade por satisfazer (por linha)**

```text
quantidadePorSatisfazer = ISNULL(NULLIF(u_qttorig, 0), qtt) - qtt2
```

> O restante a fornecer é gerido pela **quantidade original** (`u_qttorig`), não pelo `BI.qtt` ajustado.  
> **Representante** (`vendnm` / `vendedor`): **não utilizado** — fora de âmbito.

**Campos relevantes do item (lista)** — além dos campos históricos do exemplo:

| Campo | Tipo | Descrição |
| --- | --- | --- |
| `prontaPicking` | bool | `u_pickrdy` |
| `pickStatus` | number | Estado efectivo Kapps / `u_pickstat` (0–3) |
| `temQtt66` | bool | **REGRA B:** `true` se existe pelo menos uma linha da encomenda com `SUM(66.BI.qtt) > 0` (`66.BI.obistamp = 1.BI.bistamp`, série `SeriePickingNdos`). **Não** usa `BI.qtt2`, Kapps (`QuantityPicked` / `QuantitySatisfied`) nem ndos=65. **Não** significa “totally separated”, nem “existe 66 aberto”. |

**Response 200**

```json
{
  "page": 1,
  "pageSize": 50,
  "total": 128,
  "items": [
    {
      "boStamp": "ABC123...",
      "numeroEncomenda": 12345,
      "clienteNo": 100,
      "clienteNome": "Cliente X",
      "data": "2026-08-10",
      "hora": "09:15:00",
      "totalLinhas": 8,
      "quantidadeTotal": 420,
      "quantidadePorSatisfazer": 180,
      "estado": "Aberto",
      "estadoPlaneamento": "Após Limite Definido",
      "estadoPlaneamentoCodigo": "AC",
      "prontaPicking": true,
      "pickStatus": 1,
      "temQtt66": false
    }
  ]
}
```

**Erros:** 401

---

### GET `/encomendas/{boStamp}`

Detalhe do cabeçalho e linhas.

**Autorização:** autenticado (Cliente: apenas as suas, Fase 2)

Inclui o mesmo indicador `temQtt66` (REGRA B) que a lista.

**Response 200**

```json
{
  "boStamp": "ABC123...",
  "numeroEncomenda": 12345,
  "serie": 1,
  "nomeSerie": "Encomenda Cliente",
  "clienteNo": 100,
  "clienteEstab": 0,
  "clienteNome": "Cliente X",
  "data": "2026-08-10",
  "hora": "09:15:00",
  "estadoPlaneamento": "Dentro do Limite Definido",
  "estadoPlaneamentoCodigo": "DP",
  "prontaPicking": true,
  "pickStatus": 1,
  "temQtt66": false,
  "linhas": [
    {
      "biStamp": "LIN001...",
      "ref": "A-001",
      "descricao": "Farinha 1kg",
      "quantidade": 50,
      "quantidadeOriginalPortal": 100,
      "qtt": 50,
      "qtt2": 40,
      "quantidadePorSatisfazer": 60,
      "precoUnitario": 9.50,
      "precoUnitarioOriginal": 10.00,
      "quantidadeAutorizada": 60,
      "autorizadaPor": "ana.operadora",
      "autorizadaEm": "2026-08-10T11:20:00",
      "usrinis": "ANA",
      "usrdata": "2026-08-10",
      "usrhora": "11:20:00"
    }
  ]
}
```

> `quantidadePorSatisfazer` = `quantidadeOriginalPortal - qtt2` (aqui `100 - 40 = 60`).

**Erros:** 401, 404

---

### GET `/painel/kpis`

KPIs do Painel Principal.

**Autorização:** autenticado

**Disponibilidade:** KPIs de rutura / capacidade operacional usam a **previsão aberta** (Previsto − Alocado), não `ST.stock`. Ver [`PROJECT-STATE.md`](./PROJECT-STATE.md).

**Response 200**

```json
{
  "encomendasEmAberto": 128,
  "encomendasAposCorte": 17,
  "artigosEmRutura": 4,
  "quantidadePorSatisfazer": 15420.5,
  "quantidadeAutorizada": 9800,
  "clientesAfetados": 63
}
```

> Campo futuro (não no MVP): `encomendasCashCarryPendentes`.

---

### GET `/painel/centro-estados`

KPIs do Centro de Operações / Vista TV.

**Autorização:** **anónimo** (`[AllowAnonymous]`) — usado pela TV pública.

**Response 200** — duas famílias de métricas no mesmo payload (não misturar):

| Família | Campos | Unidade | Uso UI |
| --- | --- | --- | --- |
| COUNT operacional | `emAberto`, `emPicking`, `separado`, `emEntrega`, `expedido`, (`expedicao`, `concluidas`, `total`) | Documentos | Número grande dos 5 cards (= critério das listas) |
| Distribuição lógica | `distribuicaoLogica` | Encomendas `ndos=1` (**1,0 unidade repartida**; `quantidade` pode ser decimal) | Texto `X% encomendas` nos cards |

```json
{
  "emAberto": 12,
  "emPicking": 1,
  "expedicao": 11,
  "separado": 10,
  "emEntrega": 1,
  "expedido": 1,
  "concluidas": 3,
  "total": 27,
  "distribuicaoLogica": {
    "totalEncomendasLogicas": 24,
    "emAberto": { "quantidade": 12, "percentagem": 50.0 },
    "emPicking": { "quantidade": 1, "percentagem": 4.2 },
    "separado": { "quantidade": 9.5, "percentagem": 39.6 },
    "emEntrega": { "quantidade": 1.0, "percentagem": 4.2 },
    "emExpedicao": { "quantidade": 0.5, "percentagem": 2.1 },
    "naoClassificadas": 0
  }
}
```

Cada encomenda lógica contribui **1,0**: só 66 → 100% repartidos pelos 66 activos; 66+65 → 50% conjunto 66 + 50% Em Expedição; só 65 → 100% Em Expedição.  
Detalhe e evidência UAT: [`PROJECT-STATE.md`](./PROJECT-STATE.md) § Centro / TV.

### GET `/painel/tv-kapps-resumo`

Resumo Kapps **magro** (kind / pct / operador / qty) para TV, Em Picking, Separado e Centro — evita N+1 de detalhe Kapps.

**Autorização:** **anónimo** (`[AllowAnonymous]`).

**Response 200**

```json
{
  "items": [
    {
      "boStamp": "...",
      "origem": "encomenda",
      "qty": 12,
      "picked": 4,
      "pending": 8,
      "kind": "curso",
      "pct": 33,
      "activeTerminalId": 1,
      "activeTerminalLabel": "T1",
      "activeUserId": "op1"
    }
  ]
}
```

`kind`: `espera` | `curso` | `concluido`. Expandir linha na UI autenticada pode ainda pedir detalhe Kapps completo.

---

## Workflow Picking (encomenda `ndos=1`)

Operações sobre a **encomenda** (série `SerieEncomendasNdos`), não sobre dossiers `SeriePickingNdos`.  
O Portal **não** cria documentos 66/65.

### PATCH `/encomendas/{boStamp}/pronta-picking`

Marca ou desmarca a encomenda como pronta para Picking (`u_pickrdy`).

**Autorização:** autenticado

**Request (conceito):** `{ "pronta": true|false, … }` — parâmetros de confirmação/motivo conforme implementação actual.

Quando `pronta = false` (desmarcar / retirar de Picking):

> **REGRA B:** não é permitido desmarcar depois de existir quantidade materializada num documento da série `SeriePickingNdos` (`EXISTS` linha com `SUM(66.BI.qtt) > 0`, ligação `66.BI.obistamp = 1.BI.bistamp`). Independente de `BI.qtt2`, Kapps (`QuantityPicked` / `QuantitySatisfied`) e ndos=65.

Quando permitido, desmarcar desfaz a preparação Portal e devolve a encomenda ao universo de Encomendas (semântica operacional já existente nas SPs HCA).

**Erros típicos:** 401, 404, 409 (incl. bloqueio REGRA B).

### POST `/picking/{boStamp}/cancel`

Cancelar Picking na encomenda (desfazer preparação Portal quando permitido).

**Autorização:** autenticado

**Request (opcional):** `{ "motivo": "…" }`

> **REGRA B:** uma encomenda **não** pode ser cancelada do Picking depois de existir quantidade materializada num documento 66 (`SeriePickingNdos`), com o mesmo critério `SUM(66.BI.qtt) > 0` por linha/`obistamp`. Independente de `BI.qtt2`, estado Kapps e documentos 65.

Quando permitido, o cancelamento mantém o significado operacional já documentado nas SPs: desfazer a preparação Portal e devolver a encomenda ao estado de Encomendas (restauro de `BI.qtt` a partir de `u_qttorig`, limpeza de autorizações / flags de pronta — **sem** alterar documentos 66).

**Erros típicos:** 401, 404, 409 (bloqueio REGRA B / conflitos SP).

### Endpoints técnicos de workflow (`start` / `complete` / `ready` / `reopen`)

Existem na API:

| Método | Caminho |
| --- | --- |
| POST | `/picking/{boStamp}/start` |
| POST | `/picking/{boStamp}/complete` |
| POST | `/picking/{boStamp}/ready` |
| POST | `/picking/{boStamp}/reopen` |

São **endpoints técnicos** de transição de `u_pickstat` / preparação. **Não** fazem parte do fluxo normal da UI actual (a interface não expõe botões equivalentes “Iniciar” / “Concluir” em Em Picking). O progresso operacional de picagem é tipicamente refletido via Kapps / estado efectivo, não via estes botões.

---

## Pendentes de Picagem (ndos=1)

Consulta de encomendas da série `SerieEncomendasNdos` (tipicamente 1) que **já iniciaram fisicamente o Picking** e ainda têm quantidades por picar.  
**Autorização:** autenticado (cookie).  
**≠** lista Em Picking (`/encomendas/abertas?prontaPicking=true`). Regra completa: [`PROJECT-STATE.md`](./PROJECT-STATE.md) § *Pendentes de Picagem*.

**Semântica (resumo):**

| Passo | Regra |
| --- | --- |
| Universo | `ndos=1` ∧ `fechada=0` ∧ `u_pickrdy=1` (+ filtros de documento) |
| Started (encomenda) | ∃ linha com `Picked>0` ∨ `SUM66>0` — calculado sobre **todas** as linhas, **antes** de `artigoRef` / `artigoCor` |
| Pending (linha) | `Picked>0` → `qtt − qtt2 − Picked`; senão → `qtt − SUM66` (**nunca** `qtt − SUM66 − Picked`) |
| Inclusão | `Pending > 0` |
| 65 / sessões | **Não** participam |

**Paginação 1A:** linhas elegíveis → Service agrupa (encomenda ou referência) → ordena → `page` / `pageSize` / `totalItems`. `pageSize` omitido ou ≤0 → devolve todos os grupos. Se enviado: clamp **1..200**.

**Query comuns** (`GET` lista e por-referência):

| Query | Tipo | Notas |
| --- | --- | --- |
| `dataDe` / `dataAte` | date | Filtro de documento (`BO.dataobra`) |
| `obrano` | number | Nº encomenda exacto |
| `clienteNomeContem` | string | Contém em `BO.nome` / `BO.nome2` |
| `artigoRef` / `artigoCor` | string | Filtro de **linha** (após `started`) |
| `page` | number | Default 1 |
| `pageSize` | number \| omitido | Ver paginação 1A |

O frontend **apresenta** `pending` / totais recebidos — **não** recalcula Pending.

### GET `/pendentes-picagem`

Lista agregada **por encomenda**.

**Response 200**

```json
{
  "page": 1,
  "pageSize": 200,
  "totalItems": 1,
  "items": [
    {
      "boStamp": "ADM…",
      "numeroEncomenda": 27,
      "clienteNo": 1228,
      "clienteNome": "…",
      "clienteNome2": null,
      "dataEntrega": "2026-10-10T00:00:00",
      "metodoExpedicao": null,
      "quantidadePendenteTotal": 9,
      "totalLinhasPendentes": 3,
      "linhas": [
        {
          "boStamp": "ADM…",
          "biStamp": "ADM…",
          "numeroEncomenda": 27,
          "clienteNo": 1228,
          "clienteNome": "…",
          "clienteNome2": null,
          "ref": "1280",
          "designacao": "…",
          "cor": "",
          "qtt": 7,
          "qtt2": 3,
          "sum66": 3,
          "picked": 0,
          "pending": 4,
          "fonte": "Sum66",
          "dataEntrega": "2026-10-10T00:00:00",
          "metodoExpedicao": null
        }
      ]
    }
  ]
}
```

`fonte`: `"Kapps"` | `"Sum66"` (valor de apresentação; o Pending vem sempre do backend).

### GET `/pendentes-picagem/por-referencia`

Lista agregada **por referência**. Mesmos filtros / paginação. Cada item inclui `documentos[]` com identificação documental (`numeroEncomenda`, `clienteNo`, `clienteNome`, `clienteNome2`) e `quantidadePendente` — **sem** segundo cálculo no cliente.

**Response 200 (resumo)**

```json
{
  "page": 1,
  "pageSize": 200,
  "totalItems": 3,
  "items": [
    {
      "ref": "1280",
      "designacao": "…",
      "quantidadePendenteTotal": 4,
      "totalLinhasPendentes": 1,
      "totalDocumentos": 1,
      "documentos": [
        {
          "boStamp": "ADM…",
          "numeroEncomenda": 27,
          "clienteNo": 1228,
          "clienteNome": "…",
          "clienteNome2": null,
          "quantidadePendente": 4
        }
      ]
    }
  ]
}
```

### GET `/pendentes-picagem/{boStamp}/linhas`

Linhas pendentes da encomenda (`Pending>0`), mesma semântica da lista. Cliente / `fonte` / `qtt` / `sum66` / `picked` / `pending` alinhados ao DTO de linha acima.

---

## Dossiers de picking (ndos=66)

### GET `/picking-dossiers`

Lista dossiers da série picking (`SeriePickingNdos`, tipicamente 66).

**Query relevantes:** `fechada`, `checkIn` (`true` = A Preparar Entrega; `false` = Separado), filtros de data/cliente/artigo, `estadoPlaneamento`, `metodoExpedicao` (mesmo contrato que `/encomendas/abertas`), `pickStatus`, paginação.

**Campos de quantidade (item):**

| Campo JSON | Semântica |
| --- | --- |
| `quantidadeTotal` | Histórico: `SUM(ISNULL(NULLIF(u_qttorig,0), qtt))` — **não** usar como Qtd. documento no Separado |
| `quantidadePorSatisfazer` | Histórico: restante com base em `u_qttorig` |
| `quantidadeDocumento` | `SUM(BI.qtt)` — quantidade do documento |
| `quantidadeExpedida` | `SUM(BI.qtt2)` |
| `quantidadePendenteEntrega` | `SUM(BI.qtt − BI.qtt2)` |

Badge UI **Entrega parcial** (só Separado): `quantidadeExpedida > 0` ∧ `quantidadePendenteEntrega > 0`.

### GET `/picking-dossiers/{boStamp}/linhas`

Linhas via `view_HCA_encomenda_linhas`. Para Separado a UI usa `qtt` / `qtt2` / `qtt − qtt2` (todas as refs visíveis).

### POST `/picking-dossiers/{boStamp}/reverter-check-in`

Reverte Check-in (`u_chkin=0`). UI: **Voltar ao Separado**. Não altera `BI.qtt` / `BI.qtt2` / Kapps / `fechada`.

### POST `/picking-dossiers/check-in`

Marca Check-in em lote (`u_chkin=1`).

---

## Dossiers de separação / expedição (ndos=65)

### GET `/separacao-dossiers`

Lista dossiers `SerieSeparacaoNdos` (tipicamente 65). Query `fechada=false` → Em Expedição; `fechada=true` → Concluídas. Aceita os mesmos filtros de data/cliente/artigo/`estadoPlaneamento`/`metodoExpedicao`/paginação que as outras listas de dossiers.

### GET `/separacao-dossiers/{boStamp}/linhas`

Linhas do dossier 65.

### PATCH `/separacao-dossiers/{boStamp}/fechada`

Body: `{ "fechada": true | false }`.

| `fechada` | Efeito | SP |
| --- | --- | --- |
| `true` | Fecho operacional: `BO.fechada=1` + `BI.fechada=1` (linhas do `bostamp`) | `sp_HCA_fechar_expedicao_dossier` |
| `false` | Reabrir: `BO.fechada=0` + `BI.fechada=0` | `sp_HCA_reabrir_expedicao_dossier` |

**Não** altera `qtt` / `qtt2`, não fatura, não cria documentos.  
Erros: **404** (não encontrado / série incorrecta); **409** (já fechada / já aberta).  
UI Em Expedição: confirmação «fechado sem faturação»; Concluídas: Reabrir.

A SP genérica `sp_HCA_marcar_fecho_picking_dossier` (048) **não** é usada neste endpoint (reservada a picking-dossiers / ndos=66).

---

## Quantidade e preço da linha (RN-020 / RN-021)

### PATCH `/encomendas/linhas/{biStamp}`

Ajusta a quantidade a fornecer e/ou o preço unitário de uma linha em aberto.

**Autorização:** autenticado

**Request**

```json
{
  "quantidade": 50,
  "precoUnitario": 9.50
}
```

Campos opcionais individualmente (enviar pelo menos um).

**Comportamento — quantidade (RN-020)**

1. Se `BI.u_qttorig = 0` → gravar `BI.qtt` atual em `u_qttorig`  
2. Atualizar `BI.qtt`  
3. Atualizar `BI.usrinis`, `BI.usrdata`, `BI.usrhora`  
4. Atualizar `BO.usrinis`, `BO.usrdata`, `BO.usrhora`  
5. Recalcular linha (`etiliquido` / `ettdeb`) e totais `BO` quando exigido pelo PHC (equiv. **BOTOTS**)  

**Nunca** sobrescrever `u_qttorig` quando já for diferente de **0**.  
**Não** gravar só `qtt` sem recálculo de totais quando o PHC o exige.  
**Sem** escrita obrigatória em `U_PORTALAUDIT`.

**Comportamento — preço (RN-021)**

1. Se `BI.u_prcorig = 0` → gravar **`BI.edebito`** atual em `u_prcorig`  
2. Atualizar **`BI.edebito`**  
3. Recalcular linha (`etiliquido` / `ettdeb`) e totais `BO` (equivalente a **BOTOTS**)  
4. Atualizar `BI.usrinis`, `BI.usrdata`, `BI.usrhora`  
5. Atualizar `BO.usrinis`, `BO.usrdata`, `BO.usrhora`  

**Nunca** sobrescrever `u_prcorig` quando já for diferente de **0**.  
> Como `u_prcorig` é `numeric NOT NULL`, **0** = “ainda não preenchido”. Se existirem preços originais reais a 0 no futuro, rever a abordagem.  
Sem validações de desconto, margem, preço mínimo ou variação máxima.  
**Não** gravar só `edebito` sem recálculo de totais.

**Auditoria MVP**

| Camada | O quê | Onde |
| --- | --- | --- |
| PHC | Quem / quando (visível no Desktop) | `usrinis`, `usrdata`, `usrhora` em **BI** e **BO** |
| Portal | Before/after detalhado | `U_PORTALAUDIT` — **não** MVP (futuro) |

**Não** alterar `ousrinis` / `ousrdata` / `ousrhora` (criação) em `BO` nem `BI`.  
**Não** existem campos `U_*` do tipo `u_qttalteradapor` / `u_precoalteradapor`.

**Efeitos ao sucesso**

- Escrita nativa: `BI.qtt` e/ou **`BI.edebito`** + totais linha/cabeçalho + `usr*` em `BI` e `BO`
- Originais `U_*` quando 1.ª alteração
- Evento SignalR (opcional / recomendado)

**Response 200**

```json
{
  "biStamp": "LIN001...",
  "quantidade": 50,
  "quantidadeOriginalPortal": 100,
  "precoUnitario": 9.50,
  "precoUnitarioOriginal": 10.00,
  "usrinis": "ANA",
  "usrdata": "2026-08-10",
  "usrhora": "11:20:00"
}
```

---

## Quantidade autorizada (expedição / alocação)

### PATCH `/encomendas/linhas/{biStamp}/quantidade-autorizada`

Atualiza a quantidade autorizada de uma linha.

**Autorização:** autenticado  
**Ultrapassar** `quantidadeAutorizada > quantidadePorSatisfazer`: permitido a autenticados no MVP (perfis = futuro)

**Request**

```json
{
  "quantidadeAutorizada": 25,
  "valorAnteriorEsperado": 10
}
```

**Validação (PR3-C / actual)**

- `quantidadeAutorizada >= 0`
- Exige **previsão de entrada aberta** e quantidade prevista para Ref (+ Cor)
- **Sem teto** `ST.stock` e **sem teto** Previsto − Alocado (disponibilidade pode ficar negativa)
- `@permitir_acima_stock` é **legado e ignorado**
- Concorrência: `valorAnteriorEsperado` deve coincidir com o valor atual
- Bloqueio de **alteração da quantidade autorizada** se o picking já avançou no PHC (`u_pickstat` ≥ 1), conforme SP de autorização — **não** é a REGRA B de Cancelar/Desmarcar Picking (essa usa `temQtt66` / `SUM(66.BI.qtt) > 0`)

**Disponibilidade exposta (legado de nome):**

```text
quantidadeDisponivel / stockDisponivel = Previsto − Alocado  (previsão aberta, Ref + Cor)
-- pode ser negativa; NÃO é ST.stock
```

**Efeitos ao sucesso**

- `BI2.u_qtdaut` (+ `u_qtdautur`, `u_qtdautdt`)
- `u_qtdaut > 0` → `BI2.u_previd` = Id previsão; `u_qtdaut = 0` → `u_previd = ''`
- **1.ª** autorização: pode ajustar `BI.qtt` operacional (ver SP / business-flows)
- SignalR: **invalidação** (`dossier*` / `kappsAlterado`) → cliente refetch — sem payload de qtd

**Response 200**

```json
{
  "biStamp": "LIN001...",
  "quantidadeAutorizada": 25,
  "autorizadaPor": "ana.operadora",
  "autorizadaEm": "2026-08-10T11:20:00",
  "quantidade": 25,
  "quantidadeOriginalPortal": 40,
  "quantidadePorSatisfazer": 40,
  "primeiraAutorizacao": true
}
```

**Erros**

| HTTP | Condição |
| --- | --- |
| 400 | Validação de domínio / sem previsão |
| 401 | Auth |
| 404 | Linha inexistente |
| 409 | Conflito de concorrência / regras SP |

---

### POST `/encomendas/linhas/quantidade-autorizada/lote`

Atualização em lote (mesmo artigo recomendado numa transação).

**Autorização:** autenticado

**Request**

```json
{
  "linhas": [
    { "biStamp": "LIN001...", "quantidadeAutorizada": 30, "valorAnteriorEsperado": 10 },
    { "biStamp": "LIN002...", "quantidadeAutorizada": 20, "valorAnteriorEsperado": 0 }
  ]
}
```

**Response 200**

```json
{
  "atualizadas": 2,
  "itens": [ /* mesmo formato do PATCH */ ]
}
```

**Erros:** 400, 401, 409 (concorrência / regras SP) — operação atómica por lote do mesmo artigo.

---

## Rastreio de artigos

### GET `/artigos/procura-aberta`

Agregação de procura em aberto por artigo (ref+cor), classificada por planeamento (DP/AC).

**Autorização:** autenticado

**Arquitectura (Backend 1A):** pipeline Fase 1 (SQL linhas + filtros) → C# (`PlaneamentoCalculator` / `CoincideFiltro` / GroupBy / agregações / OrderBy) → `totalItems` → Skip/Take → Fase 2 Prev* só para `(Ref,Cor)` da página → `quantidadeDisponivel`. A regra DP/AC **não** foi migrada para SQL. Detalhe, baseline UAT e limitações: [`PROJECT-STATE.md`](./PROJECT-STATE.md) § *Em Aberto por referência — Backend 1A*.

**Query relevantes:** `estadoPlaneamento`, `q`, `cor`, `dataDe`/`dataAte`, `horaDe`/`horaAte`, `clienteNoContem`, `metodoExpedicao` (mesmo match que as listas; filtragem nas **linhas** antes do `GroupBy` — a referência aparece se ≥1 linha corresponder; totais só dessas linhas), `page` (default 1), `pageSize` (**opcional**). Sem N+1 a `encomendas-abertas`.

| Query | Tipo | Notas |
| --- | --- | --- |
| `page` | number | Default 1 |
| `pageSize` | number \| omitido | Omitido → devolve **todos** os grupos (compat. FE actual). Se enviado: clamp **1..200**. Na resposta, se omitido no pedido, `pageSize` = tamanho efectivo da lista completa. |

**Disponibilidade:** `quantidadeDisponivel` = Previsto − Alocado (previsão aberta; nome legado). **Não** `ST.stock`. Calculado na Fase 2 apenas para as chaves da página.

**Frontend:** consome `items`; **ainda não** envia paginação.

**Response 200**

```json
{
  "items": [
    {
      "ref": "A-001",
      "descricao": "Farinha 1kg",
      "cor": "",
      "quantidadeEncomendada": 500,
      "quantidadeFornecida": 100,
      "quantidadePorSatisfazer": 400,
      "quantidadeDisponivel": 200,
      "quantidadeAutorizadaTotal": 180,
      "estadoPlaneamentoCodigo": "AC"
    }
  ],
  "page": 1,
  "pageSize": 25,
  "totalItems": 123
}
```

---

### GET `/artigos/{ref}/encomendas-abertas`

Linhas / encomendas afetadas por artigo.

**Autorização:** autenticado

**Disponibilidade:** `quantidadeDisponivel` = Previsto − Alocado (previsão aberta). **Não** `ST.stock`.

**Response 200**

```json
{
  "ref": "A-001",
  "descricao": "Farinha 1kg",
  "quantidadeDisponivel": 200,
  "encomendas": [
    {
      "boStamp": "ABC...",
      "biStamp": "LIN...",
      "clienteNome": "Mercearia",
      "numeroEncomenda": 1042,
      "quantidadePedida": 60,
      "quantidadePorSatisfazer": 60,
      "quantidadeAutorizada": 30
    }
  ]
}
```

---

### POST `/artigos/{ref}/alocar/previsualizar`

Simula alocação proporcional **sem gravar**.

**Autorização:** autenticado

**Regra actual (PR2-A / SQL `069`+):** capacidade vem da **previsão aberta** no SP. `@disponivel` / `quantidadeDisponivel` do cliente é **legado e ignorado**. `fonteStock` = `u_HcaPrevEntrada`.

**Request**

```json
{
  "modo": "Proporcional",
  "quantidadeDisponivel": 5,
  "cor": ""
}
```

- `cor` presente (mesmo `""`) → filtra linhas dessa cor; ausente → todas as cores do `ref`.
- `quantidadeDisponivel` no body: **ignorado** (mantido por compatibilidade de contrato).

**Response 200**

```json
{
  "ref": "A-001",
  "stockDisponivel": 200,
  "quantidadeDisponivel": 200,
  "fonteStock": "u_HcaPrevEntrada",
  "simular": true,
  "somaProposta": 5,
  "alocacoes": [
    { "biStamp": "LIN...", "boStamp": "BO...", "numeroEncomenda": 1042, "quantidadeProposta": 3, "quantidadePorSatisfazer": 6 }
  ]
}
```

Algoritmo: ver [`business-flows.md`](./business-flows.md) (alocação); Apêndice B da arquitectura é histórico.

---

### POST `/artigos/{ref}/alocar`

Executa alocação proporcional e grava `BI2.u_qtdaut*` + `u_previd`.

**Autorização:** autenticado (MVP; restrição por perfil = futuro)

**Request**

```json
{
  "modo": "Proporcional",
  "quantidadeDisponivel": 5,
  "cor": "VM",
  "confirmar": true
}
```

**Headers:** `Idempotency-Key` recomendado

**Efeitos:** grava autorização no âmbito (`ref` + `cor` opcional); capacidade = previsão aberta; SignalR invalidação → refetch. Sem tecto `ST.stock`.

**Erros:** 400, 401, 409

---

## Cash & Carry — Reservado para futura implementação

Estas rotas **não fazem parte do MVP inicial**.

> Um portal Cash & Carry futuro **pode usar um modelo de autenticação diferente**, a definir mais tarde — **não** desenhar auth C&C no MVP.

| Método | Caminho | Nota |
| --- | --- | --- |
| GET | `/cash-carry` | Reservado para futura implementação |
| GET | `/cash-carry/pendentes` | Reservado para futura implementação |
| POST | `/cash-carry/{boStamp}/aprovar` | Reservado para futura implementação |
| POST | `/cash-carry/{boStamp}/rejeitar` | Reservado para futura implementação |
| POST | `/cash-carry/{boStamp}/em-preparacao` | Reservado para futura implementação |
| POST | `/cash-carry/{boStamp}/comentario` | Reservado para futura implementação |

Estados previstos (futuro): Pendente Aprovação · Aprovada · Em Preparação · Faturada · Rejeitada.

---

## Administração

### GET `/administracao/diagnostico`

Informação operacional / diagnóstico simples do portal (opcional).

**Autorização:** autenticado

**Response 200** (exemplo)

```json
{
  "ambiente": "UAT",
  "versaoApi": "1.0.0",
  "sqlOk": true,
  "serieEncomendasNdos": 1,
  "cortePlaneamento": {
    "dia": "Segunda",
    "hora": "12:00",
    "fuso": "Europe/Lisbon",
    "fonte": "appsettings"
  }
}
```

### GET `/administracao/auditoria`

**Não no MVP** — melhoria futura; fora do MVP; dependeria de uma futura `U_PORTALAUDIT`.

> A consulta de auditoria detalhada é uma melhoria futura. No MVP, a auditoria operacional é assegurada pelos campos nativos PHC `usr*` em `BO` e `BI`.

> Gestão de utilizadores do portal: ver secção **Administração de utilizadores** (`/admin/utilizadores`).  
> Limite definido e séries: defaults da aplicação (leitura possível via diagnóstico).
> Sem SMTP de convites; sem outros perfis além de `Admin` no MVP.

---

## Portal Cliente (Fase 2)

### POST `/publico/registo/iniciar`

Inicia registo após QR Code. Aplica **RN-017**.

**Autorização:** anónimo

**Request**

```json
{
  "nif": "123456789",
  "telemovel": "912345678"
}
```

**Validação (RN-017)**

1. Normalizar telemóvel introduzido e contactos PHC com `NormalizePhoneNumber()`  
2. Procurar cliente PHC com `CL.ncont` = NIF  
3. Contacto efetivo = `CL.tlmvl` se preenchido; senão `CL.telefone`  
4. Comparar telemóvel **já normalizado**  
5. Se válido → preparar conta cliente (modelo F2 a definir — **sem** `U_PORTALUSER` no MVP atual)  
6. Se inválido → bloquear  

**Response 400** (falha — mensagem exacta)

```json
{
  "mensagem": "Não encontramos os seus dados nos nossos registos. Dirija-se por favor ao balcão para atualização dos dados de cliente."
}
```

### Outros endpoints Fase 2 (âmbito fechado)

| Método | Caminho | Descrição |
| --- | --- | --- |
| POST | `/publico/registo/confirmar` | Confirmação / OTP futuro |
| GET | `/catalogo/produtos` | Catálogo (imagens, preços, stock) |
| POST | `/eu/encomendas` | Nova encomenda |
| GET | `/eu/encomendas` | Histórico e estado |
| GET | `/eu/faturas` | Consulta de faturas |
| GET | `/eu/faturas/{id}/pdf` | Download PDF |

---

## SignalR

Realtime = **invalidação** (sem DTO de negócio). Detalhe: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| Hub | Path | Auth | Grupo |
| --- | --- | --- | --- |
| `OperacoesHub` | `/hubs/operacoes` | Cookie (`[Authorize]`) | `operacoes` |
| `TvHub` | `/hubs/tv` | **Anónimo** (`[AllowAnonymous]`) | `tv` |

Eventos (ambos os hubs): `dossier66Alterado`, `dossier65Alterado`, `kappsAlterado`, `encomendaAlterada` → o cliente faz **refetch** das APIs / queries existentes.

Em `/picking`, `dossier66Alterado` invalida também a lista `encomendas/abertas` (`prontaPicking=true`), porque a criação de 66 pode retirar a encomenda da lista.

Fonte: `ExternalChangeDetector` + `ExternalChangeRealtimeHostedService` (ciclo ~5 s). TV mantém polling 30 s como fallback.

---

## Códigos HTTP comuns

| Código | Uso |
| --- | --- |
| 200 / 201 / 204 | Sucesso |
| 400 | Validação / RN-017 / sem previsão |
| 401 | Não autenticado |
| 403 | Sem permissão (raro no MVP — sem matriz de perfis) |
| 404 | Recurso inexistente |
| 409 | Concorrência / regras SP |
| 500 | Erro interno (sem expor detalhes sensíveis) |

---

*Contrato com emendas 2026-10-06 — SoT operacional: PROJECT-STATE.md. Baseline histórica: ARCHITECTURE.md.*
