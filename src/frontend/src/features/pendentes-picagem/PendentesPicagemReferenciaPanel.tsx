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
import { api, type PendentePicagemReferenciaItem } from '../../shared/api'
import { fmtDocNo } from '../../shared/format'
import { labels } from '../../shared/i18n/labels'
import { useOperacoesHub } from '../../shared/signalr'
import { ClienteNomeDisplay, clienteNomeTitle } from '../../shared/ui/ClienteNomeDisplay'
import { DateFilterField } from '../../shared/ui/DateFilterField'
import { PortalTableScroll } from '../centro/portalChrome'
import { encomendasTableSx } from '../encomendas/linhasTableLayout'

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

/** Alinhado ao Hub / ArtigosResumo (padrão 1A). */
const PAGE_SIZE = 200

type Props = {
  hideHeader?: boolean
}

export function PendentesPicagemReferenciaPanel({ hideHeader = false }: Props) {
  const [dataDe, setDataDe] = useState('')
  const [dataAte, setDataAte] = useState('')
  const [obrano, setObrano] = useState('')
  const [artigo, setArtigo] = useState('')
  const [cor, setCor] = useState('')
  const [cliente, setCliente] = useState('')
  const [page, setPage] = useState(1)

  const [items, setItems] = useState<PendentePicagemReferenciaItem[]>([])
  const [totalItems, setTotalItems] = useState(0)
  const [loading, setLoading] = useState(false)
  const [erro, setErro] = useState<string | null>(null)
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())

  const carregar = useCallback(async () => {
    setLoading(true)
    setErro(null)
    try {
      const obranoNum = obrano.trim() ? Number(obrano.trim()) : undefined
      const res = await api.pendentesPicagemPorReferencia({
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

  function toggleExpand(ref: string) {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(ref)) next.delete(ref)
      else next.add(ref)
      return next
    })
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
                  <TableCell>Referência</TableCell>
                  <TableCell align="right" sx={{ width: 100 }}>
                    Docs
                  </TableCell>
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
                    <TableCell colSpan={5}>
                      <Typography variant="body2" color="text.secondary">
                        {labels.pendentesPicagemVazio}
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
                {items.map((item) => {
                  const key = item.ref
                  const open = expanded.has(key)
                  return (
                    <Fragment key={key}>
                      <TableRow
                        hover
                        onClick={() => toggleExpand(key)}
                        selected={open}
                        sx={{
                          cursor: 'pointer',
                          '& > *': { borderBottom: open ? 'unset' : undefined },
                        }}
                      >
                        <TableCell padding="checkbox">
                          <IconButton
                            size="small"
                            aria-label={open ? 'Fechar documentos' : 'Ver documentos'}
                            onClick={(ev) => {
                              ev.stopPropagation()
                              toggleExpand(key)
                            }}
                          >
                            {open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
                          </IconButton>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" fontWeight={600}>
                            {item.ref}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {item.designacao}
                          </Typography>
                        </TableCell>
                        <TableCell align="right">{item.totalDocumentos}</TableCell>
                        <TableCell align="right">{item.totalLinhasPendentes}</TableCell>
                        <TableCell align="right">
                          <Typography component="span" fontWeight={700} color="warning.main">
                            {fmt(item.quantidadePendenteTotal)}
                          </Typography>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell
                          colSpan={5}
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
                              <Table size="small">
                                <TableHead>
                                  <TableRow>
                                    <TableCell sx={{ width: 72 }}>Nº</TableCell>
                                    <TableCell>Cliente</TableCell>
                                    <TableCell align="right" sx={{ width: 130 }}>
                                      {labels.colQtdPendentePicagem}
                                    </TableCell>
                                  </TableRow>
                                </TableHead>
                                <TableBody>
                                  {item.documentos.length === 0 ? (
                                    <TableRow>
                                      <TableCell colSpan={3}>
                                        <Typography variant="body2" color="text.secondary">
                                          {labels.pendentesPicagemVazio}
                                        </Typography>
                                      </TableCell>
                                    </TableRow>
                                  ) : (
                                    item.documentos.map((d) => (
                                      <TableRow key={d.boStamp}>
                                        <TableCell>{fmtDocNo(d.numeroEncomenda)}</TableCell>
                                        <TableCell
                                          title={`${d.clienteNo} — ${clienteNomeTitle(d.clienteNome, d.clienteNome2)}`}
                                        >
                                          <ClienteNomeDisplay
                                            nome={d.clienteNome}
                                            nome2={d.clienteNome2}
                                            clienteNo={d.clienteNo}
                                            showClienteNo
                                            compact
                                          />
                                        </TableCell>
                                        <TableCell align="right">
                                          <Typography
                                            component="span"
                                            fontWeight={700}
                                            color="warning.main"
                                          >
                                            {fmt(d.quantidadePendente)}
                                          </Typography>
                                        </TableCell>
                                      </TableRow>
                                    ))
                                  )}
                                </TableBody>
                              </Table>
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
          {totalItems} referência{totalItems === 1 ? '' : 's'} · página {page} / {totalPages}
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
