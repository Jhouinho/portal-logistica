# Auditoria e Alterações — Picking, Kapps e Distribuição Operacional

> Registo consolidado (06/10/2026; emendas 07/10/2026: **REGRA B — Cancelar Picking**; **UAT distribuição 2×66 ativos + 1×65 — não observável**; **UAT Kapps pausa/retoma/aborto — PASS**; **UAT múltiplos 65 abertos — PASS**) das auditorias read-only e das alterações implementadas no Portal.
> Fonte de verdade operacional continua a ser [`PROJECT-STATE.md`](./PROJECT-STATE.md); este documento detalha o *porquê* e o *antes/depois*.

## 1. Objetivo

Este documento regista:

* o comportamento existente antes das alterações;
* as conclusões das auditorias realizadas ao circuito PHC / Portal / Kapps / Syslog;
* as regras funcionais que foram validadas;
* as alterações efetivamente realizadas no Portal;
* o comportamento final esperado;
* as situações que permanecem tecnicamente não determinadas.

O objetivo foi corrigir o comportamento do **Picking** e da **distribuição lógica do Centro de Operações / TV**, sem alterar a responsabilidade dos sistemas externos nem introduzir lógica adicional desnecessária no Portal.

---

# 2. Circuito operacional validado

O circuito final auditado é:

```text
Encomenda
  ndos = 1
      │
      │ Portal
      │ autorização / pronta para Picking
      ▼
BI.qtt = quantidade operacional
      │
      │
      ├──────────────────────────────┐
      │                              │
      ▼                              ▼
Kapps Quantity                 Picking físico
= BI.qtt                       Kapps / Syslog
                                     │
                                     ▼
                             documentos 66
                                     │
                                     ▼
                              quantidade separada
                                     │
                                     ▼
                             documentos 65
```

O Portal **não cria** os documentos 66 nem 65.

A criação desses documentos pertence ao circuito externo Syslog/Kapps.

---

# 3. Conceitos fundamentais validados

## 3.1 Quantidade original

`BI2.u_qttorig`

Representa a quantidade existente antes da primeira autorização.

O valor `0` funciona como indicador de que o campo ainda não foi preenchido, sendo usada como alternativa a quantidade de `BI.qtt`.

---

## 3.2 Quantidade autorizada

`BI2.u_qtdaut`

Representa a decisão de autorização.

Não é, por si só, a quantidade utilizada posteriormente pelo circuito de Picking.

---

## 3.3 Quantidade operacional

`BI.qtt`

Depois da autorização, o Portal grava a quantidade operacional em `BI.qtt`.

É esta quantidade que passa a comandar o circuito.

Consequentemente:

> `BI.qtt` é a quantidade operacional que o Kapps também apresenta como `Quantity`.

---

# 4. Origem de Kapps `Quantity`

A auditoria à view `v_Kapps_Picking_Lines` confirmou:

```sql
bi.qtt AS Quantity
```

Portanto:

```text
BI.qtt
  ↓
v_Kapps_Picking_Lines.Quantity
  ↓
Portal
```

A origem de `Quantity` está **PROVADA**.

Não é:

* `BI2.u_qtdaut`;
* `BI.qtt2`;
* `u_Kapps_DossierLin`;
* uma quantidade calculada pelo Kapps.

A coincidência entre `Quantity` e quantidade autorizada resulta do processo anterior:

```text
u_qtdaut
   ↓
Portal
   ↓
BI.qtt
   ↓
Kapps Quantity
```

e não de uma ligação direta entre `u_qtdaut` e `Quantity`.

---

# 5. Campos Kapps auditados

A definição da `v_Kapps_Picking_Lines` permitiu determinar:

| Campo               | Origem                              | Estado  |
| ------------------- | ----------------------------------- | ------- |
| `Quantity`          | `BI.qtt`                            | PROVADO |
| `QuantitySatisfied` | `BI.qtt2`                           | PROVADO |
| `QuantityPicked`    | `SUM(u_Kapps_DossierLin.Qty2)`      | PROVADO |
| `QuantityPending`   | `BI.qtt - BI.qtt2 - QuantityPicked` | PROVADO |
| `PickingLineKey`    | `BI.bistamp`                        | PROVADO |
| `PickingKey`        | `BI.bostamp` / `BO.bostamp`         | PROVADO |

`QuantityPicked` utiliza:

```sql
SUM(u_Kapps_DossierLin.Qty2)
```

com:

```text
Status = 'A'
Integrada = 'N'
stampbi = BI.bistamp
```

A view não utiliza `SessionID` nem `SessionType` para calcular `QuantityPicked`.

---

# 6. Quantidade pendente Kapps

A definição correta é:

```text
QuantityPending
    =
BI.qtt
-
BI.qtt2
-
QuantityPicked
```

