import type {
  KappsPickingDetalhe,
  KappsPickingLinha,
  TvKappsResumoItem,
} from './api'

export type KappsByStampMap = Record<string, KappsPickingDetalhe | null>

/** Converte resumo TV num KappsPickingDetalhe mínimo para reutilizar kappsVisual / kappsTotais. */
export function resumoToKappsDetalhe(item: TvKappsResumoItem): KappsPickingDetalhe {
  const line: KappsPickingLinha = {
    pickingLineKey: item.boStamp,
    article: '',
    description: '',
    quantity: item.qty,
    quantityOriginal: item.qty,
    quantitySatisfied: 0,
    quantityPending: item.pending,
    quantityPicked: item.picked,
    baseUnit: '',
    busyUnit: '',
    conversionFator: 1,
    warehouse: 0,
    pickingKey: item.boStamp,
    originalLineNumber: 0,
    location: null,
    lot: null,
    allowReplacement: 0,
    linObs: null,
    hasReservedQty: 0,
  }
  return {
    pickingKey: item.boStamp,
    number: 0,
    customerName: '',
    date: null,
    customer: '',
    document: '',
    documentName: '',
    exr: null,
    sec: null,
    tpd: null,
    ndc: null,
    deliveryCustomer: null,
    deliveryCode: null,
    barcode: null,
    allowNewProduct: 0,
    useSDR: 0,
    activeTerminalId: item.activeTerminalId,
    activeTerminalLabel: item.activeTerminalLabel,
    activeUserId: item.activeUserId,
    lines: item.qty > 0 || item.picked > 0 || item.pending > 0 ? [line] : [],
  }
}

export function partitionTvKappsResumo(items: TvKappsResumoItem[]): {
  picking: KappsByStampMap
  separacao: KappsByStampMap
} {
  const picking: KappsByStampMap = {}
  const separacao: KappsByStampMap = {}
  for (const item of items) {
    const detalhe = resumoToKappsDetalhe(item)
    if (item.origem === 'dossier66') separacao[item.boStamp] = detalhe
    else picking[item.boStamp] = detalhe
  }
  return { picking, separacao }
}

/** Filtra o resumo batch para a origem da lista operacional. */
export function kappsMapFromTvResumo(
  items: TvKappsResumoItem[],
  origem: 'encomenda' | 'dossier66',
): KappsByStampMap {
  const { picking, separacao } = partitionTvKappsResumo(items)
  return origem === 'dossier66' ? separacao : picking
}
