/**
 * Aceita apenas paths relativos internos da área de operador (anti open-redirect).
 * Decodifica percent-encoding em ciclo (Navigate/query podem deixar uma camada extra).
 */
export function sanitizeOperadorReturnUrl(raw: string | null | undefined): string | null {
  if (raw == null) return null
  let decoded = String(raw).trim()
  if (!decoded) return null

  for (let i = 0; i < 3; i++) {
    if (!/%[0-9A-Fa-f]{2}/.test(decoded)) break
    try {
      const next = decodeURIComponent(decoded)
      if (next === decoded) break
      decoded = next
    } catch {
      return null
    }
  }

  const t = decoded.trim()
  if (!t.startsWith('/')) return null
  if (t.startsWith('//')) return null
  if (t.includes('://')) return null
  if (!t.startsWith('/operador')) return null
  // Evitar /operadorEvil — só /operador ou /operador/...
  if (t !== '/operador' && !t.startsWith('/operador/')) return null
  if (t.includes('\\') || t.includes('\n') || t.includes('\r')) return null
  return t
}

/** Backup se a query/state se perder entre redirect e submit (ex.: remount). */
const RETURN_STORAGE_KEY = 'ls_operador_return'

export function stashOperadorReturnUrl(path: string): void {
  const safe = sanitizeOperadorReturnUrl(path)
  if (!safe) return
  try {
    sessionStorage.setItem(RETURN_STORAGE_KEY, safe)
  } catch {
    /* private mode / quota — query+state continuam a ser a fonte principal */
  }
}

export function takeStashedOperadorReturnUrl(): string | null {
  try {
    const raw = sessionStorage.getItem(RETURN_STORAGE_KEY)
    sessionStorage.removeItem(RETURN_STORAGE_KEY)
    return sanitizeOperadorReturnUrl(raw)
  } catch {
    return null
  }
}

export function peekStashedOperadorReturnUrl(): string | null {
  try {
    return sanitizeOperadorReturnUrl(sessionStorage.getItem(RETURN_STORAGE_KEY))
  } catch {
    return null
  }
}

export type OperadorReturnSources = {
  queryReturnUrl?: string | null
  state?: unknown
  /** Injectável nos testes; por omissão lê sessionStorage. */
  stashed?: string | null | undefined
}

function stateReturnUrl(state: unknown): string | null {
  if (!state || typeof state !== 'object' || !('returnUrl' in state)) return null
  return String((state as { returnUrl?: unknown }).returnUrl ?? '')
}

/**
 * Resolve destino de operador a partir de query, state de navegação e stash.
 * Preferência: query → state → stash.
 */
export function resolveOperadorReturnUrl(sources: OperadorReturnSources): string | null {
  const stashed =
    sources.stashed !== undefined ? sources.stashed : peekStashedOperadorReturnUrl()
  return (
    sanitizeOperadorReturnUrl(sources.queryReturnUrl) ??
    sanitizeOperadorReturnUrl(stateReturnUrl(sources.state)) ??
    sanitizeOperadorReturnUrl(stashed)
  )
}

/** UI de login de operador quando existe destino `/operador…` validado. */
export function isOperadorLoginContext(sources: OperadorReturnSources): boolean {
  return resolveOperadorReturnUrl(sources) != null
}

/**
 * Destino após login PHC bem-sucedido.
 * Operador validado → esse path; caso contrário → entrada normal da Logística (`/`).
 */
export function resolvePostLoginDestination(sources: OperadorReturnSources): string {
  return resolveOperadorReturnUrl(sources) ?? '/'
}
