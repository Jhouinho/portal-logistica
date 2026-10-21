# Portal Mobile Liliana & Seródio — Entrega técnica

## Pedidos Mobile Internos — versão 1.0

| | |
| --- | --- |
| **Versão** | 1.0 |
| **Data** | 21 de outubro de 2026 |
| **Estado** | Validação funcional parcial concluída em UAT |
| **Âmbito** | Submissão, aprovação, rejeição e integração de pedidos mobile internos no PHC (`ndos = 67`) |

Documentação relacionada (não substituída por este documento):

- [`portal-mobile-plano-geral-implementacao.md`](./portal-mobile-plano-geral-implementacao.md)
- [`portal-mobile-sp-criar-pedido.md`](./portal-mobile-sp-criar-pedido.md)
- [`portal-mobile-deploy-uat.md`](./portal-mobile-deploy-uat.md)
- [`portal-mobile-estados.md`](./portal-mobile-estados.md) — estados do **dossier** cliente legado (`submetido` / cancelamento); distinto dos estados internos `u_HcaPmPedido`
- Scripts: `sql/098_*`, `sql/099_*`, `sql/100_*`, `sql/101_*` (doc), `sql/102_*`, `sql/103_*`

---

## 1. Objetivo e âmbito

Este documento consolida a implementação dos **pedidos mobile internos**, a preparação da base de dados e da API, as validações executadas e os resultados observados em UAT.

Objetivo da funcionalidade: registar pedidos submetidos pelo portal mobile em tabelas próprias, permitir análise e decisão pela equipa autorizada, e integrar o documento PHC (`ndos = 67`) apenas após aprovação — **sem alterar** os circuitos documentais tradicionais (`ndos` 1 / 66 / 65).

A validação UAT descrita aqui é **parcial**. Não substitui testes de concorrência HTTP/API, recuperação operacional nem o circuito completo de stock/expedição/faturação.

---

## 2. Arquitetura e funcionamento dos pedidos mobile internos

### 2.1. Persistência

| Objecto | Função |
| --- | --- |
| `dbo.u_HcaPmPedido` | Cabeçalho do pedido interno (estado, cliente, associação PHC, decisão) |
| `dbo.u_HcaPmPedidoLin` | Linhas (ref, qtt, preços, totais) |
| `dbo.u_HcaPedidoMobileIdem` | Idempotência da criação do dossier (`IdempotencyKey` → `bostamp` / `obrano` / `boano`) |
| `dbo.HCA_PedidoMobileLinhaType` | TVP de linhas para a SP (após SQL 100: inclui `edebito` opcional) |
| `dbo.sp_HCA_criar_pedido_mobile` | Cria `BO`/`BI` (e extensões) para `ndos = 67` |

Cada pedido recebe um número interno no formato `PM-AAAA-NNNNNN` (campo `NumeroInterno`).

### 2.2. Controlo por configuração

A funcionalidade de fila interna é controlada por `Portal:Cliente:PedidosInternosEnabled`:

- Valor versionado em `Portal.Api/appsettings.json`: **`false`** (omissão segura).
- Com `true` (observado no host UAT `portal-local` durante a validação): a submissão do cliente grava pedido interno (`recebido`) e **não** chama de imediato a SP com TVP legado.
- Com `false`: percurso legado directo — `PedidoMobileLinhaTvp.BuildLegado` → SP com `edebito = NULL`.

Ver implementação em `ClientePedidosService` e opções em `PortalClienteOptions`.

### 2.3. Área staff

API: `api/v1/staff/pedidos-mobile` (`StaffPmPedidosController`) — autenticação Identity staff (não cookie cliente).

Operações relevantes: listar / detalhe / guardar preços (`PUT …/precos`) / aprovar / rejeitar.

---

## 3. Estados do pedido interno

Valores de aplicação em `u_HcaPmPedido.EstadoInterno` (varchar existente desde o script 096; SQL **101** documenta a semântica sem alterar schema):

| Estado | Significado operacional |
| --- | --- |
| `recebido` | Pendente de análise; preços editáveis; rejeitável |
| `em_aprovacao` | Claim atómico antes da SP; preços bloqueados; rejeição bloqueada; aprovação pode continuar |
| `integrado` | Dossier PHC associado (`Bostamp` preenchido); terminal de sucesso |
| `rejeitado` | Terminal; sem dossier |

Nota: o SQL 101 menciona também `em_analise` / `cancelado` como valores possíveis da coluna; a validação UAT desta entrega focou-se nos quatro estados da tabela acima, usados pelo fluxo staff de aprovação.

Até à integração, `Bostamp`, `Obrano`, `Boano` e `Ndos` permanecem sem preenchimento útil (NULL / vazios conforme schema).

---

