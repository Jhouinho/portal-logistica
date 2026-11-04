# Portal Mobile — Estados (circuito balcão 1B + 2C)

| Estado UI | Código API | Notas |
| --- | --- | --- |
| Recebido / Em análise | `recebido` / `em_analise` | Fila portal (`u_HcaPmPedido`); **sem** BO67 na submissão |
| Em aprovação | `em_aprovacao` | Claim atómico antes da SP criar ndos=67 |
| Validado | `validado` (interno: `integrado` / `em_separacao` / legado operacional) | Dossier PHC ligado; faturação **no PHC CS** |
| Rejeitado | `rejeitado` | Staff rejeitou no balcão |
| Cancelado | `cancelado` | Circuito legado / cancelamento |

## Circuito actual (balcão)

1. Cliente regista e recolhe artigos → submete → só `u_HcaPmPedido` (`PedidosInternosEnabled=true`).
2. Dirige-se ao balcão com os artigos.
3. Staff confere linhas/preços → **Validar** (`Aprovar`) → cria dossier `ndos=67`.
4. Faturação do dossier no PHC — **fora do portal**.
5. Fim.

**Removido da UI/API activa:** Em separação → Pronto p/ levantamento → Concluir (`POST …/operacao` devolve 400).

## Legado (flag off / BO directo)

| Estado UI | Código API | Implementação |
| --- | --- | --- |
| Pedido submetido | `submetido` | Documento `ndos=67` sem entrada em `u_HcaPedidoMobileCancel` |
| Cancelado | `cancelado` | `sp_HCA_cancelar_pedido_mobile` |

## Flag

`Portal:Cliente:PedidosInternosEnabled` — `true` = fila interna; `false` = criação legado via SP.