ou:

```text
QuantityPending
    =
Quantity
-
QuantitySatisfied
-
QuantityPicked
```

Não é correto interpretar `QuantityPending` simplesmente como:

```text
Quantity - QuantityPicked
```

---

# 7. O que representa `BI.qtt2`

O Portal trata `BI.qtt2` como um campo de origem externa/PHC e utiliza-o para:

* quantidade satisfeita;
* cálculo de pendente;
* estado de documentos;
* determinação de quantidades ainda pendentes em determinados circuitos.

A auditoria determinou que:

* o Portal não escreve `qtt2`;
* as SPs HCA analisadas não escrevem `qtt2`;
* as SPs Kapps legíveis analisadas não escrevem `qtt2`;
* existem triggers `BI` encriptados;
* o escritor efetivo de `BI.qtt2` não foi determinado.

### Conclusão

> `BI.qtt2` é utilizado pelo Portal como campo read-only de origem externa/PHC, mas a rotina efetiva que o escreve não foi determinada na auditoria.

Não existe evidência suficiente para atribuir essa escrita especificamente ao PHC, Syslog, Kapps ou aos triggers encriptados.

Esta lacuna não bloqueia as alterações realizadas.

---

# 8. Estado ANTES — Picking

Antes da alteração, a lista de Picking era determinada essencialmente por:

```text
ndos = 1
fechada = 0
restante > 0
u_pickrdy = 1
```

Ou seja, `u_pickrdy` determinava a pertença ao universo de Picking.

A existência de documentos 66 já criados **não era utilizada para determinar se ainda existia quantidade por separar**.

Consequentemente, uma encomenda podia continuar no Picking mesmo depois de toda a sua quantidade operacional já ter sido materializada em documentos 66.

---

# 9. Problema identificado

Consideremos:

```text
BI.qtt = 10
```

e:

```text
66 #1 = 4
66 #2 = 3
66 #3 = 3
```

A quantidade operacional é:

```text
10
```

A quantidade já separada é:

```text
4 + 3 + 3 = 10
```

Logo:

```text
10 - 10 = 0
```

Não existe mais quantidade para separar.

Contudo, o comportamento anterior podia manter a encomenda no Picking porque:

```text
u_pickrdy = 1
```

continuava verdadeiro.

---

# 10. Regra FINAL do Picking

Foi implementada a regra:

> Uma encomenda permanece no Picking enquanto existir pelo menos uma linha cuja quantidade operacional (`BI.qtt`) seja superior à soma das quantidades de todos os documentos 66 associados à mesma linha.

Formalmente:

```text
BI.qtt > SUM(66.BI.qtt)
```

com relação:

```text
66.BI.obistamp = 1.BI.bistamp
```

e considerando **todos os 66**, independentemente de:

* `fechada`;
* `u_chkin`;
* estado de entrega.

---

# 11. Porque são considerados todos os 66

Um documento 66 fechado continua a representar quantidade que foi separada.

Fechar um 66:

```text
BO.fechada = 1
```

não:

* elimina o documento;
* remove `obistamp`;
* devolve a quantidade à encomenda;
* altera `66.BI.qtt`.

Logo, para determinar quanto já foi separado, o documento continua a contar.

Exemplo:

```text
BI.qtt = 10

66 #1 fechado = 4
66 #2 aberto  = 3
66 #3 fechado = 3

SUM(66.qtt) = 10
```

Resultado:

```text
0 por separar
```

A encomenda não deve permanecer no Picking.

---

# 12. Alteração implementada — Query de Encomendas

Foi acrescentada à query de encomendas a condição específica para:

```text
ProntaPicking = true
```

A lógica passou a ser conceptualmente:

```text
Encomendas abertas
        AND
u_pickrdy = 1
        AND
EXISTS(
    linha com
    BI.qtt > SUM(66.BI.qtt)
)
```

A série de Picking continua a ser obtida através de `_options.SeriePickingNdos`, evitando hardcode desnecessário.

---

# 13. Alteração implementada — Centro de Operações

A mesma regra foi aplicada ao cálculo do estado:

```text
Em Picking
```

no `PainelQuery`.

Isto garante que o contador do Centro de Operações não apresenta uma população diferente daquela que o Picking efetivamente considera.

A alteração foi feita na classificação SQL do estado, sem alterar os restantes estados documentais.

---

# 14. Picking — realtime

Depois da alteração do critério de pertença ao Picking, surgiu uma consequência importante:

A criação/alteração de um 66 pode alterar imediatamente o resultado da condição:

```text
BI.qtt > SUM(66.BI.qtt)
```

Por isso, o evento:

```text
dossier66Alterado
```

passou a invalidar também a lista de encomendas abertas quando o utilizador está no modo Picking.

