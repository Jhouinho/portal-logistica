import { Fragment, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Checkbox,
  CircularProgress,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  IconButton,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
  MenuItem,
} from '@mui/material'
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown'
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp'
import CheckIcon from '@mui/icons-material/Check'
import CloseIcon from '@mui/icons-material/Close'
import PriorityHighIcon from '@mui/icons-material/PriorityHigh'
import WarningAmberIcon from '@mui/icons-material/WarningAmber'
import {
  api,
  caminhoDocumentos,
  labelDossier,
  type ArtigoSugestao,
  type EncomendaLinha,
  type EncomendaListaItem,
  type KappsPickingDetalhe,
} from '../../shared/api'
import { kappsMapFromTvResumo } from '../../shared/tvKappsResumo'
import { labels } from '../../shared/i18n/labels'
import { fmtMoney, fmtDocNo, fmtDate, fmtMetodoExpedicao } from '../../shared/format'
import { ClienteNomeDisplay } from '../../shared/ui/ClienteNomeDisplay'
import { DossierInfoButton } from '../../shared/ui/DossierInfoButton'
import { DateFilterField } from '../../shared/ui/DateFilterField'
import { TimeFilterField } from '../../shared/ui/TimeFilterField'
import { UrgenteBadge, ProgressBar } from '../centro/centroUi'
import {
  StatusBadge,
  estadoSemantic,
  portalActionBtnSx,
  portalColHeaderSx,
  portalPanelSx,
  portalPrimaryCtaSx,
  PortalEmptyState,
  PortalTableScroll,
  urgenteRowSx,
} from '../centro/portalChrome'
import {
  QuantidadeAutorizadaCell,
  stockDisponivelComSugestao,
  totalLinhaAutorizada,
} from './QuantidadeAutorizadaCell'
import { LinhaPrecoCell } from './LinhaPrecoCell'
import { GravacaoSnackbar, type GravacaoSnack } from './GravacaoSnackbar'
import { KappsPickingPanel } from './KappsPickingPanel'
import { encomendasTableSx, LinhasColGroup, linhasTableSx } from './linhasTableLayout'
import { useEncomendasFiltrosUrl } from './useEncomendasFiltrosUrl'
import { prepararAutorizacoesAntesPicking } from './persistirAutorizacoesAoCriarPicking'
import { kappsTotais } from './kappsProgresso'
import { useOperacoesHub } from '../../shared/signalr'
import {
  useEncomendasAbertasListaQuery,
  useInvalidateEncomendasAbertasLista,
} from '../../shared/encomendasQuery'
import {
  useDossiers65ListaQuery,
  useDossiers66ListaQuery,
  useInvalidateDossiers65Lista,
  useInvalidateDossiers66Lista,
} from '../../shared/dossiersQuery'
import { FILTRO_METODO_OPCOES } from '../../shared/metodoExpedicaoFiltro'

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

/** Expedição parcial no dossier 66: já expediu e ainda há pendente (BI.qtt / BI.qtt2). */
function isEntregaParcialDossier(e: {
  quantidadeExpedida?: number
  quantidadePendenteEntrega?: number
}): boolean {
  return (e.quantidadeExpedida ?? 0) > 0 && (e.quantidadePendenteEntrega ?? 0) > 0
}

function fmtPickingMeta(por: string | null | undefined, em: string | null | undefined): string {
  const parts: string[] = []
  if (por?.trim()) parts.push(por.trim())
  if (em) {
    const d = new Date(em)
    if (!Number.isNaN(d.getTime())) {
      parts.push(
        d.toLocaleString('pt-PT', {
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        }),
      )
    }
  }
  return parts.join(' · ')
}

function dayBefore(yyyyMmDd: string): string | null {
  const [yRaw, mRaw, dRaw] = yyyyMmDd.split('-')
  const y = Number(yRaw)
  const m = Number(mRaw)
  const d = Number(dRaw)
  if (!Number.isInteger(y) || !Number.isInteger(m) || !Number.isInteger(d)) return null
  const date = new Date(y, m - 1, d)
  if (Number.isNaN(date.getTime())) return null
  date.setDate(date.getDate() - 1)
  const yy = date.getFullYear()
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  const dd = String(date.getDate()).padStart(2, '0')
  return `${yy}-${mm}-${dd}`
}

function chipPlaneamento(codigo: string, compact = false) {
  const apos = codigo === 'AC'
  const full = apos ? labels.aposCorte : labels.dentroPlaneamento
  if (apos) {
    return (
      <Tooltip title={full} arrow>
        <Box
          component="span"
          display="inline-flex"
          alignItems="center"
          justifyContent="center"
          aria-label={full}
          sx={{ color: estadoSemantic.atrasado.color, lineHeight: 0 }}
        >
          <WarningAmberIcon sx={{ fontSize: 20 }} />
        </Box>
      </Tooltip>
    )
  }
  const short = labels.limiteCurtoDentro
  return (
    <Tooltip title={full} arrow>
      <span>
        <StatusBadge tone="emCurso" label={compact ? short : full} />
      </span>
    </Tooltip>
  )
}

function chipPickStatus(pickStatus: number | undefined, modoSeparacao = false) {
  const status = pickStatus ?? 0
  // Em Separação: u_pickstat 0 trata-se como «Em espera» (igual ao legado do picking).
  if (status === 1 || (modoSeparacao && status === 0)) {
    return <StatusBadge tone="pendente" label={labels.pickStatusReady} />
  }
  if (status === 2) {
    return <StatusBadge tone="emCurso" label={labels.pickStatusInProgress} />
  }
  if (status === 3) {
    return <StatusBadge tone="concluido" label={labels.pickStatusCompleted} />
  }
  return <StatusBadge tone="pendente" label={labels.pickStatusOpen} />
}

const statusCellSx = {
  py: 0.5,
  verticalAlign: 'middle',
  height: 52,
  boxSizing: 'border-box' as const,
}

/** Indicador visual Kapps (só leitura). Não altera pickStatus. */
function EstadoPickingComKapps({
  pickStatus,
  kapps,
  modoSeparacao = false,
}: {
  pickStatus: number | undefined
  /** undefined = ainda não pedido; null = 204 */
  kapps: KappsPickingDetalhe | null | undefined
  modoSeparacao?: boolean
}) {
  // Separado (ndos=66, sem check-in): badges operacionais — sem ProgressBar.
  // A Preparar Entrega usa o mesmo ramo Kapps que Em Picking (barra %).
  if (modoSeparacao) {
    const pendente = kapps ? kappsTotais(kapps).pendente : 0
    const recolhaPendente = pendente > 0
    return (
      <Box display="flex" alignItems="center" height="100%">
        <StatusBadge
          tone={recolhaPendente ? 'pendente' : 'emCurso'}
          label={
            recolhaPendente
              ? labels.estadoSeparadoRecolhaPendente
              : labels.estadoSeparado
          }
        />
      </Box>
    )
  }

  if (kapps) {
    const { total, recolhido, concluido, emCurso } = kappsTotais(kapps)

    if (concluido) {
      return (
        <Box display="flex" alignItems="center" height="100%">
          <StatusBadge tone="concluido" label={labels.pickStatusCompleted} />
        </Box>
      )
    }

    if (emCurso) {
      const pct = Math.max(0, Math.min(100, Math.round((recolhido / total) * 100)))
      return (
        <Box
          minWidth={148}
          maxWidth={200}
          display="flex"
          alignItems="center"
          height="100%"
        >
          <ProgressBar
            value={pct}
            color={estadoSemantic.emCurso.color}
            label={labels.pickingKappsRecolhidas
              .replace('{picked}', fmt(recolhido))
              .replace('{total}', fmt(total))}
          />
        </Box>
      )
    }
  }

  // 204, sem Kapps, ou sem progresso → badge actual (Em espera), mesma altura
  return (
    <Box display="flex" alignItems="center" height="100%">
      {chipPickStatus(pickStatus, modoSeparacao)}
    </Box>
  )
}

/** Picking já iniciado no Kapps (ou pickStatus em curso) — não permitir Cancelar. */
function pickingEmAndamento(
  pickStatus: number | undefined,
  kapps: KappsPickingDetalhe | null | undefined,
): boolean {
  if (pickStatus === 2) return true
  const { emCurso } = kappsTotais(kapps)
  return emCurso
}

/** Ainda sem picagem — permite alterar quantidades em Em Picking. */
function pickingAindaNaoIniciado(
  pickStatus: number | undefined,
  kapps: KappsPickingDetalhe | null | undefined,
): boolean {
  if (pickStatus === 2 || pickStatus === 3) return false
  if (kapps === undefined) return false // ainda a carregar
  if (kapps === null) return true // sem Kapps = sem picagem
  const { recolhido, concluido } = kappsTotais(kapps)
  return !concluido && recolhido <= 0
}

function labelSugestao(a: ArtigoSugestao): string {
  return [a.ref.trim(), a.design.trim()].filter(Boolean).join(' · ')
}

function linhaCorrespondeFiltros(
  l: EncomendaLinha,
  artigo: string,
  cor: string,
): boolean {
  const a = artigo.trim().toLowerCase()
  const c = cor.trim().toLowerCase()
  if (a && !(l.ref.toLowerCase().includes(a) || l.descricao.toLowerCase().includes(a))) {
    return false
  }
  if (c && !(l.cor ?? '').toLowerCase().includes(c)) {
    return false
  }
  return true
}

const pageSize = 200

