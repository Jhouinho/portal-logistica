# Baseline Documental v1.0 — Documentação Aprovada

> **HISTÓRICO / SUPERSEDED como SoT (2026-09-29).**  
> Estado operacional actual: [`PROJECT-STATE.md`](./PROJECT-STATE.md).  
> Esta baseline (2026-08-10) aprovou a Fase 0B; regras **RN-018 = ST.stock**, auth só `u_portalph`, e ARCHITECTURE como “única fonte” estão **desactualizadas**. Manter para auditoria.

| | |
| --- | --- |
| Versão | `v1.0-documentacao-aprovada` |
| Projeto | Liliana & Seródio — Portal de Logística e B2B |
| Estado | Documentação aprovada para avançar para **Fase 0B — Preparação de Ambiente** (à data) |
| Data | 2026-08-10 |
| Veredito | **Aprovado** (histórico) |
| Emenda | 2026-08-10 — `CL.u_portalactive` **removido** dos campos obrigatórios MVP (fica apenas como possível futuro Fase 2) |
| Emenda | 2026-08-10 — nomes físicos `U_*` encurtados: `u_portalph`, `u_qtdaut`, `u_qtdautur`, `u_qtdautdt`, `u_qttorig`, `u_prcorig` |
| Emenda | 2026-08-10 — tipagem real PHC + sentinel **0** para `u_qttorig`/`u_prcorig` (`NOT NULL`); restante = `ISNULL(NULLIF(u_qttorig, 0), qtt) - qtt2` |
| Emenda | 2026-09-29 — SoT → `PROJECT-STATE.md`; previsão substitui teto `ST.stock` |

---

## Documentos incluídos nesta baseline

| Ficheiro | Papel |
| --- | --- |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Fonte de verdade arquitetural |
| [README.md](../README.md) | Visão geral e estado do projeto |
| [sql/001_user_fields.md](../sql/001_user_fields.md) | Campos `U_*` obrigatórios e opcionais |
| [sql/002_views_and_procedures.md](../sql/002_views_and_procedures.md) | Catálogo `view_HCA_*` / `sp_HCA_*` |
| [docs/api-contract.md](./api-contract.md) | Contrato da API `/api/v1` |
| [docs/business-flows.md](./business-flows.md) | Fluxos de negócio |
| [docs/deployment-architecture.md](./deployment-architecture.md) | Implantação on-premises (IIS) |
| [docs/implementation-plan.md](./implementation-plan.md) | Plano por sprints |
| [docs/phc-database-discovery.md](./phc-database-discovery.md) | Discovery PHC (0A confirmada) |
| [docs/phc-installation-checklist.md](./phc-installation-checklist.md) | Checklist Fase 0B / instalação |
| [docs/security-permissions.md](./security-permissions.md) | Segurança e permissões |
| [docs/validacao-orientador.md](./validacao-orientador.md) | Briefing para orientador |

---

## Âmbito MVP aprovado

- Login com utilizador + password via tabela PHC `US`
- Password do portal em `US.u_portalph`
- Sessão web/cookie
- Painel Principal
- Encomendas em aberto
- Detalhe de encomenda
- Gestão de quantidade
- Gestão de preço
- Quantidade autorizada
- Rastreio de artigos
- Alocação proporcional
- Views SQL para leitura
- Stored procedures SQL para escrita
- Deploy on-premises em Windows Server + IIS

## Fora do MVP

- Portal Cliente B2B
- Cash & Carry
- JWT / tokens
- `U_PORTALUSER`
- `U_PORTALREFRESH`
- `U_PORTALCFG`
- `U_PORTALAUDIT`
- `CL.u_portalactive`
- Perfis próprios do portal
- RN-019
- Representante como filtro funcional
- Gestão de utilizadores no portal
- Auditoria detalhada before/after

## Regras aprovadas

- **RN-017** — Registo Cliente Fase 2
- **RN-018** — `StockDisponivel = ST.stock`
- **RN-020** — Ajuste de Quantidade
- **RN-021** — Alteração de Preço Unitário
- **RN-022** — Arquitetura Orientada à Mudança

## Modelo de autenticação aprovado

- Utilizadores na tabela PHC `US`
- Login com utilizador + password
- Password do portal em `US.u_portalph`
- Password guardada apenas como hash seguro (PasswordHasher / PBKDF2)
- Sem JWT
- Sem tokens
- Sem refresh tokens
- Sessão através de cookie
- Gestão de utilizadores feita no PHC
- Portal sem ecrãs de gestão de utilizadores

## Modelo SQL aprovado

Leituras através de views:

- `view_HCA_encomendas_abertas`
- `view_HCA_encomenda_linhas`
- `view_HCA_rastreio_artigos`
- `view_HCA_artigo_encomendas`
- `view_HCA_utilizadores`

Escritas através de stored procedures:

- `sp_HCA_validar_login`
- `sp_HCA_atualizar_linha_qtt_preco`
- `sp_HCA_atualizar_qtd_autorizada`
- `sp_HCA_alocacao_proporcional`

Nota:

- Views = leitura
- Stored procedures = escritas de negócio
- `sp_HCA_validar_login` = exceção técnica para validação de login (não é escrita de negócio)

## Campos obrigatórios MVP

**US**

- `u_portalph` — `varchar(254) NOT NULL`

**BI**

- `u_qtdaut` — `numeric(16,2) NOT NULL`
- `u_qtdautur` — `varchar(100) NOT NULL`
- `u_qtdautdt` — `datetime NOT NULL`
- `u_qttorig` — `numeric(16,2) NOT NULL` (**0** = ainda não preenchido)
- `u_prcorig` — `numeric(16,2) NOT NULL` (**0** = ainda não preenchido)

**CL**

- nenhum campo obrigatório no MVP

> `CL.u_portalactive` poderá ser considerado na Fase 2, caso seja necessário controlar quais clientes têm acesso ao Portal Cliente B2B. Não faz parte do MVP do Portal Logístico.

## Fórmulas aprovadas

**Restante**

```text
ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
```

**Encomenda aberta**

```text
BO.fecho = 0
AND
ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2 > 0
```

**Stock disponível**

```text
ST.stock
```

**Preço unitário**

```text
BI.edebito
```

## Auditoria MVP

A auditoria do MVP usa os campos nativos PHC:

**BI:** `usrinis`, `usrdata`, `usrhora`  
**BO:** `usrinis`, `usrdata`, `usrhora`

O portal nunca deve alterar:

**BI:** `ousrinis`, `ousrdata`, `ousrhora`  
**BO:** `ousrinis`, `ousrdata`, `ousrhora`

A consulta de auditoria detalhada (`/administracao/auditoria`, `U_PORTALAUDIT`) é melhoria futura — **fora do MVP**.

## Próximo passo

**Fase 0B — Preparação do Ambiente** (bloqueia Sprint 1).

## Critério de mudança

Qualquer alteração futura a esta baseline deve ser tratada como alteração controlada de âmbito, regra ou arquitetura.

Não alterar documentação aprovada sem registar decisão.