Fluxo final:

```text
66 alterado
   │
   ├── invalidate dossiers 66
   │
   └── se modo Picking
          │
          ▼
      invalidate
      encomendas abertas
```

Assim, quando o último 66 satisfaz a quantidade operacional, a encomenda desaparece do Picking sem depender de refresh manual.

---

# 15. O que NÃO foi alterado no Picking

Não foram alterados:

* `u_pickrdy`;
* `u_pickstat`;
* processo físico Kapps;
* criação de 66;
* SPs Kapps;
* documentos 65;
* regras de Check-in;
* SignalR existente;
* quantidade operacional `BI.qtt`;
* origem de preços;
* circuito externo Syslog/Kapps.

A alteração limita-se à determinação de **existência de quantidade ainda por separar**.

---

# 16. Estado ANTES — distribuição Centro / TV

O cálculo anterior tratava cada encomenda lógica como uma unidade indivisível:

```text
1 encomenda = 1 unidade
```

Mesmo quando a mesma encomenda possuía simultaneamente:

```text
66 + 65
```

a encomenda era atribuída a apenas um estado.

A prioridade lógica fazia com que o 66 pudesse absorver a totalidade da unidade.

Exemplo:

```text
Encomenda
 ├── 66 parcial
 └── 65 aberto
```

Anteriormente podia resultar em:

```text
100% Separado
0% Em Expedição
```

quando funcionalmente existiam duas partes distintas do circuito.

---

# 17. Regra FINAL da distribuição lógica

Foi definida uma regra de distribuição fracionada.

Cada encomenda lógica representa inicialmente:

```text
1.0
```

## Apenas um 66

```text
66
```

Resultado:

```text
100% para o estado do 66
```

---

## Vários 66

Se existirem:

```text
66 #1
66 #2
```

a unidade é dividida:

```text
0.5 + 0.5
```

Cada 66 recebe 50% da unidade.

---

## Apenas 65

```text
65
```

Resultado:

```text
100% Em Expedição
```

---

## 66 + 65

```text
66
65
```

Resultado:

```text
50% 66
50% Em Expedição
```

---

## 2 × 66 + 65

```text
66 #1 = 25%
66 #2 = 25%
65    = 50%
```

Total:

```text
100%
```

Regra **mantida** na documentação e nos testes unitários.  
UAT com dados reais: ver §21A — **PENDENTE / NÃO OBSERVÁVEL** (07/10/2026).

---

## 3 × 66 + 65

```text
66 #1 = 16,67%
66 #2 = 16,67%
66 #3 = 16,67%
65    = 50%
```

A soma mantém-se em:

```text
100%
```

---

# 18. Regra para múltiplos 65

Quando existem vários 65 ativos para a mesma encomenda, o grupo 65 representa a fase:

```text
Em Expedição
```

Não é dividido individualmente pelos vários 65.

Assim:

```text
66 + 65 + 65
```

continua a representar:

```text
50% 66
50% Em Expedição
```

---

# 19. Definição de documentos ativos na distribuição

### 66 ativo

```text
fechada = 0
AND
SUM(qtt - qtt2) > 0
```

O estado depende de:

```text
u_chkin = 0 → Separado
u_chkin = 1 → Em Entrega
```

### 65 ativo

```text
fechada = 0
```

Os 66 fechados continuam a ser relevantes para o cálculo de quantidade separada do Picking, mas **não participam na distribuição lógica Centro/TV**.

Esta diferença é intencional.

---

# 20. Exemplo real validado — 66 + 65

Foi validado em UAT um caso real com:

```text
Encomenda:
ADM26092937019,063000002
```

Existiam:

```text
1 × 66 ativo
1 × 65 aberto
```

O resultado da API passou a incluir a contribuição:

```text
0,5 Separado
0,5 Em Expedição
```

O Centro de Operações apresentou visualmente os mesmos valores.

A TV apresentou igualmente os mesmos valores.

### Resultado

**PASS**

---

# 21. Exemplo real validado — 2 × 66 fechados + 2 × 65

Foi também encontrado e validado um caso real:

```text
Encomenda:
ADM26100257049,148000002
```

Existiam:

```text
66 #1 fechado
66 #2 fechado

65 #1 aberto
65 #2 aberto
```

Como não existiam 66 ativos, mas existiam 65 ativos:

```text
100% Em Expedição
```

O comportamento observado correspondeu à regra definida.

### Resultado

**PASS**

Este caso não corresponde ao cenário `2 × 66 ativos + 1 × 65`; corresponde a `2 × 66 fechados + 2 × 65 abertos`.

---

# 21A. UAT — cenário 2 × 66 ativos + 1 × 65 aberto (07/10/2026)

## Objectivo

