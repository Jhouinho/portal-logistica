# Fase 0B — Preparação do ambiente

> **HISTÓRICO (2026-09-29).** Objectos 0B validados em UAT; evolução posterior (Identity, previsão `068`/`069`/`082`, Centro/TV) em [`PROJECT-STATE.md`](./PROJECT-STATE.md).  
> Tabelas abaixo descrevem o estado **à data da 0B**, não o inventário SQL completo de hoje.

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Âmbito | Campos `U_*`, vistas `view_HCA_*`, procedimentos `sp_HCA_*`, permissões SQL |
| Política BD | **Só UAT/teste** até implementação completa + **GO formal** em Produção |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) · [phc-installation-checklist.md](./phc-installation-checklist.md) |

---

## Estado dos objetos SQL (vistas)

| Objeto | Script | Documento | Estado UAT | Estado Prod |
| --- | --- | --- | --- | --- |
| `view_HCA_utilizadores` | [`010`](../sql/010_create_view_HCA_utilizadores.sql) | [fase-0b-view-HCA-utilizadores.md](./fase-0b-view-HCA-utilizadores.md) | **Validado** | Pendente (fim implementação) |
| `view_HCA_encomendas_abertas` | [`012`](../sql/012_create_view_HCA_encomendas_abertas.sql) · validação [`013`](../sql/013_validate_view_HCA_encomendas_abertas.sql) | [fase-0b-view-HCA-encomendas-abertas.md](./fase-0b-view-HCA-encomendas-abertas.md) | **Validado** (2026-08-10) | Pendente (fim implementação) |
| `view_HCA_encomenda_linhas` | [`014`](../sql/014_create_view_HCA_encomenda_linhas.sql) · validação [`015`](../sql/015_validate_view_HCA_encomenda_linhas.sql) | [fase-0b-view-HCA-encomenda-linhas.md](./fase-0b-view-HCA-encomenda-linhas.md) | **Validado** (2026-08-10) | Pendente (fim implementação) |
| `view_HCA_rastreio_artigos` | [`016`](../sql/016_create_view_HCA_rastreio_artigos.sql) · [`017`](../sql/017_validate_view_HCA_rastreio_artigos.sql) | [fase-0b-view-HCA-rastreio-artigos.md](./fase-0b-view-HCA-rastreio-artigos.md) | **Validado** (2026-08-10) | Pendente (fim implementação) |
| `view_HCA_artigo_encomendas` | [`018`](../sql/018_create_view_HCA_artigo_encomendas.sql) · [`019`](../sql/019_validate_view_HCA_artigo_encomendas.sql) | [fase-0b-view-HCA-artigo-encomendas.md](./fase-0b-view-HCA-artigo-encomendas.md) | **Validado** (2026-08-10) | Pendente (fim implementação) |

**Catálogo MVP de vistas completo em UAT** (2026-08-10). Produção diferida até GO formal.

---

## Procedimentos (`sp_HCA_*`)

| Objeto | Scripts | Estado UAT | Estado Prod |
| --- | --- | --- | --- |
| `sp_HCA_validar_login` | [`020`](../sql/020_create_sp_HCA_validar_login.sql)/[`021`](../sql/021_validate_sp_HCA_validar_login.sql) | Actualizar com `u_usaPort` | Pendente |
| `sp_HCA_atualizar_linha_qtt_preco` | [`022`](../sql/022_create_sp_HCA_atualizar_linha_qtt_preco.sql)/[`023`](../sql/023_validate_sp_HCA_atualizar_linha_qtt_preco.sql) | **Validado** (2026-08-10) — `ettdeb`; sem `etiliquido` | Pendente |
| `sp_HCA_atualizar_qtd_autorizada` | [`024`](../sql/024_create_sp_HCA_atualizar_qtd_autorizada.sql)/[`025`](../sql/025_validate_sp_HCA_atualizar_qtd_autorizada.sql) | **Validado** (2026-08-10) | Pendente |
| `sp_HCA_alocacao_proporcional` | [`026`](../sql/026_create_sp_HCA_alocacao_proporcional.sql)/[`035`](../sql/035_alter_sp_HCA_alocacao_proporcional_disponivel_cor.sql)/[`027`](../sql/027_validate_sp_HCA_alocacao_proporcional.sql) | **Validado** + `@disponivel`/`@cor` (2026-09-02) | Pendente |

Hub: [fase-0b-sp-HCA.md](./fase-0b-sp-HCA.md)

## Identity (`u_HcaLogi*` + `u_usaPort`)

| Objeto | Scripts | Doc |
| --- | --- | --- |
| `US.u_usaPort` | [`028`](../sql/028_add_us_u_usaPort.sql) | [auth-portal-identity.md](./auth-portal-identity.md) |
| Tabelas `u_HcaLogi*` | [`029`](../sql/029_create_u_HcaLogi_identity_tables.sql) · [`029b`](../sql/029b_validate_u_HcaLogi_identity_tables.sql) | [fase-0b-u-HcaLogi-identity-tables.md](./fase-0b-u-HcaLogi-identity-tables.md) |

**Catálogo MVP de vistas + procedimentos completo em UAT** (2026-08-10).

---

## Permissões SQL da aplicação

| Item | Doc / script | Estado |
| --- | --- | --- |
| Login SQL dedicado (`portal_app`) | [fase-0b-permissoes-sql-app.md](./fase-0b-permissoes-sql-app.md) | **Pendente execução UAT** |
| `GRANT` vistas/SPs | [`030`](../sql/030_grant_portal_app.sql) | Script criado |

---

## GO Sprint 1 (checklist)

| # | Critério | Estado |
| --- | --- | --- |
| 1 | Discovery 0A | **Confirmada** |
| 2 | `u_portalph` + `U_*` BI + `view_HCA_*` / `sp_HCA_*` | **Feito UAT** |
| 3 | Sem `U_PORTAL*` / JWT | **Feito** |
| 4 | Acesso SQL app (`SELECT`/`EXEC` via `030`) | **Script pronto** · execução UAT pendente |
| 5 | `SerieEncomendasNdos = 1` (appsettings) | **Feito** (`Phc:SerieEncomendasNdos = 1`) |
| 6 | Piloto Identity + `u_usaPort` + cookie | Ver [auth-portal-identity.md](./auth-portal-identity.md) |

---

## Referências rápidas

- [fase-0b-view-HCA-utilizadores.md](./fase-0b-view-HCA-utilizadores.md)
- [fase-0b-view-HCA-encomendas-abertas.md](./fase-0b-view-HCA-encomendas-abertas.md)
- [fase-0b-view-HCA-encomenda-linhas.md](./fase-0b-view-HCA-encomenda-linhas.md)
- [fase-0b-view-HCA-rastreio-artigos.md](./fase-0b-view-HCA-rastreio-artigos.md)
- [fase-0b-view-HCA-artigo-encomendas.md](./fase-0b-view-HCA-artigo-encomendas.md)
- [fase-0b-sp-HCA.md](./fase-0b-sp-HCA.md)
- [fase-0b-permissoes-sql-app.md](./fase-0b-permissoes-sql-app.md)
- [fase-0b-validacao-login-cookie.md](./fase-0b-validacao-login-cookie.md) (legado)
- [auth-portal-identity.md](./auth-portal-identity.md)
- [fase-0b-u-HcaLogi-identity-tables.md](./fase-0b-u-HcaLogi-identity-tables.md)
- [phc-installation-checklist.md](./phc-installation-checklist.md)
