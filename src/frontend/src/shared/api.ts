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
    throw new Error(
      'API indisponível. Confirme que o backend está a correr em http://localhost:5080.',
    )
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

export type Utilizador = { login: string; nome: string; isAdmin: boolean }

export type AdminUtilizador = {
  userstamp: string
  login: string
  nome: string
  usrinis: string
  email: string
  usaPort: boolean
  temContaIdentity: boolean
  temPassword: boolean
  isAdmin: boolean
}

export type ActivarAcessoResponse = {
  email: string
  login: string
  definirPasswordUrl: string
  token: string
}

export type PrevisaoEntradaListaItem = {
  id: string
  dataInicio: string
  dataFim: string
  fechada: boolean
  fechadaEm: string | null
  fechadaPor: string | null
  totalLinhas: number
  quantidadeTotal: number
}

export type PrevisaoEntradaLinha = {
  id: string
  ref: string
  cor: string
  design: string
  quantidadePrevista: number
  quantidadeAlocada: number
  quantidadeDisponivel: number
}

export type PrevisaoEntradaDetalhe = {
  id: string
  dataInicio: string
  dataFim: string
  fechada: boolean
  fechadaEm: string | null
  fechadaPor: string | null
  linhas: PrevisaoEntradaLinha[]
}

export type PrevisaoArtigoSugestao = {
  ref: string
  design: string
}

export type EncomendaListaItem = {
  boStamp: string
  numeroEncomenda: number
  /** Nº do dossier (ndos 66/65). */
  numeroDossier?: number | null
  /** Nº dossier picking (ndos=66) na cadeia documental. */
  numeroPicking?: number | null
  /** Nº dossier separação/expedição (ndos=65) na cadeia documental. */
  numeroSeparacao?: number | null
  /** Nome da série do dossier (nmdos). */
  nomeDossier?: string | null
  clienteNo: number
  clienteNome: string
  /** BO.nome2 — nome principal (PR5). */
  clienteNome2?: string | null
  data: string
  hora: string
  totalLinhas: number
  quantidadeTotal: number
  quantidadePorSatisfazer: number
  /** SUM(BI.qtt) — quantidade do documento (Separado / ndos=66). */
  quantidadeDocumento?: number
  /** SUM(BI.qtt2) — já expedida (Separado). */
  quantidadeExpedida?: number
  /** SUM(BI.qtt − BI.qtt2) — pendente de entrega (Separado). */
  quantidadePendenteEntrega?: number
  estado: string
  estadoPlaneamento: string
  estadoPlaneamentoCodigo: string
  prontaPicking: boolean
  prontaPickingPor: string | null
  prontaPickingEm: string | null
  pickStatus: number
  urgente: boolean
  /** Check-in (BO3.u_chkin) — dossiers ndos=66. */
  checkIn?: boolean
  checkInPor?: string | null
  checkInEm?: string | null
  /** BO3.TAXPOINTDT — data de entrega (ISO / null). */
  dataEntrega?: string | null
  /** BO3.u_modExp — método de expedição (PHC). */
  metodoExpedicao?: string | null
  /** BO2.u_mEntrega — morada de entrega (texto corrido; null se vazio). */
  moradaEntrega?: string | null
  /** REGRA B: existe quantidade materializada em ndos=66 (SUM qtt > 0). */
  temQtt66?: boolean
}

/** «Nome Nº» do dossier (ex.: «Picking #2»), ou «—». */
export function labelDossier(e: {
  numeroDossier?: number | null
  nomeDossier?: string | null
}): string {
  const n = e.numeroDossier
  const nome = e.nomeDossier?.trim()
  if (n == null && !nome) return '—'
  if (nome && n != null) return `${nome} #${n}`
  if (n != null) return `#${n}`
  return nome ?? '—'
}

/** Cadeia Encomenda → Picking → Separação (só níveis disponíveis). */
export function caminhoDocumentos(e: {
  numeroEncomenda: number
  numeroPicking?: number | null
  numeroSeparacao?: number | null
}): { label: string; n: number }[] {
  const rows: { label: string; n: number }[] = [
    { label: 'Encomenda', n: e.numeroEncomenda },
  ]
  if (e.numeroPicking != null && e.numeroPicking > 0) {
    rows.push({ label: 'Picking', n: e.numeroPicking })
  }
  if (e.numeroSeparacao != null && e.numeroSeparacao > 0) {
    rows.push({ label: 'Separação', n: e.numeroSeparacao })
  }
  return rows
}

export type EncomendaListaResponse = {
  page: number
  pageSize: number
  total: number
  items: EncomendaListaItem[]
}

