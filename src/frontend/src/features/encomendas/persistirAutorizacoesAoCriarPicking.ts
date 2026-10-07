import { api, type EncomendaLinha } from '../../shared/api'

/**
 * Ao criar picking: garante que o que a UI sugere/mostra fica em BI2.u_qtdaut.
 *
 * - Rascunhos locais (deferSave) com valor > 0 são gravados.
 * - Linhas ainda com autorização 0 e restante > 0 recebem quantidadePorSatisfazer
 *   (o valor que a célula já mostrava como sugestão).
 */
export async function prepararAutorizacoesAntesPicking(
  boStamp: string,
  rascunhoLinhas?: EncomendaLinha[] | null,
): Promise<void> {
  const detalhe = await api.encomendaDetalhe(boStamp)
  const draftBy = new Map((rascunhoLinhas ?? []).map((l) => [l.biStamp, l]))

  for (const server of detalhe.linhas) {
    const draft = draftBy.get(server.biStamp)
    const candidata = draft?.quantidadeAutorizada ?? server.quantidadeAutorizada
    const desejada =
      candidata > 0
        ? candidata
        : server.quantidadePorSatisfazer > 0
          ? server.quantidadePorSatisfazer
          : 0

    if (desejada === server.quantidadeAutorizada) continue

    await api.atualizarQuantidadeAutorizada(server.biStamp, {
      quantidadeAutorizada: desejada,
      valorAnteriorEsperado: server.quantidadeAutorizada,
      permitirAcimaStock: false,
    })
  }
}
