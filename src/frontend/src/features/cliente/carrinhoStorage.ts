export type CarrinhoLinha = {
  ref: string
  design: string
  cor: string
  qtt: number
  precoUnitario: number
}

function lisbonDateKey(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Lisbon',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function storageKey(no: number, estab: number): string {
  return `ls_cliente_cart_${no}_${estab}_${lisbonDateKey()}`
}

export function loadCarrinho(no: number, estab: number): CarrinhoLinha[] {
  try {
    const raw = localStorage.getItem(storageKey(no, estab))
    if (!raw) return []
    const parsed = JSON.parse(raw) as CarrinhoLinha[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

export function saveCarrinho(no: number, estab: number, linhas: CarrinhoLinha[]) {
  localStorage.setItem(storageKey(no, estab), JSON.stringify(linhas))
}

export function clearCarrinho(no: number, estab: number) {
  localStorage.removeItem(storageKey(no, estab))
}

export function upsertLinha(linhas: CarrinhoLinha[], nova: CarrinhoLinha): CarrinhoLinha[] {
  const key = `${nova.ref}|${nova.cor}`
  const idx = linhas.findIndex((l) => `${l.ref}|${l.cor}` === key)
  if (idx < 0) return [...linhas, nova]
  const next = [...linhas]
  next[idx] = { ...next[idx], qtt: next[idx].qtt + nova.qtt }
  return next
}
