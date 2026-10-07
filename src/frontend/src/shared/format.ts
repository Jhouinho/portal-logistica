/** Montantes (preço / total): sempre 2 casas decimais, pt-PT. */
export function fmtMoney(n: number): string {
  return new Intl.NumberFormat('pt-PT', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n)
}

/** Valor para input type=number (separador `.`). */
export function moneyInputValue(n: number): string {
  return Number.isFinite(n) ? n.toFixed(2) : '0.00'
}

/**
 * Numeração de documentos PHC (encomenda, picking, dossier, etc.): `#123`.
 * Não usar para nº de cliente.
 */
export function fmtDocNo(n: number | string | null | undefined): string {
  if (n == null || n === '') return '—'
  const s = String(n).trim()
  if (!s) return '—'
  return s.startsWith('#') ? s : `#${s}`
}

/**
 * Data de calendário (ISO / yyyy-MM-dd) → dd/MM/yyyy.
 * Nulo, inválido, 0001-01-01 ou sentinela PHC (&lt; 1950) → —.
 */
export function fmtDate(value: string | Date | null | undefined): string {
  if (value == null || value === '') return '—'
  let y: number
  let m: number
  let d: number
  if (typeof value === 'string') {
    const iso = value.trim().match(/^(\d{4})-(\d{2})-(\d{2})/)
    if (iso) {
      y = Number(iso[1])
      m = Number(iso[2])
      d = Number(iso[3])
    } else {
      const dt = new Date(value)
      if (Number.isNaN(dt.getTime())) return '—'
      y = dt.getFullYear()
      m = dt.getMonth() + 1
      d = dt.getDate()
    }
  } else {
    if (Number.isNaN(value.getTime())) return '—'
    y = value.getFullYear()
    m = value.getMonth() + 1
    d = value.getDate()
  }
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d) || y < 1950) return '—'
  return `${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}/${y}`
}

/** BO3.u_modExp — valor PHC tal qual; vazio → —. */
export function fmtMetodoExpedicao(value: string | null | undefined): string {
  const s = value?.trim() ?? ''
  return s || '—'
}

