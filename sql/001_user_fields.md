# PHC — Campos de utilizador (checklist)

Criar via **Supervisor → Framework PHC** (ativar campos de utilizador nos parâmetros gerais).  
Após criar: **Atualizar a Tabela**. Documentação: Enciclopédia — *Funcionamento dos Campos do Utilizador*.

> Confirmar nomes e tipos na BD Liliana & Seródio antes de produção.

## Nomes físicos oficiais (MVP) — campos reais no PHC

> **Tabelas de extensão:** em CS, estes campos de utilizador estão em **`BI2`** (linhas) e **`BO3`** (cabeçalho), **não** em `BI`/`BO`.

| Finalidade | Tabela | Nome físico | Tipo Framework PHC | Tipo SQL |
| --- | --- | --- | --- | --- |
| Acesso ao portal logístico | US | `u_usaPort` | **Lógico** | `bit NOT NULL` default `0` |
| Password do portal em hash seguro (legado) | US | `u_portalph` | Carácter | `varchar(254) NOT NULL` |
| Quantidade autorizada para expedição | **BI2** | `u_qtdaut` | Numérico | `numeric(16,2) NOT NULL` |
| Utilizador que alterou a quantidade autorizada | **BI2** | `u_qtdautur` | Carácter | `varchar(100) NOT NULL` |
| Data/hora da alteração da quantidade autorizada | **BI2** | `u_qtdautdt` | Data | `datetime NOT NULL` |
| Quantidade originalmente encomendada (antes do portal alterar `BI.qtt`) | **BI2** | `u_qttorig` | Numérico | `numeric(16,2) NOT NULL` |
| Preço unitário original (antes do portal alterar `BI.edebito`) | **BI2** | `u_prcorig` | Numérico | `numeric(16,2) NOT NULL` |
| Previsão de entrada que consumiu a autorização (PR2-A) | **BI2** | `u_prevId` | Carácter C(50) | `varchar(50) NOT NULL` default `''` — GUID de `u_HcaPrevEntrada.Id` em texto; `''` = sem associação |
| Encomenda pronta para picking | **BO3** | `u_pickrdy` | **Lógico** | `bit NOT NULL` |
| Quem marcou / desmarcou picking | **BO3** | `u_pickrdr` | Carácter | `varchar(100) NOT NULL` |
| Quando marcou picking | **BO3** | `u_pickrdt` | Data | `datetime NOT NULL` |
| Encomenda urgente | **BO3** | `u_urgente` | **Lógico** | `bit NOT NULL` |
| Motivo de cancelamento do picking | **BO3** | `u_pickcobs` | Carácter | `varchar(254) NOT NULL` |
| Check-in (cliente chegou) — dossier ndos=66 | **BO3** | `u_chkin` | **Lógico** | `bit NOT NULL` |
| Quem fez o Check-in | **BO3** | `u_chkinur` | Carácter | `varchar(100) NOT NULL` |
| Quando fez o Check-in | **BO3** | `u_chkindt` | Data | `datetime NOT NULL` |

Script SPs: [`056_alter_sp_picking_cancel_motivo_u_pickcobs.sql`](./056_alter_sp_picking_cancel_motivo_u_pickcobs.sql), [`057_create_sp_HCA_marcar_urgente_encomenda.sql`](./057_create_sp_HCA_marcar_urgente_encomenda.sql), [`058_create_sp_HCA_cancelar_encomenda.sql`](./058_create_sp_HCA_cancelar_encomenda.sql), [`059_create_sp_HCA_marcar_checkin_dossier.sql`](./059_create_sp_HCA_marcar_checkin_dossier.sql), [`060_create_sp_HCA_reverter_checkin_dossier.sql`](./060_create_sp_HCA_reverter_checkin_dossier.sql).

Script vistas com urgente: [`044_add_bo3_u_urgente_views.sql`](./044_add_bo3_u_urgente_views.sql).

### Cor da linha (Liliana & Seródio)