export function EncomendasListPage({
  hideHeader = false,
  modoPicking = false,
  modoDossier,
  accentColor,
}: {
  hideHeader?: boolean
  /** Lista de prontas para picking (linhas só leitura; permite cancelar). */
  modoPicking?: boolean
  /** Dossiers: expedição/concluídas (ndos 66), em entrega (66+check-in) ou separação (ndos 65). */
  modoDossier?: 'expedicao' | 'concluidas' | 'separacao' | 'emEntrega'
  /** Cor da etapa (menu / header). */
  accentColor?: string
}) {
  // Picking (modoPicking=true) deve permitir editar os mesmos campos que em Encomendas.
  // Dossiers (modoDossier) ficam em modo consulta (readOnly).
  const soConsulta = !!modoDossier
  /**
   * Em Separação — um só filtro:
   * todos/espera/curso → ndos 66; separados → ndos 65.
   */
  const [filtroSeparacao, setFiltroSeparacao] = useState<
    'todos' | 'espera' | 'curso' | 'separados'
  >('todos')
  const jaSeparados =
    (modoDossier === 'expedicao' && filtroSeparacao === 'separados') ||
    modoDossier === 'separacao'
  const emEntrega = modoDossier === 'emEntrega'
  const emPicagem66 = (modoDossier === 'expedicao' && !jaSeparados) || emEntrega
  /** Separado (ndos=66 sem check-in) — quantidades de expedição + badge. */
  const modoSeparado66 = modoDossier === 'expedicao' && !jaSeparados
  /** Em Expedição (abertos) ou Concluídas (fechados) — dossiers ndos=65. */
  const modoSeparacaoDossier = jaSeparados || modoDossier === 'concluidas'
  /** Separado (ndos=66): sem coluna Acção. Em Expedição (65) tem Fechar. */
  const semAccao = modoDossier === 'expedicao'
  /** Encomendas ndos=1 (e Em Picking): urgente editável; dossiers só leitura. */
  const podeEditarUrgente = !modoDossier
  const mostraEstadoOperacional = modoPicking || emPicagem66
  /** Em Picking (ndos=1) ou Em Separação ndos=66: progresso Kapps. */
  const modoKapps = modoPicking || emPicagem66
  /** Coluna/ⓘ Entrega (`dataEntrega` ← BO3.TAXPOINTDT) em ndos=1 (Encomendas + Em Picking).
   * Dossiers 66/65: DTO sem dataEntrega — não mostrar (sem SQL novo). */
  const mostraEntrega = !modoDossier
  /** POC1/POC2: lista Encomendas ou Picking via TanStack Query. */
  const modoListaEncomendas = !modoPicking && !modoDossier
  const modoListaAbertasQuery = modoListaEncomendas || modoPicking
  /** POC3: listas dossiers 65/66 via TanStack Query. */
  const modoListaDossierQuery = !!modoDossier
  const invalidateEncomendasAbertasLista = useInvalidateEncomendasAbertasLista()
  const invalidateDossiers66Lista = useInvalidateDossiers66Lista()
  const invalidateDossiers65Lista = useInvalidateDossiers65Lista()
  /**
   * Residual POC1–3: já não alimenta loaders de lista (Encomendas/Picking/dossiers).
   * Mantido para não remover infra global sem consumidores futuros claros.
   */
  const [listaRefreshTick, setListaRefreshTick] = useState(0)
  const refreshSilenciosoRef = useRef(false)
  const pedirRefreshLista = useCallback(() => {
    refreshSilenciosoRef.current = true
    setListaRefreshTick((n) => n + 1)
  }, [])
  /**
   * POC2/POC3: kappsAlterado → tick Kapps (não refresh da lista Query).
   * Picking e dossier 66 (emPicagem66).
   */
  const [kappsRefreshTick, setKappsRefreshTick] = useState(0)
  const pedirRefreshKapps = useCallback(() => {
    setKappsRefreshTick((n) => n + 1)
  }, [])
  /** Vista Expedição a mostrar ndos=65 (Já separados) — não invalidar 66. */
  const vistaExpedicaoSeparados65 =
    modoDossier === 'expedicao' && jaSeparados
  useOperacoesHub(true, {
    onEncomendaAlterada: modoListaAbertasQuery
      ? () => void invalidateEncomendasAbertasLista()
      : undefined,
    onDossier66Alterado:
      modoPicking ||
      modoDossier === 'emEntrega' ||
      (modoDossier === 'expedicao' && !jaSeparados)
        ? () => {
            // Dossiers 66 (Separado / Em Entrega): comportamento existente.
            if (
              modoDossier === 'emEntrega' ||
              (modoDossier === 'expedicao' && !jaSeparados)
            ) {
              void invalidateDossiers66Lista()
            }
            // /picking: SUM(66) pode retirar a encomenda da lista — refetch abertas.
            if (modoPicking) {
              void invalidateEncomendasAbertasLista()
            }
          }
        : undefined,
    onDossier65Alterado:
      modoDossier === 'separacao' ||
      modoDossier === 'concluidas' ||
      vistaExpedicaoSeparados65
        ? () => void invalidateDossiers65Lista()
        : undefined,
    onKappsAlterado: modoKapps ? pedirRefreshKapps : undefined,
  })
  const colCount =
    7 +
    (mostraEntrega ? 1 : 0) +
    1 + // método de expedição (PR6)
    (mostraEstadoOperacional ? 1 : 0) +
    (semAccao ? 0 : 1)
  const [items, setItems] = useState<EncomendaListaItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [erroGravacao, setErroGravacao] = useState<GravacaoSnack | null>(null)
  const [confirmarPicking, setConfirmarPicking] = useState<{
    item: EncomendaListaItem
    acao: 'marcar' | 'reverter'
  } | null>(null)
  const [motivoCancelamento, setMotivoCancelamento] = useState('')
  const [confirmarLinhasZero, setConfirmarLinhasZero] = useState<EncomendaListaItem | null>(null)
  const [confirmarFecho, setConfirmarFecho] = useState<{
    item: EncomendaListaItem
    fechar: boolean
  } | null>(null)
  const [confirmarReverterCheckIn, setConfirmarReverterCheckIn] =
    useState<EncomendaListaItem | null>(null)
  const [confirmarCancelarEncomenda, setConfirmarCancelarEncomenda] =
    useState<EncomendaListaItem | null>(null)

  const {
    dataDe,
    setDataDe,
    dataAte,
    setDataAte,
    horaDe,
    setHoraDe,
    horaAte,
    setHoraAte,
    clienteNo,
    setClienteNo,
    clienteDebounced,
    artigoInput,
    setArtigoInput,
    artigoDebounced,
    corInput,
    setCorInput,
    corDebounced,
    estado,
    setEstado,
    pickStatus,
    setPickStatus,
    metodoExpedicao,
    setMetodoExpedicao,
    temFiltroArtigo,
  } = useEncomendasFiltrosUrl()

  const [sugestoes, setSugestoes] = useState<ArtigoSugestao[]>([])
  const [loadingSugestoes, setLoadingSugestoes] = useState(false)
  const [sugestoesCor, setSugestoesCor] = useState<string[]>([])
  const [loadingSugestoesCor, setLoadingSugestoesCor] = useState(false)
  const [page, setPage] = useState(1)
  const [expandedStamps, setExpandedStamps] = useState<Set<string>>(() => new Set())
  const [linhasByStamp, setLinhasByStamp] = useState<Record<string, EncomendaLinha[]>>({})
  /** Quantidades autorizadas no servidor (baseline para rascunho). */
  const [servidorAutByStamp, setServidorAutByStamp] = useState<
    Record<string, Record<string, number>>
  >({})
  const [rascunhoByStamp, setRascunhoByStamp] = useState<Record<string, boolean>>({})
  const [gravandoAutByStamp, setGravandoAutByStamp] = useState<Record<string, boolean>>({})
  const [loadingLinhas, setLoadingLinhas] = useState<Record<string, boolean>>({})
  const [erroLinhas, setErroLinhas] = useState<Record<string, string>>({})
  /** Cache Kapps: chave presente = já pedido; valor null = 204. */
  const [kappsByStamp, setKappsByStamp] = useState<Record<string, KappsPickingDetalhe | null>>({})
  const [loadingKapps, setLoadingKapps] = useState<Record<string, boolean>>({})
  const [erroKapps, setErroKapps] = useState<Record<string, string>>({})
  const [savingPicking, setSavingPicking] = useState<Record<string, boolean>>({})
  const [savingUrgente, setSavingUrgente] = useState<Record<string, boolean>>({})
  const [anterioresPorTratar, setAnterioresPorTratar] = useState<number | null>(null)
  const [anterioresPorTratarDetalhe, setAnterioresPorTratarDetalhe] = useState<EncomendaListaItem[]>(
    [],
  )
  const [mostrarDetalheAtraso, setMostrarDetalheAtraso] = useState(false)

  useEffect(() => {
    setPage(1)
  }, [
    dataDe,
    dataAte,
    horaDe,
    horaAte,
    clienteDebounced,
    artigoDebounced,
    corDebounced,
    estado,
    pickStatus,
    filtroSeparacao,
  ])

  useEffect(() => {
    let cancel = false
    if (artigoDebounced.length < 1) {
      setSugestoes([])
      setLoadingSugestoes(false)
      return
    }
    setLoadingSugestoes(true)
    api
      .artigoSugestoes(artigoDebounced, 20)
      .then((rows) => {
        if (!cancel) setSugestoes(rows)
      })
      .catch(() => {
        if (!cancel) setSugestoes([])
      })
      .finally(() => {
        if (!cancel) setLoadingSugestoes(false)
      })
    return () => {
      cancel = true
    }
  }, [artigoDebounced])

  useEffect(() => {
    let cancel = false
    if (corDebounced.length < 1) {
      setSugestoesCor([])
      setLoadingSugestoesCor(false)
      return
    }
    setLoadingSugestoesCor(true)
    api
      .corSugestoes(corDebounced, 20)
      .then((rows) => {
        if (!cancel) setSugestoesCor(rows)
      })
      .catch(() => {
        if (!cancel) setSugestoesCor([])
      })
      .finally(() => {
        if (!cancel) setLoadingSugestoesCor(false)
      })
    return () => {
      cancel = true
    }
  }, [corDebounced])

  const query = useMemo(() => {
    const pickStatusNum = (() => {
      if (modoPicking && pickStatus !== 'Todos') {
        const n = Number(pickStatus)
        return Number.isNaN(n) ? undefined : n
      }
      if (emPicagem66) {
        if (filtroSeparacao === 'espera') return 1
        if (filtroSeparacao === 'curso') return 2
        return undefined
      }
      return undefined
    })()
    const q: {
      dataDe?: string
      dataAte?: string
      horaDe?: string
      horaAte?: string
      clienteNoContem?: string
      artigoRef?: string
      artigoCor?: string
      estadoPlaneamento?: string
      metodoExpedicao?: string
      prontaPicking?: boolean
      pickStatus?: number
      fechada?: boolean
      page: number
      pageSize: number
    } = {
      page,
      pageSize,
      ...(modoSeparacaoDossier
        ? { fechada: modoDossier === 'concluidas' }
        : modoDossier
          ? { fechada: false }
          : { prontaPicking: modoPicking }),
    }

    if (dataDe) q.dataDe = dataDe
    if (dataAte) q.dataAte = dataAte
    if (horaDe) q.horaDe = horaDe
    if (horaAte) q.horaAte = horaAte
    if (clienteDebounced) q.clienteNoContem = clienteDebounced
    if (artigoDebounced) q.artigoRef = artigoDebounced
    if (corDebounced) q.artigoCor = corDebounced
    if (estado !== 'Todos') q.estadoPlaneamento = estado
    if (metodoExpedicao && metodoExpedicao !== 'todos') q.metodoExpedicao = metodoExpedicao
    if (pickStatusNum != null) q.pickStatus = pickStatusNum
    return q
  }, [
    dataDe,
    dataAte,
    horaDe,
    horaAte,
    clienteDebounced,
    artigoDebounced,
    corDebounced,
    estado,
    metodoExpedicao,
    pickStatus,
    modoPicking,
    modoDossier,
    modoSeparacaoDossier,
    emPicagem66,
    filtroSeparacao,
    page,
  ])

  const encomendasAbertasQuery = useEncomendasAbertasListaQuery(
    {
      dataDe: query.dataDe,
      dataAte: query.dataAte,
      horaDe: query.horaDe,
      horaAte: query.horaAte,
      clienteNoContem: query.clienteNoContem,
      artigoRef: query.artigoRef,
      artigoCor: query.artigoCor,
      estadoPlaneamento: query.estadoPlaneamento,
      metodoExpedicao: query.metodoExpedicao,
      prontaPicking: modoPicking,
      pickStatus: query.pickStatus,
      page: query.page,
      pageSize: query.pageSize,
    },
    { enabled: modoListaAbertasQuery },
  )

  const dossiers66Params = {
    fechada: query.fechada,
    checkIn: emEntrega ? true : emPicagem66 ? false : undefined,
    dataDe: query.dataDe,
    dataAte: query.dataAte,
    horaDe: query.horaDe,
    horaAte: query.horaAte,
    clienteNoContem: query.clienteNoContem,
    artigoRef: query.artigoRef,
    artigoCor: query.artigoCor,
    estadoPlaneamento: query.estadoPlaneamento,
    metodoExpedicao: query.metodoExpedicao,
    pickStatus: query.pickStatus,
    page: query.page,
    pageSize: query.pageSize,
  }

  const dossiers65Params = {
    fechada: query.fechada,
    dataDe: query.dataDe,
    dataAte: query.dataAte,
    horaDe: query.horaDe,
    horaAte: query.horaAte,
    clienteNoContem: query.clienteNoContem,
    artigoRef: query.artigoRef,
    artigoCor: query.artigoCor,
    estadoPlaneamento: query.estadoPlaneamento,
    metodoExpedicao: query.metodoExpedicao,
    page: query.page,
    pageSize: query.pageSize,
  }

  const dossiers66Query = useDossiers66ListaQuery(dossiers66Params, {
    enabled: modoListaDossierQuery && !modoSeparacaoDossier,
  })
  const dossiers65Query = useDossiers65ListaQuery(dossiers65Params, {
    enabled: modoListaDossierQuery && modoSeparacaoDossier,
  })

  // POC1/POC2: sincronizar server state da query → estado local (mutations usam setItems).
  useEffect(() => {
    if (!modoListaAbertasQuery) return
    if (encomendasAbertasQuery.data) {
      const res = encomendasAbertasQuery.data
      // Defesa em UI: Picking = só marcadas; Encomendas = só por marcar.
      const filtered = modoPicking
        ? res.items.filter((i) => i.prontaPicking === true)
        : res.items.filter((i) => i.prontaPicking !== true)
      setItems(filtered)
      setTotal(
        filtered.length === res.items.length
          ? res.total
          : Math.max(0, res.total - (res.items.length - filtered.length)),
      )
    }
    // Spinner só no 1.º load; refetch SignalR (isFetching) mantém-se silencioso.
    setLoading(encomendasAbertasQuery.isLoading)
    if (encomendasAbertasQuery.isError && !encomendasAbertasQuery.data) {
      const err = encomendasAbertasQuery.error
      setErro(err instanceof Error ? err.message : labels.erroGenerico)
    } else if (encomendasAbertasQuery.data) {
      setErro(null)
    }
  }, [
    modoListaAbertasQuery,
    modoPicking,
    encomendasAbertasQuery.data,
    encomendasAbertasQuery.isLoading,
    encomendasAbertasQuery.isError,
    encomendasAbertasQuery.error,
  ])

  // POC3: bridge dossiers 65/66 → items/total/loading/erro (mutations usam setItems).
  useEffect(() => {
    if (!modoListaDossierQuery) return
    const active = modoSeparacaoDossier ? dossiers65Query : dossiers66Query
    if (active.data) {
      setItems(active.data.items)
      setTotal(active.data.total)
    }
    setLoading(active.isLoading)
    if (active.isError && !active.data) {
      const err = active.error
      setErro(err instanceof Error ? err.message : labels.erroGenerico)
    } else if (active.data) {
      setErro(null)
    }
  }, [
    modoListaDossierQuery,
    modoSeparacaoDossier,
    dossiers65Query.data,
    dossiers65Query.isLoading,
    dossiers65Query.isError,
    dossiers65Query.error,
    dossiers66Query.data,
    dossiers66Query.isLoading,
    dossiers66Query.isError,
    dossiers66Query.error,
  ])

  // Residual: listaRefreshTick / pedirRefreshLista já não disparam GETs de lista (POC1–3).
  void listaRefreshTick
  void pedirRefreshLista
  void refreshSilenciosoRef

  useEffect(() => {
    let cancel = false
    if (modoPicking || modoDossier || !dataDe) {
      setAnterioresPorTratar(null)
      setAnterioresPorTratarDetalhe([])
      setMostrarDetalheAtraso(false)
      return () => {
        cancel = true
      }
    }

    const dataAte = dayBefore(dataDe)
    if (!dataAte) {
      setAnterioresPorTratar(null)
      setAnterioresPorTratarDetalhe([])
      setMostrarDetalheAtraso(false)
      return () => {
        cancel = true
      }
    }

    api
      .encomendasAbertas({
        prontaPicking: false,
        dataAte,
        page: 1,
        pageSize: 8,
      })
      .then((res) => {
        if (cancel) return
        setAnterioresPorTratar(res.total)
        setAnterioresPorTratarDetalhe(res.items)
        setMostrarDetalheAtraso(false)
      })
      .catch(() => {
        if (cancel) return
        setAnterioresPorTratar(null)
        setAnterioresPorTratarDetalhe([])
        setMostrarDetalheAtraso(false)
      })

    return () => {
      cancel = true
    }
  }, [dataDe, modoPicking, modoDossier])

  // Em Picking / Separado: 1× tv-kapps-resumo (mesmo batch da TV) em vez de N+1 detalhe.
  // Expand continua a pedir picking-kapps completo (linhas) sob pedido.
  useEffect(() => {
    if (!modoKapps || items.length === 0) return
    let cancel = false
    const pendentes = items.filter((i) =>
      modoPicking ? i.prontaPicking === true : true,
    )
    if (pendentes.length === 0) return

    const stamps = new Set(pendentes.map((i) => i.boStamp))
    setLoadingKapps((prev) => {
      const next = { ...prev }
      for (const s of stamps) next[s] = true
      return next
    })

    void (async () => {
      try {
        const resumo = await api.tvKappsResumo()
        if (cancel) return
        const origem = modoPicking ? 'encomenda' : 'dossier66'
        const map = kappsMapFromTvResumo(resumo.items, origem)
        setKappsByStamp((prev) => {
          const next = { ...prev }
          for (const stamp of stamps) {
            next[stamp] = stamp in map ? map[stamp] : null
          }
          return next
        })
        setErroKapps((prev) => {
          let changed = false
          const next = { ...prev }
          for (const stamp of stamps) {
            if (stamp in next) {
              delete next[stamp]
              changed = true
            }
          }
          return changed ? next : prev
        })
      } catch {
        if (cancel) return
        setErroKapps((prev) => {
          const next = { ...prev }
          for (const stamp of stamps) next[stamp] = labels.pickingKappsErro
          return next
        })
      } finally {
        if (!cancel) {
          setLoadingKapps((prev) => {
            const next = { ...prev }
            for (const stamp of stamps) delete next[stamp]
            return next
          })
        }
      }
    })()

    return () => {
      cancel = true
    }
    // Refetch quando a página de items muda, ou kappsAlterado (tick dedicado no Picking).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [modoKapps, modoPicking, items, kappsRefreshTick])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  function onEstadoChange(value: string) {
    setEstado(value)
    setPage(1)
  }

  function onPickStatusChange(value: string) {
    setPickStatus(value)
    setPage(1)
  }

  function onMetodoExpedicaoChange(value: string) {
    setMetodoExpedicao(value)
    setPage(1)
  }

  async function carregarLinhas(boStamp: string) {
    setLoadingLinhas((prev) => ({ ...prev, [boStamp]: true }))
    setErroLinhas((prev) => {
      const next = { ...prev }
      delete next[boStamp]
      return next
    })
    try {
      const linhas = modoSeparacaoDossier
        ? await api.separacaoDossierLinhas(boStamp)
        : modoDossier
          ? await api.pickingDossierLinhas(boStamp)
          : (await api.encomendaDetalhe(boStamp)).linhas
      setLinhasByStamp((prev) => ({ ...prev, [boStamp]: linhas }))
      const baseline: Record<string, number> = {}
      for (const l of linhas) baseline[l.biStamp] = l.quantidadeAutorizada
      setServidorAutByStamp((prev) => ({ ...prev, [boStamp]: baseline }))
      setRascunhoByStamp((prev) => {
        const next = { ...prev }
        delete next[boStamp]
        return next
      })
    } catch (e) {
      setErroLinhas((prev) => ({
        ...prev,
        [boStamp]: e instanceof Error ? e.message : 'Erro ao carregar linhas.',
      }))
    } finally {
      setLoadingLinhas((prev) => {
        const next = { ...prev }
        delete next[boStamp]
        return next
      })
    }
  }

  function patchLinhaAutDraft(boStamp: string, next: EncomendaLinha) {
    setLinhasByStamp((prev) => {
      const cur = prev[boStamp]
      if (!cur) return prev
      const updated = cur.map((x) => (x.biStamp === next.biStamp ? next : x))
      const baseline = servidorAutByStamp[boStamp] ?? {}
      const dirty = updated.some(
        (l) => (baseline[l.biStamp] ?? 0) !== l.quantidadeAutorizada,
      )
      setRascunhoByStamp((r) => {
        if (!dirty) {
          const n = { ...r }
          delete n[boStamp]
          return n
        }
        return { ...r, [boStamp]: true }
      })
      return { ...prev, [boStamp]: updated }
    })
  }

  async function gravarAutorizadasEncomenda(boStamp: string) {
    const linhas = linhasByStamp[boStamp] ?? []
    const baseline = servidorAutByStamp[boStamp] ?? {}
    const aGravar = linhas.filter(
      (l) => (baseline[l.biStamp] ?? 0) !== l.quantidadeAutorizada,
    )
    if (aGravar.length === 0) {
      setRascunhoByStamp((prev) => {
        const n = { ...prev }
        delete n[boStamp]
        return n
      })
      return
    }

    setGravandoAutByStamp((prev) => ({ ...prev, [boStamp]: true }))
    try {
      const nextBaseline = { ...baseline }
      let updatedLinhas = [...linhas]
      for (const l of aGravar) {
        const res = await api.atualizarQuantidadeAutorizada(l.biStamp, {
          quantidadeAutorizada: l.quantidadeAutorizada,
          valorAnteriorEsperado: baseline[l.biStamp] ?? l.quantidadeAutorizada,
          permitirAcimaStock: false,
        })
        nextBaseline[l.biStamp] = res.quantidadeAutorizada
        updatedLinhas = updatedLinhas.map((x) =>
          x.biStamp === l.biStamp
            ? {
                ...x,
                quantidadeAutorizada: res.quantidadeAutorizada,
                autorizadaPor: res.autorizadaPor,
                autorizadaEm: res.autorizadaEm,
                quantidade: res.quantidade,
                qtt: res.quantidade,
                quantidadeOriginalPortal: res.quantidadeOriginalPortal,
                quantidadePorSatisfazer: res.quantidadePorSatisfazer,
                stockDisponivel:
                  x.stockDisponivel +
                  (baseline[l.biStamp] ?? l.quantidadeAutorizada) -
                  res.quantidadeAutorizada,
              }
            : x,
        )
      }
      setLinhasByStamp((prev) => ({ ...prev, [boStamp]: updatedLinhas }))
      setServidorAutByStamp((prev) => ({ ...prev, [boStamp]: nextBaseline }))
      setRascunhoByStamp((prev) => {
        const n = { ...prev }
        delete n[boStamp]
        return n
      })
      setErroGravacao({ message: labels.alocacaoOk, severity: 'success' })
    } catch (e) {
      setErroGravacao({
        message: e instanceof Error ? e.message : labels.erroGenerico,
        severity: 'error',
      })
      await carregarLinhas(boStamp)
    } finally {
      setGravandoAutByStamp((prev) => {
        const n = { ...prev }
        delete n[boStamp]
        return n
      })
    }
  }

  async function descartarRascunhoAutorizadas(boStamp: string) {
    await carregarLinhas(boStamp)
    setErroGravacao({ message: 'Alterações descartadas.', severity: 'info' })
  }

  async function carregarKapps(boStamp: string) {
    setLoadingKapps((prev) => ({ ...prev, [boStamp]: true }))
    setErroKapps((prev) => {
      const next = { ...prev }
      delete next[boStamp]
      return next
    })
    try {
      const detalhe = modoPicking
        ? await api.encomendaPickingKapps(boStamp)
        : await api.pickingDossierPickingKapps(boStamp)
      setKappsByStamp((prev) => ({ ...prev, [boStamp]: detalhe }))
    } catch {
      setErroKapps((prev) => ({
        ...prev,
        [boStamp]: labels.pickingKappsErro,
      }))
    } finally {
      setLoadingKapps((prev) => {
        const next = { ...prev }
        delete next[boStamp]
        return next
      })
    }
  }

  function toggleExpand(boStamp: string) {
    const aAbrir = !expandedStamps.has(boStamp)
    setExpandedStamps((prev) => {
      const next = new Set(prev)
      if (next.has(boStamp)) next.delete(boStamp)
      else next.add(boStamp)
      return next
    })
    if (!aAbrir) return

    if (modoKapps) {
      const item = items.find((x) => x.boStamp === boStamp)
      const elegivel = modoPicking ? item?.prontaPicking === true : true
      // Resumo lista não traz linhas reais — expand pede sempre o detalhe completo.
      if (elegivel && !loadingKapps[boStamp]) {
        void carregarKapps(boStamp)
      }
      return
    }

    if (!linhasByStamp[boStamp] && !loadingLinhas[boStamp]) {
      void carregarLinhas(boStamp)
    }
  }

  async function toggleUrgente(e: EncomendaListaItem) {
    const next = !e.urgente
    setSavingUrgente((prev) => ({ ...prev, [e.boStamp]: true }))
    try {
      const result = await api.marcarUrgente(e.boStamp, next)
      setItems((prev) => {
        const mapped = prev.map((x) =>
          x.boStamp === e.boStamp ? { ...x, urgente: result.urgente } : x,
        )
        return [...mapped].sort((a, b) => {
          if (a.urgente !== b.urgente) return a.urgente ? -1 : 1
          return a.numeroEncomenda - b.numeroEncomenda
        })
      })
      setErroGravacao({ message: labels.urgenteOk, severity: 'success' })
    } catch (err) {
      setErroGravacao({
        message: err instanceof Error ? err.message : labels.erroGenerico,
        severity: 'error',
      })
    } finally {
      setSavingUrgente((prev) => {
        const copy = { ...prev }
        delete copy[e.boStamp]
        return copy
      })
    }
  }

  async function executarMarcarPicking(
    e: EncomendaListaItem,
    pronta: boolean,
    confirmarLinhasSemAutorizacao: boolean,
    motivo?: string,
  ) {
    setSavingPicking((prev) => ({ ...prev, [e.boStamp]: true }))
    try {
      if (pronta && !confirmarLinhasSemAutorizacao) {
        // Grava rascunhos (deferSave) + sugestões ainda com u_qtdaut=0
        await prepararAutorizacoesAntesPicking(
          e.boStamp,
          rascunhoByStamp[e.boStamp] ? (linhasByStamp[e.boStamp] ?? null) : null,
        )
        setRascunhoByStamp((prev) => {
          const n = { ...prev }
          delete n[e.boStamp]
          return n
        })
      }
      await api.marcarProntaPicking(e.boStamp, pronta, {
        confirmarLinhasSemAutorizacao,
        motivo,
      })
      setItems((prev) => prev.filter((x) => x.boStamp !== e.boStamp))
      setTotal((t) => Math.max(0, t - 1))
      setExpandedStamps((prev) => {
        const next = new Set(prev)
        next.delete(e.boStamp)
        return next
      })
      setErroGravacao({
        message: pronta ? labels.prontaPickingOk : labels.prontaPickingRevertidaOk,
        severity: 'success',
      })
    } catch (err) {
      const msg = err instanceof Error ? err.message : labels.erroGenerico
      if (pronta && !confirmarLinhasSemAutorizacao && msg.includes('LINHAS_SEM_AUTORIZACAO')) {
        setConfirmarLinhasZero(e)
        return
      }
      setErroGravacao({ message: msg, severity: 'error' })
    } finally {
      setSavingPicking((prev) => {
        const next = { ...prev }
        delete next[e.boStamp]
        return next
      })
    }
  }

  async function executarWorkflowPicking(
    e: EncomendaListaItem,
    acao: 'start' | 'complete' | 'cancel' | 'ready' | 'reopen',
    motivo?: string,
  ) {
    setSavingPicking((prev) => ({ ...prev, [e.boStamp]: true }))
    try {
      const result =
        acao === 'start'
          ? await api.pickingStart(e.boStamp)
          : acao === 'complete'
            ? await api.pickingComplete(e.boStamp)
            : acao === 'cancel'
              ? await api.pickingCancel(e.boStamp, motivo ?? '')
              : acao === 'ready'
                ? await api.pickingReady(e.boStamp)
                : await api.pickingReopen(e.boStamp)

      if (acao === 'cancel') {
        setItems((prev) => prev.filter((x) => x.boStamp !== e.boStamp))
        setTotal((t) => Math.max(0, t - 1))
        setExpandedStamps((prev) => {
          const next = new Set(prev)
          next.delete(e.boStamp)
          return next
        })
      } else {
        setItems((prev) =>
          prev.map((x) =>
            x.boStamp === e.boStamp
              ? {
                  ...x,
                  prontaPicking: result.prontaPicking,
                  pickStatus: result.pickStatus,
                  prontaPickingPor: result.prontaPickingPor,
                  prontaPickingEm: result.prontaPickingEm,
                }
              : x,
          ),
        )
      }

      const okMsg =
        acao === 'start'
          ? labels.pickingIniciarOk
          : acao === 'complete'
            ? labels.pickingConcluirOk
            : acao === 'cancel'
              ? labels.prontaPickingRevertidaOk
              : acao === 'ready'
                ? labels.pickingVoltarPreparadoOk
                : labels.pickingReabrirOk
      setErroGravacao({ message: okMsg, severity: 'success' })
    } catch (err) {
      setErroGravacao({
        message: err instanceof Error ? err.message : labels.erroGenerico,
        severity: 'error',
      })
    } finally {
      setSavingPicking((prev) => {
        const next = { ...prev }
        delete next[e.boStamp]
        return next
      })
    }
  }

  async function confirmarAccaoPicking() {
    const ctx = confirmarPicking
    if (!ctx) return
    const { item: e, acao } = ctx
    if (acao === 'reverter') {
      const motivo = motivoCancelamento.trim()
      if (!motivo) {
        setErroGravacao({
          message: labels.motivoCancelamentoObrigatorio,
          severity: 'error',
        })
        return
      }
      setConfirmarPicking(null)
      setMotivoCancelamento('')
      if (modoPicking) {
        await executarWorkflowPicking(e, 'cancel', motivo)
        return
      }
      await executarMarcarPicking(e, false, false, motivo)
      return
    }
    setConfirmarPicking(null)
    setMotivoCancelamento('')
    await executarMarcarPicking(e, true, false)
  }

  async function confirmarLinhasZeroPicking() {
    const e = confirmarLinhasZero
    if (!e) return
    setConfirmarLinhasZero(null)
    await executarMarcarPicking(e, true, true)
  }

  async function executarMarcarFecho(e: EncomendaListaItem, fechar: boolean) {
    setSavingPicking((prev) => ({ ...prev, [e.boStamp]: true }))
    try {
      if (modoDossier === 'concluidas' || modoDossier === 'separacao') {
        await api.marcarFechoSeparacaoDossier(e.boStamp, fechar)
      } else {
        await api.marcarFechoPickingDossier(e.boStamp, fechar)
      }
      setItems((prev) => prev.filter((x) => x.boStamp !== e.boStamp))
      setTotal((t) => Math.max(0, t - 1))
      setExpandedStamps((prev) => {
        const next = new Set(prev)
        next.delete(e.boStamp)
        return next
      })
      setErroGravacao({
        message: fechar ? labels.fecharDossierOk : labels.reabrirDossierOk,
        severity: 'success',
      })
    } catch (err) {
      setErroGravacao({
        message: err instanceof Error ? err.message : labels.erroGenerico,
        severity: 'error',
      })
    } finally {
      setSavingPicking((prev) => {
        const next = { ...prev }
        delete next[e.boStamp]
        return next
      })
    }
  }

  async function confirmarAccaoFecho() {
    const ctx = confirmarFecho
    if (!ctx) return
    setConfirmarFecho(null)
    await executarMarcarFecho(ctx.item, ctx.fechar)
  }

  async function executarReverterCheckIn(e: EncomendaListaItem) {
    setSavingPicking((prev) => ({ ...prev, [e.boStamp]: true }))
    try {
      await api.reverterCheckIn(e.boStamp)
      setItems((prev) => prev.filter((x) => x.boStamp !== e.boStamp))
      setTotal((t) => Math.max(0, t - 1))
      setExpandedStamps((prev) => {
        const next = new Set(prev)
        next.delete(e.boStamp)
        return next
      })
      setErroGravacao({ message: labels.reverterCheckInOk, severity: 'success' })
      window.dispatchEvent(new Event('portal:contagens-refresh'))
    } catch (err) {
      setErroGravacao({
        message: err instanceof Error ? err.message : labels.erroGenerico,
        severity: 'error',
      })
    } finally {
      setSavingPicking((prev) => {
        const next = { ...prev }
        delete next[e.boStamp]
        return next
      })
    }
  }

  async function confirmarReverterCheckInAccao() {
    const e = confirmarReverterCheckIn
    if (!e) return
    setConfirmarReverterCheckIn(null)
    await executarReverterCheckIn(e)
  }

  async function executarCancelarEncomenda(e: EncomendaListaItem, motivo: string) {
    setSavingPicking((prev) => ({ ...prev, [e.boStamp]: true }))
    try {
      await api.cancelarEncomenda(e.boStamp, motivo)
      setItems((prev) => prev.filter((x) => x.boStamp !== e.boStamp))
      setTotal((t) => Math.max(0, t - 1))
      setExpandedStamps((prev) => {
        const next = new Set(prev)
        next.delete(e.boStamp)
        return next
      })
      setErroGravacao({ message: labels.cancelarEncomendaOk, severity: 'success' })
    } catch (err) {
      setErroGravacao({
        message: err instanceof Error ? err.message : labels.erroGenerico,
        severity: 'error',
      })
    } finally {
      setSavingPicking((prev) => {
        const next = { ...prev }
        delete next[e.boStamp]
        return next
      })
    }
  }

  async function confirmarCancelarEncomendaAccao() {
    const e = confirmarCancelarEncomenda
    if (!e) return
    const motivo = motivoCancelamento.trim()
    if (!motivo) {
      setErroGravacao({
        message: labels.motivoCancelamentoObrigatorio,
        severity: 'error',
      })
      return
    }
    setConfirmarCancelarEncomenda(null)
    setMotivoCancelamento('')
    await executarCancelarEncomenda(e, motivo)
  }

  function tituloLista(): string {
    if (modoDossier === 'expedicao') return labels.expedicao
    if (modoDossier === 'emEntrega') return labels.emEntrega
    if (modoDossier === 'concluidas') return labels.concluidas
    if (modoDossier === 'separacao') return labels.expedido
    if (modoPicking) return labels.picking
    return labels.encomendas
  }

  function hintLista(): string {
    if (modoDossier === 'expedicao') {
      const estadoHint =
        filtroSeparacao === 'separados'
          ? labels.separacaoVistaJaSeparados
          : filtroSeparacao === 'espera'
            ? labels.pickStatusReady
            : filtroSeparacao === 'curso'
              ? labels.pickStatusInProgress
              : labels.separacaoFiltroTodos
      return `${labels.expedicaoHint} · ${estadoHint} · ${total} registo(s)`
    }
    if (modoDossier === 'emEntrega') return `${labels.emEntregaHint} · ${total} registo(s)`
    if (modoDossier === 'concluidas') return `${labels.concluidasHint} · ${total} registo(s)`
    if (modoDossier === 'separacao') return `${labels.expedidoHint} · ${total} registo(s)`
    if (modoPicking) return `${labels.pickingHint} · ${total} registo(s)`
    return `Encomendas em aberto · ${total} registo(s)`
  }

  useEffect(() => {
    if (loading) return

    if (!temFiltroArtigo) {
      setExpandedStamps(new Set())
      return
    }

    const stamps = items.map((i) => i.boStamp)
    setExpandedStamps(new Set(stamps))
    for (const stamp of stamps) {
      if (!linhasByStamp[stamp] && !loadingLinhas[stamp]) {
        void carregarLinhas(stamp)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items, temFiltroArtigo, loading])

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        flex: 1,
        minHeight: 0,
        height: 'auto',
        overflow: 'hidden',
      }}
    >
      {!hideHeader && (
        <Box flexShrink={0}>
          <Typography variant="h5" fontWeight={700} gutterBottom>
            {tituloLista()}
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            {hintLista()}
          </Typography>
        </Box>
      )}

      <Dialog
        open={!!confirmarFecho}
        onClose={() => setConfirmarFecho(null)}
        aria-labelledby="confirma-fecho-titulo"
      >
        <DialogTitle id="confirma-fecho-titulo">
          {confirmarFecho?.fechar && modoDossier === 'separacao'
            ? labels.fecharExpedicaoSemFaturacaoTitulo
            : confirmarFecho?.fechar
              ? labels.fecharDossierTitulo
              : labels.reabrirDossierTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {confirmarFecho?.fechar && modoDossier === 'separacao'
              ? labels.fecharExpedicaoSemFaturacaoMsg
              : (confirmarFecho?.fechar
                  ? labels.fecharDossierMsg
                  : labels.reabrirDossierMsg
                ).replace(
                  '{n}',
                  String(
                    confirmarFecho?.item
                      ? labelDossier(confirmarFecho.item)
                      : '',
                  ),
                )}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmarFecho(null)}>{labels.cancelar}</Button>
          <Button
            variant="contained"
            color={confirmarFecho?.fechar ? 'success' : 'error'}
            onClick={() => void confirmarAccaoFecho()}
            autoFocus
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={!!confirmarReverterCheckIn}
        onClose={() => setConfirmarReverterCheckIn(null)}
        aria-labelledby="confirma-reverter-checkin-titulo"
      >
        <DialogTitle id="confirma-reverter-checkin-titulo">
          {labels.reverterCheckInTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {labels.reverterCheckInMsg.replace(
              '{n}',
              String(
                confirmarReverterCheckIn ? labelDossier(confirmarReverterCheckIn) : '',
              ),
            )}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmarReverterCheckIn(null)}>{labels.cancelar}</Button>
          <Button
            variant="contained"
            color="warning"
            onClick={() => void confirmarReverterCheckInAccao()}
            autoFocus
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={!!confirmarCancelarEncomenda}
        onClose={() => {
          setConfirmarCancelarEncomenda(null)
          setMotivoCancelamento('')
        }}
        aria-labelledby="confirma-cancelar-encomenda-titulo"
      >
        <DialogTitle id="confirma-cancelar-encomenda-titulo">
          {labels.cancelarEncomendaTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {labels.cancelarEncomendaMsg.replace(
              '{n}',
              fmtDocNo(confirmarCancelarEncomenda?.numeroEncomenda),
            )}
          </DialogContentText>
          <TextField
            autoFocus
            margin="dense"
            label={labels.motivoCancelamento}
            fullWidth
            multiline
            minRows={2}
            value={motivoCancelamento}
            onChange={(ev) => setMotivoCancelamento(ev.target.value.slice(0, 254))}
            inputProps={{ maxLength: 254 }}
            helperText={`${motivoCancelamento.trim().length}/254`}
            error={motivoCancelamento.trim().length === 0}
            sx={{ mt: 1.5 }}
          />
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setConfirmarCancelarEncomenda(null)
              setMotivoCancelamento('')
            }}
          >
            {labels.cancelar}
          </Button>
          <Button
            variant="contained"
            color="error"
            disabled={motivoCancelamento.trim().length === 0}
            onClick={() => void confirmarCancelarEncomendaAccao()}
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={!!confirmarPicking}
        onClose={() => {
          setConfirmarPicking(null)
          setMotivoCancelamento('')
        }}
        aria-labelledby="confirma-picking-titulo"
      >
        <DialogTitle id="confirma-picking-titulo">
          {confirmarPicking?.acao === 'reverter'
            ? labels.prontaPickingReverterTitulo
            : labels.prontaPickingConfirmarTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {(confirmarPicking?.acao === 'reverter'
              ? labels.prontaPickingReverterMsg
              : labels.prontaPickingConfirmarMsg
            ).replace(
              '{n}',
              confirmarPicking?.item
                ? fmtDocNo(confirmarPicking.item.numeroEncomenda)
                : '—',
            )}
          </DialogContentText>
          {confirmarPicking?.acao === 'reverter' ? (
            <TextField
              autoFocus
              margin="dense"
              label={labels.motivoCancelamento}
              fullWidth
              multiline
              minRows={2}
              value={motivoCancelamento}
              onChange={(ev) => setMotivoCancelamento(ev.target.value.slice(0, 254))}
              inputProps={{ maxLength: 254 }}
              helperText={`${motivoCancelamento.trim().length}/254`}
              error={motivoCancelamento.trim().length === 0}
              sx={{ mt: 1.5 }}
            />
          ) : null}
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setConfirmarPicking(null)
              setMotivoCancelamento('')
            }}
          >
            {labels.cancelar}
          </Button>
          <Button
            variant="contained"
            onClick={() => void confirmarAccaoPicking()}
            disabled={
              confirmarPicking?.acao === 'reverter' && motivoCancelamento.trim().length === 0
            }
            autoFocus={confirmarPicking?.acao !== 'reverter'}
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={!!confirmarLinhasZero}
        onClose={() => setConfirmarLinhasZero(null)}
        aria-labelledby="confirma-linhas-zero-titulo"
      >
        <DialogTitle id="confirma-linhas-zero-titulo">
          {labels.prontaPickingLinhasZeroTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>{labels.prontaPickingLinhasZeroMsg}</DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmarLinhasZero(null)}>{labels.cancelar}</Button>
          <Button
            variant="contained"
            color="warning"
            onClick={() => void confirmarLinhasZeroPicking()}
            autoFocus
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Box
        display="flex"
        gap={1}
        mb={2}
        flexWrap="nowrap"
        alignItems="center"
        flexShrink={0}
        sx={{
          pt: 0.75,
          width: '100%',
          maxWidth: '100%',
          overflowX: 'auto',
          '& .MuiFormControl-root, & .MuiAutocomplete-root': {
            flex: '1 1 0',
            minWidth: 88,
          },
        }}
      >
        <DateFilterField label="Data de" value={dataDe} onChange={setDataDe} width={132} />
        <DateFilterField label="Data até" value={dataAte} onChange={setDataAte} width={132} />
        <TimeFilterField label="Hora de" value={horaDe} onChange={setHoraDe} width={100} />
        <TimeFilterField label="Hora até" value={horaAte} onChange={setHoraAte} width={100} />
        <TextField
          label="Nº cliente"
          size="small"
          value={clienteNo}
          onChange={(e) => {
            setClienteNo(e.target.value)
          }}
          placeholder="Contém…"
          sx={{ flex: '0.7 1 0', maxWidth: 120, minWidth: 88 }}
        />
        <Autocomplete
          freeSolo
          options={sugestoes}
          filterOptions={(x) => x}
          loading={loadingSugestoes}
          inputValue={artigoInput}
          onInputChange={(_, value, reason) => {
            if (reason === 'reset') return
            setArtigoInput(value)
            setPage(1)
          }}
          onChange={(_, value) => {
            if (typeof value === 'string') {
              setArtigoInput(value)
            } else if (value) {
              setArtigoInput(value.ref.trim())
            } else {
              setArtigoInput('')
            }
            setPage(1)
          }}
          getOptionLabel={(opt) => (typeof opt === 'string' ? opt : labelSugestao(opt))}
          isOptionEqualToValue={(a, b) =>
            typeof a !== 'string' &&
            typeof b !== 'string' &&
            a.ref === b.ref &&
            a.design === b.design
          }
          sx={{ flex: '1.6 1 0', minWidth: 140 }}
          renderOption={(props, option) => (
            <li {...props} key={`${option.ref}|${option.design}`}>
              <Box>
                <Typography variant="body2" fontWeight={600}>
                  {option.ref}
                </Typography>
                <Typography variant="caption" color="text.secondary" display="block">
                  {option.design}
                </Typography>
              </Box>
            </li>
          )}
          renderInput={(params) => (
            <TextField
              {...params}
              label="Artigo"
              size="small"
              placeholder="Referência ou designação…"
              InputProps={{
                ...params.InputProps,
                endAdornment: (
                  <>
                    {loadingSugestoes ? <CircularProgress color="inherit" size={16} /> : null}
                    {params.InputProps.endAdornment}
                  </>
                ),
              }}
            />
          )}
        />
        <Autocomplete
          freeSolo
          options={sugestoesCor}
          filterOptions={(x) => x}
          loading={loadingSugestoesCor}
          inputValue={corInput}
          onInputChange={(_, value, reason) => {
            if (reason === 'reset') return
            setCorInput(value)
            setPage(1)
          }}
          onChange={(_, value) => {
            setCorInput(typeof value === 'string' ? value : value ?? '')
            setPage(1)
          }}
          sx={{ flex: '0.65 1 0', maxWidth: 110, minWidth: 88 }}
          renderInput={(params) => (
            <TextField
              {...params}
              label="Cor"
              size="small"
              placeholder="Cor…"
              InputProps={{
                ...params.InputProps,
                endAdornment: (
                  <>
                    {loadingSugestoesCor ? (
                      <CircularProgress color="inherit" size={16} />
                    ) : null}
                    {params.InputProps.endAdornment}
                  </>
                ),
              }}
            />
          )}
        />
        <TextField
          select
          label="Limite definido"
          size="small"
          value={estado}
          onChange={(e) => onEstadoChange(e.target.value)}
          InputLabelProps={{ shrink: true }}
          sx={{ flex: '0.9 1 0', minWidth: 140, maxWidth: 170 }}
        >
          <MenuItem value="Todos">Todos</MenuItem>
          <MenuItem value="DentroDoPlaneamento">{labels.dentroPlaneamento}</MenuItem>
          <MenuItem value="AposCorte">{labels.aposCorte}</MenuItem>
        </TextField>
        <TextField
          select
          label={labels.filtroMetodoExpedicao}
          size="small"
          value={metodoExpedicao}
          onChange={(e) => onMetodoExpedicaoChange(e.target.value)}
          InputLabelProps={{ shrink: true }}
          sx={{ flex: '1.1 1 0', minWidth: 168, maxWidth: 220 }}
        >
          {FILTRO_METODO_OPCOES.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              {o.label()}
            </MenuItem>
          ))}
        </TextField>
        {modoDossier === 'expedicao' ? (
          <TextField
            select
            label={labels.estadoSeparacao}
            size="small"
            value={filtroSeparacao}
            onChange={(e) => {
              const v = e.target.value
              const next =
                v === 'espera' || v === 'curso' || v === 'separados' || v === 'todos'
                  ? v
                  : 'todos'
              setFiltroSeparacao(next)
              setExpandedStamps(new Set())
              setPage(1)
            }}
            InputLabelProps={{ shrink: true }}
            sx={{ flex: '0.95 1 0', minWidth: 150, maxWidth: 180 }}
          >
            <MenuItem value="todos">{labels.separacaoFiltroTodos}</MenuItem>
            <MenuItem value="espera">{labels.pickStatusReady}</MenuItem>
            <MenuItem value="curso">{labels.pickStatusInProgress}</MenuItem>
            <MenuItem value="separados">{labels.separacaoVistaJaSeparados}</MenuItem>
          </TextField>
        ) : null}
        {mostraEstadoOperacional && modoPicking ? (
          <TextField
            select
            label={labels.estadoPicking}
            size="small"
            value={pickStatus}
            onChange={(e) => onPickStatusChange(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ flex: '0.9 1 0', minWidth: 140, maxWidth: 170 }}
          >
            <MenuItem value="Todos">Todos</MenuItem>
            <MenuItem value="1">{labels.pickStatusReady}</MenuItem>
            <MenuItem value="2">{labels.pickStatusInProgress}</MenuItem>
            <MenuItem value="3">{labels.pickStatusCompleted}</MenuItem>
          </TextField>
        ) : null}
      </Box>

      {erro && (
        <Alert severity="error" sx={{ mb: 2, flexShrink: 0 }}>
          {erro}
        </Alert>
      )}
      {!modoPicking && !modoDossier && (anterioresPorTratar ?? 0) > 0 && (
        <Alert severity="warning" sx={{ mb: 2, flexShrink: 0 }}>
          <Box>
            <Typography variant="body2">
              Existem {anterioresPorTratar} encomenda(s) por tratar anteriores a {dataDe}. Ajuste
              o filtro &quot;Data de&quot; para as visualizar.
            </Typography>
            {anterioresPorTratarDetalhe.length > 0 ? (
              <>
                <Button
                  size="small"
                  color="inherit"
                  onClick={() => setMostrarDetalheAtraso((v) => !v)}
                  endIcon={
                    mostrarDetalheAtraso ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />
                  }
                  sx={{ mt: 0.75, px: 0, minWidth: 0, textTransform: 'none', fontWeight: 700 }}
                >
                  {mostrarDetalheAtraso ? 'Ocultar detalhe' : 'Ver detalhe das encomendas'}
                </Button>
                <Collapse in={mostrarDetalheAtraso}>
                  <Box mt={0.5}>
                    <Typography variant="caption" color="text.secondary" display="block" mb={0.25}>
                      Documentos em atraso:
                    </Typography>
                    <Table size="small" sx={{ '& .MuiTableCell-root': { py: 0.35 } }}>
                      <TableHead>
                        <TableRow>
                          <TableCell sx={{ fontWeight: 700 }}>Nº</TableCell>
                          <TableCell sx={{ fontWeight: 700 }}>Cliente</TableCell>
                          <TableCell sx={{ fontWeight: 700 }}>Data</TableCell>
                          <TableCell sx={{ fontWeight: 700 }}>Hora</TableCell>
                          <TableCell sx={{ fontWeight: 700 }}>Limite</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {anterioresPorTratarDetalhe.map((e) => (
                          <TableRow key={e.boStamp}>
                            <TableCell>{fmtDocNo(e.numeroEncomenda)}</TableCell>
                            <TableCell>
                              <Box display="flex" alignItems="center" gap={0.25} minWidth={0}>
                                <Box minWidth={0} flex={1}>
                                  <ClienteNomeDisplay
                                    nome={e.clienteNome}
                                    nome2={e.clienteNome2}
                                    compact
                                  />
                                </Box>
                                <DossierInfoButton
                                  clienteNome={e.clienteNome}
                                  clienteNome2={e.clienteNome2}
                                  moradaEntrega={e.moradaEntrega}
                                  dataEntrega={e.dataEntrega}
                                  showDataEntrega
                                  metodoExpedicao={e.metodoExpedicao}
                                  showMetodoExpedicao
                                />
                              </Box>
                            </TableCell>
                            <TableCell>{e.data}</TableCell>
                            <TableCell>{e.hora}</TableCell>
                            <TableCell align="center">{chipPlaneamento(e.estadoPlaneamentoCodigo, true)}</TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                    {(anterioresPorTratar ?? 0) > anterioresPorTratarDetalhe.length ? (
                      <Typography variant="caption" color="text.secondary" display="block" mt={0.35}>
                        +{(anterioresPorTratar ?? 0) - anterioresPorTratarDetalhe.length} registo(s)
                        adicionais.
                      </Typography>
                    ) : null}
                  </Box>
                </Collapse>
              </>
            ) : null}
          </Box>
        </Alert>
      )}

      <GravacaoSnackbar snack={erroGravacao} onClose={() => setErroGravacao(null)} />

      {loading ? (
        <Box display="flex" justifyContent="center" alignItems="center" flex={1} py={6} minHeight={0}>
          <CircularProgress />
        </Box>
      ) : (
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            flex: 1,
            minHeight: 0,
            overflow: 'hidden',
          }}
        >
          <PortalTableScroll fill>
            <Paper
              sx={[
                portalPanelSx,
                {
                  width: '100%',
                  overflow: 'visible',
                  ...(accentColor
                    ? { borderTop: `2px solid ${accentColor}` }
                    : null),
                },
              ]}
            >
              <Table size="small" sx={encomendasTableSx}>
              <colgroup>
                <col style={{ width: '3%' }} />
                <col style={{ width: modoDossier ? '9%' : '5%' }} />
                <col style={{ width: mostraEstadoOperacional ? '18%' : '22%' }} />
                {mostraEntrega ? <col style={{ width: '8%' }} /> : null}
                <col style={{ width: '11%' }} />
                <col style={{ width: '8%' }} />
                <col style={{ width: '7%' }} />
                <col style={{ width: '5%' }} />
                {mostraEstadoOperacional ? (
                  <col style={{ width: modoKapps ? '12%' : '10%' }} />
                ) : null}
                <col style={{ width: '4%' }} />
                {!semAccao ? (
                  <col
                    style={{
                      width: modoPicking
                        ? '10%'
                        : emEntrega
                          ? '11%'
                          : modoDossier === 'separacao'
                            ? '10%'
                            : modoDossier
                              ? '5%'
                              : '12%',
                    }}
                  />
                ) : null}
              </colgroup>
              <TableHead
                sx={{
                  '& .MuiTableCell-head': {
                    position: 'sticky',
                    top: 0,
                    zIndex: 3,
                    bgcolor: (theme) => theme.palette.portal.panel,
                  },
                }}
              >
                <TableRow>
                  <TableCell padding="checkbox" sx={[portalColHeaderSx, { px: 0.25 }]} />
                  <TableCell sx={portalColHeaderSx}>
                    {modoDossier ? labels.colDocumentos : 'Nº'}
                  </TableCell>
                  <TableCell sx={portalColHeaderSx}>Cliente</TableCell>
                  {mostraEntrega ? (
                    <TableCell sx={portalColHeaderSx}>{labels.colEntrega}</TableCell>
                  ) : null}
                  <TableCell sx={portalColHeaderSx}>
                    {labels.colMetodoExpedicao}
                  </TableCell>
                  <TableCell sx={portalColHeaderSx}>Data</TableCell>
                  <TableCell sx={portalColHeaderSx}>Hora</TableCell>
                  <TableCell sx={portalColHeaderSx} align="center">
                    Limite
                  </TableCell>
                  {mostraEstadoOperacional ? (
                    <TableCell sx={portalColHeaderSx}>
                      {modoPicking ? labels.estadoPicking : labels.estadoSeparacao}
                    </TableCell>
                  ) : null}
                  <TableCell sx={[portalColHeaderSx, { px: 0.25 }]} align="center">
                    <Tooltip title={labels.urgente} arrow>
                      <PriorityHighIcon sx={{ fontSize: 16, color: estadoSemantic.urgente.color }} />
                    </Tooltip>
                  </TableCell>
                  {!semAccao ? (
                    <TableCell sx={portalColHeaderSx}>
                      {labels.colunaAccao}
                    </TableCell>
                  ) : null}
                </TableRow>
              </TableHead>
              <TableBody>
                {items.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={colCount} sx={{ border: 0, py: 2 }}>
                      <PortalEmptyState
                        message={
                          modoDossier === 'expedicao'
                            ? jaSeparados
                              ? 'Sem dossiers já separados.'
                              : 'Sem dossiers em separação.'
                            : modoDossier === 'emEntrega'
                              ? labels.emEntregaVazio
                              : modoDossier === 'concluidas'
                                ? 'Sem expedições concluídas.'
                                : modoDossier === 'separacao'
                                  ? 'Sem dossiers em expedição.'
                                  : modoPicking
                                    ? 'Sem encomendas em picking.'
                                    : 'Sem encomendas em aberto.'
                        }
                      />
                    </TableCell>
                  </TableRow>
                )}
                {items.map((e) => {
                  const open = expandedStamps.has(e.boStamp)
                  const linhas = linhasByStamp[e.boStamp]
                  const linhasVisiveis = linhas
                    ? temFiltroArtigo
                      ? linhas.filter((l) =>
                          linhaCorrespondeFiltros(l, artigoDebounced, corDebounced),
                        )
                      : linhas
                    : undefined
                  const aCarregar = !!loadingLinhas[e.boStamp]
                  const erroLinha = erroLinhas[e.boStamp]
                  const pickingMeta = fmtPickingMeta(e.prontaPickingPor, e.prontaPickingEm)
                  const kappsDetalhe = kappsByStamp[e.boStamp]
                  const podeCancelarPicking =
                    modoPicking &&
                    !e.temQtt66 &&
                    !pickingEmAndamento(e.pickStatus, kappsDetalhe)
                  return (
                    <Fragment key={e.boStamp}>
                      <TableRow
                        hover
                        onClick={() => toggleExpand(e.boStamp)}
                        selected={open}
                        sx={{
                          cursor: 'pointer',
                          height: modoKapps ? 52 : undefined,
                          '& > *': {
                            borderBottom: open ? 'unset' : undefined,
                            ...(modoKapps ? { height: 52, py: 0.25 } : {}),
                          },
                          ...urgenteRowSx(e.urgente),
                        }}
                      >
                        <TableCell padding="checkbox">
                          <IconButton
                            size="small"
                            aria-label={open ? 'Fechar linhas' : 'Ver linhas'}
                            onClick={(ev) => {
                              ev.stopPropagation()
                              toggleExpand(e.boStamp)
                            }}
                          >
                            {open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
                          </IconButton>
                        </TableCell>
                        <TableCell>
                          {modoDossier ? (
                            <Box
                              sx={{
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 0.15,
                                py: 0.25,
                              }}
                            >
                              {caminhoDocumentos(e).map((r) => (
                                <Typography
                                  key={r.label}
                                  variant="caption"
                                  component="div"
                                  sx={{ lineHeight: 1.25, whiteSpace: 'nowrap' }}
                                >
                                  {r.label} {fmtDocNo(r.n)}
                                </Typography>
                              ))}
                            </Box>
                          ) : (
                            fmtDocNo(e.numeroEncomenda)
                          )}
                        </TableCell>
                        <TableCell
                          sx={{ maxWidth: 0 }}
                          onClick={(ev) => {
                            // Evitar expand ao interagir com ⓘ
                            if ((ev.target as HTMLElement).closest('button')) {
                              ev.stopPropagation()
                            }
                          }}
                        >
                          <Box display="flex" alignItems="center" gap={0.25} minWidth={0} width="100%">
                            <Box minWidth={0} flex={1} overflow="hidden">
                              <ClienteNomeDisplay
                                nome={e.clienteNome}
                                nome2={e.clienteNome2}
                                compact
                              />
                            </Box>
                            <DossierInfoButton
                              clienteNome={e.clienteNome}
                              clienteNome2={e.clienteNome2}
                              moradaEntrega={e.moradaEntrega}
                              dataEntrega={e.dataEntrega}
                              showDataEntrega={mostraEntrega}
                              metodoExpedicao={e.metodoExpedicao}
                              showMetodoExpedicao
                            />
                          </Box>
                        </TableCell>
                        {mostraEntrega ? (
                          <TableCell>{fmtDate(e.dataEntrega)}</TableCell>
                        ) : null}
                        <TableCell
                          title={fmtMetodoExpedicao(e.metodoExpedicao)}
                          sx={{
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {fmtMetodoExpedicao(e.metodoExpedicao)}
                        </TableCell>
                        <TableCell>{fmtDate(e.data)}</TableCell>
                        <TableCell title={e.hora}>
                          {e.hora?.trim().match(/^(\d{1,2}:\d{2})/)?.[1] ?? e.hora}
                        </TableCell>
                        <TableCell align="center" sx={{ py: modoKapps ? 0.25 : 1 }}>
                          {chipPlaneamento(e.estadoPlaneamentoCodigo, mostraEstadoOperacional)}
                        </TableCell>
                        {mostraEstadoOperacional ? (
                          <TableCell
                            onClick={(ev) => ev.stopPropagation()}
                            sx={modoKapps ? statusCellSx : { py: 1 }}
                          >
                            <Box
                              display="flex"
                              flexDirection="column"
                              alignItems="flex-start"
                              gap={0.35}
                            >
                              {modoKapps ? (
                                <EstadoPickingComKapps
                                  pickStatus={e.pickStatus}
                                  modoSeparacao={modoSeparado66}
                                  kapps={
                                    e.boStamp in kappsByStamp
                                      ? kappsByStamp[e.boStamp]
                                      : undefined
                                  }
                                />
                              ) : (
                                chipPickStatus(e.pickStatus, emPicagem66)
                              )}
                              {modoSeparado66 && isEntregaParcialDossier(e) ? (
                                <StatusBadge
                                  tone="atrasado"
                                  label={labels.entregaParcial}
                                />
                              ) : null}
                            </Box>
                          </TableCell>
                        ) : null}
                        <TableCell
                          onClick={(ev) => ev.stopPropagation()}
                          sx={{ px: 0.5, textAlign: 'center' }}
                        >
                          {podeEditarUrgente ? (
                            <Tooltip
                              title={e.urgente ? labels.urgenteDesmarcar : labels.urgenteMarcar}
                              arrow
                            >
                              <span>
                                <Checkbox
                                  size="small"
                                  checked={e.urgente}
                                  disabled={!!savingUrgente[e.boStamp]}
                                  onChange={() => void toggleUrgente(e)}
                                  icon={
                                    <PriorityHighIcon fontSize="small" sx={{ opacity: 0.35 }} />
                                  }
                                  checkedIcon={
                                    <PriorityHighIcon
                                      fontSize="small"
                                      sx={{ color: estadoSemantic.urgente.color }}
                                    />
                                  }
                                  inputProps={{
                                    'aria-label': e.urgente
                                      ? labels.urgenteDesmarcar
                                      : labels.urgenteMarcar,
                                  }}
                                  sx={{ p: 0.25 }}
                                />
                              </span>
                            </Tooltip>
                          ) : e.urgente ? (
                            <UrgenteBadge />
                          ) : null}
                        </TableCell>
                        {!semAccao ? (
                        <TableCell
                          onClick={(ev) => ev.stopPropagation()}
                          sx={{
                            whiteSpace: 'nowrap',
                            py: 0.5,
                            overflow: 'hidden',
                            '& .MuiButton-root': {
                              px: 0.85,
                              fontSize: '0.72rem',
                              minWidth: 0,
                            },
                          }}
                        >
                          {emEntrega ? (
                            <Tooltip title={labels.reverterCheckInHint} arrow>
                              <span>
                                <Button
                                  size="small"
                                  variant="outlined"
                                  color="warning"
                                  aria-label={labels.reverterCheckIn}
                                  disabled={!!savingPicking[e.boStamp]}
                                  onClick={() => setConfirmarReverterCheckIn(e)}
                                  sx={portalActionBtnSx}
                                >
                                  {labels.reverterCheckIn}
                                </Button>
                              </span>
                            </Tooltip>
                          ) : modoDossier === 'separacao' ? (
                            <Tooltip title={labels.fecharDossierHint} arrow>
                              <span>
                                <Button
                                  size="small"
                                  variant="contained"
                                  color="success"
                                  aria-label={labels.fecharDossier}
                                  disabled={!!savingPicking[e.boStamp]}
                                  onClick={() => setConfirmarFecho({ item: e, fechar: true })}
                                  startIcon={<CheckIcon fontSize="small" />}
                                  sx={portalActionBtnSx}
                                >
                                  {labels.fecharDossier}
                                </Button>
                              </span>
                            </Tooltip>
                          ) : modoDossier === 'concluidas' ? (
                            <Tooltip title={labels.reabrirDossierHint} arrow>
                              <span>
                                <Button
                                  size="small"
                                  variant="contained"
                                  color="error"
                                  aria-label={labels.reabrirDossier}
                                  disabled={!!savingPicking[e.boStamp]}
                                  onClick={() => setConfirmarFecho({ item: e, fechar: false })}
                                  sx={{ minWidth: 36, px: 1 }}
                                >
                                  <CloseIcon fontSize="small" />
                                </Button>
                              </span>
                            </Tooltip>
                          ) : modoPicking ? (
                            podeCancelarPicking ? (
                              <Tooltip
                                title={
                                  pickingMeta
                                    ? `${labels.pickingCancelarHint} · Marcada por ${pickingMeta}`
                                    : labels.pickingCancelarHint
                                }
                                arrow
                              >
                                <span>
                                  <Button
                                    size="small"
                                    variant="outlined"
                                    color="error"
                                    aria-label={labels.pickingCancelar}
                                    disabled={!!savingPicking[e.boStamp]}
                                      onClick={() => {
                                        setMotivoCancelamento('')
                                        setConfirmarPicking({ item: e, acao: 'reverter' })
                                      }}
                                    sx={portalActionBtnSx}
                                  >
                                    {labels.pickingCancelar}
                                  </Button>
                                </span>
                              </Tooltip>
                            ) : null
                          ) : (
                            <Box display="flex" gap={0.5} alignItems="center" flexWrap="nowrap">
                              <Tooltip title={labels.marcarProntaPickingHint} arrow>
                                <span>
                                  <Button
                                    size="small"
                                    variant="contained"
                                    aria-label={labels.marcarProntaPickingHint}
                                    disabled={!!savingPicking[e.boStamp]}
                                    onClick={() =>
                                      setConfirmarPicking({ item: e, acao: 'marcar' })
                                    }
                                    startIcon={<CheckIcon fontSize="small" />}
                                    sx={{
                                      ...portalPrimaryCtaSx,
                                      ...portalActionBtnSx,
                                      minWidth: 0,
                                      px: 1.25,
                                      height: 30,
                                      fontSize: '0.75rem',
                                      letterSpacing: 0.3,
                                    }}
                                  >
                                    {labels.marcarProntaPicking}
                                  </Button>
                                </span>
                              </Tooltip>
                              <Tooltip title={labels.cancelarEncomendaHint} arrow>
                                <span>
                                  <Button
                                    size="small"
                                    variant="outlined"
                                    color="error"
                                    aria-label={labels.cancelarEncomenda}
                                    disabled={!!savingPicking[e.boStamp]}
                                    onClick={() => {
                                      setMotivoCancelamento('')
                                      setConfirmarCancelarEncomenda(e)
                                    }}
                                    sx={{ minWidth: 36, width: 36, px: 0, height: 30 }}
                                  >
                                    <CloseIcon fontSize="small" />
                                  </Button>
                                </span>
                              </Tooltip>
                            </Box>
                          )}
                        </TableCell>
                        ) : null}
                      </TableRow>
                      <TableRow sx={{ display: open ? 'table-row' : 'none' }}>
                        <TableCell
                          colSpan={colCount}
                          sx={{
                            py: 0,
                            borderBottom: (t) => `2px solid ${t.palette.divider}`,
                            bgcolor: 'background.default',
                          }}
                        >
                          <Collapse in={open} timeout="auto" unmountOnExit>
                            <Box sx={{ py: 0.75, px: 0.5 }}>
                              {modoKapps ? (
                                <KappsPickingPanel
                                  loading={!!loadingKapps[e.boStamp]}
                                  erro={erroKapps[e.boStamp] ?? null}
                                  data={
                                    e.boStamp in kappsByStamp
                                      ? kappsByStamp[e.boStamp]
                                      : undefined
                                  }
                                  variante={emPicagem66 ? 'separacao' : 'picking'}
                                  podeEditarQuantidade={
                                    modoPicking &&
                                    pickingAindaNaoIniciado(
                                      e.pickStatus,
                                      e.boStamp in kappsByStamp
                                        ? kappsByStamp[e.boStamp]
                                        : undefined,
                                    )
                                  }
                                  onNotify={setErroGravacao}
                                  onQuantidadeAlterada={(pickingLineKey, quantidade) => {
                                    setKappsByStamp((prev) => {
                                      const cur = prev[e.boStamp]
                                      if (!cur) return prev
                                      return {
                                        ...prev,
                                        [e.boStamp]: {
                                          ...cur,
                                          lines: cur.lines.map((l) =>
                                            l.pickingLineKey === pickingLineKey
                                              ? {
                                                  ...l,
                                                  quantity: quantidade,
                                                  quantityPending: Math.max(
                                                    0,
                                                    quantidade - l.quantityPicked,
                                                  ),
                                                }
                                              : l,
                                          ),
                                        },
                                      }
                                    })
                                  }}
                                />
                              ) : (
                                <>
                                  {aCarregar && (
                                    <Box display="flex" justifyContent="center" py={1.5}>
                                      <CircularProgress size={22} />
                                    </Box>
                                  )}
                                  {erroLinha && (
                                    <Alert severity="error" sx={{ mb: 1 }}>
                                      {erroLinha}
                                    </Alert>
                                  )}
                                  {!aCarregar && !erroLinha && linhasVisiveis && (
                                    <>
                                      {linhas?.some((l) => l.disponivelNoPortal === false) ? (
                                        <Alert severity="warning" sx={{ mb: 1 }}>
                                          {labels.encomendaComArtigosNaoDisponiveisPortal}
                                        </Alert>
                                      ) : null}
                                      {temFiltroArtigo && (
                                        <Typography
                                          variant="caption"
                                          color="text.secondary"
                                          display="block"
                                          mb={0.5}
                                          px={0.5}
                                        >
                                          Linhas filtradas
                                          {artigoDebounced
                                            ? ` · artigo «${artigoDebounced}»`
                                            : ''}
                                          {corDebounced ? ` · cor «${corDebounced}»` : ''}
                                          {' · '}
                                          {linhasVisiveis.length} de {linhas?.length ?? 0}
                                        </Typography>
                                      )}
                                      <PortalTableScroll>
                                      <Table size="small" sx={linhasTableSx}>
                                        <LinhasColGroup
                                          withCor
                                          variant={
                                            modoSeparado66 ? 'separadoExpedicao' : 'encomenda'
                                          }
                                        />
                                        <TableHead>
                                          <TableRow>
                                            <TableCell>Artigo</TableCell>
                                            <TableCell>Descrição</TableCell>
                                            <TableCell>Cor</TableCell>
                                            <TableCell>Unidade</TableCell>
                                            {modoSeparado66 ? (
                                              <>
                                                <TableCell align="right">
                                                  {labels.colQtdDocumento}
                                                </TableCell>
                                                <TableCell align="right">
                                                  {labels.colExpedida}
                                                </TableCell>
                                                <TableCell align="right">
                                                  {labels.colPendenteEntrega}
                                                </TableCell>
                                              </>
                                            ) : (
                                              <>
                                                <TableCell align="right">Encomendada</TableCell>
                                                <TableCell align="center">Autorizada</TableCell>
                                                <TableCell align="center">Preço</TableCell>
                                                <TableCell align="right">Total</TableCell>
                                                <TableCell align="right">
                                                  {labels.colDisponivelPrevisto}
                                                </TableCell>
                                              </>
                                            )}
                                          </TableRow>
                                        </TableHead>
                                        <TableBody>
                                          {linhasVisiveis.length === 0 ? (
                                            <TableRow>
                                              <TableCell colSpan={modoSeparado66 ? 7 : 9}>
                                                <Typography
                                                  variant="body2"
                                                  color="text.secondary"
                                                >
                                                  Sem linhas
                                                  {temFiltroArtigo
                                                    ? ' para estes filtros'
                                                    : ''}
                                                  .
                                                </Typography>
                                              </TableCell>
                                            </TableRow>
                                          ) : (
                                            linhasVisiveis.map((l) => {
                                              const disponivelUi = stockDisponivelComSugestao(
                                                l,
                                                linhas ?? [],
                                                servidorAutByStamp[e.boStamp],
                                              )
                                              return (
                                              <TableRow
                                                key={l.biStamp}
                                                sx={
                                                  temFiltroArtigo
                                                    ? { bgcolor: 'action.selected' }
                                                    : undefined
                                                }
                                              >
                                                <TableCell>
                                                  {l.ref}
                                                  {l.disponivelNoPortal === false ? (
                                                    <Typography
                                                      component="span"
                                                      display="block"
                                                      variant="caption"
                                                      color="warning.main"
                                                      fontWeight={700}
                                                    >
                                                      {labels.artigoNaoDisponivelPortal}
                                                    </Typography>
                                                  ) : null}
                                                </TableCell>
                                                <TableCell>{l.descricao}</TableCell>
                                                <TableCell>
                                                  {l.cor?.trim() ? l.cor : '—'}
                                                </TableCell>
                                                <TableCell>
                                                  {l.unidade?.trim() ? l.unidade : '—'}
                                                </TableCell>
                                                {modoSeparado66 ? (
                                                  <>
                                                    <TableCell align="right">
                                                      {fmt(l.qtt)}
                                                    </TableCell>
                                                    <TableCell align="right">
                                                      {fmt(l.qtt2)}
                                                    </TableCell>
                                                    <TableCell align="right">
                                                      {fmt(l.qtt - l.qtt2)}
                                                    </TableCell>
                                                  </>
                                                ) : (
                                                  <>
                                                    <TableCell align="right">
                                                      {fmt(l.quantidadeOriginalPortal)}
                                                    </TableCell>
                                                    <TableCell
                                                      align="center"
                                                      onClick={(ev) => ev.stopPropagation()}
                                                      sx={{ px: 0.5 }}
                                                    >
                                                      <QuantidadeAutorizadaCell
                                                        linha={l}
                                                        readOnly={
                                                          soConsulta ||
                                                          !!gravandoAutByStamp[e.boStamp]
                                                        }
                                                        deferSave={!soConsulta}
                                                        onNotify={setErroGravacao}
                                                        onDraftChange={(next) =>
                                                          patchLinhaAutDraft(e.boStamp, next)
                                                        }
                                                        onSaved={(next) => {
                                                          setLinhasByStamp((prev) => {
                                                            const cur = prev[e.boStamp]
                                                            if (!cur) return prev
                                                            return {
                                                              ...prev,
                                                              [e.boStamp]: cur.map((x) =>
                                                                x.biStamp === next.biStamp
                                                                  ? next
                                                                  : x,
                                                              ),
                                                            }
                                                          })
                                                        }}
                                                      />
                                                    </TableCell>
                                                    <TableCell
                                                      align="center"
                                                      onClick={(ev) => ev.stopPropagation()}
                                                      sx={{ px: 0.5 }}
                                                    >
                                                      <LinhaPrecoCell
                                                        linha={l}
                                                        readOnly={soConsulta}
                                                        onNotify={setErroGravacao}
                                                        onSaved={(next) => {
                                                          setLinhasByStamp((prev) => {
                                                            const cur = prev[e.boStamp]
                                                            if (!cur) return prev
                                                            return {
                                                              ...prev,
                                                              [e.boStamp]: cur.map((x) =>
                                                                x.biStamp === next.biStamp
                                                                  ? next
                                                                  : x,
                                                              ),
                                                            }
                                                          })
                                                        }}
                                                      />
                                                    </TableCell>
                                                    <TableCell align="right">
                                                      {fmtMoney(totalLinhaAutorizada(l))}
                                                    </TableCell>
                                                      <TableCell
                                                      align="right"
                                                      sx={{
                                                        color:
                                                          disponivelUi < 0
                                                            ? 'warning.main'
                                                            : undefined,
                                                        fontWeight:
                                                          disponivelUi < 0 ? 700 : undefined,
                                                      }}
                                                    >
                                                      {fmt(disponivelUi)}
                                                    </TableCell>
                                                  </>
                                                )}
                                              </TableRow>
                                              )
                                            })
                                          )}
                                        </TableBody>
                                      </Table>
                                      </PortalTableScroll>
                                      {!soConsulta ? (
                                        <Box
                                          display="flex"
                                          gap={1}
                                          alignItems="center"
                                          justifyContent="flex-end"
                                          flexWrap="wrap"
                                          mt={1}
                                          px={0.5}
                                        >
                                          {rascunhoByStamp[e.boStamp] ? (
                                            <Button
                                              variant="outlined"
                                              size="small"
                                              disabled={!!gravandoAutByStamp[e.boStamp]}
                                              onClick={(ev) => {
                                                ev.stopPropagation()
                                                void descartarRascunhoAutorizadas(e.boStamp)
                                              }}
                                            >
                                              {labels.descartarRascunho}
                                            </Button>
                                          ) : null}
                                          <Button
                                            variant="contained"
                                            color="success"
                                            size="small"
                                            disabled={
                                              !rascunhoByStamp[e.boStamp] ||
                                              !!gravandoAutByStamp[e.boStamp]
                                            }
                                            onClick={(ev) => {
                                              ev.stopPropagation()
                                              void gravarAutorizadasEncomenda(e.boStamp)
                                            }}
                                          >
                                            {gravandoAutByStamp[e.boStamp] ? (
                                              <CircularProgress size={18} color="inherit" />
                                            ) : (
                                              labels.gravarAutorizadas
                                            )}
                                          </Button>
                                        </Box>
                                      ) : null}
                                    </>
                                  )}
                                </>
                              )}
                            </Box>
                          </Collapse>
                        </TableCell>
                      </TableRow>
                    </Fragment>
                  )
                })}
              </TableBody>
            </Table>
            </Paper>
          </PortalTableScroll>

          {totalPages > 1 ? (
            <Box
              display="flex"
              justifyContent="space-between"
              alignItems="center"
              mt={2}
              flexWrap="wrap"
              gap={1}
              flexShrink={0}
            >
              <Typography variant="body2" color="text.secondary">
                Página {page} de {totalPages} · {total} registo(s)
              </Typography>
              <Box display="flex" gap={1}>
                <Button
                  size="small"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Anterior
                </Button>
                <Button
                  size="small"
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Seguinte
                </Button>
              </Box>
            </Box>
          ) : null}
        </Box>
      )}
    </Box>
  )
}