Validar em dados reais a distribuição esperada:

```text
66 #1 ativo → 25%
66 #2 ativo → 25%
65 aberto   → 50%
```

Definições usadas na pesquisa (alinhadas à regra de distribuição):

* **66 ativo** = `BO.fechada = 0` **e** `SUM(BI.qtt − BI.qtt2) > 0` nesse 66;
* **65 aberto** = `BO.fechada = 0`;
* ligações: `66.BI.obistamp = 1.BI.bistamp`, `65.BI.obistamp = 66.BI.bistamp`.

## Pesquisa read-only — BD UAT `LillianaSerodioPhc`

**Não** foram criados dados artificiais; **não** foi alterada a implementação.

| Métrica | Resultado |
| --- | --- |
| Encomendas com algum `ndos=66` | 16 |
| Com ≥2 documentos 66 (qualquer estado) | 2 |
| Com ≥2 documentos 66 **abertos** | **0** |
| Com ≥2 documentos 66 **ativos** | **0** |
| Com ≥2 66 ativos **e** ≥1 65 aberto | **0** |

## Casos mais próximos (não satisfazem o cenário)

### Encomenda 11 — `ADM26092937019,063000002`

* 1×66 **fechado** + 1×66 **ativo**;
* 1×65 **aberto** associado ao 66 fechado;
* corresponde ao cenário `1×66 ativo + 1×65`, já validado (Cenário A / §20) — **PASS**.

### Encomenda 16 — `ADM26100257049,148000002`

* 2×66 **fechados**;
* 2×65 **abertos**;
* corresponde ao cenário já validado de múltiplos 66 fechados + 65 aberto (§21) — **PASS**.

## Conclusão

> **UAT PENDENTE / NÃO OBSERVÁVEL — o cenário 2×66 ativos + 1×65 aberto não é reproduzível com os dados reais atualmente existentes na BD UAT.**

> A regra de distribuição para este cenário (`25% + 25% + 50%`) permanece coberta pelos testes unitários da `DistribuicaoLogicaCalculator`, mas não foi validada com dados reais porque não existe atualmente uma ocorrência que permita observá-la.

Classificação:

| Tipo | Estado |
| --- | --- |
| Regra documental | **mantida** |
| Teste unitário | **cobertura existente** (não removida) |
| UAT dados reais | **PENDENTE / NÃO OBSERVÁVEL** |
| Veredicto | **não é FAIL** |

---

# 22. Implementação da distribuição

Foram alterados:

```text
Portal.Application/Painel/DistribuicaoLogicaCalculator.cs
Portal.Application/Painel/PainelDtos.cs
Portal.Infrastructure/Painel/PainelQuery.cs
Portal.UnitTests/DistribuicaoLogicaCalculatorTests.cs
```

### `DistribuicaoLogicaCalculator`

Passou de uma classificação exclusivamente unitária para uma classificação baseada em contribuições fracionadas.

### `PainelDtos`

`Quantidade` passou a suportar `decimal`, permitindo representar contribuições como:

```text
0,5
0,25
0,166666...
```

antes do arredondamento final da percentagem.

### `PainelQuery`

Passou a produzir os factos necessários para a distribuição fracionada.

### Testes

Foram acrescentados testes específicos para:

* apenas 66;
* vários 66;
* apenas 65;
* 66 + 65;
* vários 66 + 65;
* ausência de documentos ativos.

---

# 23. O que NÃO foi alterado na distribuição

Não foram alterados:

* contadores documentais do Centro;
* listas de documentos;
* Picking;
* Kapps;
* SignalR;
* SPs;
* documentos PHC;
* frontend do Centro;
* frontend da TV.

Centro e TV continuam a consumir o mesmo endpoint:

```text
GET /api/v1/painel/centro-estados
```

Consequentemente, a regra de cálculo é única.

---

# 24. Validação técnica

Após as alterações:

```text
Portal.Domain       OK
Portal.Application  OK
Portal.Infrastructure OK
Portal.Api          OK
Portal.UnitTests    OK
```

Resultado:

```text
0 warnings
0 errors
```

Testes:

```text
106 passed
0 failed
0 skipped
```

Dos testes específicos da distribuição:

```text
19 passed
```

---

# 25. Estado FINAL do Picking

A pergunta:

> "Esta encomenda ainda tem alguma quantidade para separar?"

é agora respondida por:

```text
Existe uma linha onde:

BI.qtt > SUM(66.BI.qtt)
```

Se sim:

```text
permanece no Picking
```

Se não:

```text
não pertence mais ao Picking
```

Independentemente de:

* 66 aberto/fechado;
* check-in;
* número de sessões de Picking;
* existência de vários 66.

---

# 26. Estado FINAL da distribuição Centro / TV

