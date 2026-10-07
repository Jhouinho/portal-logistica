import { Fragment, useCallback, useEffect, useMemo, useState } from 'react'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  CircularProgress,
  Collapse,
  IconButton,
  MenuItem,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown'
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp'
import WarningAmberIcon from '@mui/icons-material/WarningAmber'
import {
  api,
  type ArtigoEncomendaAbertaItem,
  type ArtigoProcuraItem,
  type ArtigoSugestao,
  type EncomendaLinha,
} from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { fmtMoney, fmtDocNo, fmtDate, fmtMetodoExpedicao } from '../../shared/format'
import { ClienteNomeDisplay, clienteNomeTitle } from '../../shared/ui/ClienteNomeDisplay'
import { DateFilterField } from '../../shared/ui/DateFilterField'
import { TimeFilterField } from '../../shared/ui/TimeFilterField'
import { urgenteRowSx } from '../../shared/ui/urgenteRowSx'
import { FILTRO_METODO_OPCOES } from '../../shared/metodoExpedicaoFiltro'
import {
  StatusBadge,
  portalColHeaderSx,
  portalPanelSx,
  PortalEmptyState,
  PortalTableScroll,
  estadoSemantic,
} from '../centro/portalChrome'
import { encomendasTableSx, LinhasColGroup, linhasTableSx } from '../encomendas/linhasTableLayout'
import { GravacaoSnackbar, type GravacaoSnack } from '../encomendas/GravacaoSnackbar'
import {
  QuantidadeAutorizadaCell,
  quantidadeAutorizadaTotalEfectiva,
  stockDisponivelComSugestao,
  totalLinhaAutorizada,
} from '../encomendas/QuantidadeAutorizadaCell'
import { LinhaPrecoCell } from '../encomendas/LinhaPrecoCell'
import { useEncomendasFiltrosUrl } from '../encomendas/useEncomendasFiltrosUrl'

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
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

function rowKey(item: ArtigoProcuraItem) {
  return `${item.estadoPlaneamentoCodigo}|${item.ref}|${item.cor}`
}

function labelSugestao(a: ArtigoSugestao): string {
  return [a.ref.trim(), a.design.trim()].filter(Boolean).join(' · ')
}

function asLinha(e: ArtigoEncomendaAbertaItem): EncomendaLinha {
  return {
    biStamp: e.biStamp,
    ref: e.ref,
    descricao: e.descricao,
    cor: e.cor,
    unidade: e.unidade,
    quantidade: e.quantidade,
    quantidadeOriginalPortal: e.quantidadeOriginalPortal,
    qtt: e.qtt,
    qtt2: e.qtt2,
    quantidadePorSatisfazer: e.quantidadePorSatisfazer,
    precoUnitario: e.precoUnitario,
    precoUnitarioOriginal: e.precoUnitarioOriginal,
    quantidadeAutorizada: e.quantidadeAutorizada,
    autorizadaPor: e.autorizadaPor,
    autorizadaEm: e.autorizadaEm,
    stockDisponivel: e.stockDisponivel,
    usrinis: e.usrinis,
    usrdata: e.usrdata,
    usrhora: e.usrhora,
  }
}

function mergeLinha(
  e: ArtigoEncomendaAbertaItem,
  next: EncomendaLinha,
): ArtigoEncomendaAbertaItem {
  return {
    ...e,
    ...next,
    ref: next.ref,
    descricao: next.descricao,
  }
}

/** Autorizada no cartão do artigo: sugestão = por satisfazer quando ainda nada gravado. */
function autorizadaArtigoUi(
  item: ArtigoProcuraItem,
  detalhe: ArtigoEncomendaAbertaItem[] | undefined,
): number {
  if (detalhe && detalhe.length > 0) {
    return quantidadeAutorizadaTotalEfectiva(detalhe.map(asLinha))
  }
  if (item.quantidadeAutorizadaTotal === 0) {
    return item.quantidadePorSatisfazer
  }
  return item.quantidadeAutorizadaTotal
}

