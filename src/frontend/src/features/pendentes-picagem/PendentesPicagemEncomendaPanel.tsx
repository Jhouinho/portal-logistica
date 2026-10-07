import { Fragment, useCallback, useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Collapse,
  IconButton,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material'
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown'
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp'
import {
  api,
  type PendentePicagemEncomendaItem,
  type PendentePicagemLinha,
} from '../../shared/api'
import { fmtDate, fmtDocNo } from '../../shared/format'
import { labels } from '../../shared/i18n/labels'
import { useOperacoesHub } from '../../shared/signalr'
import { DateFilterField } from '../../shared/ui/DateFilterField'
import { PortalTableScroll } from '../centro/portalChrome'
import { encomendasTableSx } from '../encomendas/linhasTableLayout'

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

/** Alinhado ao Hub de Encomendas (padrão 1A). */
const PAGE_SIZE = 200

type Props = {
  hideHeader?: boolean
}

export function PendentesPicagemEncomendaPanel({ hideHeader = false }: Props) {
  const [dataDe, setDataDe] = useState('')
  const [dataAte, setDataAte] = useState('')
  const [obrano, setObrano] = useState('')
  const [artigo, setArtigo] = useState('')
  const [cor, setCor] = useState('')
  const [cliente, setCliente] = useState('')
  const [page, setPage] = useState(1)

  const [items, setItems] = useState<PendentePicagemEncomendaItem[]>([])
  const [totalItems, setTotalItems] = useState(0)
  const [loading, setLoading] = useState(false)
  const [erro, setErro] = useState<string | null>(null)

  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())
  const [linhasByStamp, setLinhasByStamp] = useState<Record<string, PendentePicagemLinha[]>>(
    {},
  )
  const [loadingLinhas, setLoadingLinhas] = useState<Record<string, boolean>>({})
  const [erroLinhas, setErroLinhas] = useState<Record<string, string>>({})

  const carregar = useCallback(async () => {
    setLoading(true)
    setErro(null)
    try {
      const obranoNum = obrano.trim() ? Number(obrano.trim()) : undefined
      const res = await api.pendentesPicagem({
        dataDe: dataDe || undefined,
        dataAte: dataAte || undefined,
        obrano: obranoNum != null && !Number.isNaN(obranoNum) ? obranoNum : undefined,
        artigoRef: artigo.trim() || undefined,
        artigoCor: cor.trim() || undefined,
        clienteNomeContem: cliente.trim() || undefined,
        page,
        pageSize: PAGE_SIZE,
      })
      setItems(res.items)
      setTotalItems(res.totalItems)
      setExpanded(new Set())
      setLinhasByStamp({})
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
      setItems([])
      setTotalItems(0)
    } finally {
      setLoading(false)
    }
  }, [dataDe, dataAte, obrano, artigo, cor, cliente, page])

  useEffect(() => {
    void carregar()
  }, [carregar])

  useOperacoesHub(true, {
    onEncomendaAlterada: () => void carregar(),
    onDossier66Alterado: () => void carregar(),
    onKappsAlterado: () => void carregar(),
  })

  async function carregarLinhas(boStamp: string) {
    setLoadingLinhas((prev) => ({ ...prev, [boStamp]: true }))
    setErroLinhas((prev) => {
      const next = { ...prev }
      delete next[boStamp]
      return next
    })
    try {
      const linhas = await api.pendentesPicagemLinhas(boStamp)
      setLinhasByStamp((prev) => ({ ...prev, [boStamp]: linhas }))
    } catch (e) {
      setErroLinhas((prev) => ({
        ...prev,
        [boStamp]: e instanceof Error ? e.message : labels.erroGenerico,
      }))
    } finally {
      setLoadingLinhas((prev) => {
        const next = { ...prev }
        delete next[boStamp]
        return next
      })
    }
  }

  function toggleExpand(boStamp: string) {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(boStamp)) next.delete(boStamp)
      else next.add(boStamp)
      return next
    })
    if (!linhasByStamp[boStamp] && !loadingLinhas[boStamp]) {
      void carregarLinhas(boStamp)
    }
  }

  const totalPages = Math.max(1, Math.ceil(totalItems / PAGE_SIZE))

  return (
    <Box>
      {!hideHeader && (
        <>
          <Typography variant="h5" fontWeight={700} gutterBottom>
            {labels.pendentesPicagem}
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            {labels.pendentesPicagemHint}
          </Typography>
        </>
      )}

      <Box display="flex" gap={2} mb={2} flexWrap="wrap" alignItems="flex-start">
        <DateFilterField
          label="Data de"
          value={dataDe}
          onChange={(v) => {
            setDataDe(v)
            setPage(1)
          }}
        />
        <DateFilterField
          label="Data até"
          value={dataAte}
          onChange={(v) => {
            setDataAte(v)
            setPage(1)
          }}
        />
        <TextField
          label="Nº"
          size="small"
          value={obrano}
          onChange={(e) => {
            setObrano(e.target.value)
            setPage(1)
          }}
          sx={{ width: 140 }}
        />
        <TextField
          label="Cliente"
          size="small"
          value={cliente}
          onChange={(e) => {
            setCliente(e.target.value)
            setPage(1)
          }}
          placeholder="Nome…"
          sx={{ width: 200 }}
        />
        <TextField
          label="Artigo"
          size="small"
          value={artigo}
          onChange={(e) => {
            setArtigo(e.target.value)
            setPage(1)
          }}
          placeholder="Ref.…"
          sx={{ width: 180 }}
        />
        <TextField
          label="Cor"
          size="small"
          value={cor}
          onChange={(e) => {
            setCor(e.target.value)
            setPage(1)
          }}
          sx={{ width: 140 }}
        />
      </Box>

      {erro && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {erro}
        </Alert>
      )}

      {loading ? (
        <Box display="flex" justifyContent="center" py={6}>
          <CircularProgress />
        </Box>
      ) : (
        <PortalTableScroll>
          <Paper>
            <Table size="small" sx={encomendasTableSx}>
              <TableHead>
                <TableRow>
                  <TableCell padding="checkbox" sx={{ width: 40, px: 0.5 }} />
                  <TableCell sx={{ width: 72 }}>Nº</TableCell>
                  <TableCell>Cliente</TableCell>
                  <TableCell sx={{ width: 120 }}>{labels.colEntrega}</TableCell>
                  <TableCell align="right" sx={{ width: 80 }}>
                    Linhas
                  </TableCell>
                  <TableCell align="right" sx={{ width: 130 }}>
                    {labels.colQtdPendentePicagem}
                  </TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {items.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6}>
                      <Typography variant="body2" color="text.secondary">
                        {labels.pendentesPicagemVazio}
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
                {items.map((e) => {
                  const open = expanded.has(e.boStamp)
                  const linhas = linhasByStamp[e.boStamp]
                  const aCarregar = !!loadingLinhas[e.boStamp]
                  const erroLinha = erroLinhas[e.boStamp]
                  return (
                    <Fragment key={e.boStamp}>
                      <TableRow
                        hover
                        onClick={() => toggleExpand(e.boStamp)}
                        selected={open}
                        sx={{
                          cursor: 'pointer',
                          '& > *': { borderBottom: open ? 'unset' : undefined },
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
                        <TableCell>{fmtDocNo(e.numeroEncomenda)}</TableCell>
                        <TableCell>
                          {e.clienteNo} — {e.clienteNome}
                          {e.clienteNome2?.trim() ? (
                            <Typography variant="caption" display="block" color="text.secondary">
                              {e.clienteNome2}
                            </Typography>
                          ) : null}
                        </TableCell>
                        <TableCell>{fmtDate(e.dataEntrega)}</TableCell>
                        <TableCell align="right">{e.totalLinhasPendentes}</TableCell>
                        <TableCell align="right">
                          <Typography component="span" fontWeight={700} color="warning.main">
                            {fmt(e.quantidadePendenteTotal)}
                          </Typography>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell
                          colSpan={6}
                          sx={{
                            py: 0,
                            borderBottom: open
                              ? ((t) => `2px solid ${t.palette.divider}`)
                              : 0,
                            bgcolor: open ? 'background.default' : undefined,
                          }}
                        >
                          <Collapse in={open} timeout="auto" unmountOnExit>
                            <Box sx={{ py: 0.75, px: 0.5 }}>
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
                              {!aCarregar && !erroLinha && linhas && (
                                <Table size="small">
                                  <TableHead>
                                    <TableRow>
                                      <TableCell>Artigo</TableCell>
                                      <TableCell>Cor</TableCell>
                                      <TableCell align="right">{labels.colQtdOriginal}</TableCell>
                                      <TableCell align="right">{labels.colQtd66}</TableCell>
                                      <TableCell align="right">
                                        {labels.colQtdPendentePicagem}
                                      </TableCell>
                                    </TableRow>
                                  </TableHead>
                                  <TableBody>
                                    {linhas.length === 0 ? (
                                      <TableRow>
                                        <TableCell colSpan={5}>
                                          <Typography variant="body2" color="text.secondary">
                                            {labels.pendentesPicagemVazio}
                                          </Typography>
                                        </TableCell>
                                      </TableRow>
                                    ) : (
                                      linhas.map((l) => (
                                        <TableRow key={l.biStamp}>
                                          <TableCell>
                                            <Typography variant="body2" fontWeight={600}>
                                              {l.ref}
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                              {l.designacao}
                                            </Typography>
                                          </TableCell>
                                          <TableCell>{l.cor?.trim() ? l.cor : '—'}</TableCell>
                                          <TableCell align="right">{fmt(l.qtt)}</TableCell>
                                          <TableCell align="right">{fmt(l.sum66)}</TableCell>
                                          <TableCell align="right">
                                            <Typography
                                              component="span"
                                              fontWeight={700}
                                              color="warning.main"
                                            >
                                              {fmt(l.pending)}
                                            </Typography>
                                          </TableCell>
                                        </TableRow>
                                      ))
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
      )}

      <Box display="flex" alignItems="center" gap={2} mt={2}>
        <Typography variant="body2" color="text.secondary">
          {totalItems} encomenda{totalItems === 1 ? '' : 's'} · página {page} / {totalPages}
        </Typography>
        <Button size="small" disabled={page <= 1 || loading} onClick={() => setPage((p) => p - 1)}>
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
  )
}