A pergunta:

> "Como deve ser distribuída uma encomenda pelos estados operacionais?"

é respondida através de unidades fracionadas.

Uma encomenda lógica vale:

```text
1.0
```

Essa unidade pode ser distribuída pelos documentos ativos que representam as diferentes fases do circuito.

Exemplo:

```text
66 + 65
```

passa a:

```text
0,5 + 0,5
```

e não:

```text
1,0 + 0,0
```

---

# 27. Distinção fundamental entre as duas regras

As duas regras não devem ser confundidas.

### Picking

Pergunta:

> Quanto ainda falta separar?

Fonte:

```text
BI.qtt
-
SUM(66.BI.qtt)
```

### Centro / TV

Pergunta:

> Como está distribuída a encomenda pelas fases operacionais?

Fonte:

```text
documentos 66 ativos
+
documentos 65 ativos
```

com distribuição fracionada.

São conceitos diferentes e devem continuar independentes.

---

# 28. Situações que permanecem não determinadas

## `BI.qtt2`

Não foi determinado o escritor efetivo.

Existem triggers `BI` encriptados e podem existir processos PHC externos não acessíveis.

## `BI.qtt` externo

Foram identificados escritores conhecidos:

* Portal;
* SPs HCA;
* SP Kapps para documentos gerados.

Pode existir escrita adicional através de módulos PHC/triggers externos cujo comportamento não é acessível.

Isto não altera a conclusão sobre `Kapps Quantity`, porque a view acessível demonstra inequivocamente:

```text
Quantity = BI.qtt
```

---

# 29. Conclusão final

A implementação final fica assente em três princípios:

### 1. `BI.qtt` é a quantidade operacional

É a quantidade que o Portal coloca em circulação depois da autorização e é também a quantidade que o Kapps expõe como `Quantity`.

### 2. 66 representa quantidade separada

Para determinar se ainda existe quantidade por separar:

```text
BI.qtt > SUM(66.BI.qtt)
```

é a regra funcional aplicada.

### 3. 66 e 65 podem representar partes simultâneas da mesma encomenda

Por isso, para o Centro de Operações e TV, uma encomenda pode representar uma unidade fracionada:

```text
66 + 65
→ 50% + 50%
```

em vez de ser artificialmente colocada a 100% num único estado.

---

# 30. Ficheiros alterados

## Backend

```text
Portal.Infrastructure/Encomendas/EncomendasQuery.cs
Portal.Infrastructure/Painel/PainelQuery.cs
Portal.Application/Painel/DistribuicaoLogicaCalculator.cs
Portal.Application/Painel/PainelDtos.cs
```

## Testes

```text
Portal.UnitTests/DistribuicaoLogicaCalculatorTests.cs
```

## Frontend

```text
src/frontend/src/features/encomendas/EncomendasListPage.tsx
```

Alteração frontend:

```text
dossier66Alterado
    ↓
invalida dossiers 66
    ↓
se modo Picking
    ↓
invalida encomendas abertas
```

---

# 31. Resultado

O circuito fica agora coerente entre:

```text
Autorização
    ↓
BI.qtt
    ↓
Kapps
    ↓
Picking físico
    ↓
66
    ↓
65
    ↓
Centro / TV
```

sem transferir para o Portal responsabilidades que pertencem ao Kapps/Syslog ou ao PHC.

As regras implementadas baseiam-se nos campos e relações efetivamente auditados, mantendo explicitamente identificadas as partes cuja origem permanece não determinável.

---

# 32. REGRA B — Cancelar Picking bloqueado após separação materializada

## Decisão funcional final (07/10/2026)

> Depois de existir quantidade materializada num ndos=66 para qualquer linha da encomenda, o Picking não pode ser cancelado.

### Critério

```text
EXISTS linha da encomenda (ndos=1) com
  SUM(66.BI.qtt) > 0
onde
  66.BI.obistamp = 1.BI.bistamp
  e ndos do 66 = série de Picking configurada (SeriePickingNdos)
```

Sem filtro por `fechada` / `u_chkin` no 66 (qualquer quantidade materializada em 66 conta).

### O que NÃO entra no critério

* **Não** usar `BI.qtt2`.
* **Não** usar Kapps `QuantityPicked` / `QuantitySatisfied`.
* **Não** usar ndos=65.

### Relação com a lista Em Picking

A encomenda **continua** no universo Picking enquanto existir:

```text
BI.qtt > SUM(66.BI.qtt)
```

(por linha, mesma ligação `obistamp = bistamp`).

Portanto é possível estar **simultaneamente**:

* no universo Picking (ainda há quantidade por separar);
* com quantidade já separada em 66 (`SUM(66.qtt) > 0` nalguma linha);
* e com **Cancelar bloqueado** (REGRA B).