## 4. Aprovação e integração com `sp_HCA_criar_pedido_mobile`

Fluxo (código + SP):

1. Claim do pedido para `em_aprovacao` (impede rejeição e alteração de preços em concorrência incompatível).
2. Construção do TVP via `PedidoMobileLinhaTvp.BuildStaffComPrecoOperador` — coluna `edebito` = `PrecoUnitario` do operador.
3. Invocação de `dbo.sp_HCA_criar_pedido_mobile` com chave `HCA-PM-APROV-{PedidoId}`.
4. Persistência da associação (`Bostamp`, `Obrano`, `Boano`, `Ndos`, totais) e transição para `integrado`.
5. Campos de decisão (`DecididoPor`, `DataDecisao`) preenchidos na aprovação (schema SQL 098).

Comportamento da SP quanto a preços (SQL 100):

- `edebito` **NULL** → preço via `CL.preco` / `ST.epvN` (legado).
- `edebito` **NOT NULL** → esse valor é o preço unitário da linha → `BI.edebito`.

A UI staff **esconde** o botão de aprovar quando o pedido já está `integrado` (`podeAprovar = false`). Isso é comportamento esperado e não invalida a idempotência da SP.

---

## 5. Idempotência e associação pedido ↔ chave ↔ dossier

| Elemento | Formato / regra |
| --- | --- |
| Chave de aprovação | `HCA-PM-APROV-{PedidoId}` |
| Tabela | `u_HcaPedidoMobileIdem` |
| Garantia SP | Se a chave já existir: `alreadyExists = 1`, devolve o mesmo `bostamp`/`obrano`/`boano`, **sem** criar novo `BO` |

### Evidência UAT (nuance)

Foi demonstrada a **idempotência da stored procedure** com re-execução da SP usando a chave `HCA-PM-APROV-5`: resultado `alreadyExists = 1`, mesmo `bostamp` / `obrano = 8`, contagens de BO67 e de linhas idem inalteradas (`OK_SEM_DUPLICAR`).

**Não** se generaliza este resultado à totalidade do fluxo HTTP/API nem à concorrência na interface. Esses cenários continuam por validar especificamente (ver secção 12).

Diagnóstico de associação (SQL 102, secção C2), nos pedidos 4 e 5: **`OK_ASSOCIACAO`** (pedido, idem e `bo` coerentes; um registo de cada lado).

---

## 6. Tratamento dos preços

| Campo | Onde | Função |
| --- | --- | --- |
| `PrecoSubmissao` | `u_HcaPmPedidoLin` (SQL 099) | Preço original na submissão; preservado para auditoria; **não** é sobrescrito pela edição staff |
| `PrecoUnitario` | `u_HcaPmPedidoLin` | Preço de trabalho do operador (editável se pendente) |
| `TotalLinha` | `u_HcaPmPedidoLin` | Tipicamente `Qtt * PrecoUnitario` |
| `edebito` (TVP) | `HCA_PedidoMobileLinhaType` (SQL 100) | Canal para a SP: `NULL` = legado; valor = preço operador |
| `BI.edebito` | Linha PHC | Preço unitário gravado no dossier |

Código de referência: `PedidoMobileLinhaTvp` (`BuildLegado` → `DBNull`; `BuildStaffComPrecoOperador` → preço arredondado do operador).

**Nota SQL 102:** a secção E do diagnóstico **não** selecciona `PrecoSubmissao` (contrato do script; coluna opcional 099 só via metadados A2b). Na validação UAT, `PrecoSubmissao` foi confirmado por consultas read-only suplementares após aplicação do 099.

---

## 7. Scripts SQL 098, 099 e 100 (aplicados em UAT)

| Script | Ficheiro | Finalidade | Estado UAT |
| --- | --- | --- | --- |
| **098** | `sql/098_alter_u_HcaPmPedido_decisao_staff.sql` | `MotivoRejeicao`, `DecididoPor`, `DataDecisao` + índice de suporte à lista staff | Aplicado (2026-10-21) |
| **099** | `sql/099_alter_u_HcaPmPedidoLin_preco_submissao.sql` | Coluna `PrecoSubmissao`; backfill a partir de `PrecoUnitario` onde NULL; `GRANT` relevante a `portal_app` | Aplicado (2026-10-21) |
| **100** | `sql/100_alter_sp_HCA_criar_pedido_mobile_edebito_opcional.sql` | DROP/recreate TVP + SP com `edebito` opcional; repor `EXECUTE` a `portal_app` | Aplicado (2026-10-21) |

Pré-requisitos de baseline (já existentes na UAT antes desta fatia): 091/093 (SP/TVP com `cor`), 096/096b (tabelas PM), grants `portal_app`.

