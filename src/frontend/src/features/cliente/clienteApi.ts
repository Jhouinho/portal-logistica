const API_BASE = import.meta.env.VITE_API_BASE ?? ''
const FETCH_TIMEOUT_MS = 8_000

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    const { signal: outerSignal, ...rest } = init ?? {}
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
    if (outerSignal) {
      if (outerSignal.aborted) controller.abort()
      else outerSignal.addEventListener('abort', () => controller.abort(), { once: true })
    }
    try {
      res = await fetch(`${API_BASE}${path}`, {
        credentials: 'include',
        ...rest,
        // headers depois do spread — senão Idempotency-Key (etc.) apaga Content-Type → 415
        headers: {
          'Content-Type': 'application/json',
          ...(rest.headers as Record<string, string> | undefined),
        },
        signal: controller.signal,
      })
    } finally {
      clearTimeout(timer)
    }
  } catch {
    throw new Error('API indisponível. Confirme que o backend está a correr.')
  }
  if (!res.ok) {
    let detail = res.statusText
    try {
      const body = await res.json()
      detail = body.detail ?? body.title ?? detail
    } catch {
      /* ignore */
    }
    throw new Error(detail)
  }
  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

export type ClienteMe = { no: number; estab: number; nome: string; ncont: string }

export type ClienteArtigo = {
  ref: string
  design: string
  precoUnitario: number
  avisoStockBaixo: boolean
  temImagem: boolean
}

export function clienteArtigoImagemUrl(ref: string): string {
  return `/api/v1/cliente/artigos/${encodeURIComponent(ref)}/imagem`
}

export type ClientePedidoOrigem = 'interno' | 'legado'

export type ClientePedidoLista = {
  bostamp: string | null
  obrano: number | null
  boano: number | null
  dataObra: string
  hora: string | null
  estadoCodigo: string
  estadoEtiqueta: string
  etotaldeb: number
  podeCancelar: boolean
  pedidoId: number | null
  numeroInterno: string | null
  origem: ClientePedidoOrigem
}

export type ClientePedidoDetalhe = ClientePedidoLista & {
  linhas: {
    ref: string
    design: string
    cor: string
    qtt: number
    precoUnitario: number
    totalLinha: number
  }[]
}

export type ClientePedidoCreateResult = {
  alreadyExists: boolean
  bostamp: string | null
  obrano: number | null
  boano: number | null
  etotaldeb: number
  pedidoId: number | null
  numeroInterno: string | null
  origem: ClientePedidoOrigem
  estadoCodigo: string
  estadoEtiqueta: string
}

/** Identificador de rota/API: pedidoId, numeroInterno ou bostamp legado. */
export function clientePedidoRouteId(p: {
  origem?: string | null
  pedidoId?: number | null
  numeroInterno?: string | null
  bostamp?: string | null
}): string {
  if (p.origem === 'interno') {
    if (p.pedidoId != null) return String(p.pedidoId)
    if (p.numeroInterno) return p.numeroInterno
  }
  if (p.bostamp) return p.bostamp
  if (p.pedidoId != null) return String(p.pedidoId)
  if (p.numeroInterno) return p.numeroInterno
  return ''
}

export function clientePedidoNumeroLabel(p: {
  origem?: string | null
  numeroInterno?: string | null
  obrano?: number | null
  pedidoId?: number | null
}): string {
  if (p.origem === 'interno' && p.numeroInterno) return p.numeroInterno
  if (p.obrano != null) return String(p.obrano)
  if (p.numeroInterno) return p.numeroInterno
  if (p.pedidoId != null) return String(p.pedidoId)
  return '—'
}

export const clienteApi = {
  me: () => request<ClienteMe>('/api/v1/cliente/auth/me'),
  login: (nif: string, password: string) =>
    request<{ utilizador: ClienteMe }>('/api/v1/cliente/auth/login', {
      method: 'POST',
      body: JSON.stringify({ nif, password }),
    }),
  logout: () => request<void>('/api/v1/cliente/auth/logout', { method: 'POST' }),
  primeiroAcessoIniciar: (nif: string) =>
    request<{ challengeToken: string; nome: string }>('/api/v1/cliente/auth/primeiro-acesso/iniciar', {
      method: 'POST',
      body: JSON.stringify({ nif }),
    }),
  primeiroAcessoTelemovel: (challengeToken: string, telemovel: string) =>
    request<{ passwordToken: string }>('/api/v1/cliente/auth/primeiro-acesso/validar-telemovel', {
      method: 'POST',
      body: JSON.stringify({ challengeToken, telemovel }),
    }),
  primeiroAcessoPassword: (passwordToken: string, password: string) =>
    request<{ utilizador: ClienteMe }>('/api/v1/cliente/auth/primeiro-acesso/definir-password', {
      method: 'POST',
      body: JSON.stringify({ passwordToken, password }),
    }),
  recuperarIniciar: (nif: string) =>
    request<{ challengeToken: string; nome: string }>('/api/v1/cliente/auth/recuperar/iniciar', {
      method: 'POST',
      body: JSON.stringify({ nif }),
    }),
  recuperarTelemovel: (challengeToken: string, telemovel: string) =>
    request<{ passwordToken: string }>('/api/v1/cliente/auth/recuperar/validar-telemovel', {
      method: 'POST',
      body: JSON.stringify({ challengeToken, telemovel }),
    }),
  recuperarPassword: (passwordToken: string, password: string) =>
    request<{ utilizador: ClienteMe }>('/api/v1/cliente/auth/recuperar/definir-password', {
      method: 'POST',
      body: JSON.stringify({ passwordToken, password }),
    }),
  artigo: (ref: string) => request<ClienteArtigo>(`/api/v1/cliente/artigos/${encodeURIComponent(ref)}`),
  pedidos: (top = 10) => request<ClientePedidoLista[]>(`/api/v1/cliente/pedidos?top=${top}`),
  pedido: (id: string) =>
    request<ClientePedidoDetalhe>(`/api/v1/cliente/pedidos/${encodeURIComponent(id)}`),
  criarPedido: (idempotencyKey: string, linhas: { linhaOrd: number; ref: string; qtt: number; cor?: string }[]) =>
    request<ClientePedidoCreateResult>('/api/v1/cliente/pedidos', {
      method: 'POST',
      headers: { 'Idempotency-Key': idempotencyKey },
      body: JSON.stringify({ linhas }),
    }),
  cancelar: (id: string) =>
    request<{ mensagem: string }>(`/api/v1/cliente/pedidos/${encodeURIComponent(id)}/cancelar`, {
      method: 'POST',
    }),
}