export type CorteEncomendaItem = {
  boStamp: string
  numeroEncomenda: number
  numeroDossier?: number | null
  nomeDossier?: string | null
  data: string
  hora: string
  clienteNo: number
  clienteNome: string
  clienteNome2?: string | null
  totalLinhas: number
  quantidadeDocumento: number
  quantidadeExpedida: number
  quantidadePendenteEntrega: number
  fechada: boolean
  urgente: boolean
  estado: string
}

export type CorteQuantidadeLinha = {
  biStamp: string
  boStamp: string
  ref: string
  descricao: string
  cor: string
  unidade: string
  quantidadeDocumento: number
  quantidadeExpedida: number
  quantidadePendenteEntrega: number
}

export type CortesQuantidadeResponse = {
  page: number
  pageSize: number
  total: number
  items: CorteEncomendaItem[]
}

/** Linha pendente de picagem (fonte de verdade = backend). */
export type PendentePicagemLinha = {
  boStamp: string
  biStamp: string
  numeroEncomenda: number
  clienteNo: number
  clienteNome: string
  clienteNome2?: string | null
  ref: string
  designacao: string
  cor: string
  qtt: number
  qtt2: number
  sum66: number
  picked: number
  pending: number
  fonte: string
  dataEntrega?: string | null
  metodoExpedicao?: string | null
}

export type PendentePicagemEncomendaItem = {
  boStamp: string
  numeroEncomenda: number
  clienteNo: number
  clienteNome: string
  clienteNome2?: string | null
  dataEntrega?: string | null
  metodoExpedicao?: string | null
  quantidadePendenteTotal: number
  totalLinhasPendentes: number
  linhas: PendentePicagemLinha[]
}

export type PendentePicagemEncomendaLista = {
  page: number
  pageSize: number
  totalItems: number
  items: PendentePicagemEncomendaItem[]
}

export type PendentePicagemDocumentoRef = {
  boStamp: string
  numeroEncomenda: number
  clienteNo: number
  clienteNome: string
  clienteNome2?: string | null
  quantidadePendente: number
}

export type PendentePicagemReferenciaItem = {
  ref: string
  designacao: string
  quantidadePendenteTotal: number
  totalLinhasPendentes: number
  totalDocumentos: number
  documentos: PendentePicagemDocumentoRef[]
}

export type PendentePicagemReferenciaLista = {
  page: number
  pageSize: number
  totalItems: number
  items: PendentePicagemReferenciaItem[]
}

export type PendentesPicagemFiltroParams = {
  dataDe?: string
  dataAte?: string
  obrano?: number
  artigoRef?: string
  artigoCor?: string
  clienteNomeContem?: string
  page?: number
  pageSize?: number
}

export type ArtigoSugestao = {
  ref: string
  design: string
  cor: string
}

export type ArtigoProcuraItem = {
  ref: string
  descricao: string
  cor: string
  quantidadeEncomendada: number
  quantidadeFornecida: number
  quantidadePorSatisfazer: number
  quantidadeDisponivel: number
  quantidadeAutorizadaTotal: number
  totalLinhas: number
  totalEncomendas: number
  estadoPlaneamento: string
  estadoPlaneamentoCodigo: string
  urgente: boolean
}

export type ArtigoProcuraResponse = {
  items: ArtigoProcuraItem[]
  page: number
  pageSize: number
  totalItems: number
}

export type ArtigoEncomendaAbertaItem = {
  boStamp: string
  biStamp: string
  numeroEncomenda: number
  clienteNo: number
  clienteNome: string
  /** BO.nome2 — nome principal (PR5). */
  clienteNome2?: string | null
  data: string
  hora: string
  estadoPlaneamento: string
  estadoPlaneamentoCodigo: string
  ref: string
  descricao: string
  cor: string
  unidade: string
  quantidade: number
  quantidadeOriginalPortal: number
  qtt: number
  qtt2: number
  quantidadePorSatisfazer: number
  precoUnitario: number
  precoUnitarioOriginal: number
  quantidadeAutorizada: number
  autorizadaPor: string | null
  autorizadaEm: string | null
  stockDisponivel: number
  usrinis: string | null
  usrdata: string | null
  usrhora: string | null
  urgente: boolean
  /** BO3.TAXPOINTDT — data de entrega (ISO / null). */
  dataEntrega?: string | null
  /** BO3.u_modExp — método de expedição (PHC). */
  metodoExpedicao?: string | null
}

export type ArtigoEncomendasAbertasResponse = {
  ref: string
  cor: string | null
  descricao: string
  quantidadeDisponivel: number
  encomendas: ArtigoEncomendaAbertaItem[]
}

export type AlocacaoLinha = {
  biStamp: string
  boStamp: string
  numeroEncomenda: number
  quantidadePorSatisfazer: number
  quantidadeProposta: number
}

