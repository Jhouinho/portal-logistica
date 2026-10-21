import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom'
import { api, type StaffPmPedidoDetalhe } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { portalPageScrollSx, portalPanelSx, portalPrimaryCtaSx } from '../centro/portalChrome'

function fmtData(iso: string | null | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString('pt-PT', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function parsePreco(raw: string): number | null {
  const t = raw.trim().replace(',', '.')
  if (!t) return null
  const n = Number(t)
  if (!Number.isFinite(n)) return null
  return n
}

export function PedidosMobileDetailPage() {
  const { pedidoId: pedidoIdParam } = useParams()
  const pedidoId = Number(pedidoIdParam)
  const navigate = useNavigate()
  const [item, setItem] = useState<StaffPmPedidoDetalhe | null>(null)
  const [precosEdit, setPrecosEdit] = useState<Record<number, string>>({})
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [erro, setErro] = useState<string | null>(null)
  const [sucesso, setSucesso] = useState<string | null>(null)
  const [rejeitarAberto, setRejeitarAberto] = useState(false)
  const [motivo, setMotivo] = useState('')
  const actionLock = useRef(false)

  const syncPrecos = useCallback((detalhe: StaffPmPedidoDetalhe) => {
    const next: Record<number, string> = {}
    for (const l of detalhe.linhas) {
      next[l.linhaOrd] = String(l.precoUnitario)
    }
    setPrecosEdit(next)
  }, [])

  const carregar = useCallback(async () => {
    if (!Number.isFinite(pedidoId) || pedidoId <= 0) {
      setErro('Identificador de pedido inválido.')
      setLoading(false)
      return
    }
    setLoading(true)
    setErro(null)
    try {
      const d = await api.staffPmPedido(pedidoId)
      setItem(d)
      syncPrecos(d)
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
      setItem(null)
    } finally {
      setLoading(false)
    }
  }, [pedidoId, syncPrecos])

  useEffect(() => {
    void carregar()
  }, [carregar])

  const totaisLocais = useMemo(() => {
    if (!item) return { linhas: new Map<number, number>(), pedido: 0 }
    const linhas = new Map<number, number>()
    let pedido = 0
    for (const l of item.linhas) {
      const parsed = parsePreco(precosEdit[l.linhaOrd] ?? String(l.precoUnitario))
      const preco = parsed ?? l.precoUnitario
      const total = Math.round(l.qtt * preco * 1e6) / 1e6
      linhas.set(l.linhaOrd, total)
      pedido += total
    }
    return { linhas, pedido: Math.round(pedido * 1e6) / 1e6 }
  }, [item, precosEdit])

  async function guardarPrecos() {
    if (actionLock.current || !item?.podeEditarPrecos) return
    const payload: { linhaOrd: number; precoUnitario: number }[] = []
    for (const l of item.linhas) {
      const parsed = parsePreco(precosEdit[l.linhaOrd] ?? '')
      if (parsed === null) {
        setErro(`Preço inválido na linha ${l.linhaOrd}.`)
        return
      }
      if (parsed < 0) {
        setErro(`Preço negativo na linha ${l.linhaOrd}.`)
        return
      }
      if (parsed > 999999.999999) {
        setErro(`Preço demasiado elevado na linha ${l.linhaOrd}.`)
        return
      }
      payload.push({ linhaOrd: l.linhaOrd, precoUnitario: parsed })
    }

    actionLock.current = true
    setBusy(true)
    setErro(null)
    setSucesso(null)
    try {
      const d = await api.staffPmGuardarPrecos(pedidoId, payload)
      setItem(d)
      syncPrecos(d)
      setSucesso('Preços do operador gravados.')
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setBusy(false)
      actionLock.current = false
    }
  }

  async function aprovar() {
    if (actionLock.current || !item?.podeAprovar) return
    actionLock.current = true
    setBusy(true)
    setErro(null)
    setSucesso(null)
    try {
      const r = await api.staffPmAprovar(pedidoId)
      setSucesso(
        r.alreadyIntegrated || r.alreadyExistsBo
          ? `Pedido já integrado — dossier ${r.bostamp} (obrano ${r.obrano}).`
          : `Aprovado. Dossier PHC ndos=${r.ndos} criado: ${r.bostamp} (obrano ${r.obrano}).`,
      )
      await carregar()
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setBusy(false)
      actionLock.current = false
    }
  }

  async function rejeitar(e: FormEvent) {
    e.preventDefault()
    if (actionLock.current || !item?.podeRejeitar) return
    actionLock.current = true
    setBusy(true)
    setErro(null)
    setSucesso(null)
    try {
      await api.staffPmRejeitar(pedidoId, motivo.trim() || undefined)
      setRejeitarAberto(false)
      setSucesso('Pedido rejeitado.')
      await carregar()
    } catch (err) {
      setErro(err instanceof Error ? err.message : labels.erroGenerico)
    } finally {
      setBusy(false)
      actionLock.current = false
    }
  }

  if (loading) {
    return (
      <Box sx={portalPageScrollSx} display="flex" justifyContent="center" py={6}>
        <CircularProgress />
      </Box>
    )
  }

  if (!item) {
    return (
      <Box sx={portalPageScrollSx}>
        <Alert severity="error" sx={{ mb: 2 }}>
          {erro ?? 'Pedido não encontrado.'}
        </Alert>
        <Button component={RouterLink} to="/pedidos-mobile" startIcon={<ArrowBackIcon />}>
          Voltar à lista
        </Button>
      </Box>
    )
  }

  const listPath = '/pedidos-mobile'
  const totalMostrado = item.podeEditarPrecos ? totaisLocais.pedido : item.etotaldeb

  return (
    <Box sx={portalPageScrollSx}>
      <Button
        component={RouterLink}
        to={listPath}
        startIcon={<ArrowBackIcon />}
        sx={{ mb: 2 }}
      >
        Pedidos Mobile
      </Button>

      <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" mb={2} gap={1}>
        <Box>
          <Typography variant="h5" fontWeight={700}>
            {item.numeroInterno}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {item.clienteNome || 'Cliente'} ({item.clNo}
            {item.clEstab ? ` / estab. ${item.clEstab}` : ''})
          </Typography>
        </Box>
        <Chip label={item.estadoEtiqueta} color={item.podeAprovar ? 'warning' : 'default'} />
      </Stack>

      {erro && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
          {erro}
        </Alert>
      )}
      {sucesso && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSucesso(null)}>
          {sucesso}
        </Alert>
      )}

      <Box sx={{ ...portalPanelSx, mb: 2, p: 2 }}>
        <Stack spacing={0.75}>
          <Typography variant="body2">
            <strong>Submissão:</strong> {fmtData(item.dataSubmissao)}
          </Typography>
          <Typography variant="body2">
            <strong>Total (preço operador):</strong> {totalMostrado.toFixed(2)} €
          </Typography>
          {item.bostamp && (
            <Typography variant="body2">
              <strong>PHC:</strong> {item.bostamp}
              {item.obrano != null ? ` · obrano ${item.obrano}` : ''}
              {item.ndos != null ? ` · ndos ${item.ndos}` : ''}
            </Typography>
          )}
          {item.motivoRejeicao && (
            <Typography variant="body2">
              <strong>Motivo rejeição:</strong> {item.motivoRejeicao}
            </Typography>
          )}
          {item.decididoPor && (
            <Typography variant="body2" color="text.secondary">
              Decisão por {item.decididoPor} em {fmtData(item.dataDecisao)}
            </Typography>
          )}
        </Stack>
      </Box>

      <Box sx={{ ...portalPanelSx, mb: 2, overflow: 'auto' }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>#</TableCell>
              <TableCell>Ref.</TableCell>
              <TableCell>Designação</TableCell>
              <TableCell>Cor</TableCell>
              <TableCell align="right">Qtt</TableCell>
              <TableCell align="right">P. submetido</TableCell>
              <TableCell align="right">P. operador</TableCell>
              <TableCell align="right">Total</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {item.linhas.map((l) => {
              const totalLinha = item.podeEditarPrecos
                ? (totaisLocais.linhas.get(l.linhaOrd) ?? l.totalLinha)
                : l.totalLinha
              return (
                <TableRow key={l.linhaOrd}>
                  <TableCell>{l.linhaOrd}</TableCell>
                  <TableCell>{l.ref}</TableCell>
                  <TableCell>{l.design}</TableCell>
                  <TableCell>{l.cor || '—'}</TableCell>
                  <TableCell align="right">{l.qtt}</TableCell>
                  <TableCell align="right">{l.precoSubmissao.toFixed(2)}</TableCell>
                  <TableCell align="right" sx={{ minWidth: 110 }}>
                    {item.podeEditarPrecos ? (
                      <TextField
                        size="small"
                        value={precosEdit[l.linhaOrd] ?? ''}
                        onChange={(e) =>
                          setPrecosEdit((prev) => ({
                            ...prev,
                            [l.linhaOrd]: e.target.value,
                          }))
                        }
                        inputProps={{
                          inputMode: 'decimal',
                          'aria-label': `Preço operador linha ${l.linhaOrd}`,
                        }}
                        disabled={busy}
                      />
                    ) : (
                      l.precoUnitario.toFixed(2)
                    )}
                  </TableCell>
                  <TableCell align="right">{totalLinha.toFixed(2)}</TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </Box>

      <Stack direction="row" spacing={1.5} flexWrap="wrap">
        {item.podeEditarPrecos && (
          <Button variant="outlined" disabled={busy} onClick={() => void guardarPrecos()}>
            Guardar preços
          </Button>
        )}
        {item.podeAprovar && (
          <Button
            variant="contained"
            disabled={busy}
            onClick={() => void aprovar()}
            sx={portalPrimaryCtaSx}
          >
            {busy ? 'A processar…' : 'Aprovar e criar dossier PHC'}
          </Button>
        )}
        {item.podeRejeitar && (
          <Button
            variant="outlined"
            color="error"
            disabled={busy}
            onClick={() => setRejeitarAberto(true)}
          >
            Rejeitar
          </Button>
        )}
        <Button variant="text" onClick={() => navigate(listPath)}>
          Voltar
        </Button>
      </Stack>

      <Dialog open={rejeitarAberto} onClose={() => !busy && setRejeitarAberto(false)} fullWidth maxWidth="sm">
        <Box component="form" onSubmit={(e) => void rejeitar(e)}>
          <DialogTitle>Rejeitar pedido {item.numeroInterno}</DialogTitle>
          <DialogContent>
            <Typography variant="body2" color="text.secondary" mb={2}>
              Não será criado dossier PHC. O pedido ficará bloqueado para aprovação.
            </Typography>
            <TextField
              label="Motivo (opcional)"
              value={motivo}
              onChange={(e) => setMotivo(e.target.value.slice(0, 500))}
              fullWidth
              multiline
              minRows={2}
              autoFocus
            />
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setRejeitarAberto(false)} disabled={busy}>
              Cancelar
            </Button>
            <Button type="submit" color="error" variant="contained" disabled={busy}>
              Confirmar rejeição
            </Button>
          </DialogActions>
        </Box>
      </Dialog>
    </Box>
  )
}
