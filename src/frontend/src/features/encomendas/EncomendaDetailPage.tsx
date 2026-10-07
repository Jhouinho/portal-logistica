import { useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
} from '@mui/material'
import CheckIcon from '@mui/icons-material/Check'
import CloseIcon from '@mui/icons-material/Close'
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom'
import { api, type EncomendaDetalhe, type EncomendaLinha } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { fmtMoney, fmtDocNo, fmtDate, fmtMetodoExpedicao } from '../../shared/format'
import { ClienteNomeDisplay } from '../../shared/ui/ClienteNomeDisplay'
import { DossierInfoButton } from '../../shared/ui/DossierInfoButton'
import {
  QuantidadeAutorizadaCell,
  stockDisponivelComSugestao,
  totalLinhaAutorizada,
} from './QuantidadeAutorizadaCell'
import { LinhaPrecoCell } from './LinhaPrecoCell'
import { GravacaoSnackbar, type GravacaoSnack } from './GravacaoSnackbar'
import { LinhasColGroup, linhasTableSx } from './linhasTableLayout'
import { portalPageScrollSx } from '../centro/portalChrome'
import { prepararAutorizacoesAntesPicking } from './persistirAutorizacoesAoCriarPicking'

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

export function EncomendaDetailPage() {
  const { boStamp } = useParams()
  const navigate = useNavigate()
  const [detalhe, setDetalhe] = useState<EncomendaDetalhe | null>(null)
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [erroGravacao, setErroGravacao] = useState<GravacaoSnack | null>(null)
  const [savingPicking, setSavingPicking] = useState(false)
  const [confirmarPicking, setConfirmarPicking] = useState<'marcar' | 'reverter' | null>(null)
  const [confirmarLinhasZero, setConfirmarLinhasZero] = useState(false)

  useEffect(() => {
    if (!boStamp) return
    let cancel = false
    setLoading(true)
    setErro(null)
    api
      .encomendaDetalhe(boStamp)
      .then((d) => {
        if (!cancel) setDetalhe(d)
      })
      .catch((e: Error) => {
        if (!cancel) setErro(e.message)
      })
      .finally(() => {
        if (!cancel) setLoading(false)
      })
    return () => {
      cancel = true
    }
  }, [boStamp])

  function patchLinha(next: EncomendaLinha) {
    setDetalhe((d) =>
      d
        ? {
            ...d,
            linhas: d.linhas.map((x) => (x.biStamp === next.biStamp ? next : x)),
          }
        : d,
    )
  }

  async function executarMarcarPicking(pronta: boolean, confirmarLinhasSemAutorizacao: boolean) {
    if (!detalhe) return
    setSavingPicking(true)
    try {
      if (pronta && !confirmarLinhasSemAutorizacao) {
        await prepararAutorizacoesAntesPicking(detalhe.boStamp, detalhe.linhas)
      }
      await api.marcarProntaPicking(detalhe.boStamp, pronta, { confirmarLinhasSemAutorizacao })
      navigate(pronta ? '/picking' : '/encomendas', { replace: true })
    } catch (e) {
      const msg = e instanceof Error ? e.message : labels.erroGenerico
      if (pronta && !confirmarLinhasSemAutorizacao && msg.includes('LINHAS_SEM_AUTORIZACAO')) {
        setConfirmarLinhasZero(true)
        return
      }
      setErroGravacao({ message: msg, severity: 'error' })
    } finally {
      setSavingPicking(false)
    }
  }

  async function confirmarAccaoPicking() {
    if (!confirmarPicking) return
    const pronta = confirmarPicking === 'marcar'
    setConfirmarPicking(null)
    await executarMarcarPicking(pronta, false)
  }

  if (loading) {
    return (
      <Box sx={portalPageScrollSx} display="flex" justifyContent="center" py={6}>
        <CircularProgress />
      </Box>
    )
  }

  if (erro || !detalhe) {
    return (
      <Box sx={portalPageScrollSx}>
        <Button component={RouterLink} to="/encomendas" sx={{ mb: 2 }}>
          ← {labels.encomendas}
        </Button>
        <Alert severity="error">{erro ?? 'Encomenda não encontrada.'}</Alert>
      </Box>
    )
  }

  const ac = detalhe.estadoPlaneamentoCodigo === 'AC'
  const soConsulta = detalhe.prontaPicking
  const voltarTo = soConsulta ? '/picking' : '/encomendas'
  const voltarLabel = soConsulta ? labels.picking : labels.encomendas

  return (
    <Box sx={portalPageScrollSx}>
      <Button component={RouterLink} to={voltarTo} sx={{ mb: 2 }}>
        ← {voltarLabel}
      </Button>

      <Box
        sx={
          detalhe.urgente
            ? {
                mb: 2,
                pl: 1.5,
                borderLeft: 3,
                borderColor: 'error.main',
                bgcolor: (t) =>
                  t.palette.mode === 'dark'
                    ? 'rgba(244, 67, 54, 0.10)'
                    : 'rgba(244, 67, 54, 0.07)',
                borderRadius: 1,
                py: 1,
                pr: 1,
              }
            : { mb: 2 }
        }
      >
        <Box display="flex" alignItems="center" gap={0.5} sx={{ mb: 1 }}>
          <Typography variant="h5" fontWeight={700} gutterBottom={false} component="div">
            Encomenda {fmtDocNo(detalhe.numeroEncomenda)}
            {detalhe.urgente ? (
              <Typography
                component="span"
                variant="subtitle2"
                color="error.main"
                fontWeight={700}
                sx={{ ml: 1.5 }}
              >
                {labels.urgente}
              </Typography>
            ) : null}
          </Typography>
          <DossierInfoButton
            clienteNome={detalhe.clienteNome}
            clienteNome2={detalhe.clienteNome2}
            moradaEntrega={detalhe.moradaEntrega}
            dataEntrega={detalhe.dataEntrega}
            showDataEntrega
            metodoExpedicao={detalhe.metodoExpedicao}
            showMetodoExpedicao
            size="medium"
          />
        </Box>

      <Box display="flex" gap={1} flexWrap="nowrap" alignItems="center">
        <Chip size="small" label={detalhe.nomeSerie || `Série ${detalhe.serie}`} />
        <Chip
          size="small"
          color={ac ? 'warning' : 'info'}
          label={detalhe.estadoPlaneamento}
        />
        {detalhe.prontaPicking ? (
          <>
            <Chip size="small" color="success" label={labels.prontaParaPicking} />
            <Tooltip
              title={
                detalhe.temQtt66
                  ? labels.pickingCancelarBloqueado66
                  : labels.desmarcarProntaPickingHint
              }
              arrow
            >
              <span>
                <Button
                  size="small"
                  variant="contained"
                  color="error"
                  aria-label={labels.desmarcarProntaPicking}
                  disabled={savingPicking || !!detalhe.temQtt66}
                  onClick={() => {
                    if (detalhe.temQtt66) return
                    setConfirmarPicking('reverter')
                  }}
                  sx={{ minWidth: 40, px: 1.25 }}
                >
                  <CloseIcon fontSize="small" />
                </Button>
              </span>
            </Tooltip>
          </>
        ) : (
          <Tooltip title={labels.marcarProntaPickingHint} arrow>
            <span>
              <Button
                size="small"
                variant="contained"
                color="success"
                aria-label={labels.marcarProntaPickingHint}
                disabled={savingPicking}
                onClick={() => setConfirmarPicking('marcar')}
                startIcon={<CheckIcon fontSize="small" />}
                sx={{ textTransform: 'none', minWidth: 120, px: 1.5 }}
              >
                {labels.marcarProntaPicking}
              </Button>
            </span>
          </Tooltip>
        )}
      </Box>
      </Box>

      <Dialog
        open={!!confirmarPicking}
        onClose={() => setConfirmarPicking(null)}
        aria-labelledby="confirma-picking-detalhe"
      >
        <DialogTitle id="confirma-picking-detalhe">
          {confirmarPicking === 'reverter'
            ? labels.prontaPickingReverterTitulo
            : labels.prontaPickingConfirmarTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {(confirmarPicking === 'reverter'
              ? labels.prontaPickingReverterMsg
              : labels.prontaPickingConfirmarMsg
            ).replace('{n}', fmtDocNo(detalhe.numeroEncomenda))}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmarPicking(null)}>{labels.cancelar}</Button>
          <Button variant="contained" onClick={() => void confirmarAccaoPicking()} autoFocus>
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={confirmarLinhasZero}
        onClose={() => setConfirmarLinhasZero(false)}
        aria-labelledby="confirma-linhas-zero-detalhe"
      >
        <DialogTitle id="confirma-linhas-zero-detalhe">
          {labels.prontaPickingLinhasZeroTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>{labels.prontaPickingLinhasZeroMsg}</DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmarLinhasZero(false)}>{labels.cancelar}</Button>
          <Button
            variant="contained"
            color="warning"
            onClick={() => {
              setConfirmarLinhasZero(false)
              void executarMarcarPicking(true, true)
            }}
            autoFocus
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>

      <Paper sx={{ p: 2, mb: 3 }}>
        <Typography variant="body2" component="div" sx={{ display: 'flex', gap: 0.75, alignItems: 'baseline', flexWrap: 'wrap' }}>
          <strong>Cliente:</strong> {detalhe.clienteNo}
          {detalhe.clienteEstab ? ` / ${detalhe.clienteEstab}` : ''} —
          <ClienteNomeDisplay nome={detalhe.clienteNome} nome2={detalhe.clienteNome2} />
        </Typography>
        <Typography variant="body2">
          <strong>Data / hora:</strong> {detalhe.data} {detalhe.hora}
        </Typography>
        <Typography variant="body2">
          <strong>{labels.colEntrega}:</strong> {fmtDate(detalhe.dataEntrega)}
        </Typography>
        <Typography variant="body2">
          <strong>{labels.colMetodoExpedicao}:</strong>{' '}
          {fmtMetodoExpedicao(detalhe.metodoExpedicao)}
        </Typography>
        {detalhe.moradaEntrega?.trim() ? (
          <Typography variant="body2" component="div" sx={{ mt: 0.5 }}>
            <strong>{labels.moradaEntrega}</strong>
            <Typography
              variant="body2"
              component="div"
              sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word', mt: 0.25 }}
            >
              {detalhe.moradaEntrega.trim()}
            </Typography>
          </Typography>
        ) : null}
        {detalhe.prontaPicking && (detalhe.prontaPickingPor || detalhe.prontaPickingEm) ? (
          <Typography variant="body2">
            <strong>Marcada por:</strong> {detalhe.prontaPickingPor?.trim() || '—'}
            {detalhe.prontaPickingEm
              ? ` · ${new Date(detalhe.prontaPickingEm).toLocaleString('pt-PT', {
                  day: '2-digit',
                  month: '2-digit',
                  year: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                })}`
              : ''}
          </Typography>
        ) : null}
      </Paper>

      {detalhe.linhas.some((l) => l.disponivelNoPortal === false) ? (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {labels.encomendaComArtigosNaoDisponiveisPortal}
        </Alert>
      ) : null}

      <Typography variant="h6" gutterBottom>
        Linhas
      </Typography>
      <GravacaoSnackbar snack={erroGravacao} onClose={() => setErroGravacao(null)} />
      <Paper>
        <Table size="small" sx={linhasTableSx}>
          <LinhasColGroup withCor={false} />
          <TableHead>
            <TableRow>
              <TableCell>Artigo</TableCell>
              <TableCell>Descrição</TableCell>
              <TableCell>Unidade</TableCell>
              <TableCell align="right">Encomendada</TableCell>
              <TableCell align="center">Autorizada</TableCell>
              <TableCell align="center">Preço</TableCell>
              <TableCell align="right">Total</TableCell>
              <TableCell align="right">{labels.colDisponivelPrevisto}</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {detalhe.linhas.map((l) => {
              const disponivelUi = stockDisponivelComSugestao(l, detalhe.linhas)
              return (
              <TableRow key={l.biStamp}>
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
                <TableCell>{l.unidade?.trim() ? l.unidade : '—'}</TableCell>
                <TableCell align="right">{fmt(l.quantidadeOriginalPortal)}</TableCell>
                <TableCell align="center" sx={{ px: 0.5 }}>
                  <QuantidadeAutorizadaCell
                    linha={l}
                    readOnly={soConsulta}
                    onSaved={patchLinha}
                    onNotify={setErroGravacao}
                  />
                </TableCell>
                <TableCell align="center" sx={{ px: 0.5 }}>
                  <LinhaPrecoCell
                    linha={l}
                    readOnly={soConsulta}
                    onSaved={patchLinha}
                    onNotify={setErroGravacao}
                  />
                </TableCell>
                <TableCell align="right">
                  {fmtMoney(totalLinhaAutorizada(l))}
                </TableCell>
                <TableCell
                  align="right"
                  sx={{
                    color: disponivelUi < 0 ? 'warning.main' : undefined,
                    fontWeight: disponivelUi < 0 ? 700 : undefined,
                  }}
                >
                  {fmt(disponivelUi)}
                </TableCell>
              </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </Paper>
    </Box>
  )
}