### Motivação

* **Cancelar Picking** (actual) restaura `BI.qtt` a partir de `BI2.u_qttorig` e limpa autorizações / flags de pronta (`u_pickrdy` / `u_pickstat`).
* Os documentos **66 não são alterados** pelo cancelamento do Portal.
* Por decisão funcional: depois de existir **separação materializada em 66**, essa operação **não** pode ser revertida através de «Cancelar Picking» (nem desmarcar pronta no detalhe pelo mesmo caminho).

### Implementação (referência)

| Camada | O quê |
| --- | --- |
| API lista/detalhe | Campo `temQtt66` (mesmo critério EXISTS/SUM) |
| UI `/picking` | Cancelar oculto quando `temQtt66` (mantém também o guard legado `pickingEmAndamento`) |
| UI detalhe | Desmarcar pronta desactivado + tooltip quando `temQtt66` |
| SP | `sp_HCA_picking_cancel` e `sp_HCA_marcar_pronta_picking` (pronta=0) bloqueiam com mensagem REGRA B — script `sql/086_alter_picking_cancel_block_when_qtt66.sql` |
| Testes | `PickingCancelRules` / `PickingCancelRulesTests` |

### UAT — encomenda 27 (07/10/2026) — **PASS**

| Campo | Valor |
| --- | --- |
| Encomenda | 27 · `ADM26100264549,203000002` |
| Linha relevante | ref 1280 · `BI.qtt = 7` |
| Materializado 66 | `SUM(66.BI.qtt) = 3` (dossier 66 n.º 19, **aberto**) |
| Restante por separar | 4 (`7 > 3`) |
| ndos=65 | **sem** |
| Continua em Picking | **sim** (`GET …/abertas?prontaPicking=true`) |
| `temQtt66` | **true** |
| Cancelar (lista) | **bloqueado** |
| Desmarcar (detalhe) | **bloqueado** |
| Backend / SP | **protegido** (086 aplicado em UAT) |
| UI | **validada manualmente** |

Veredicto: **PASS**.

---

# 33. UAT — Pausa e Retoma Kapps (picagem parcial)

## Caso

| Campo | Valor |
| --- | --- |
| Data | 07/10/2026 |
| Encomenda | `ADM26100264485,524000002` (obrano **26**) |
| Cliente | ALFREDO DE OLIVEIRA MOTA |
| Linha | ref **1414** · bistamp `ADM26100264529,045000003` |
| `BI.qtt` | 8 |

## Estado inicial

* `BI.qtt = 8`, `BI.qtt2 = 0`
* `u_qttorig = 8`, `u_qtdaut = 8`
* `u_pickrdy = 1`, `u_pickstat = 1`
* sem 66 / sem 65
* sem `u_Kapps_DossierLin`
* sem `u_Kapps_Session_Docs` para esta encomenda

## Após picagem parcial + PAUSA

Picadas **3** unidades; operação normal de pausa no terminal Kapps.

| Campo | Resultado |
| --- | --- |
| `DossierLin` | 1 linha · `Qty=3`, `Qty2=3`, `Status=A`, `Integrada=N` |
| `QuantityPicked` | 3 |
| `QuantityPending` | 5 |
| `BI.qtt` / `BI.qtt2` | 8 / 0 (inalterados) |
| 66 / 65 | nenhum |
| `Session_Docs` | **criado** 1 registo; `SessionEndDateTime` **preenchido** |

> A pausa não reverte a picagem parcial nem altera as quantidades PHC. A quantidade picada permanece ativa em `DossierLin` e continua a ser considerada por `v_Kapps_Picking_Lines`.

## Após RETOMA

Retoma no terminal **sem** picar quantidade adicional e **sem** integrar.

| Campo | Resultado |
| --- | --- |
| `Session_Docs` | **novo** registo; **mesmo** `SessionID` |
| `DossierLin` | **reutilizada** (não criada segunda linha) |
| `Qty2` | mantém 3 |
| `QuantityPicked` / `QuantityPending` | 3 / 5 |
| `BI.qtt` / `BI.qtt2` | inalterados |
| 66 / 65 | nenhum |

## Conclusões funcionais — **UAT PASS**

1. Pausa não desfaz quantidade já picada.
2. Pausa não altera `BI.qtt` nem `BI.qtt2`.
3. A quantidade parcial continua visível no Portal através de `QuantityPicked`.
4. Retoma não duplica quantidade.
5. Retoma reutiliza a `DossierLin` existente.
6. Retoma cria novo registo em `Session_Docs`.
7. O `SessionID` mantém-se entre as passagens.
8. Pausa/retoma não cria nem altera documentos 66/65.

## Ressalva — `SessionEndDateTime IS NULL`

