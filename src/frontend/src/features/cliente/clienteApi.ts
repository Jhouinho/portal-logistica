const API_BASE = import.meta.env.VITE_API_BASE ?? ''

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    res = await fetch(`${API_BASE}${path}`, {
      credentials: 'include',
      headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
      ...init,
    })
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
  cores: { codigo: string; nome: string }[]
}

export type ClientePedidoLista = {
  bostamp: string
  obrano: number
  boano: number
  dataObra: string
  hora: string | null
  estadoCodigo: string
  estadoEtiqueta: string
  etotaldeb: number
  podeCancelar: boolean
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
  pedido: (bostamp: string) =>
    request<ClientePedidoDetalhe>(`/api/v1/cliente/pedidos/${encodeURIComponent(bostamp)}`),
  criarPedido: (idempotencyKey: string, linhas: { linhaOrd: number; ref: string; qtt: number; cor?: string }[]) =>
    request<{
      alreadyExists: boolean
      bostamp: string
      obrano: number
      boano: number
      etotaldeb: number
    }>('/api/v1/cliente/pedidos', {
      method: 'POST',
      headers: { 'Idempotency-Key': idempotencyKey },
      body: JSON.stringify({ linhas }),
    }),
  cancelar: (bostamp: string) =>
    request<{ mensagem: string }>(`/api/v1/cliente/pedidos/${encodeURIComponent(bostamp)}/cancelar`, {
      method: 'POST',
    }),
}
