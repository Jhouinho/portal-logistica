# Checklist de Instalação PHC e Aplicação

> **HISTÓRICO / parcialmente SUPERSEDED (2026-09-29).**  
> Checklist da Fase 0B. Itens `ST.stock` / RN-018 e auth só `u_portalph` **não** reflectem o Portal actual (previsão + Identity).  
> SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md) · Identity: [`auth-portal-identity.md`](./auth-portal-identity.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística e B2B |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) · [sql/001_user_fields.md](../sql/001_user_fields.md) |
| Uso | Executar em UAT e repetir em Produção — corresponde à **Fase 0B** (histórico) |
| GO Sprint 1 | [ARCHITECTURE.md](../ARCHITECTURE.md#critérios-para-início-de-desenvolvimento-go-sprint-1) |

Marcar cada item aquando da conclusão.

---

## Base de Dados

### Discovery `US` (0B)

| Item | OK UAT | OK Prod |
| --- | --- | --- |
| Confirmar tabela `US` | ☐ | ☐ |
| Confirmar campo de login em `US` | ☐ | ☐ |
| Confirmar campo de nome em `US` | ☐ | ☐ |
| Confirmar campo de iniciais / fonte para `usrinis` | ☐ | ☐ |

### Identidade — campos em `US` (criar)

| Tabela | Campo físico | Tipo | OK UAT | OK Prod |
| --- | --- | --- | --- | --- |
| US | `u_portalph` | `varchar(254) NOT NULL` | ☐ | ☐ |

### Não criar no MVP

| Item | Estado | OK |
| --- | --- | --- |
| `US.u_portalperfil` | ✗ **Não criar** (perfis = futuro) | — |
| `US.u_portalativo` | ✗ **Não criar** (RN-019 / futuro) | — |
| `US.u_portalfalhas` | ✗ **Não criar** (**RN-019** = futuro) | — |
| `US.u_portallockuntil` | ✗ **Não criar** (**RN-019** = futuro) | — |
| `CL.u_portalactive` | ✗ **Não criar** no MVP (possível futuro Fase 2) | — |
| `U_PORTALAUDIT` | ✗ **Não criar** no MVP (melhoria futura) | — |
| `U_PORTALUSER` | ✗ **Não criar** | — |
| `U_PORTALREFRESH` | ✗ **Não criar** | — |
| `U_PORTALCFG` | ✗ **Não criar** | — |
| Setup JWT | ✗ **Não criar** | — |

### Campos de utilizador — logística MVP (obrigatórios)

Criar em **Supervisor → Framework → Campos do utilizador** e **Atualizar a Tabela**.

| Tabela | Campo físico | Tipo SQL | OK UAT | OK Prod |
| --- | --- | --- | --- | --- |
| BI | `u_qtdaut` | `numeric(16,2) NOT NULL` | ☐ | ☐ |
| BI | `u_qtdautur` | `varchar(100) NOT NULL` | ☐ | ☐ |
| BI | `u_qtdautdt` | `datetime NOT NULL` | ☐ | ☐ |
| BI | `u_qttorig` | `numeric(16,2) NOT NULL` | ☐ | ☐ |
| BI | `u_prcorig` | `numeric(16,2) NOT NULL` | ☐ | ☐ |

> **NOT NULL:** `u_qttorig` / `u_prcorig` usam **0** como “ainda não preenchido”. Restante = `ISNULL(NULLIF(u_qttorig, 0), qtt) - qtt2`.

**Não criar** `u_portalmobile`.  
**Não criar** `CL.u_portalactive` no MVP — `CL.u_portalactive` poderá ser considerado na Fase 2, caso seja necessário controlar quais clientes têm acesso ao Portal Cliente B2B. **Não faz parte do MVP** do Portal Logístico. No MVP, `CL` = só leitura.

BI: ativar visível na grelha e restringir às séries de encomenda (botão Documentos). ☐

### Confirmações nativas (0B)

| Item | OK |
| --- | --- |
| Confirmar `BI.edebito` | ☐ |
| Confirmar `ST.stock` | ☐ |
| Confirmar `SerieEncomendasNdos = 1` | ☐ |
| Confirmar updates `usr*` em BO/BI + recálculo de totais | ☐ |

### Objetos SQL do portal (0B)

| Item | OK UAT | OK Prod |
| --- | --- | --- |
| Criar vistas `view_HCA_*` | ☑ *catálogo MVP completo em UAT* | ☐ *(só no fim da implementação)* |
| Criar `view_HCA_utilizadores` (script `010`) — ver [fase-0b-view-HCA-utilizadores.md](./fase-0b-view-HCA-utilizadores.md) | ☑ | ☐ *(só no fim da implementação)* |
| Criar `view_HCA_encomendas_abertas` (script `012` + validação `013`) — ver [fase-0b-view-HCA-encomendas-abertas.md](./fase-0b-view-HCA-encomendas-abertas.md) | ☑ | ☐ *(só no fim da implementação)* |
| Criar `view_HCA_encomenda_linhas` (script `014` + validação `015`) — ver [fase-0b-view-HCA-encomenda-linhas.md](./fase-0b-view-HCA-encomenda-linhas.md) | ☑ | ☐ *(só no fim da implementação)* |
| Criar `view_HCA_rastreio_artigos` (script `016` + validação `017`) — ver [fase-0b-view-HCA-rastreio-artigos.md](./fase-0b-view-HCA-rastreio-artigos.md) | ☑ | ☐ *(só no fim da implementação)* |
| Criar `view_HCA_artigo_encomendas` (script `018` + validação `019`) — ver [fase-0b-view-HCA-artigo-encomendas.md](./fase-0b-view-HCA-artigo-encomendas.md) | ☑ | ☐ *(só no fim da implementação)* |
| Criar procedimentos `sp_HCA_*` | ☑ *catálogo MVP completo em UAT* | ☐ *(só no fim da implementação)* |
| Validar `SELECT` nas `view_HCA_*` | ☑ | ☐ |
| Validar `EXEC` nas `sp_HCA_*` | ☑ | ☐ |
| Validar permissões SQL com a nomenclatura oficial | ☐ *script `030` criado* | ☐ |

> Catálogo: [`sql/002_views_and_procedures.md`](../sql/002_views_and_procedures.md).
### Campos reservados — capacidade futura Cash & Carry (**opcionais**)

| Tabela | Campo físico | Tipo | Criado (opcional) |
| --- | --- | --- | --- |
| BO | `u_ccstatus` | C | ☐ |
| BO | `u_cccomment` | M/C | ☐ |
| BO | `u_ccuser` | C | ☐ |
| BO | `u_ccdate` | D | ☐ |

Campos **opcionais** na Fase 0B. **Não bloqueiam** GO nem go-live do MVP.  
Auth C&C futura pode diferir do MVP — **não** desenhar no MVP.

### Defaults de configuração (appsettings / constantes)

| Parâmetro | Valor MVP | OK |
| --- | --- | --- |
| Dia de corte | Segunda | ☐ |
| Hora de corte | 12:00 | ☐ |
| Fuso | Europe/Lisbon | ☐ |
| `SerieEncomendasNdos` | **1** (confirmar BD) | ☑ *appsettings scaffold* |

> Stock disponível = `ST.stock` (**RN-018**). Não configurar modo de stock. Sem `U_PORTALCFG`.

### Utilizador piloto

| Item | OK |
| --- | --- |
| Pelo menos um utilizador `US` com `u_portalph` (via PHC) | ☑ UAT (`sa`) |
| Hash gerado com PasswordHasher / PBKDF2 (nunca texto simples) | ☑ |
| Login de teste conhecido pela equipa | ☑ |
| Validar hash + login cookie | ☑ UAT (2026-08-10) |

Passwords iniciais temporárias; entregar por canal seguro; alteração de hash no PHC/SQL.

---

## Configuração PHC

| Item | Detalhe | OK |
| --- | --- | --- |
| Confirmar `ndos` encomendas | `SerieEncomendasNdos = 1` em appsettings | ☐ |
| Confirmar séries ativas (encomendas) | Nomes `nmdos` coerentes | ☐ |
| `ndos` Cash & Carry | Apenas se/quando capacidade futura for ativada | ☐ |
| Campos utilizador ativos | Parâmetros gerais PHC | ☐ |
| Visibilidade grelha BI | Autorização / originais qtt-preço visíveis nas séries certas | ☐ |
| Permissões operadores PHC Desktop | Conhecer quem edita os mesmos `U_*` e coexiste com `BI.qtt`/`edebito` | ☐ |
| Gama PHC | `US.u_portalph` + campos `U_*` em BI validados | ☐ |
| Discovery tabela `US` | Colunas de login/nome/iniciais confirmadas | ☐ |
| Preço unitário `BI` = `edebito` (**0A**) | Confirmado Enciclopédia — RN-021 | ✓ |
| Totais / líquidos / BOTOTS (**0A**) | Recálculo obrigatório ao alterar preço/qtt | ✓ |
| `usrinis`/`usrdata`/`usrhora` BO+BI (**0A**) | Confirmados; *verificação pontual* tipagem na 0B | ✓ / ☐ |
| *Verificação pontual* BD cliente (**0B**) | Existência colunas + tipagem `usrinis` + `US` | ☐ |
| Mapeamento `US` → `usrinis` (**0B**) | Documentar campo fonte exacto após validação | ☐ |

---

## SQL Server

### Login dedicado da aplicação

| Item | OK |
| --- | --- |
| Criar login SQL (não usar `sa`) | ☐ *ver [fase-0b-permissoes-sql-app.md](./fase-0b-permissoes-sql-app.md)* |
| Password forte em secret store | ☐ |
| User mapeado na BD PHC | ☐ |
| Executar `030_grant_portal_app.sql` | ☐ |

### Permissões mínimas (modelo `view_HCA_*` + `sp_HCA_*`)

| Objeto | Permissão | OK |
| --- | --- | --- |
| `view_HCA_encomendas_abertas` | `SELECT` | ☑ UAT · ☐ Prod |
| `view_HCA_encomenda_linhas` | `SELECT` | ☑ UAT · ☐ Prod |
| `view_HCA_rastreio_artigos` | `SELECT` | ☑ UAT · ☐ Prod |
| `view_HCA_artigo_encomendas` | `SELECT` | ☑ UAT · ☐ Prod |
| `view_HCA_utilizadores` | `SELECT` | ☑ UAT · ☐ Prod |
| `sp_HCA_validar_login` | `EXECUTE` | ☑ UAT · ☐ Prod |
| `sp_HCA_atualizar_linha_qtt_preco` | `EXECUTE` | ☑ UAT · ☐ Prod |
| `sp_HCA_atualizar_qtd_autorizada` | `EXECUTE` | ☑ UAT · ☐ Prod |
| `sp_HCA_alocacao_proporcional` | `EXECUTE` | ☑ UAT · ☐ Prod |
| Tabelas base `BO`/`BI`/`ST`/`CL`/`US` | Preferir **sem** acesso direto pela aplicação (só via vistas/procedimentos) | ☐ |
| `US.u_portalph` | UPDATE apenas no arranque/SQL (não na UI do portal) | ☐ |
| Sem `U_PORTALUSER` / `U_PORTALREFRESH` / `U_PORTALCFG` / `U_PORTALAUDIT` / `CL.u_portalactive` (MVP) | Confirmado (não criar) | ☐ |
| Sem DDL em produção pela aplicação | Confirmado | ☐ |
| Sem DELETE em BO/BI/ST/FT | Confirmado | ☐ |

> Catálogo: [`sql/002_views_and_procedures.md`](../sql/002_views_and_procedures.md). Criar `view_HCA_*` / `sp_HCA_*` na 0B antes do Sprint 1.

### Índices (validar plano de execução com DBA)

| Índice sugerido | OK |
| --- | --- |
| `BO (ndos, fecho, dataobra)` INCLUDE relevantes | ☐ |
| `BI (bostamp)` INCLUDE `ref, qtt, qtt2, u_qttorig, u_qtdaut*` | ☐ |
| `BI (ref)` INCLUDE para rastreio | ☐ |
| Índice / uniqueness nativo em coluna de login `US` (conforme modelo PHC) | ☐ |

---

## Aplicação — IIS (produção)

### Pré-requisitos no servidor

| Item | OK |
| --- | --- |
| Windows Server 2022+ | ☐ |
| IIS 10+ instalado | ☐ |
| Instalar ASP.NET Core Hosting Bundle (.NET 8) | ☐ |
| Criar Site IIS Portal Web (`portal-web`) | ☐ |
| Criar Site IIS Portal API (`portal-api`) | ☐ |
| Configurar HTTPS (certificado válido, porta 443) | ☐ |
| Redirect HTTP 80 → HTTPS | ☐ |
| Validar ligação SQL | ☐ |
| Validar cookie auth (login + logout + `/auth/me`) | ☐ |
| Validar SignalR | ☐ |

Caminhos exemplo: `C:\inetpub\portal\web` · `C:\inetpub\portal\api`  
Detalhe: [`deployment-architecture.md`](./deployment-architecture.md).

### Servidor / API (.NET 8)

| Item | OK |
| --- | --- |
| `dotnet publish` e deploy para site IIS `portal-api` | ☐ |
| Connection string fora do código | ☐ |
| Data Protection / cookie keys fora do código | ☐ |
| Defaults corte / `SerieEncomendasNdos` em appsettings | ☐ |
| Cookie / sessão configurada (sem JWT) | ☐ |
| CORS alinhado ao `portal-web` (credenciais) | ☐ |
| HTTPS / certificado válido | ☐ |
| Health check a responder | ☐ |
| Swagger desativado ou protegido em Produção | ☐ |
| SignalR hub `/hubs/operacoes` acessível com cookie | ☐ |
| Logs (Serilog) sem dados sensíveis | ☐ |
| Windows Authentication **desligada** no site da API | ☐ |

### Interface (React)

| Item | OK |
| --- | --- |
| `npm run build` e deploy para site IIS `portal-web` | ☐ |
| Redirecionamento SPA (`index.html`) configurado | ☐ |
| URL da API correta por ambiente | ☐ |
| Pedidos com credenciais de cookie (sem Bearer / accessToken) | ☐ |
| Tema escuro e menus PT | ☐ |
| Rotas protegidas por sessão (sem perfil) | ☐ |
| Teste em tablet / touch | ☐ |

### Cookie / sessão e SignalR

| Item | Valor / verificação | OK |
| --- | --- | --- |
| Login devolve `utilizador` + Set-Cookie (sem tokens) | Confirmado | ☐ |
| Logout limpa cookie/sessão | Confirmado | ☐ |
| Sem JWT / Bearer / `/auth/refresh` | Confirmado | ☐ |
| Sem dependência de AD / Entra ID / Windows Auth | Confirmado | ☐ |
| RN-019 **não** exigido no MVP | Confirmado | ☐ |
| SignalR: dois browsers recebem evento de autorização | Testado | ☐ |
| Um nó IIS (ou sticky se NLB futuro) | Documentado | ☐ |

---

## Validação final

Executar com utilizadores `US` que tenham `u_portalph`.

| Cenário | Quem | OK |
| --- | --- | --- |
| Login (cookie) | autenticado | ☐ |
| Painel Principal — KPIs MVP | autenticado | ☐ |
| Encomendas — lista + filtros + cores DP/AC | autenticado | ☐ |
| Encomendas — detalhe | autenticado | ☐ |
| Quantidade / preço da linha (RN-020/021) + `usr*` | autenticado | ☐ |
| Quantidade autorizada — gravar | autenticado | ☐ |
| Ultrapassar autorização > restante | autenticado (MVP) | ☐ |
| Rastreio — pré-visualizar alocação | autenticado | ☐ |
| Rastreio — confirmar alocação | autenticado (MVP) | ☐ |
| Diagnóstico operacional (se existir) | autenticado | ☐ |
| Logout limpa cookie | autenticado | ☐ |
| Sem `/administracao/auditoria` no MVP (consulta detalhada = futuro / `U_PORTALAUDIT`) | verificar | ☐ |
| Nenhum ecrã/API de manutenção de utilizadores / passwords / config corte / auditoria `U_PORTALAUDIT` | verificar | ☐ |
| Nenhum ecrã/API Cash & Carry no MVP | verificar | ☐ |
| Sem JWT / `U_PORTALUSER` / `U_PORTALREFRESH` / `U_PORTALCFG` / `U_PORTALAUDIT` (MVP) | verificar | ☐ |

### Critério de go-live MVP

Todos os itens acima em Produção marcados **OK**, discovery fechado, e aceite formal do cliente registado.  
**Cash & Carry** e **Portal Cliente B2B** ficam fora deste go-live.

---

## Rollback rápido

| Situação | Ação |
| --- | --- |
| Bug crítico na API | Repor release anterior em `C:\inetpub\portal\api`; manter campos `U_*` / `US.u_portalph` |
| Dados de autorização / qtt / preço incorretos | Corrigir via portal ou script controlado (`BI.qtt`, preço nativo, `U_*`) |
| Problema de login | Verificar `US` + hash; regenerar hash via PHC/SQL; validar Data Protection / cookie no IIS |
| Desastre | Ver procedimento em `deployment-architecture.md` (restore SQL + IIS) |

---

*Checklist de implantação alinhado com a arquitetura — sem alteração de regras de negócio de logística.*