> O teste não permite concluir que `SessionEndDateTime IS NULL` seja uma definição universal de “sessão Kapps em curso”. Tanto o registo criado na pausa como o novo registo criado na retoma estavam com `SessionEndDateTime` preenchido no momento dos snapshots. A causa exata deste comportamento no terminal não foi determinada.

**Não** transformar esta ressalva em alteração de código nem em regra Portal.

## Resumo UAT Kapps (cenários relacionados)

| Cenário | Estado |
| --- | --- |
| Pausa | **PASS** |
| Retoma | **PASS** |
| Aborto | **PASS** (ver §34) |
| Múltiplos 65 abertos | **PASS** (ver §35) |
| 2×65 na mesma linha do mesmo 66 | **NÃO OBSERVÁVEL** |

---

# 34. UAT — Aborto de picagem Kapps (parcial)

## Caso

| Campo | Valor |
| --- | --- |
| Data | 07/10/2026 |
| Encomenda | `ADM26100264485,524000002` (obrano **26**) |
| Linha | ref **1414** · bistamp `ADM26100264529,045000003` |
| Operação | Aborto/cancelamento explícito no terminal Kapps/Syslog (sem integração/fecho posterior) |

## Antes do aborto (`2026-10-07 14:34:23`)

| Campo | Valor |
| --- | --- |
| `BI.qtt` / `BI.qtt2` | 8 / 0 |
| `u_qttorig` / `u_qtdaut` | 8 / 8 |
| `u_pickrdy` / `u_pickstat` / `fechada` | 1 / 1 / 0 |
| `DossierLin` | `Qty=3`, `Qty2=3`, `Status=A`, `Integrada=N`, `SessionID=NULL` |
| `Quantity` / `Satisfied` / `Picked` / `Pending` | 8 / 0 / **3** / **5** |
| 66 / 65 / SUM66 | 0 / 0 / 0 |
| `Session_Docs` | 2 registos (ambos fechados) |

## Depois do aborto (`2026-10-07 14:37:18`)

| Campo | Valor |
| --- | --- |
| `BI.qtt` / `BI.qtt2` | 8 / 0 (**inalterados**) |
| `u_qttorig` / `u_qtdaut` | 8 / 8 |
| `u_pickrdy` / `u_pickstat` / `fechada` | 1 / 1 / 0 (**inalterados**) |
| `DossierLin` | **0 linhas** — linha `Qty2=3` **removida**; sem nova linha |
| `Quantity` / `Satisfied` / `Picked` / `Pending` | 8 / 0 / **0** / **8** |
| 66 / 65 / SUM66 | 0 / 0 / 0 |
| `Session_Docs` | **3** registos; 3.º com mesmo `SessionID`, Start `20261007143537`, End `20261007143609` (fechado) |

## Conclusões comprovadas — **UAT PASS**

1. O aborto remove a `DossierLin` associada à picagem parcial.
2. A quantidade materializada em `Qty2` deixa de existir com a remoção da linha.
3. `QuantityPicked` passa de 3 para 0.
4. `QuantityPending` passa de 5 para 8.
5. `BI.qtt` não é alterado.
6. `BI.qtt2` não é alterado.
7. `u_pickrdy` não é alterado.
8. `u_pickstat` não é alterado.
9. O aborto não cria 66.
10. O aborto não cria 65.
11. A encomenda continua preparada para Picking após o aborto (`u_pickrdy=1`, `QuantityPending=8`).
12. Não foi criada uma segunda `DossierLin`.

## Distinção funcional

> **Abortar Kapps não é o mesmo que Cancelar Picking no Portal.**

O aborto Kapps remove a materialização da picagem (`DossierLin`) e devolve a linha ao estado de quantidade não picada, mas **não** desfaz a preparação da encomenda no Portal nem restaura/limpa `BI.qtt`, `u_qtdaut`, `u_pickrdy` ou `u_pickstat`.

Neste caso, após o aborto: `BI.qtt = 8` e `QuantityPending = 8`, mantendo a encomenda no universo de Picking.

## Ressalva — `Session_Docs` no ciclo de aborto

> Durante o ciclo que culminou no aborto foi criado um terceiro `Session_Docs`, com o mesmo `SessionID` e `SessionEndDateTime` preenchido. O significado funcional exato deste novo registo **não foi determinado**.

**Não** concluir que o terceiro registo “representa semanticamente o aborto”. **Não** alterar código com base nesta observação.

---

# 35. UAT — Múltiplos 65 abertos sobre o mesmo 66

## Caso (vivo UAT, 07/10/2026)

| Peça | Valor |
| --- | --- |
| Encomenda 1 | obrano **26** · `ADM26100264485,524000002` |
| 66 #20 | `Syslog_20261007144453293` |
| 65 #8 | `Syslog_20261007144614576` |
| 65 #9 | `Syslog_20261007144729923` |