export type AlocarArtigoResponse = {
  ref: string
  stockDisponivel: number
  quantidadeDisponivel: number
  fonteStock: string
  simular: boolean
  somaProposta: number
  alocacoes: AlocacaoLinha[]
}

export type EncomendaLinha = {
  biStamp: string
  ref: string
  descricao: string
  cor: string
  unidade: string
  quantidade: number
  quantidadeOriginalPortal: number
  qtt: number
  qtt2: number
  quantidadePorSatisfazer: number
  precoUnitario: number
  precoUnitarioOriginal: number
  quantidadeAutorizada: number
  autorizadaPor: string | null
  autorizadaEm: string | null
  stockDisponivel: number
  /** STOBS.u_dispPort — false = artigo fora do universo Portal. */
  disponivelNoPortal?: boolean
  usrinis: string | null
  usrdata: string | null
  usrhora: string | null
}

export type QuantidadeAutorizadaAtualizada = {
  biStamp: string
  quantidadeAutorizada: number
  autorizadaPor: string | null
  autorizadaEm: string | null
  quantidade: number
  quantidadeOriginalPortal: number
  quantidadePorSatisfazer: number
  primeiraAutorizacao: boolean
}

export type LinhaAtualizada = {
  biStamp: string
  quantidade: number
  quantidadeOriginalPortal: number
  precoUnitario: number
  precoUnitarioOriginal: number
  usrinis: string | null
  usrdata: string | null
  usrhora: string | null
}

export type EncomendaDetalhe = {
  boStamp: string
  numeroEncomenda: number
  serie: number
  nomeSerie: string
  clienteNo: number
  clienteEstab: number
  clienteNome: string
  /** BO.nome2 — nome principal (PR5). */
  clienteNome2?: string | null
  data: string
  hora: string
  estadoPlaneamento: string
  estadoPlaneamentoCodigo: string
  prontaPicking: boolean
  prontaPickingPor: string | null
  prontaPickingEm: string | null
  pickStatus: number
  urgente: boolean
  /** BO3.TAXPOINTDT — data de entrega (ISO / null). */
  dataEntrega?: string | null
  /** BO3.u_modExp — método de expedição (PHC). */
  metodoExpedicao?: string | null
  /** BO2.u_mEntrega — morada de entrega (texto corrido; null se vazio). */
  moradaEntrega?: string | null
  linhas: EncomendaLinha[]
  /** REGRA B: existe quantidade materializada em ndos=66 (SUM qtt > 0). */
  temQtt66?: boolean
}

/** Read-model Kapps (GET .../picking-kapps). Campos em camelCase como na API. */
export type KappsPickingLinha = {
  pickingLineKey: string
  article: string
  description: string
  quantity: number
  /** Quantidade originalmente pedida (só informativa). */
  quantityOriginal: number
  quantitySatisfied: number
  quantityPending: number
  quantityPicked: number
  baseUnit: string
  busyUnit: string
  conversionFator: number
  warehouse: number
  pickingKey: string
  originalLineNumber: number
  location: string | null
  lot: string | null
  allowReplacement: number
  linObs: string | null
  hasReservedQty: number
}

export type KappsPickingDetalhe = {
  pickingKey: string
  number: number
  customerName: string
  date: string | null
  customer: string
  document: string
  documentName: string
  exr: string | null
  sec: string | null
  tpd: string | null
  ndc: number | null
  deliveryCustomer: string | null
  deliveryCode: string | null
  barcode: string | null
  allowNewProduct: number
  useSDR: number
  /** Terminal Kapps activo (se houver). */
  activeTerminalId: number | null
  activeTerminalLabel: string | null
  /** UserID Kapps na última actividade. */
  activeUserId: string | null
  lines: KappsPickingLinha[]
}

export type ProntaPickingAtualizada = {
  boStamp: string
  prontaPicking: boolean
  prontaPickingPor: string | null
  prontaPickingEm: string | null
  pickStatus: number
}

export type PickWorkflowAtualizada = {
  boStamp: string
  prontaPicking: boolean
  pickStatus: number
  prontaPickingPor: string | null
  prontaPickingEm: string | null
}

export type FechoPickingAtualizada = {
  boStamp: string
  fechada: boolean
  numeroEncomenda: number
  ndos: number
}

export type CheckInAtualizada = {
  boStamp: string
  checkIn: boolean
  checkInPor: string | null
  checkInEm: string | null
  numeroDossier: number
  ndos: number
}

export type CheckInLoteItem = {
  boStamp: string
  ok: boolean
  erro: string | null
  resultado: CheckInAtualizada | null
}

export type CheckInLoteResponse = {
  total: number
  sucesso: number
  falha: number
  resultados: CheckInLoteItem[]
}

