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
  type CorteEncomendaItem,
  type CorteQuantidadeLinha,
} from '../../shared/api'
import { fmtDocNo } from '../../shared/format'
import { labels } from '../../shared/i18n/labels'
import { DateFilterField } from '../../shared/ui/DateFilterField'
import { urgenteRowSx } from '../../shared/ui/urgenteRowSx'
import { PortalTableScroll, portalPageScrollSx } from '../centro/portalChrome'
import { encomendasTableSx } from '../encomendas/linhasTableLayout'

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

function numeroLista(e: CorteEncomendaItem) {
  return e.numeroDossier ?? e.numeroEncomenda
}

const pageSize = 25

export function CortesQuantidadePage() {
  const [dataDe, setDataDe] = useState('')
  const [dataAte, setDataAte] = useState('')
  const [obrano, setObrano] = useState('')
  const [artigo, setArtigo] = useState('')
  const [cor, setCor] = useState('')
  const [page, setPage] = useState(1)

  const [items, setItems] = useState<CorteEncomendaItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(false)
  const [erro, setErro] = useState<string | null>(null)

  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())
  const [linhasByStamp, setLinhasByStamp] = useState<Record<string, CorteQuantidadeLinha[]>>({})
  const [loadingLinhas, setLoadingLinhas] = useState<Record<string, boolean>>({})
  const [erroLinhas, setErroLinhas] = useState<Record<string, string>>({})

  const carregar = useCallback(async () => {
    setLoading(true)
    setErro(null)
    try {
      const obranoNum = obrano.trim() ? Number(obrano.trim()) : undefined
      const res = await api.cortesQuantidade({
        dataDe: dataDe || undefined,
        dataAte: dataAte || undefined,
        obrano: obranoNum != null && !Number.isNaN(obranoNum) ? obranoNum : undefined,
        artigoRef: artigo.trim() || undefined,
        artigoCor: cor.trim() || undefined,
        page,
        pageSize,
      })
      setItems(res.items)
      setTotal(res.total)
      setExpanded(new Set())
      setLinhasByStamp({})
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
      setItems([])
      setTotal(0)
    } finally {
      setLoading(false)
    }
  }, [dataDe, dataAte, obrano, artigo, cor, page])

  useEffect(() => {
    void carregar()
  }, [carregar])

  async function carregarLinhas(boStamp: string) {
    setLoadingLinhas((prev) => ({ ...prev, [boStamp]: true }))
    setErroLinhas((prev) => {
      const next = { ...prev }
      delete next[boStamp]
      return next
    })
    try {
      const linhas = await api.cortesQuantidadeLinhas(boStamp, {
        artigoRef: artigo.trim() || undefined,
        artigoCor: cor.trim() || undefined,
      })
      setLinhasByStamp((prev) => ({ ...prev, [boStamp]: linhas }))
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

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <Box sx={portalPageScrollSx}>
      <Typography variant="h5" fontWeight={700} gutterBottom>
        {labels.cortesQuantidade}
      </Typography>
      <Typography variant="body2" color="text.secondary" mb={2}>
        {labels.cortesQuantidadeHint}
      </Typography>

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
          label="Artigo"
          size="small"
          value={artigo}
          onChange={(e) => {
            setArtigo(e.target.value)
            setPage(1)
          }}
          placeholder="Ref. / designação…"
          sx={{ width: 220 }}
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
                <TableCell sx={{ width: 110 }}>Data</TableCell>
                <TableCell sx={{ width: 80 }}>Hora</TableCell>
                <TableCell align="right" sx={{ width: 72 }}>
                  Linhas
                </TableCell>
                <TableCell align="right" sx={{ width: 110 }}>
                  {labels.colQtdDocumento}
                </TableCell>
                <TableCell align="right" sx={{ width: 96 }}>
                  {labels.colExpedida}
                </TableCell>
                <TableCell align="right" sx={{ width: 96 }}>
                  {labels.colPendenteEntrega}
                </TableCell>
                <TableCell sx={{ width: 48, px: 0.5 }} />
                <TableCell sx={{ width: 120 }}>Estado</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {items.length === 0 && (
                <TableRow>
                  <TableCell colSpan={11}>
                    <Typography variant="body2" color="text.secondary">
                      Sem dossiers com quantidades não entregues.
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
                      <TableCell>{fmtDocNo(numeroLista(e))}</TableCell>
                      <TableCell>
                        {e.clienteNo} — {e.clienteNome}
                        {e.clienteNome2?.trim() ? (
                          <Typography variant="caption" display="block" color="text.secondary">
                            {e.clienteNome2}
                          </Typography>
                        ) : null}
                      </TableCell>
                      <TableCell>{e.data}</TableCell>
                      <TableCell>{e.hora}</TableCell>
                      <TableCell align="right">{e.totalLinhas}</TableCell>
                      <TableCell align="right">{fmt(e.quantidadeDocumento)}</TableCell>
                      <TableCell align="right">{fmt(e.quantidadeExpedida)}</TableCell>
                      <TableCell align="right">
                        <Typography component="span" fontWeight={700} color="warning.main">
                          {fmt(e.quantidadePendenteEntrega)}
                        </Typography>
                      </TableCell>
                      <TableCell
                        sx={{ px: 0.5, textAlign: 'center' }}
                        aria-label={e.urgente ? labels.urgente : undefined}
                      />
                      <TableCell>{e.estado || labels.estadoFechada}</TableCell>
                    </TableRow>
                    <TableRow>
                      <TableCell
                        colSpan={11}
                        sx={{
                          py: 0,
                          borderBottom: open ? ((t) => `2px solid ${t.palette.divider}`) : 0,
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
                                    <TableCell>Unidade</TableCell>
                                    <TableCell align="right">{labels.colQtdDocumento}</TableCell>
                                    <TableCell align="right">{labels.colExpedida}</TableCell>
                                    <TableCell align="right">{labels.colPendenteEntrega}</TableCell>
                                  </TableRow>
                                </TableHead>
                                <TableBody>
                                  {linhas.length === 0 ? (
                                    <TableRow>
                                      <TableCell colSpan={6}>
                                        <Typography variant="body2" color="text.secondary">
                                          Sem linhas neste filtro.
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
                                            {l.descricao}
                                          </Typography>
                                        </TableCell>
                                        <TableCell>
                                          {l.cor?.trim() ? l.cor : '—'}
                                        </TableCell>
                                        <TableCell>{l.unidade || '—'}</TableCell>
                                        <TableCell align="right">
                                          {fmt(l.quantidadeDocumento)}
                                        </TableCell>
                                        <TableCell align="right">
                                          {fmt(l.quantidadeExpedida)}
                                        </TableCell>
                                        <TableCell align="right">
                                          <Typography
                                            component="span"
                                            fontWeight={l.quantidadePendenteEntrega > 0 ? 700 : 400}
                                            color={
                                              l.quantidadePendenteEntrega > 0
                                                ? 'warning.main'
                                                : 'text.secondary'
                                            }
                                          >
                                            {fmt(l.quantidadePendenteEntrega)}
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
          {total} dossier{total === 1 ? '' : 's'} · página {page} / {totalPages}
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
