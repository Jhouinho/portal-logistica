# Go-live — tudo a funcionar na semana

| | |
| --- | --- |
| Objectivo | Portal operacional no servidor do cliente |
| Instalação | [`PASSO_A_PASSO_PRODUCAO.md`](./PASSO_A_PASSO_PRODUCAO.md) |
| Estado produto | [`PROJECT-STATE.md`](./PROJECT-STATE.md) |
| Actualizado | 2026-10-09 |

**Mensagem clara:** o circuito principal **já está validado em UAT**. Para a semana, o risco não é “falta feature” — é **replicar UAT em Prod** (SQL, IIS, auth, Kapps) e fechar smoke no local.

Pendentes de documentação (paginação FE por referência, “Não picada”, Cenário B 2×66) **não bloqueiam** go-live do armazém.

---

## 1. O que tem de funcionar no dia (definição de “OK”)

| Área | Critério de aceitação |
| --- | --- |
| Acesso | `https://…` com certificado; login / logout |
| Utilizadores | Pelo menos 1 Admin + operadores com `US.u_usaPort=1` |
| Centro `/` | 5 KPIs + painéis em progresso |
| TV `/tv` | Sem login; actualiza sozinha |
| Em Aberto | Lista, autorizar qtd, Disponível coerente, pronta picking |
| Em Picking | Lista; Kapps; Cancelar bloqueado se já há qtt em 66 |
| Separado / Check-in / Em Entrega | 66; check-in; reverter |
| Em Expedição / Concluídas | 65; Fechar / Reabrir (sem faturação) |
| Previsão | Existe 1 previsão aberta (se usam autorização por previsão) |
| Realtime | Mudança no PHC/Kapps → UI refresca (~5–30 s) |

Se estes 10 pontos passam no cliente → **go-live OK**.

---

## 2. Esta semana (antes de ir ao servidor) — obrigatório

Fazer **em UAT** (ou espelho), não deixar para o dia:

| # | Tarefa | Feito |
| --- | --- | --- |
| A1 | Circuito completo numa encomenda real: Aberto → autorizar → pronta → Kapps 66 → Separado → check-in → 65 → Fechar expedição | ☐ |
| A2 | Vista TV aberta noutro ecrã durante A1 — KPIs e painéis actualizam | ☐ |
| A3 | Confirmar `SP_u_Kapps_DossiersUSR` em UAT (morada / modo expedição 1→66→65) e **anotar** o script/patch a levar a Prod | ☐ |
| A4 | Exportar lista de campos `U_*` UAT vs checklist `001_user_fields.md` | ☐ |
| A5 | Gerar pacote de release: `dotnet publish` API + `npm run build` SPA; guardar zip datado | ☐ |
| A6 | Lista ordenada de scripts SQL a aplicar em Prod (delta vs UAT, **sem** `090`) | ☐ |
| A7 | Pedir a IT: DNS, certificado, RDP, backup PHC, login SQL `portal_app` (ou criar no dia) | ☐ |
| A8 | Smoke fecho Em Expedição na UI (pendente documentado — fechar agora) | ☐ |
| A9 | Criar 2–3 contas Identity de teste + validar `u_usaPort` | ☐ |
| A10 | Imprimir / ter offline: este ficheiro + `PASSO_A_PASSO_PRODUCAO.md` | ☐ |

---

## 3. No servidor (dia da instalação) — ordem fixa

Seguir [`PASSO_A_PASSO_PRODUCAO.md`](./PASSO_A_PASSO_PRODUCAO.md) §12:

```text
Backup → Campos U_* → SQL+grants → IIS+Hosting Bundle → Publish → Config → Users → Smoke
```

**Não improvisar:** não correr `090`; não mudar intervalo SignalR; não abrir features novas no dia.

Tempo útil estimado (se IT preparado): **meio dia a 1 dia**.  
Se campos `U_*` ainda não existem em Prod: **contar +½ a 1 dia** (Supervisor + Actualizar Tabela).

---

## 4. Bloqueadores vs “pode ficar para depois”

| Bloqueia go-live | Pode esperar pós go-live |
| --- | --- |
| Connection string / `portal_app` / grants | Paginação FE Em Aberto por referência |
| Campos `U_*` em falta | Distinção formal “Não picada” |
| Identity + `u_usaPort` | Cenário B 2×66 (não observável) |
| HTTPS / cookies / CORS | Microsoft Login |
| Kapps a criar 66/65 | Navegação 1↔66↔65 na UI |
| WebSockets (TV/SignalR) | Polish UX cabeçalhos |

---

## 5. Plano B (se algo falhar no dia)

| Falha | Mitigação |
| --- | --- |
| SQL script falha a meio | Parar; restaurar backup; aplicar delta conhecido de UAT |
| Login não entra | Verificar email `US`, `u_usaPort=1`, user Identity, HTTPS cookie |
| Kapps não propaga campos | Portal continua; corrigir `SP_u_Kapps_DossiersUSR` depois (já anotado em A3) |
| SignalR morto | UI ainda faz polling 30 s na TV / refresh manual; WebSockets no dia seguinte |
| Sem certificado válido | Acordar com IT hostname interno + cert; cookies Secure precisam HTTPS |

---

## 6. Critério de fecho do dia

Marcar go-live **só** se:

- [ ] Backup feito antes dos scripts  
- [ ] Login operadores OK  
- [ ] Centro + TV OK  
- [ ] Pelo menos **um** documento atravessou Separado (ou caminho acordado com o cliente)  
- [ ] Contacto IT + URL portal + URL `/tv` entregues  

Registar no `PROJECT-STATE.md` (data, servidor, veredicto) na volta.