Nesta instalação a cor operacional das linhas de dossier está em **`BI.u_cor`** (campo de utilizador). O nativo **`BI.cor`** costuma vir vazio.  
Views/SPs do portal usam a cor efectiva: `COALESCE(NULLIF(BI.cor,''), NULLIF(BI.u_cor,''), '')` — ver [`042_cor_efectiva_bi_u_cor.sql`](./042_cor_efectiva_bi_u_cor.sql).

### Migração (nomes antigos → novos)

| Antigo (incorrecto / legado) | Actual |
| --- | --- |
| `BI.u_qtdaut` / `u_qtdautur` / `u_qtdautdt` | `BI2.u_qtdaut` / `u_qtdautur` / `u_qtdautdt` |
| `BI.u_qttorig` / `u_prcorig` | `BI2.u_qttorig` / `u_prcorig` |
| `BO.u_pickrdy` | `BO3.u_pickrdy` |
| `BO.u_upickrdr` / `BO.u_upickrdt` | `BO3.u_pickrdr` / `BO3.u_pickrdt` |

Script de alinhamento views/SPs: [`041_migrate_user_fields_bi2_bo3.sql`](./041_migrate_user_fields_bi2_bo3.sql).

### Convenção NOT NULL (originais)

Como `u_qttorig` e `u_prcorig` são `NOT NULL`, **não** se usa `NULL` para “ainda não preenchido”.

No MVP: **0** = indicador técnico de “original ainda não guardado”.

- Restante: `ISNULL(NULLIF(BI2.u_qttorig, 0), BI.qtt) - BI.qtt2`
- RN-020: se `u_qttorig = 0` → guardar `BI.qtt`; nunca sobrescrever se `<> 0`
- RN-021: se `u_prcorig = 0` → guardar `BI.edebito`; nunca sobrescrever se `<> 0`

> Se futuramente existirem preços originais reais a **0**, deverá ser revista a abordagem de `u_prcorig`.

### Quantidade autorizada (NOT NULL)

| Campo | Significado | Valor base (“ainda sem autorização”) |
| --- | --- | --- |
| `u_qtdaut` | Quantidade autorizada para expedição | `0` |
| `u_qtdautur` | Utilizador que alterou | string vazia / espaço (conforme default PHC) |
| `u_qtdautdt` | Data/hora da alteração | data base PHC (tratar como “ainda sem autorização”) |

### Login / acesso portal (`US`)

Fonte de identidade PHC: tabela nativa **`US`**. Password do portal: **Identity** (`u_HcaLogiUsers`). Gate de acesso: **`u_usaPort` (Lógico)**.

| Tabela | Nome interno (sem U_) | Nome físico | Tipo Framework | Tipo SQL | Descrição |
| --- | --- | --- | --- | --- | --- |
| US | `usaPort` | `u_usaPort` | **Lógico** | `bit NOT NULL` default `0` | `1` / verdadeiro = utilizador pode aceder ao portal |
| US | `portalph` | `u_portalph` | Carácter | `varchar(254) NOT NULL` | **Legado** — hash antigo; a password do portal está em `u_HcaLogiUsers` |

**Acesso ao portal:** ASP.NET Identity (`u_HcaLogiUsers`) + `US` activo com o mesmo email e **`u_usaPort` = verdadeiro**.

Criar `u_usaPort` via **Supervisor → Framework PHC** (tipo **Lógico**), depois **Atualizar a Tabela**.  
Script SQL de fallback: [`028_add_us_u_usaPort.sql`](./028_add_us_u_usaPort.sql).

```sql
-- Activar acesso (exemplo)
UPDATE dbo.us SET u_usaPort = 1
WHERE LOWER(LTRIM(RTRIM(email))) = LOWER(N'seu@email.pt');
```

A vista `view_HCA_utilizadores` / `sp_HCA_validar_login` filtram `u_usaPort = 1`.

### Não criar no MVP — identidade / sessão / config / auditoria / lockout / perfis

