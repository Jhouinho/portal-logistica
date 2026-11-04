export type CarrinhoLinha = {
  ref: string
  design: string
  cor: string
  qtt: number
  precoUnitario: number
}

/** Data civil em Europe/Lisbon (YYYY-MM-DD). Aceita `now` para testes. */
export function lisbonDateKey(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Lisbon',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now)
}

export function cartStorageKey(no: number, estab: number, dateKey: string): string {
  return `ls_cliente_cart_${no}_${estab}_${dateKey}`
}

function storageKey(no: number, estab: number, now?: Date): string {
  return cartStorageKey(no, estab, lisbonDateKey(now))
}

export function loadCarrinho(no: number, estab: number, now?: Date): CarrinhoLinha[] {
  try {
    const raw = localStorage.getItem(storageKey(no, estab, now))
    if (!raw) return []
    const parsed = JSON.parse(raw) as CarrinhoLinha[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

/** Notifica o shell (badge) quando o storage do carrinho muda na mesma tab. */
export const CARRINHO_CHANGED_EVENT = 'ls-cliente-cart-changed'

function notifyCarrinhoChanged() {
  if (typeof window === 'undefined') return
  window.dispatchEvent(new Event(CARRINHO_CHANGED_EVENT))
}

export function saveCarrinho(no: number, estab: number, linhas: CarrinhoLinha[], now?: Date) {
  localStorage.setItem(storageKey(no, estab, now), JSON.stringify(linhas))
  notifyCarrinhoChanged()
}

export function clearCarrinho(no: number, estab: number, now?: Date) {
  localStorage.removeItem(storageKey(no, estab, now))
  notifyCarrinhoChanged()
}

export function upsertLinha(linhas: CarrinhoLinha[], nova: CarrinhoLinha): CarrinhoLinha[] {
  const key = `${nova.ref}|${nova.cor}`
  const idx = linhas.findIndex((l) => `${l.ref}|${l.cor}` === key)
  if (idx < 0) return [...linhas, nova]
  const next = [...linhas]
  next[idx] = { ...next[idx], qtt: next[idx].qtt + nova.qtt }
  return next
}