```text
1 (enc.26)
└── 66 #20
    ├── linha 1406 → 65 #8
    └── linha 1414 → 65 #9
```

## Relações

Confirmado:

* `65#8.BI.obistamp = 66.BI.bistamp` da linha ref. **1406**;
* `65#9.BI.obistamp = 66.BI.bistamp` da linha ref. **1414**.

> Os dois 65 derivam do mesmo documento 66, mas correspondem a **linhas diferentes** do 66. Este UAT **não** representa dois 65 para a mesma linha.

## Estado observado

| Documento | Estado | Qtt | Qtt2 |
| --- | --- | ---: | ---: |
| 66 #20 | aberto, `u_chkin=1` | 23 | 13 |
| 65 #8 | aberto | 5 | 0 |
| 65 #9 | aberto | 8 | 0 |

Linhas do 66:

| ref | qtt | qtt2 | 65 |
| --- | ---: | ---: | --- |
| 1406 | 5 | 5 | → 65 #8 |
| 1407 | 2 | 0 | — |
| 1414 | 8 | 8 | → 65 #9 |
| 1416 | 5 | 0 | — |
| 1416.1 | 3 | 0 | — |

Agregados: `66.qtt=23`, `66.qtt2=13`, pendente 66 = 10, `SUM(65.qtt)=13` (esperado: 65 cobrem só duas das cinco linhas).

## Picking

Os 65 **não** entram no cálculo de quantidade separada. Nas cinco linhas: `BI.qtt = SUM(66.BI.qtt)` → remaining = 0.

```text
remaining = max(0, BI.qtt - SUM(66.BI.qtt))
```

Os documentos 65 não alteraram esse cálculo.

## Centro / TV

Contribuição lógica desta encomenda (factos: `1×66 activo` com `u_chkin=1`, `Tem65=true`):

| Estado | Contribuição |
| --- | ---: |
| Em Aberto | 0% |
| Em Picking | 0% |
| Separado | 0% |
| Em Entrega | **50%** |
| Em Expedição | **50%** |

> A existência de dois 65 abertos derivados do mesmo 66 **não** divide o peso lógico de Em Expedição entre os dois documentos. Os múltiplos 65 são tratados como um único grupo lógico `Tem65`, com peso de 50% neste cenário `1×66 activo + 65`.

Contagem documental: cada 65 conta individualmente → **COUNT** Em Expedição = **2** para estes documentos; a % lógica continua **50%**.

## Resultado — **UAT PASS**

1. Dois 65 podem coexistir abertos derivados do mesmo 66.
2. Ambos mantêm `BI.obistamp → 66.BI.bistamp`.
3. Podem corresponder a linhas diferentes do mesmo 66.
4. Os múltiplos 65 são um único grupo lógico para a distribuição Centro/TV.
5. O grupo 65 recebe 50% neste cenário.
6. Os 65 não alteram o cálculo de quantidade separada/Picking.
7. A contagem documental continua a contar cada 65 individualmente.

## Limitação

> Continua **não observado** um caso com dois ou mais 65 abertos correspondentes à **mesma linha do mesmo 66**. Esse caso **não** fica validado por este UAT.

---

# 36. Pendentes de Picagem (referência — 07/10/2026)

Funcionalidade Portal distinta de **Em Picking** e da distribuição Centro/TV. Fonte de verdade operacional: [`PROJECT-STATE.md`](./PROJECT-STATE.md) § *Pendentes de Picagem*; contrato: [`api-contract.md`](./api-contract.md).

| | Em Picking | Pendentes de Picagem |
| --- | --- | --- |
| Universo | `u_pickrdy=1` + remaining | `u_pickrdy=1` + **started** encomenda |
| Critério | `BI.qtt > SUM(66.qtt)` por linha | ∃ `Picked>0` ∨ `SUM66>0` na encomenda; depois `Pending>0` por linha |
| Kapps | UI / resumo | `Picked` = Qty2 A/N no Pending híbrido |
| 65 | Fora do remaining | **Não participa** |
| Sessões | Observação UAT (§33–§34) | `Session_Docs` **não** entra no cálculo |

`SUM66` nesta regra inclui todos os 66 ligados à linha (`obistamp`), **independentemente** de `fechada` / `u_chkin` (igual ao critério de soma usado em Em Picking / REGRA B para materialização).

O **started** é ao nível da **encomenda** (antes de filtros de artigo/cor). A regra híbrida evita `qtt − SUM66 − Picked`.

**Ressalva de UAT:** caso real `SUM66>0` ∧ `Picked>0` na mesma linha **não observável**; regra coberta por testes unitários — **não** é FAIL.