export type PainelKpis = {
  encomendasEmAberto: number
  encomendasAposCorte: number
  artigosEmRutura: number
  quantidadePorSatisfazer: number
  quantidadeAutorizada: number
  clientesAfetados: number
}

export type EstadoDistribuicaoLogica = {
  quantidade: number
  percentagem: number
}

export type DistribuicaoLogica = {
  totalEncomendasLogicas: number
  emAberto: EstadoDistribuicaoLogica
  emPicking: EstadoDistribuicaoLogica
  separado: EstadoDistribuicaoLogica
  emEntrega: EstadoDistribuicaoLogica
  emExpedicao: EstadoDistribuicaoLogica
  naoClassificadas: number
}

export type CentroEstadosKpis = {
  emAberto: number
  emPicking: number
  expedicao: number
  separado: number
  emEntrega: number
  expedido: number
  concluidas: number
  total: number
  distribuicaoLogica: DistribuicaoLogica
}

/** Resumo Kapps magro da Vista TV (GET /painel/tv-kapps-resumo). */
export type TvKappsResumoItem = {
  boStamp: string
  origem: 'encomenda' | 'dossier66' | string
  qty: number
  picked: number
  pending: number
  kind: 'espera' | 'curso' | 'concluido' | string
  pct: number
  activeTerminalId: number | null
  activeTerminalLabel: string | null
  activeUserId: string | null
}

export type TvKappsResumo = {
  items: TvKappsResumoItem[]
}

function pendentesPicagemQuery(params?: PendentesPicagemFiltroParams): string {
  const q = new URLSearchParams()
  if (params?.dataDe) q.set('dataDe', params.dataDe)
  if (params?.dataAte) q.set('dataAte', params.dataAte)
  if (params?.obrano != null) q.set('obrano', String(params.obrano))
  if (params?.artigoRef) q.set('artigoRef', params.artigoRef)
  if (params?.artigoCor) q.set('artigoCor', params.artigoCor)
  if (params?.clienteNomeContem) q.set('clienteNomeContem', params.clienteNomeContem)
  if (params?.page) q.set('page', String(params.page))
  if (params?.pageSize) q.set('pageSize', String(params.pageSize))
  return q.toString()
}

