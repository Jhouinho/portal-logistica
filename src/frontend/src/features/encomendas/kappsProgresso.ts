import type { KappsPickingDetalhe, KappsPickingLinha } from '../../shared/api'

/** Recolhido efectivo: Kapps por vezes deixa QuantityPicked=0 com Pending=0 no fim. */
export function kappsRecolhidoLinha(l: KappsPickingLinha): number {
  const qty = Number(l.quantity) || 0
  const picked = Number(l.quantityPicked) || 0
  const pending = Number(l.quantityPending) || 0
  const satisfied = Number(l.quantitySatisfied) || 0

  if (picked > 0) return picked
  if (qty > 0 && pending <= 0) return qty
  if (satisfied > 0) return satisfied
  return 0
}

export function kappsPendenteLinha(l: KappsPickingLinha): number {
  const qty = Number(l.quantity) || 0
  const pending = Number(l.quantityPending) || 0
  if (qty > 0 && pending <= 0) return 0
  if (pending > 0) return pending
  return Math.max(0, qty - kappsRecolhidoLinha(l))
}

export function kappsTotais(kapps: KappsPickingDetalhe | null | undefined): {
  total: number
  recolhido: number
  pendente: number
  concluido: boolean
  emCurso: boolean
} {
  if (!kapps?.lines.length) {
    return { total: 0, recolhido: 0, pendente: 0, concluido: false, emCurso: false }
  }
  let total = 0
  let recolhido = 0
  let pendente = 0
  for (const l of kapps.lines) {
    total += Number(l.quantity) || 0
    recolhido += kappsRecolhidoLinha(l)
    pendente += kappsPendenteLinha(l)
  }
  const concluido = total > 0 && pendente <= 0
  const emCurso = !concluido && recolhido > 0 && recolhido < total
  return { total, recolhido, pendente, concluido, emCurso }
}
