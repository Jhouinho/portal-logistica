/** QR de artigo contém só a referência; aceita também URL com ?ref= ou último segmento. */
export function normalizeQrPayload(raw: string): string {
  const t = raw.trim()
  if (!t) return t
  try {
    if (/^https?:\/\//i.test(t)) {
      const u = new URL(t)
      const fromQuery = u.searchParams.get('ref') ?? u.searchParams.get('referencia')
      if (fromQuery?.trim()) return fromQuery.trim()
      const parts = u.pathname.split('/').filter(Boolean)
      if (parts.length > 0) return decodeURIComponent(parts[parts.length - 1]!)
    }
  } catch {
    /* texto simples */
  }
  return t
}

export function isIosSafari(
  nav: Pick<Navigator, 'userAgent' | 'platform' | 'maxTouchPoints'> | undefined = typeof navigator !== 'undefined'
    ? navigator
    : undefined,
): boolean {
  if (!nav) return false
  const ua = nav.userAgent
  const iOS =
    /iPad|iPhone|iPod/.test(ua) || (nav.platform === 'MacIntel' && nav.maxTouchPoints > 1)
  const webkit = /WebKit/i.test(ua)
  const chromeIos = /CriOS|FxiOS|EdgiOS/i.test(ua)
  return iOS && webkit && !chromeIos
}

export type HttpsHintLocation = {
  isSecureContext: boolean
  hostname: string
  port: string
  pathname: string
  search: string
}

export function httpsHintUrl(loc?: HttpsHintLocation | null): string | null {
  const w =
    loc ??
    (typeof window !== 'undefined'
      ? {
          isSecureContext: window.isSecureContext,
          hostname: window.location.hostname,
          port: window.location.port,
          pathname: window.location.pathname,
          search: window.location.search,
        }
      : null)
  if (!w || w.isSecureContext) return null
  if (w.hostname === 'localhost' || w.hostname === '127.0.0.1') return null
  if (w.port === '8088') return `https://${w.hostname}:8443${w.pathname}${w.search}`
  return `https://${w.hostname}${w.pathname}${w.search}`
}