SQL **101** (`sql/101_doc_estado_em_aprovacao_pedidos_mobile.sql`): documentação / verificação de leitura do estado `em_aprovacao` — **não** altera schema.

---

## 8. Scripts SQL 102 e 103 (apenas diagnóstico)

| Script | Finalidade | Escrita? |
| --- | --- | --- |
| **102** | `sql/102_diagnose_pedidos_mobile_uat_readonly.sql` — esquema, associação C2, preços E3, etc. | Não |
| **103** | `sql/103_precheck_sp_mobile_edebito_readonly.sql` — TYPE/SP, dependências, grants, execuções activas (pré/pós 100) | Não |

Após o SQL 100, o 103 confirmou (resultado observado UAT): TYPE com coluna `edebito` `numeric(19,6)` anulável; única dependência SQL do TYPE = `sp_HCA_criar_pedido_mobile`; `GRANT EXECUTE` a `portal_app` no TYPE e na SP.

---

## 9. Publicação da API, hash e correção WebDAV/IIS

### 9.1. Artefacto observado na publicação UAT

Release gerada com `tools/publish-release.ps1` → pasta `releases/portal-20261021-1427/` (máquina de build / workspace local).

| Propriedade | Valor observado |
| --- | --- |
| Ficheiro | `Portal.Infrastructure.dll` (contém `PedidoMobileLinhaTvp` / gateway BO67) |
| SHA-256 | `66B6B8C06A6ACD15DCB9D3A6E3A0BC9AAAAC3B59C52204EC7CAB3612A9D5ED71` |
| Tamanho | 517 120 bytes |
| Destino IIS local | `C:\inetpub\portal-local\api` |
| `/health` | Operacional (`Healthy`) após publicação |

**Verificação no workspace (2026-10-21):** o mesmo SHA-256 e tamanho foram confirmados em:

- `releases/portal-20261021-1427/Portal.Infrastructure.dll`
- `C:\inetpub\portal-local\api\Portal.Infrastructure.dll`

A pasta `releases/` está excluída pelo `.gitignore` e os artefactos de release não são versionados neste repositório. O hash acima descreve o artefacto de release/publicação observado no disco (workspace / IIS local), não um ficheiro commitado.

A API **não** expõe endpoint de versão/commit; a rastreabilidade faz-se por hash de DLL / pasta de release.

### 9.2. Correção IIS — WebDAV e PUT

Durante os testes, `PUT /api/v1/staff/pedidos-mobile/{id}/precos` devolvia **405 Method Not Allowed** porque o módulo/handler **WebDAV** do IIS interceptava o verbo antes do ASP.NET Core.

Correcção aplicada no `web.config` do site `portal-local` (`remove` de `WebDAV` / `WebDAVModule`). O script `tools/publish-release.ps1` foi actualizado para incluir a mesma remoção nas publicações futuras.

Após a correcção: `PUT` sem autenticação → **401** (esperado); com sessão staff, gravação de preços concluída com sucesso.

---

## 10. Evidências UAT — pedidos 4 e 5

Fonte: validação funcional + diagnósticos read-only (SQL 102 C2/E3 e consultas suplementares) em 21/10/2026, BD UAT utilizada pelo `portal-local`.

### 10.1. Pedido PM-2026-000004 (PedidoId = 4)

| Campo | Resultado observado |
| --- | --- |
| Estado | `integrado` |
| Dossier PHC | `ndos = 67`, `Obrano = 7`, `Boano = 2026` |
| Bostamp | `A0BC5FBC-09C2-4C16-8D69` |
| Chave idem | `HCA-PM-APROV-4` |
| Ref / Qtt | 1051 / 3 |
| `PrecoSubmissao` | 6,50 € |
| `PrecoUnitario` | 6,00 € |
| `BI.edebito` | 6,00 € |
| Total da linha (`TotalLinha` / `BI.ettdeb`) | 18,00 € |
| `BO.etotaldeb` | 16,98 € |

### 10.2. Pedido PM-2026-000005 (PedidoId = 5)

| Campo | Resultado observado |
| --- | --- |
| Estado | `integrado` |
| Dossier PHC | `ndos = 67`, `Obrano = 8`, `Boano = 2026` |
| Bostamp | `2A53510A-D8D5-4E95-B92C` |
| Chave idem | `HCA-PM-APROV-5` |
| Ref / Qtt | 1051 / 3 |
| `PrecoSubmissao` | 6,50 € |
| `PrecoUnitario` | 7,00 € |
| `BI.edebito` | 7,00 € |
| Total da linha | 21,00 € |
| `BO.etotaldeb` | 19,81 € |

---

## 11. Validação de totais, IVA, associação e linhas

Nos **dois** pedidos analisados (resultados observados UAT):