| Item | Estado |
| --- | --- |
| `U_PORTALUSER` | **Não criar** — identidade = `US` |
| `U_PORTALREFRESH` | **Não criar** — sem tokens |
| `U_PORTALCFG` | **Não criar** — corte/séries = defaults em appsettings/constantes |
| `U_PORTALAUDIT` | **Não criar** no MVP — melhoria futura (não 0B / Sprint 1 / go-live) |
| `US.u_portalperfil` | **Não criar** no MVP — perfis = futuro/condicional |
| `US.u_portalativo` | **Não criar** no MVP — melhoria futura (RN-019 / acesso) |
| `US.u_portalfalhas` | **Não criar** no MVP — **RN-019** = melhoria de segurança futura |
| `US.u_portallockuntil` | **Não criar** no MVP — **RN-019** = melhoria de segurança futura |
| `CL.u_portalactive` | **Não criar** no MVP — possível futuro Fase 2 (Portal Cliente B2B) |

## Campos de utilizador — logística (MVP)

| Tabela | Nome interno (sem U_) | Nome físico | Tipo SQL | Descrição |
| --- | --- | --- | --- | --- |
| **BI2** | `qtdaut` | `u_qtdaut` | `numeric(16,2) NOT NULL` | Quantidade autorizada a expedir |
| **BI2** | `qtdautur` | `u_qtdautur` | `varchar(100) NOT NULL` | Utilizador que alterou a autorização |
| **BI2** | `qtdautdt` | `u_qtdautdt` | `datetime NOT NULL` | Data/hora da alteração da autorização |
| **BI2** | `qttorig` | `u_qttorig` | `numeric(16,2) NOT NULL` | Qtd original — **0** = ainda não preenchido; base do restante |
| **BI2** | `prcorig` | `u_prcorig` | `numeric(16,2) NOT NULL` | Preço original — **0** = ainda não preenchido (RN-021) |
| **BI2** | `prevId` | `u_prevId` | `varchar(50) NOT NULL` default `''` | Id da previsão (`CONVERT(varchar(36), Id)`); `''` = sem associação; sem backfill de autorizações antigas |
| **BO3** | `pickrdy` | `u_pickrdy` | **Lógico** / `bit NOT NULL` | `1` = encomenda pronta para picking |
| **BO3** | `pickrdr` | `u_pickrdr` | Carácter / `varchar(100) NOT NULL` | Utilizador que marcou / desmarcou picking |
| **BO3** | `pickrdt` | `u_pickrdt` | Data / `datetime NOT NULL` | Data/hora da marcação; data base PHC = ainda sem marcação |
| **BO3** | `pickcobs` | `u_pickcobs` | Carácter / `varchar(254) NOT NULL` | Motivo ao cancelar picking; limpo ao criar picking de novo |
| **BO3** | `chkin` | `u_chkin` | **Lógico** / `bit NOT NULL` | `1` = Check-in feito (dossier ndos=66 → Em Entrega) |
| **BO3** | `chkinur` | `u_chkinur` | Carácter / `varchar(100) NOT NULL` | Utilizador do Check-in |
| **BO3** | `chkindt` | `u_chkindt` | Data / `datetime NOT NULL` | Data/hora do Check-in; data base PHC = sem check-in |
| BO | `ccstatus` | `u_ccstatus` | C(2) | **Opcional** — futuro Cash & Carry (PA/AP/EP/FT/RJ) |
| BO | `cccomment` | `u_cccomment` | M ou C(250) | **Opcional** — futuro Cash & Carry |
| BO | `ccuser` | `u_ccuser` | C(80) | **Opcional** — futuro Cash & Carry |
| BO | `ccdate` | `u_ccdate` | D | **Opcional** — futuro Cash & Carry |

> **CL:** nenhum campo `U_*` obrigatório no MVP. A tabela `CL` é só leitura (dados de cliente).  
> `CL.u_portalactive` poderá ser considerado na Fase 2, caso seja necessário controlar quais clientes têm acesso ao Portal Cliente B2B. **Não faz parte do MVP** do Portal Logístico.