export const api = {
  login: (login: string, password: string) =>
    request<{ utilizador: Utilizador }>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ login, password }),
    }),
  logout: () => request<void>('/api/v1/auth/logout', { method: 'POST' }),
  me: () => request<{ login: string; nome: string; isAdmin: boolean }>('/api/v1/auth/me'),
  definirPassword: (email: string, token: string, password: string, confirmPassword: string) =>
    request<void>('/api/v1/auth/definir-password', {
      method: 'POST',
      body: JSON.stringify({ email, token, password, confirmPassword }),
    }),
  adminUtilizadores: () => request<AdminUtilizador[]>('/api/v1/admin/utilizadores'),
  activarAcesso: (email: string) =>
    request<ActivarAcessoResponse>('/api/v1/admin/utilizadores/acesso', {
      method: 'POST',
      body: JSON.stringify({ email }),
    }),
  revogarAcesso: (email: string) =>
    request<void>('/api/v1/admin/utilizadores/revogar', {
      method: 'POST',
      body: JSON.stringify({ email }),
    }),
  reenviarConvite: (email: string) =>
    request<ActivarAcessoResponse>('/api/v1/admin/utilizadores/reenviar-convite', {
      method: 'POST',
      body: JSON.stringify({ email }),
    }),
  resetPassword: (email: string) =>
    request<ActivarAcessoResponse>('/api/v1/admin/utilizadores/reset-password', {
      method: 'POST',
      body: JSON.stringify({ email }),
    }),
  atribuirAdmin: (email: string) =>
    request<void>('/api/v1/admin/utilizadores/admin', {
      method: 'POST',
      body: JSON.stringify({ email }),
    }),
  removerAdmin: (email: string) =>
    request<void>('/api/v1/admin/utilizadores/admin', {
      method: 'DELETE',
      body: JSON.stringify({ email }),
    }),
  previsoesEntradaListar: () =>
    request<PrevisaoEntradaListaItem[]>('/api/v1/previsoes-entrada'),
  previsoesEntradaObter: (id: string) =>
    request<PrevisaoEntradaDetalhe>(`/api/v1/previsoes-entrada/${encodeURIComponent(id)}`),
  previsoesEntradaCriar: (body: { dataInicio: string; dataFim: string }) =>
    request<PrevisaoEntradaDetalhe>('/api/v1/previsoes-entrada', {
      method: 'POST',
      body: JSON.stringify(body),
    }),
  previsoesEntradaGuardar: (
    id: string,
    body: {
      dataInicio: string
      dataFim: string
      linhas: { ref: string; cor: string; quantidadePrevista: number }[]
    },
  ) =>
    request<PrevisaoEntradaDetalhe>(
      `/api/v1/previsoes-entrada/${encodeURIComponent(id)}`,
      {
        method: 'PUT',
        body: JSON.stringify(body),
      },
    ),
  previsoesEntradaSugestoes: (q: string, limit = 20) => {
    const params = new URLSearchParams({ q, limit: String(limit) })
    return request<PrevisaoArtigoSugestao[]>(
      `/api/v1/previsoes-entrada/artigos/sugestoes?${params}`,
    )
  },
  previsoesEntradaSugestoesCores: (artigoRef: string, q = '', limit = 30) => {
    const params = new URLSearchParams({
      artigoRef,
      limit: String(limit),
    })
    if (q) params.set('q', q)
    return request<{ cor: string }[]>(
      `/api/v1/previsoes-entrada/cores/sugestoes?${params}`,
    )
  },
  previsoesEntradaFechar: (id: string) =>
    request<PrevisaoEntradaDetalhe>(
      `/api/v1/previsoes-entrada/${encodeURIComponent(id)}/fechar`,
      { method: 'POST' },
    ),
  previsoesEntradaAtualizarLinhas: (id: string) =>
    request<{ detalhe: PrevisaoEntradaDetalhe; linhasAdicionadas: number }>(
      `/api/v1/previsoes-entrada/${encodeURIComponent(id)}/atualizar-linhas`,
      { method: 'POST' },
    ),
  encomendasAbertas: (params?: {
    dataDe?: string
    dataAte?: string
    horaDe?: string
    horaAte?: string
    clienteNo?: number
    clienteNoContem?: string
    artigoRef?: string
    artigoCor?: string
    estadoPlaneamento?: string
    metodoExpedicao?: string
    prontaPicking?: boolean
    pickStatus?: number
    page?: number
    pageSize?: number
  }) => {
    const q = new URLSearchParams()
    if (params?.dataDe) q.set('dataDe', params.dataDe)
    if (params?.dataAte) q.set('dataAte', params.dataAte)
    if (params?.horaDe) q.set('horaDe', params.horaDe)
    if (params?.horaAte) q.set('horaAte', params.horaAte)
    if (params?.clienteNo != null) q.set('clienteNo', String(params.clienteNo))
    if (params?.clienteNoContem) q.set('clienteNoContem', params.clienteNoContem)
    if (params?.artigoRef) q.set('artigoRef', params.artigoRef)
    if (params?.artigoCor) q.set('artigoCor', params.artigoCor)
    if (params?.estadoPlaneamento) q.set('estadoPlaneamento', params.estadoPlaneamento)
    if (params?.metodoExpedicao) q.set('metodoExpedicao', params.metodoExpedicao)
    if (params?.prontaPicking != null) {
      q.set('prontaPicking', params.prontaPicking ? 'true' : 'false')
    }
    if (params?.pickStatus != null) q.set('pickStatus', String(params.pickStatus))
    if (params?.page) q.set('page', String(params.page))
    if (params?.pageSize) q.set('pageSize', String(params.pageSize))
    const qs = q.toString()
    return request<EncomendaListaResponse>(
      `/api/v1/encomendas/abertas${qs ? `?${qs}` : ''}`,
    )
  },
  cortesQuantidade: (params?: {
    dataDe?: string
    dataAte?: string
    obrano?: number
    artigoRef?: string
    artigoCor?: string
    page?: number
    pageSize?: number
  }) => {
    const q = new URLSearchParams()
    if (params?.dataDe) q.set('dataDe', params.dataDe)
    if (params?.dataAte) q.set('dataAte', params.dataAte)
    if (params?.obrano != null) q.set('obrano', String(params.obrano))
    if (params?.artigoRef) q.set('artigoRef', params.artigoRef)
    if (params?.artigoCor) q.set('artigoCor', params.artigoCor)
    if (params?.page) q.set('page', String(params.page))
    if (params?.pageSize) q.set('pageSize', String(params.pageSize))
    const qs = q.toString()
    return request<CortesQuantidadeResponse>(
      `/api/v1/cortes-quantidade${qs ? `?${qs}` : ''}`,
    )
  },
  cortesQuantidadeLinhas: (
    boStamp: string,
    params?: { artigoRef?: string; artigoCor?: string },
  ) => {
    const q = new URLSearchParams()
    if (params?.artigoRef) q.set('artigoRef', params.artigoRef)
    if (params?.artigoCor) q.set('artigoCor', params.artigoCor)
    const qs = q.toString()
    return request<CorteQuantidadeLinha[]>(
      `/api/v1/cortes-quantidade/${encodeURIComponent(boStamp)}/linhas${qs ? `?${qs}` : ''}`,
    )
  },
  /** Quantidades pendentes de picagem — agrupado por encomenda (padrão 1A). */
  pendentesPicagem: (params?: PendentesPicagemFiltroParams) => {
    const q = pendentesPicagemQuery(params)
    return request<PendentePicagemEncomendaLista>(
      `/api/v1/pendentes-picagem${q ? `?${q}` : ''}`,
    )
  },
  /** Quantidades pendentes de picagem — agrupado por referência. */
  pendentesPicagemPorReferencia: (params?: PendentesPicagemFiltroParams) => {
    const q = pendentesPicagemQuery(params)
    return request<PendentePicagemReferenciaLista>(
      `/api/v1/pendentes-picagem/por-referencia${q ? `?${q}` : ''}`,
    )
  },
  pendentesPicagemLinhas: (boStamp: string) =>
    request<PendentePicagemLinha[]>(
      `/api/v1/pendentes-picagem/${encodeURIComponent(boStamp)}/linhas`,
    ),
  encomendaDetalhe: (boStamp: string) =>
    request<EncomendaDetalhe>(`/api/v1/encomendas/${encodeURIComponent(boStamp)}`),
  /**
   * Picking Kapps associado à encomenda (só leitura).
   * 200 → dados; 204 → null (ainda sem picking); outros erros → throw.
   */
  encomendaPickingKapps: async (boStamp: string): Promise<KappsPickingDetalhe | null> => {
    const data = await request<KappsPickingDetalhe | undefined>(
      `/api/v1/encomendas/${encodeURIComponent(boStamp)}/picking-kapps`,
    )
    return data ?? null
  },
  marcarUrgente: (boStamp: string, urgente: boolean) =>
    request<{ boStamp: string; urgente: boolean }>(
      `/api/v1/encomendas/${encodeURIComponent(boStamp)}/urgente`,
      {
        method: 'PATCH',
        body: JSON.stringify({ urgente }),
      },
    ),
  cancelarEncomenda: (boStamp: string, motivo: string) =>
    request<{ boStamp: string; fechada: boolean; numeroEncomenda: number; motivo: string | null }>(
      `/api/v1/encomendas/${encodeURIComponent(boStamp)}/cancelar`,
      {
        method: 'POST',
        body: JSON.stringify({ motivo }),
      },
    ),
  marcarProntaPicking: (
    boStamp: string,
    pronta: boolean,
    opts?: { confirmarLinhasSemAutorizacao?: boolean; motivo?: string },
  ) =>
    request<ProntaPickingAtualizada>(
      `/api/v1/encomendas/${encodeURIComponent(boStamp)}/pronta-picking`,
      {
        method: 'PATCH',
        body: JSON.stringify({
          pronta,
          confirmarLinhasSemAutorizacao: opts?.confirmarLinhasSemAutorizacao ?? false,
          motivo: opts?.motivo ?? null,
        }),
      },
    ),
  pickingStart: (boStamp: string) =>
    request<PickWorkflowAtualizada>(
      `/api/v1/picking/${encodeURIComponent(boStamp)}/start`,
      { method: 'POST' },
    ),
  pickingComplete: (boStamp: string) =>
    request<PickWorkflowAtualizada>(
      `/api/v1/picking/${encodeURIComponent(boStamp)}/complete`,
      { method: 'POST' },
    ),
  pickingCancel: (boStamp: string, motivo: string) =>
    request<PickWorkflowAtualizada>(
      `/api/v1/picking/${encodeURIComponent(boStamp)}/cancel`,
      {
        method: 'POST',
        body: JSON.stringify({ motivo }),
      },
    ),
  pickingReady: (boStamp: string) =>
    request<PickWorkflowAtualizada>(
      `/api/v1/picking/${encodeURIComponent(boStamp)}/ready`,
      { method: 'POST' },
    ),
  pickingReopen: (boStamp: string) =>
    request<PickWorkflowAtualizada>(
      `/api/v1/picking/${encodeURIComponent(boStamp)}/reopen`,
      { method: 'POST' },
    ),
  pickingDossiers: (params?: {
    fechada?: boolean
    dataDe?: string
    dataAte?: string
    horaDe?: string
    horaAte?: string
    clienteNoContem?: string
    clienteNomeContem?: string
    artigoRef?: string
    artigoCor?: string
    estadoPlaneamento?: string
    metodoExpedicao?: string
    pickStatus?: number
    checkIn?: boolean
    page?: number
    pageSize?: number
  }) => {
    const q = new URLSearchParams()
    if (params?.fechada != null) q.set('fechada', params.fechada ? 'true' : 'false')
    if (params?.dataDe) q.set('dataDe', params.dataDe)
    if (params?.dataAte) q.set('dataAte', params.dataAte)
    if (params?.horaDe) q.set('horaDe', params.horaDe)
    if (params?.horaAte) q.set('horaAte', params.horaAte)
    if (params?.clienteNoContem) q.set('clienteNoContem', params.clienteNoContem)
    if (params?.clienteNomeContem) q.set('clienteNomeContem', params.clienteNomeContem)
    if (params?.artigoRef) q.set('artigoRef', params.artigoRef)
    if (params?.artigoCor) q.set('artigoCor', params.artigoCor)
    if (params?.estadoPlaneamento) q.set('estadoPlaneamento', params.estadoPlaneamento)
    if (params?.metodoExpedicao) q.set('metodoExpedicao', params.metodoExpedicao)
    if (params?.pickStatus != null) q.set('pickStatus', String(params.pickStatus))
    if (params?.checkIn != null) q.set('checkIn', params.checkIn ? 'true' : 'false')
    if (params?.page) q.set('page', String(params.page))
    if (params?.pageSize) q.set('pageSize', String(params.pageSize))
    const qs = q.toString()
    return request<EncomendaListaResponse>(`/api/v1/picking-dossiers${qs ? `?${qs}` : ''}`)
  },
  pickingDossierLinhas: (boStamp: string) =>
    request<EncomendaLinha[]>(
      `/api/v1/picking-dossiers/${encodeURIComponent(boStamp)}/linhas`,
    ),
  /**
   * Dossiers de separação ndos=65 (só leitura).
   */
  separacaoDossiers: (params?: {
    fechada?: boolean
    dataDe?: string
    dataAte?: string
    horaDe?: string
    horaAte?: string
    clienteNoContem?: string
    artigoRef?: string
    artigoCor?: string
    estadoPlaneamento?: string
    metodoExpedicao?: string
    page?: number
    pageSize?: number
  }) => {
    const q = new URLSearchParams()
    if (params?.fechada != null) q.set('fechada', params.fechada ? 'true' : 'false')
    if (params?.dataDe) q.set('dataDe', params.dataDe)
    if (params?.dataAte) q.set('dataAte', params.dataAte)
    if (params?.horaDe) q.set('horaDe', params.horaDe)
    if (params?.horaAte) q.set('horaAte', params.horaAte)
    if (params?.clienteNoContem) q.set('clienteNoContem', params.clienteNoContem)
    if (params?.artigoRef) q.set('artigoRef', params.artigoRef)
    if (params?.artigoCor) q.set('artigoCor', params.artigoCor)
    if (params?.estadoPlaneamento) q.set('estadoPlaneamento', params.estadoPlaneamento)
    if (params?.metodoExpedicao) q.set('metodoExpedicao', params.metodoExpedicao)
    if (params?.page) q.set('page', String(params.page))
    if (params?.pageSize) q.set('pageSize', String(params.pageSize))
    const qs = q.toString()
    return request<EncomendaListaResponse>(`/api/v1/separacao-dossiers${qs ? `?${qs}` : ''}`)
  },
  separacaoDossierLinhas: (boStamp: string) =>
    request<EncomendaLinha[]>(
      `/api/v1/separacao-dossiers/${encodeURIComponent(boStamp)}/linhas`,
    ),
  /**
   * Picking Kapps associado ao dossier ndos=66 (só leitura).
   * PickingKey = bostamp do dossier. 200 → dados; 204 → null.
   */
  pickingDossierPickingKapps: async (boStamp: string): Promise<KappsPickingDetalhe | null> => {
    const data = await request<KappsPickingDetalhe | undefined>(
      `/api/v1/picking-dossiers/${encodeURIComponent(boStamp)}/picking-kapps`,
    )
    return data ?? null
  },
  marcarFechoPickingDossier: (boStamp: string, fechada: boolean) =>
    request<FechoPickingAtualizada>(
      `/api/v1/picking-dossiers/${encodeURIComponent(boStamp)}/fechada`,
      {
        method: 'PATCH',
        body: JSON.stringify({ fechada }),
      },
    ),
  /** Fecha / reabre expedição ndos=65 (Em Expedição ↔ Concluídas). */
  marcarFechoSeparacaoDossier: (boStamp: string, fechada: boolean) =>
    request<FechoPickingAtualizada>(
      `/api/v1/separacao-dossiers/${encodeURIComponent(boStamp)}/fechada`,
      {
        method: 'PATCH',
        body: JSON.stringify({ fechada }),
      },
    ),
  marcarCheckIn: (boStamps: string[]) =>
    request<CheckInLoteResponse>('/api/v1/picking-dossiers/check-in', {
      method: 'POST',
      body: JSON.stringify({ boStamps }),
    }),
  reverterCheckIn: (boStamp: string) =>
    request<CheckInAtualizada>(
      `/api/v1/picking-dossiers/${encodeURIComponent(boStamp)}/reverter-check-in`,
      { method: 'POST' },
    ),
  atualizarQuantidadeAutorizada: (
    biStamp: string,
    body: {
      quantidadeAutorizada: number
      valorAnteriorEsperado?: number
      permitirAcimaStock?: boolean
    },
  ) =>
    request<QuantidadeAutorizadaAtualizada>(
      `/api/v1/encomendas/linhas/${encodeURIComponent(biStamp)}/quantidade-autorizada`,
      {
        method: 'PATCH',
        body: JSON.stringify(body),
      },
    ),
  atualizarLinha: (
    biStamp: string,
    body: {
      quantidade?: number
      precoUnitario?: number
      quantidadeAnteriorEsperada?: number
      precoAnteriorEsperado?: number
    },
  ) =>
    request<LinhaAtualizada>(`/api/v1/encomendas/linhas/${encodeURIComponent(biStamp)}`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),
  artigoSugestoes: (q: string, limit = 20) => {
    const params = new URLSearchParams({ q, limit: String(limit) })
    return request<ArtigoSugestao[]>(`/api/v1/artigos/sugestoes?${params}`)
  },
  corSugestoes: (q: string, limit = 20) => {
    const params = new URLSearchParams({ q, limit: String(limit) })
    return request<string[]>(`/api/v1/artigos/sugestoes-cor?${params}`)
  },
  artigosProcuraAberta: (params?: {
    estadoPlaneamento?: string
    q?: string
    cor?: string
    dataDe?: string
    dataAte?: string
    horaDe?: string
    horaAte?: string
    clienteNoContem?: string
    metodoExpedicao?: string
    page?: number
    pageSize?: number
  }) => {
    const q = new URLSearchParams()
    if (params?.estadoPlaneamento) q.set('estadoPlaneamento', params.estadoPlaneamento)
    if (params?.q) q.set('q', params.q)
    if (params?.cor) q.set('cor', params.cor)
    if (params?.dataDe) q.set('dataDe', params.dataDe)
    if (params?.dataAte) q.set('dataAte', params.dataAte)
    if (params?.horaDe) q.set('horaDe', params.horaDe)
    if (params?.horaAte) q.set('horaAte', params.horaAte)
    if (params?.clienteNoContem) q.set('clienteNoContem', params.clienteNoContem)
    if (params?.metodoExpedicao) q.set('metodoExpedicao', params.metodoExpedicao)
    if (params?.page != null) q.set('page', String(params.page))
    if (params?.pageSize != null) q.set('pageSize', String(params.pageSize))
    const qs = q.toString()
    return request<ArtigoProcuraResponse>(`/api/v1/artigos/procura-aberta${qs ? `?${qs}` : ''}`)
  },
  artigoEncomendasAbertas: (
    ref: string,
    params?: { cor?: string; estadoPlaneamento?: string },
  ) => {
    const q = new URLSearchParams()
    // Sempre enviar cor (mesmo vazia) para filtrar exacto no expand
    if (params && 'cor' in params) q.set('cor', params.cor ?? '')
    if (params?.estadoPlaneamento) q.set('estadoPlaneamento', params.estadoPlaneamento)
    const qs = q.toString()
    return request<ArtigoEncomendasAbertasResponse>(
      `/api/v1/artigos/${encodeURIComponent(ref)}/encomendas-abertas${qs ? `?${qs}` : ''}`,
    )
  },
  alocarArtigo: (
    ref: string,
    body: { quantidadeDisponivel?: number; cor?: string; modo?: string; confirmar?: boolean },
  ) =>
    request<AlocarArtigoResponse>(`/api/v1/artigos/${encodeURIComponent(ref)}/alocar`, {
      method: 'POST',
      body: JSON.stringify({
        modo: 'Proporcional',
        confirmar: true,
        ...body,
      }),
    }),
  previsualizarAlocacao: (
    ref: string,
    body: { quantidadeDisponivel?: number; cor?: string; modo?: string },
  ) =>
    request<AlocarArtigoResponse>(
      `/api/v1/artigos/${encodeURIComponent(ref)}/alocar/previsualizar`,
      {
        method: 'POST',
        body: JSON.stringify({
          modo: 'Proporcional',
          ...body,
        }),
      },
    ),
  painelKpis: () => request<PainelKpis>('/api/v1/painel/kpis'),
  centroEstados: () => request<CentroEstadosKpis>('/api/v1/painel/centro-estados'),
  /** Resumo Kapps para Vista TV — 1 pedido em vez de N+1 detalhe. */
  tvKappsResumo: () => request<TvKappsResumo>('/api/v1/painel/tv-kapps-resumo'),
}
