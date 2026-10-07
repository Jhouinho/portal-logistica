export type TabId = 'geral' | 'separacao' | 'expedicao'

export type EstadoSeparacao = 'EM_SEPARACAO' | 'PENDENTE'
export type EstadoLevantamento =
  | 'CLIENTE_CHEGOU'
  | 'AGUARDA_CLIENTE'
  | 'AGUARDA_OPERADOR'
  | 'EM_ENTREGA'

export type LinhaSeparacao = {
  id: string
  encomenda: string
  cliente: string
  linhasFeitas: number
  linhasTotal: number
  zona: string
  operador: string | null
  estado: EstadoSeparacao
  progresso: number
  limite: string
  urgente: boolean
}

export type LinhaLevantamento = {
  id: string
  encomenda: string
  cliente: string
  volumes: number
  local: string
  prontaDesde: string
  chegadaCliente: string | null
  estado: EstadoLevantamento
  operador: string | null
}

export type CentroMock = {
  armazem: string
  kpisSeparacao: {
    activas: number
    prontas: number
    urgentes: number
    operadoresActivos: number
  }
  kpisGeral: {
    emSeparacao: number
    prontas: number
    aguardamCliente: number
    clienteChegou: number
  }
  kpisExpedicao: {
    prontasLevantamento: number
    aguardamCliente: number
    clienteChegou: number
    emEntrega: number
  }
  separacoes: LinhaSeparacao[]
  levantamentos: LinhaLevantamento[]
}

export const centroMock: CentroMock = {
  armazem: 'ARMAZÉM PRINCIPAL — INFORMAÇÃO OPERACIONAL',
  kpisSeparacao: {
    activas: 14,
    prontas: 22,
    urgentes: 2,
    operadoresActivos: 4,
  },
  kpisGeral: {
    emSeparacao: 14,
    prontas: 22,
    aguardamCliente: 3,
    clienteChegou: 2,
  },
  kpisExpedicao: {
    prontasLevantamento: 5,
    aguardamCliente: 3,
    clienteChegou: 2,
    emEntrega: 1,
  },
  separacoes: [
    {
      id: '1',
      encomenda: 'EC-10490',
      cliente: 'Cliente Centro',
      linhasFeitas: 22,
      linhasTotal: 31,
      zona: 'Picking B',
      operador: 'João Silva',
      estado: 'EM_SEPARACAO',
      progresso: 71,
      limite: '13:00',
      urgente: true,
    },
    {
      id: '2',
      encomenda: 'EC-10488',
      cliente: 'Cliente Norte',
      linhasFeitas: 18,
      linhasTotal: 24,
      zona: 'Picking A',
      operador: 'Carlos Costa',
      estado: 'EM_SEPARACAO',
      progresso: 75,
      limite: '13:30',
      urgente: false,
    },
    {
      id: '3',
      encomenda: 'EC-10485',
      cliente: 'Cliente Sul',
      linhasFeitas: 2,
      linhasTotal: 19,
      zona: 'À espera',
      operador: null,
      estado: 'PENDENTE',
      progresso: 8,
      limite: '14:00',
      urgente: false,
    },
    {
      id: '4',
      encomenda: 'EC-10483',
      cliente: 'Cliente Oeste',
      linhasFeitas: 11,
      linhasTotal: 16,
      zona: 'Picking C',
      operador: 'Maria Lopes',
      estado: 'EM_SEPARACAO',
      progresso: 69,
      limite: '14:00',
      urgente: false,
    },
    {
      id: '5',
      encomenda: 'EC-10479',
      cliente: 'Cliente Este',
      linhasFeitas: 9,
      linhasTotal: 14,
      zona: 'Picking A',
      operador: 'Rui Ferreira',
      estado: 'EM_SEPARACAO',
      progresso: 64,
      limite: '14:30',
      urgente: true,
    },
  ],
  levantamentos: [
    {
      id: 'l1',
      encomenda: 'EC-10482',
      cliente: 'Cliente Norte',
      volumes: 8,
      local: 'Zona E1',
      prontaDesde: '10:42',
      chegadaCliente: '11:58',
      estado: 'CLIENTE_CHEGOU',
      operador: 'Miguel Rocha',
    },
    {
      id: 'l2',
      encomenda: 'EC-10475',
      cliente: 'Cliente Centro',
      volumes: 5,
      local: 'Zona E2',
      prontaDesde: '11:05',
      chegadaCliente: null,
      estado: 'AGUARDA_CLIENTE',
      operador: null,
    },
    {
      id: 'l3',
      encomenda: 'EC-10471',
      cliente: 'Cliente Sul',
      volumes: 12,
      local: 'Zona E1',
      prontaDesde: '11:20',
      chegadaCliente: '12:10',
      estado: 'AGUARDA_OPERADOR',
      operador: null,
    },
    {
      id: 'l4',
      encomenda: 'EC-10468',
      cliente: 'Cliente Oeste',
      volumes: 3,
      local: 'Zona E3',
      prontaDesde: '11:45',
      chegadaCliente: null,
      estado: 'AGUARDA_CLIENTE',
      operador: null,
    },
    {
      id: 'l5',
      encomenda: 'EC-10460',
      cliente: 'Cliente Este',
      volumes: 6,
      local: 'Zona E2',
      prontaDesde: '09:50',
      chegadaCliente: '10:15',
      estado: 'EM_ENTREGA',
      operador: 'Sofia Lima',
    },
  ],
}

/** Agregados para a vista TV (overview de estado) — mock alinhado aos 4 cards do Geral. */
export function tvEstadoResumo(m: CentroMock = centroMock) {
  const emAberto = m.kpisSeparacao.activas
  const emPicking = m.kpisGeral.emSeparacao
  const expedicao = m.kpisExpedicao.prontasLevantamento
  const concluidas = m.kpisGeral.prontas
  const total = emAberto + emPicking + expedicao + concluidas
  const pct = (v: number) => (total <= 0 ? 0 : Math.round((100 * v) / total))
  return [
    {
      key: 'abertas',
      label: 'Em aberto',
      value: emAberto,
      percent: pct(emAberto),
      tone: 'warning' as const,
    },
    {
      key: 'picking',
      label: 'Em Picking',
      value: emPicking,
      percent: pct(emPicking),
      tone: 'info' as const,
    },
    {
      key: 'expedicao',
      label: 'Em Separação',
      value: expedicao,
      percent: pct(expedicao),
      tone: 'error' as const,
    },
    {
      key: 'concluidas',
      label: 'Concluídas',
      value: concluidas,
      percent: pct(concluidas),
      tone: 'success' as const,
    },
  ]
}