> Campos `u_cc*` são **opcionais** na Fase 0B. **Não são obrigatórios** para o GO de desenvolvimento nem para o go-live do MVP.

> **Não criar** campo `u_portalmobile` (nem equivalente). O telemóvel de validação de registo usa campos nativos `CL.tlmvl` / `CL.telefone`.

> **Exceções nativas aprovadas (não são campos U_):** o portal pode atualizar `BI.qtt` (**RN-020**), **`BI.edebito`** (**RN-021**, preço unitário €), recalcular totais de linha/cabeçalho (equivalente a **BOTOTS**), e os campos nativos **`usrinis` / `usrdata` / `usrhora` em `BI` e `BO`**. Originais em `u_qttorig` / `u_prcorig` (sentinel **0**). **Não** criar `U_*` para quem/quando alterou o dossier. Em RN-020/021: atualizar **`usr*`** em BO+BI; **nunca** alterar `ousr*`. **Sem** escrita obrigatória em `U_PORTALAUDIT`.

### Estados Cash & Carry (`u_ccstatus`) — capacidade futura

| Código | Etiqueta (UI / documentação) |
| --- | --- |
| `PA` | Pendente Aprovação |
| `AP` | Aprovada |
| `EP` | Em Preparação |
| `FT` | Faturada |
| `RJ` | Rejeitada |

> Um portal Cash & Carry futuro **pode usar um modelo de autenticação diferente**, a definir mais tarde. **Não** desenhar auth C&C no MVP.

**BI:** ativar “Visível na grelha” nos campos de autorização e restringir ao(s) tipo(s) de dossier de encomenda (botão Documentos).

## Campos nativos CL usados no registo (RN-017)

| Coluna | Uso |
| --- | --- |
| `ncont` | NIF |
| `tlmvl` | Telemóvel — **prioridade 1** |
| `telefone` | Telefone — **prioridade 2** (só se `tlmvl` vazio/nulo) |

Mensagem de falha (obrigatória):

> Não encontramos os seus dados nos nossos registos. Dirija-se por favor ao balcão para atualização dos dados de cliente.

## Arranque

1. Criar/confirmar utilizadores em `US` (PHC).  
2. Criar campo **`US.u_usaPort`** (Framework: tipo **Lógico**) e activar (`= 1`) nos utilizadores do portal.  
3. Criar tabelas Identity [`029`](./029_create_u_HcaLogi_identity_tables.sql) e utilizador em `u_HcaLogiUsers` ([`tools/criar-utilizador-portal`](../tools/criar-utilizador-portal/README.md)).  
4. Validar login cookie com utilizador piloto.  

Checklist mínimo piloto:

- Utilizador existe em `US`  
- `u_usaPort` = verdadeiro (`1`)  
- Email alinhado com Identity  
- Login cookie OK  

## Verificação rápida (SQL)

```sql
-- Acesso portal (u_usaPort Lógico)
SELECT TOP 20
  LTRIM(RTRIM(usercode)) AS usercode,
  LTRIM(RTRIM(email)) AS email,
  u_usaPort
FROM dbo.us WITH (NOLOCK)
WHERE ISNULL(inactivo, 0) = 0
  AND u_usaPort = 1;
```

SELECT TOP 1
  bi.bistamp, bi.ref, bi.qtt, bi.qtt2, bi.edebito,
  bi2.u_qttorig, bi2.u_prcorig,
  bi2.u_qtdaut, bi2.u_qtdautur, bi2.u_qtdautdt
FROM bi WITH (NOLOCK)
LEFT JOIN bi2 WITH (NOLOCK) ON bi2.bi2stamp = bi.bistamp;

-- Campos nativos usados no registo (RN-017) — sem u_portalmobile; sem u_portalactive no MVP
SELECT TOP 1 no, estab, nome, ncont, tlmvl, telefone
FROM cl WITH (NOLOCK);

-- Séries de dossiers (confirmar nome da tabela de séries na BD)
SELECT ndos, nmdos
FROM /* TS / config local */;
-- Confirmar SerieEncomendasNdos = 1
```
