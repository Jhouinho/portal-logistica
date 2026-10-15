# Portal Mobile — Estados (implementação actual)

| Estado UI | Código API | Implementação actual |
| --- | --- | --- |
| Pedido submetido | `submetido` | Documento `ndos=67` sem entrada em `u_HcaPedidoMobileCancel` |
| Cancelado | `cancelado` | Entrada em `u_HcaPedidoMobileCancel` (histórico omite; detalhe devolve 404) |
| Em preparação | — | **Pendente** — exige associação Cópia de Dossier (B06–B08) |
| Pronto para levantamento | — | **Pendente** — sem mapeamento PHC confirmado |
| Concluído / processado | — | **Pendente** — sem campos de origem confirmados |

Cancelamento: insert em `u_HcaPedidoMobileCancel`; **não** apaga BO/BI. Validação no servidor via `PodeCancelar` (só `submetido`). Histórico omite cancelados.

Número apresentado ao cliente: `obrano` (**provisório** até fecho B05/C03).

## Gap conhecido (não inventar)

Sem campos PHC confirmados que liguem o dossier destino (Cópia de Dossier) ao `bostamp` mobile, o portal **não** marca pedidos como processados nem bloqueia cancelamento por «já processado».

### Informação em falta (B06–B08)

1. Configuração da Cópia de Dossier (origem `ndos=67` → destino).
2. Campos físicos de origem no destino (ex.: stamp/número de origem no BO/BI).
3. Regra para impedir cópias/associações duplicadas.

### Proposta técnica (após evidência)

1. Mapear campos confirmados → código API `processado` (ou `em_preparacao`), `PodeCancelar = false`.
2. Cancel atómico: `INSERT … WHERE NOT EXISTS (associação destino)` além do unique em `u_HcaPedidoMobileCancel`.
3. Testes de corrida cancelamento vs processamento em UAT.