/** Disponível no cartão: desconta sugestões / rascunhos do mesmo Ref+Cor. */
function disponivelArtigoUi(
  item: ArtigoProcuraItem,
  detalhe: ArtigoEncomendaAbertaItem[] | undefined,
  baseline: Record<string, number> | undefined,
): number {
  if (detalhe && detalhe.length > 0) {
    const linhas = detalhe.map(asLinha)
    return stockDisponivelComSugestao(linhas[0], linhas, baseline)
  }
  if (item.quantidadeAutorizadaTotal === 0 && item.quantidadePorSatisfazer > 0) {
    return item.quantidadeDisponivel - item.quantidadePorSatisfazer
  }
  return item.quantidadeDisponivel
}

const PAGE_SIZE = 200

export function ArtigosResumoPage({ hideHeader = false }: { hideHeader?: boolean }) {
  const [items, setItems] = useState<ArtigoProcuraItem[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [page, setPage] = useState(1)
  const [totalItems, setTotalItems] = useState(0)

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
    metodoExpedicao,
    setMetodoExpedicao,
    temFiltroArtigo,
  } = useEncomendasFiltrosUrl()

  const [sugestoes, setSugestoes] = useState<ArtigoSugestao[]>([])
  const [loadingSugestoes, setLoadingSugestoes] = useState(false)
  const [sugestoesCor, setSugestoesCor] = useState<string[]>([])
  const [loadingSugestoesCor, setLoadingSugestoesCor] = useState(false)

  const [expanded, setExpanded] = useState<Record<string, boolean>>({})
  const [detalheByKey, setDetalheByKey] = useState<
    Record<string, ArtigoEncomendaAbertaItem[]>
  >({})
  const [loadingDetalhe, setLoadingDetalhe] = useState<Record<string, boolean>>({})
  const [erroDetalhe, setErroDetalhe] = useState<Record<string, string>>({})
  const [gravando, setGravando] = useState<Record<string, boolean>>({})
  /** Valores gravados no servidor (por biStamp), para comparar rascunho. */
  const [servidorAutByKey, setServidorAutByKey] = useState<
    Record<string, Record<string, number>>
  >({})
  const [rascunhoByKey, setRascunhoByKey] = useState<Record<string, boolean>>({})
  const [erroGravacao, setErroGravacao] = useState<GravacaoSnack | null>(null)

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
    metodoExpedicao,
  ])

  const query = useMemo(
    () => ({
      estadoPlaneamento: estado === 'Todos' ? undefined : estado,
      q: artigoDebounced || undefined,
      cor: corDebounced || undefined,
      dataDe: dataDe || undefined,
      dataAte: dataAte || undefined,
      horaDe: horaDe || undefined,
      horaAte: horaAte || undefined,
      clienteNoContem: clienteDebounced || undefined,
      metodoExpedicao:
        metodoExpedicao && metodoExpedicao !== 'todos' ? metodoExpedicao : undefined,
      page,
      pageSize: PAGE_SIZE,
    }),
    [
      estado,
      artigoDebounced,
      corDebounced,
      dataDe,
      dataAte,
      horaDe,
      horaAte,
      clienteDebounced,
      metodoExpedicao,
      page,
    ],
  )

  useEffect(() => {
    let cancel = false
    setLoading(true)
    setErro(null)
    api
      .artigosProcuraAberta(query)
      .then((res) => {
        if (cancel) return
        setItems(res.items)
        setTotalItems(res.totalItems)
        setDetalheByKey({})
        setErroDetalhe({})
        setLoadingDetalhe({})
        if (!temFiltroArtigo) setExpanded({})
      })
      .catch((e: Error) => {
        if (!cancel) {
          setErro(e.message)
          setItems([])
          setTotalItems(0)
        }
      })
      .finally(() => {
        if (!cancel) setLoading(false)
      })
    return () => {
      cancel = true
    }
  }, [query, temFiltroArtigo])

  const totalPages = Math.max(1, Math.ceil(totalItems / PAGE_SIZE))

  function onEstadoChange(value: string) {
    setEstado(value)
  }

  const carregarDetalhe = useCallback(async (item: ArtigoProcuraItem) => {
    const key = rowKey(item)
    setLoadingDetalhe((prev) => ({ ...prev, [key]: true }))
    setErroDetalhe((prev) => {
      const n = { ...prev }
      delete n[key]
      return n
    })
    try {
      const res = await api.artigoEncomendasAbertas(item.ref, {
        cor: item.cor,
        estadoPlaneamento: item.estadoPlaneamentoCodigo,
      })
      setDetalheByKey((prev) => ({ ...prev, [key]: res.encomendas }))
      const baseline: Record<string, number> = {}
      for (const e of res.encomendas) {
        baseline[e.biStamp] = e.quantidadeAutorizada
      }
      setServidorAutByKey((prev) => ({ ...prev, [key]: baseline }))
      setRascunhoByKey((prev) => {
        const n = { ...prev }
        delete n[key]
        return n
      })
    } catch (e) {
      setErroDetalhe((prev) => ({
        ...prev,
        [key]: e instanceof Error ? e.message : labels.erroGenerico,
      }))
    } finally {
      setLoadingDetalhe((prev) => {
        const n = { ...prev }
        delete n[key]
        return n
      })
    }
  }, [])

  function marcarRascunho(
    key: string,
    linhas: ArtigoEncomendaAbertaItem[],
    baselineOverride?: Record<string, number>,
  ) {
    const baseline = baselineOverride ?? servidorAutByKey[key] ?? {}
    const dirty = linhas.some(
      (l) => (baseline[l.biStamp] ?? 0) !== l.quantidadeAutorizada,
    )
    setRascunhoByKey((prev) => ({ ...prev, [key]: dirty }))
  }

  /** Grava na BD as quantidades autorizadas do rascunho. */
  async function gravarRascunho(item: ArtigoProcuraItem) {
    const key = rowKey(item)
    const linhas = detalheByKey[key] ?? []
    const baseline = servidorAutByKey[key] ?? {}
    const aGravar = linhas.filter(
      (l) => (baseline[l.biStamp] ?? 0) !== l.quantidadeAutorizada,
    )
    if (aGravar.length === 0) {
      setRascunhoByKey((prev) => ({ ...prev, [key]: false }))
      return
    }

    setGravando((prev) => ({ ...prev, [key]: true }))
    try {
      const nextBaseline = { ...baseline }
      for (const l of aGravar) {
        const res = await api.atualizarQuantidadeAutorizada(l.biStamp, {
          quantidadeAutorizada: l.quantidadeAutorizada,
          valorAnteriorEsperado: baseline[l.biStamp] ?? l.quantidadeAutorizada,
          permitirAcimaStock: false,
        })
        nextBaseline[l.biStamp] = res.quantidadeAutorizada
        patchLinhaDetalhe(key, {
          ...asLinha(l),
          quantidadeAutorizada: res.quantidadeAutorizada,
          autorizadaPor: res.autorizadaPor,
          autorizadaEm: res.autorizadaEm,
          quantidade: res.quantidade,
          qtt: res.quantidade,
          quantidadeOriginalPortal: res.quantidadeOriginalPortal,
          quantidadePorSatisfazer: res.quantidadePorSatisfazer,
          stockDisponivel:
            l.stockDisponivel + (baseline[l.biStamp] ?? l.quantidadeAutorizada) - res.quantidadeAutorizada,
        })
      }
      setServidorAutByKey((prev) => ({ ...prev, [key]: nextBaseline }))
      setRascunhoByKey((prev) => ({ ...prev, [key]: false }))
      setErroGravacao({ message: labels.alocacaoOk, severity: 'success' })
    } catch (e) {
      setErroGravacao({
        message: e instanceof Error ? e.message : labels.erroGenerico,
        severity: 'error',
      })
      await carregarDetalhe(item)
    } finally {
      setGravando((prev) => {
        const n = { ...prev }
        delete n[key]
        return n
      })
    }
  }

  async function descartarRascunho(item: ArtigoProcuraItem) {
    await carregarDetalhe(item)
    setErroGravacao({
      message: 'Alterações descartadas.',
      severity: 'info',
    })
  }

  function patchLinhaDetalhe(key: string, next: EncomendaLinha) {
    setDetalheByKey((prev) => {
      const cur = prev[key]
      if (!cur) return prev
      const updated = cur.map((x) => (x.biStamp === next.biStamp ? mergeLinha(x, next) : x))
      setItems((itemsPrev) =>
        itemsPrev.map((item) => {
          if (rowKey(item) !== key) return item
          return {
            ...item,
            quantidadeEncomendada: updated.reduce((s, l) => s + l.quantidadeOriginalPortal, 0),
            quantidadeFornecida: updated.reduce((s, l) => s + l.qtt2, 0),
            quantidadePorSatisfazer: updated.reduce((s, l) => s + l.quantidadePorSatisfazer, 0),
            // Mantém totais “servidor”; a UI usa autorizadaArtigoUi / disponivelArtigoUi.
            quantidadeAutorizadaTotal: updated.reduce((s, l) => s + l.quantidadeAutorizada, 0),
            quantidadeDisponivel: updated[0]?.stockDisponivel ?? item.quantidadeDisponivel,
            totalLinhas: updated.length,
            totalEncomendas: new Set(updated.map((l) => l.boStamp)).size,
          }
        }),
      )
      return { ...prev, [key]: updated }
    })
  }

  function patchLinhaDraft(key: string, next: EncomendaLinha) {
    setDetalheByKey((prev) => {
      const cur = prev[key]
      if (!cur) return prev
      const updated = cur.map((x) => (x.biStamp === next.biStamp ? mergeLinha(x, next) : x))
      marcarRascunho(key, updated)
      setItems((itemsPrev) =>
        itemsPrev.map((item) => {
          if (rowKey(item) !== key) return item
          return {
            ...item,
            quantidadeAutorizadaTotal: updated.reduce((s, l) => s + l.quantidadeAutorizada, 0),
            quantidadeDisponivel: updated[0]?.stockDisponivel ?? item.quantidadeDisponivel,
          }
        }),
      )
      return { ...prev, [key]: updated }
    })
  }

  function toggleExpand(item: ArtigoProcuraItem) {
    const key = rowKey(item)
    const nextOpen = !expanded[key]
    setExpanded((prev) => ({ ...prev, [key]: nextOpen }))
    if (nextOpen && !detalheByKey[key] && !loadingDetalhe[key]) {
      void carregarDetalhe(item)
    }
  }

  useEffect(() => {
    if (loading) return
    if (!temFiltroArtigo) return

    const next: Record<string, boolean> = {}
    for (const item of items) {
      const key = rowKey(item)
      next[key] = true
      if (!detalheByKey[key] && !loadingDetalhe[key]) {
        void carregarDetalhe(item)
      }
    }
    setExpanded(next)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items, temFiltroArtigo, loading])

  const seccoes = useMemo(() => {
    const dp = items.filter((i) => i.estadoPlaneamentoCodigo === 'DP')
    const ac = items.filter((i) => i.estadoPlaneamentoCodigo === 'AC')
    return [
      { codigo: 'DP', titulo: labels.dentroPlaneamento, rows: dp },
      { codigo: 'AC', titulo: labels.aposCorte, rows: ac },
    ].filter((s) => s.rows.length > 0)
  }, [items])

  return (
    <Box>
      {!hideHeader && (
        <>
          <Typography variant="h5" fontWeight={700} gutterBottom>
            {labels.rastreio}
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Procura aberta por artigo · Página {page} de {totalPages} · {totalItems}{' '}
            registo(s)
          </Typography>
        </>
      )}
      {hideHeader && (
        <Typography variant="body2" color="text.secondary" mb={2}>
          Procura aberta por artigo · Página {page} de {totalPages} · {totalItems}{' '}
          registo(s)
        </Typography>
      )}

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
          onChange={(e) => setClienteNo(e.target.value)}
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
          }}
          onChange={(_, value) => {
            if (typeof value === 'string') {
              setArtigoInput(value)
            } else if (value) {
              setArtigoInput(value.ref.trim())
            } else {
              setArtigoInput('')
            }
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
              placeholder="Ref. / designação…"
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
          }}
          onChange={(_, value) => {
            setCorInput(typeof value === 'string' ? value : value ?? '')
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
          onChange={(e) => setMetodoExpedicao(e.target.value)}
          InputLabelProps={{ shrink: true }}
          sx={{ flex: '1.1 1 0', minWidth: 168, maxWidth: 220 }}
        >
          {FILTRO_METODO_OPCOES.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              {o.label()}
            </MenuItem>
          ))}
        </TextField>
      </Box>

      {erro && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {erro}
        </Alert>
      )}

      <GravacaoSnackbar snack={erroGravacao} onClose={() => setErroGravacao(null)} />

      {loading ? (
        <Box display="flex" justifyContent="center" py={6}>
          <CircularProgress />
        </Box>
      ) : items.length === 0 ? (
        <PortalEmptyState message="Sem artigos em procura aberta para os filtros actuais." />
      ) : (
        <>
          {seccoes.map((sec) => (
            <Box key={sec.codigo} sx={{ mb: 3 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                {chipPlaneamento(sec.codigo)}
                <Typography variant="subtitle2" color="text.secondary">
                  {sec.rows.length} artigo{sec.rows.length === 1 ? '' : 's'}
                </Typography>
              </Box>
              <PortalTableScroll>
              <Paper sx={portalPanelSx}>
                <Table size="small" sx={encomendasTableSx}>
                  <colgroup>
                    <col style={{ width: '3%' }} />
                    <col style={{ width: '9%' }} />
                    <col style={{ width: '28%' }} />
                    <col style={{ width: '8%' }} />
                    <col style={{ width: '8%' }} />
                    <col style={{ width: '8%' }} />
                    <col style={{ width: '8%' }} />
                    <col style={{ width: '8%' }} />
                    <col style={{ width: '6%' }} />
                    <col style={{ width: '12%' }} />
                    <col style={{ width: '2%' }} />
                  </colgroup>
                  <TableHead>
                    <TableRow>
                      <TableCell padding="checkbox" sx={portalColHeaderSx} />
                      <TableCell sx={portalColHeaderSx}>Artigo</TableCell>
                      <TableCell sx={portalColHeaderSx}>Descrição</TableCell>
                      <TableCell sx={portalColHeaderSx}>Cor</TableCell>
                      <TableCell align="right" sx={portalColHeaderSx}>
                        Encomendada
                      </TableCell>
                      <TableCell align="right" sx={portalColHeaderSx}>
                        Por satisfazer
                      </TableCell>
                      <TableCell align="right" sx={portalColHeaderSx}>
                        Autorizada
                      </TableCell>
                      <TableCell align="right" sx={portalColHeaderSx}>
                        {labels.colDisponivelPrevisto}
                      </TableCell>
                      <TableCell align="right" sx={portalColHeaderSx}>
                        Encomendas
                      </TableCell>
                      <TableCell sx={portalColHeaderSx} />
                      <TableCell sx={[portalColHeaderSx, { width: 48, px: 0.5 }]} />
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {sec.rows.map((item) => {
                      const key = rowKey(item)
                      const open = !!expanded[key]
                      const detalhe = detalheByKey[key]
                      const autUi = autorizadaArtigoUi(item, detalhe)
                      const dispUi = disponivelArtigoUi(
                        item,
                        detalhe,
                        servidorAutByKey[key],
                      )
                      return (
                        <Fragment key={key}>
                          <TableRow
                            hover
                            onClick={() => toggleExpand(item)}
                            selected={false}
                            sx={{
                              cursor: 'pointer',
                              '& > *': { borderBottom: open ? 'unset' : undefined },
                              ...urgenteRowSx(item.urgente),
                            }}
                          >
                            <TableCell padding="checkbox">
                              <IconButton
                                size="small"
                                aria-label={open ? 'Fechar distribuição' : 'Ver distribuição'}
                                onClick={(ev) => {
                                  ev.stopPropagation()
                                  toggleExpand(item)
                                }}
                              >
                                {open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
                              </IconButton>
                            </TableCell>
                            <TableCell>
                              <Typography variant="body2" fontWeight={700} component="span">
                                {item.ref}
                              </Typography>
                            </TableCell>
                            <TableCell>{item.descricao}</TableCell>
                            <TableCell>{item.cor?.trim() ? item.cor : '—'}</TableCell>
                            <TableCell align="right">{fmt(item.quantidadeEncomendada)}</TableCell>
                            <TableCell align="right">{fmt(item.quantidadePorSatisfazer)}</TableCell>
                            <TableCell align="right">{fmt(autUi)}</TableCell>
                            <TableCell
                              align="right"
                              sx={{
                                fontVariantNumeric: 'tabular-nums',
                                color: dispUi < 0 ? 'warning.main' : undefined,
                                fontWeight: dispUi < 0 ? 700 : undefined,
                              }}
                            >
                              {fmt(dispUi)}
                            </TableCell>
                            <TableCell align="right">{item.totalEncomendas}</TableCell>
                            <TableCell sx={{ whiteSpace: 'nowrap' }}>
                              {chipPlaneamento(item.estadoPlaneamentoCodigo, true)}
                            </TableCell>
                            <TableCell
                              onClick={(ev) => ev.stopPropagation()}
                              sx={{ px: 0.5, textAlign: 'center' }}
                              aria-label={item.urgente ? labels.urgente : undefined}
                            />
                          </TableRow>
                          <TableRow sx={{ display: open ? 'table-row' : 'none' }}>
                            <TableCell
                              colSpan={11}
                              sx={{
                                py: 0,
                                px: 0,
                                borderBottom: (t) => `2px solid ${t.palette.divider}`,
                                bgcolor: 'background.default',
                              }}
                            >
                              <Collapse in={open} timeout="auto" unmountOnExit>
                                <Box
                                  sx={{
                                    my: 1.25,
                                    mx: 1.5,
                                    ml: 5,
                                    p: 1.5,
                                    borderRadius: 1,
                                    bgcolor: 'background.paper',
                                    border: 1,
                                    borderColor: 'divider',
                                    borderLeft: 4,
                                    borderLeftColor: sec.codigo === 'AC' ? 'warning.main' : 'info.main',
                                    boxShadow: 1,
                                  }}
                                >
                                  {loadingDetalhe[key] && (
                                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 2 }}>
                                      <CircularProgress size={24} />
                                    </Box>
                                  )}
                                  {erroDetalhe[key] && (
                                    <Alert severity="error" sx={{ mb: 1 }}>
                                      {erroDetalhe[key]}
                                    </Alert>
                                  )}
                                  {!loadingDetalhe[key] && !erroDetalhe[key] && (
                                    <Box
                                      display="flex"
                                      flexWrap="wrap"
                                      gap={1.5}
                                      alignItems="center"
                                      mb={1.5}
                                      onClick={(ev) => ev.stopPropagation()}
                                    >
                                      <Button
                                        variant="contained"
                                        color="success"
                                        size="small"
                                        disabled={!rascunhoByKey[key] || !!gravando[key]}
                                        onClick={() => void gravarRascunho(item)}
                                      >
                                        {gravando[key] ? (
                                          <CircularProgress size={18} color="inherit" />
                                        ) : (
                                          labels.gravarAutorizadas
                                        )}
                                      </Button>
                                      {rascunhoByKey[key] ? (
                                        <Button
                                          variant="outlined"
                                          size="small"
                                          disabled={!!gravando[key]}
                                          onClick={() => void descartarRascunho(item)}
                                        >
                                          {labels.descartarRascunho}
                                        </Button>
                                      ) : null}
                                    </Box>
                                  )}
                                  {!loadingDetalhe[key] && !erroDetalhe[key] && (
                                    <Table size="small" sx={linhasTableSx}>
                                      <LinhasColGroup variant="rastreioSemArtigo" />
                                      <TableHead>
                                        <TableRow>
                                          <TableCell>Nº</TableCell>
                                          <TableCell sx={{ width: 48, px: 0.5 }} />
                                          <TableCell>Cliente</TableCell>
                                          <TableCell>{labels.colEntrega}</TableCell>
                                          <TableCell>{labels.colMetodoExpedicao}</TableCell>
                                          <TableCell>Cor</TableCell>
                                          <TableCell>Unidade</TableCell>
                                          <TableCell align="right">Por satisfazer</TableCell>
                                          <TableCell align="center">Autorizada</TableCell>
                                          <TableCell align="center">Preço</TableCell>
                                          <TableCell align="right">Total</TableCell>
                                          <TableCell align="right">{labels.colDisponivelPrevisto}</TableCell>
                                        </TableRow>
                                      </TableHead>
                                      <TableBody>
                                        {(detalheByKey[key] ?? []).length === 0 ? (
                                          <TableRow>
                                            <TableCell colSpan={12}>
                                              <Typography variant="body2" color="text.secondary">
                                                Sem linhas de distribuição.
                                              </Typography>
                                            </TableCell>
                                          </TableRow>
                                        ) : (
                                          (() => {
                                            const linhasGrupo = (detalheByKey[key] ?? []).map(asLinha)
                                            const baseline = servidorAutByKey[key]
                                            return linhasGrupo.map((linha, idx) => {
                                            const e = (detalheByKey[key] ?? [])[idx]!
                                            const disponivelUi = stockDisponivelComSugestao(
                                              linha,
                                              linhasGrupo,
                                              baseline,
                                            )
                                            return (
                                              <TableRow key={e.biStamp} sx={urgenteRowSx(e.urgente)}>
                                                <TableCell>{fmtDocNo(e.numeroEncomenda)}</TableCell>
                                                <TableCell
                                                  sx={{ px: 0.5, textAlign: 'center' }}
                                                  aria-label={e.urgente ? labels.urgente : undefined}
                                                />
                                                <TableCell
                                                  title={`${e.clienteNo} — ${clienteNomeTitle(e.clienteNome, e.clienteNome2)}`}
                                                >
                                                  <ClienteNomeDisplay
                                                    nome={e.clienteNome}
                                                    nome2={e.clienteNome2}
                                                    clienteNo={e.clienteNo}
                                                    showClienteNo
                                                    compact
                                                  />
                                                </TableCell>
                                                <TableCell>{fmtDate(e.dataEntrega)}</TableCell>
                                                <TableCell>{fmtMetodoExpedicao(e.metodoExpedicao)}</TableCell>
                                                <TableCell>{e.cor?.trim() ? e.cor : '—'}</TableCell>
                                                <TableCell>{e.unidade?.trim() ? e.unidade : '—'}</TableCell>
                                                <TableCell align="right">
                                                  {fmt(e.quantidadePorSatisfazer)}
                                                </TableCell>
                                                <TableCell align="center" sx={{ px: 0.5 }}>
                                                  <QuantidadeAutorizadaCell
                                                    linha={linha}
                                                    deferSave
                                                    onSaved={(next) => patchLinhaDetalhe(key, next)}
                                                    onDraftChange={(next) => patchLinhaDraft(key, next)}
                                                    onNotify={setErroGravacao}
                                                  />
                                                </TableCell>
                                                <TableCell align="center" sx={{ px: 0.5 }}>
                                                  <LinhaPrecoCell
                                                    linha={linha}
                                                    onSaved={(next) => patchLinhaDetalhe(key, next)}
                                                    onNotify={setErroGravacao}
                                                  />
                                                </TableCell>
                                                <TableCell align="right">
                                                  {fmtMoney(totalLinhaAutorizada(e))}
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
                                              </TableRow>
                                            )
                                          })
                                          })()
                                        )}
                                      </TableBody>
                                    </Table>
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
            </Box>
          ))}
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
                Página {page} de {totalPages} · {totalItems} registo(s)
              </Typography>
              <Box display="flex" gap={1}>
                <Button
                  size="small"
                  disabled={page <= 1 || loading}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Anterior
                </Button>
                <Button
                  size="small"
                  disabled={page >= totalPages || loading}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Seguinte
                </Button>
              </Box>
            </Box>
          ) : null}
        </>
      )}
    </Box>
  )
}
