# Portal Mobile — Estados (implementação actual)

| Estado UI | Código API | Implementação actual |
| --- | --- | --- |
| Pedido submetido | `submetido` | Documento `ndos=67` sem entrada em `u_HcaPedidoMobileCancel` |
| Em preparação | — | **Pendente** — exige associação Cópia de Dossier (B06–B08) |
| Pronto para levantamento | — | **Pendente** — sem mapeamento PHC confirmado |
| Concluído | — | **Pendente** — sem mapeamento PHC confirmado |

Cancelamento: insert em `u_HcaPedidoMobileCancel`; **não** apaga BO/BI. Histórico omite cancelados.

Número apresentado ao cliente: `obrano` (**provisório** até fecho B05/C03).
