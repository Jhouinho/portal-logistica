/**
 * Limites de semana civil para «Fora de prazo» (alinhado ao backend):
 * segunda 00:00 … domingo, Europe/Lisbon; corte visual refresca na passagem de semana.
 */

export const FORA_DE_PRAZO_WEEK_BOUNDARY_EVENT = 'portal:foraDePrazo-week-boundary'

const FUSO = 'Europe/Lisbon'

/** Início da segunda-feira (00:00) da semana civil de `instant` em Lisboa. */
export function inicioSegundaLisboa(instant: Date = new Date()): Date {
  const parts = lisbonParts(instant)
  const asUtcNoon = Date.UTC(parts.year, parts.month - 1, parts.day, 12, 0, 0)
  const dow = parts.weekday // 1=Mon … 7=Sun (ISO)
  const diasDesdeSegunda = dow - 1
  const segMs = asUtcNoon - diasDesdeSegunda * 86_400_000
  const seg = new Date(segMs)
  const sp = lisbonParts(seg)
  // Reconstruir instante local Lisboa 00:00 via offset aproximado no próprio dia.
  return lisbonWallToUtc(sp.year, sp.month, sp.day, 0, 0, 0)
}

/** Próxima segunda 00:00 Lisboa após o início da semana corrente. */
export function proximaSegundaLisboa(instant: Date = new Date()): Date {
  const inicio = inicioSegundaLisboa(instant)
  return new Date(inicio.getTime() + 7 * 86_400_000)
}

/** Ms até à próxima passagem de semana (mínimo 1 s). */
export function msAteProximaSegunda(instant: Date = new Date()): number {
  const alvo = proximaSegundaLisboa(instant).getTime()
  return Math.max(1_000, alvo - instant.getTime())
}

type LisbonParts = {
  year: number
  month: number
  day: number
  weekday: number
}

function lisbonParts(d: Date): LisbonParts {
  const fmt = new Intl.DateTimeFormat('en-GB', {
    timeZone: FUSO,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
  })
  const bag: Record<string, string> = {}
  for (const p of fmt.formatToParts(d)) {
    if (p.type !== 'literal') bag[p.type] = p.value
  }
  const weekdayMap: Record<string, number> = {
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
    Sun: 7,
  }
  const weekday = weekdayMap[bag.weekday ?? '']
  if (!weekday) {
    throw new Error(`foraDePrazoWeek: weekday inesperado «${bag.weekday}»`)
  }
  return {
    year: Number(bag.year),
    month: Number(bag.month),
    day: Number(bag.day),
    weekday,
  }
}

/** Converte parede Lisboa → UTC Date (usa Intl para obter offset do dia). */
function lisbonWallToUtc(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  second: number,
): Date {
  // Estimativa: UTC candidate then adjust by observed Lisboa offset.
  let guess = Date.UTC(year, month - 1, day, hour, minute, second)
  for (let i = 0; i < 3; i++) {
    const p = lisbonYmdHms(new Date(guess))
    const want = Date.UTC(year, month - 1, day, hour, minute, second)
    const got = Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi, p.s)
    guess += want - got
  }
  return new Date(guess)
}

function lisbonYmdHms(d: Date): { y: number; m: number; d: number; h: number; mi: number; s: number } {
  const fmt = new Intl.DateTimeFormat('en-GB', {
    timeZone: FUSO,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  })
  const bag: Record<string, string> = {}
  for (const p of fmt.formatToParts(d)) {
    if (p.type !== 'literal') bag[p.type] = p.value
  }
  return {
    y: Number(bag.year),
    m: Number(bag.month),
    d: Number(bag.day),
    h: Number(bag.hour),
    mi: Number(bag.minute),
    s: Number(bag.second),
  }
}