| Verificação | Resultado |
| --- | --- |
| SQL 102 C2 | `OK_ASSOCIACAO` |
| Um único `BO` por `Bostamp` (incl. `ndos = 67`) | Confirmado |
| Uma linha `BI` correspondente à linha PM esperada | Confirmado |
| Linhas BI adicionais no cruzamento Ref + `lordem` | Não detetadas (`qtd_bi_matches = 1`, zero EXTRA) |
| `BI.edebito` = `PrecoUnitario` (E3: `EDEBITO_IGUAL_PRECO_UNITARIO_PEDIDO`) | Confirmado |
| `PrecoSubmissao` distinto do preço operador (auditoria) | Confirmado (6,50 vs 6,00 / 7,00) |
| Totais linha = qtt × preço operador | 3×6,00=18,00; 3×7,00=21,00 |
| `BO.etotaldeb` vs fórmula SP 100 (`ettdeb_liq` com IVA) | 16,98 e 19,81 — coerente com SP |

**IVA:** `BI.iva = 6%`, `ivaincl` convertível. A fórmula de líquido da SP 100 reproduz `BO.etotaldeb`.  
**Limitação:** `regiva` não era acessível ao login `portal_app` (permissão negada); não se declara validação independente da tabela fiscal — apenas coerência BI + fórmula SP.

**Cruzamento BI:** indiciário (`Ref` + `lordem = LinhaOrd * 10000`), **não** chave estrangeira. Consistente nestes casos; não prova absoluta para todos os documentos.

---

## 12. Limitações, riscos e cenários ainda por validar

Ainda **não** estão demonstrados de forma específica / completa:

- Concorrência de aprovações pelo fluxo **HTTP/API** (dois operadores / dois pedidos em paralelo sobre o mesmo `PedidoId`).
- Repetição de aprovação após **perda da resposta HTTP** (cliente a reenviar), para além da re-execução directa da SP.
- Conflitos entre aprovação, rejeição e alteração de preços sob carga.
- Recuperação operacional de pedidos presos em `em_aprovacao` após falha permanente da SP (sem reset cego do estado).
- Pedidos com **várias linhas** e validação abrangente de totais.
- Efeitos posteriores em **stock**, expedição e faturação no circuito PHC do `ndos = 67`.
- Percurso legado directo (`PedidosInternosEnabled = false`, `edebito NULL` → `ST.epv`) nesta mesma janela de testes (a UAT `portal-local` estava com internos activos).

Risco operacional: falha a meio da aprovação pode deixar `em_aprovacao`. **Não** resetar manualmente esse estado sem confirmar primeiro se a SP já criou o dossier (idem / `BO`).

---

## 13. Recomendações para passagem a produção

1. Arquivar resultados dos SQL 102/103 e desta entrega (hashes, datas, PedidoIds).
2. Confirmar versão/configuração do ambiente de destino (IIS sem WebDAV a bloquear PUT; DLL com hash esperado).
3. Activar `Portal:Cliente:PedidosInternosEnabled` **apenas** nos ambientes autorizados.
4. Aplicar 098 → 099 → 100 (e baseline 091/093/096) na ordem correcta; não reexecutar o 100 sem necessidade (DROP+CREATE).
5. Executar testes de concorrência e idempotência no fluxo HTTP/API em ambiente controlado.
6. Documentar procedimento de recuperação de `em_aprovacao`.
7. Validar circuito stock / expedição / faturação aplicável ao dossier 67 com o negócio/PHC.
8. Guardar o artefacto de release e o SHA-256 para rastreabilidade.
9. Manter os circuitos `ndos` 1/66/65 fora do âmbito desta feature.

---

## 14. Conclusão e estado da entrega

| Área | Estado |
| --- | --- |
| Schema 098/099/100 + grants `portal_app` | Aplicado e verificado em UAT |
| API com TVP `edebito` + publicação `portal-local` | Artefacto hash confirmado; `/health` OK |
| Preços staff → `BI.edebito` | Confirmado nos pedidos 4 e 5 |
| Preservação `PrecoSubmissao` | Confirmada nos pedidos 4 e 5 |
| Associação pedido–idem–dossier | `OK_ASSOCIACAO` nos dois casos |
| Idempotência SP (chave `HCA-PM-APROV-5`) | Demonstrada por re-EXEC; HTTP/UI ainda parcial |
| Correção código desta componente | **Não identificada** necessidade com base nos dados disponíveis |

**Estado da entrega:** validação funcional **parcial** concluída em UAT. A implementação pode avançar para revisão técnica e preparação do ambiente de destino, mantendo explícitas as limitações da secção 12.

A validação dos pedidos 4 e 5 **não** substitui os testes adicionais de concorrência HTTP/API, recuperação e circuito operacional completo.
