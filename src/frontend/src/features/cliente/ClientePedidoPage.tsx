import { useEffect, useState } from 'react'
import {
  Box,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  Stack,
  Typography,
} from '@mui/material'
import WarningAmberRoundedIcon from '@mui/icons-material/WarningAmberRounded'
import { useNavigate, useParams } from 'react-router-dom'
import {
  clienteApi,
  clientePedidoNumeroLabel,
  clientePedidoRouteId,
  type ClientePedidoDetalhe,
} from './clienteApi'
import {
  ClienteAlert,
  ClienteArtigoThumb,
  ClienteDangerButton,
  ClienteEstadoBadge,
  ClientePageTitle,
  ClientePanel,
  ClientePrimaryButton,
  ClienteSecondaryButton,
  ClienteSuccessPanel,
} from './clienteUi'

export function ClientePedidoPage() {
  const { bostamp = '' } = useParams()
  const navigate = useNavigate()
  const [pedido, setPedido] = useState<ClientePedidoDetalhe | null>(null)
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [msg, setMsg] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)

  useEffect(() => {
    clienteApi
      .pedido(decodeURIComponent(bostamp))
      .then(setPedido)
      .catch((e) => setErro(e instanceof Error ? e.message : 'Erro'))
      .finally(() => setLoading(false))
  }, [bostamp])

  async function confirmarCancelar() {
    if (!pedido?.podeCancelar) return
    setBusy(true)
    setErro(null)
    setConfirmOpen(false)
    try {
      const res = await clienteApi.cancelar(clientePedidoRouteId(pedido))
      setMsg(res.mensagem || 'Pedido cancelado com sucesso.')
      setPedido(null)
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Não foi possível cancelar.')
    } finally {
      setBusy(false)
    }
  }

  const numeroLabel = pedido ? clientePedidoNumeroLabel(pedido) : ''

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" py={6}>
        <CircularProgress />
      </Box>
    )
  }

  if (msg) {
    return (
      <Stack spacing={2.5}>
        <ClienteSuccessPanel
          title="Pedido cancelado com sucesso"
          detail={msg}
          highlight="O pedido foi removido do histórico."
        >
          <ClientePrimaryButton onClick={() => navigate('/cliente', { replace: true })}>
            Voltar à homepage
          </ClientePrimaryButton>
        </ClienteSuccessPanel>
      </Stack>
    )
  }

  if (erro || !pedido) {
    return (
      <Stack spacing={2}>
        <ClientePageTitle title="Pedido" />
        <ClienteAlert severity="error">{erro ?? 'Pedido não encontrado.'}</ClienteAlert>
        <ClienteSecondaryButton onClick={() => navigate('/cliente')}>Voltar</ClienteSecondaryButton>
      </Stack>
    )
  }

  return (
    <Stack spacing={2.5}>
      <ClientePageTitle title={`Pedido nº ${numeroLabel}`} />

      <ClientePanel>
        <Stack direction="row" justifyContent="space-between" alignItems="center" gap={1}>
          <Box>
            <Typography variant="body2" color="text.secondary">
              {new Date(pedido.dataObra).toLocaleDateString('pt-PT')}
              {pedido.hora ? ` · ${pedido.hora}` : ''}
            </Typography>
            <Typography fontWeight={800} color="primary.main" mt={0.75} fontSize={18}>
              {pedido.etotaldeb.toFixed(2)} €
            </Typography>
          </Box>
          <ClienteEstadoBadge codigo={pedido.estadoCodigo} etiqueta={pedido.estadoEtiqueta} />
        </Stack>
      </ClientePanel>

      {pedido.linhas.map((l, i) => (
        <ClientePanel key={i}>
          <Stack direction="row" spacing={1.5}>
            <ClienteArtigoThumb refCode={l.ref} alt={l.design} />
            <Box flex={1} minWidth={0}>
              <Typography fontWeight={700}>{l.design}</Typography>
              <Typography variant="body2" color="text.secondary">
                {l.ref}
                {l.cor ? ` · ${l.cor}` : ''} · qtd {l.qtt}
              </Typography>
              <Typography variant="body2" color="text.primary" mt={0.75}>
                {l.precoUnitario.toFixed(2)} € · linha {l.totalLinha.toFixed(2)} €
              </Typography>
            </Box>
          </Stack>
        </ClientePanel>
      ))}

      {pedido.podeCancelar && (
        <ClienteDangerButton disabled={busy} onClick={() => setConfirmOpen(true)}>
          Cancelar pedido
        </ClienteDangerButton>
      )}

      <Dialog
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        PaperProps={{
          sx: {
            bgcolor: 'background.paper',
            border: 1,
            borderColor: 'portal.border',
            borderRadius: 2,
            mx: 2,
            width: '100%',
            maxWidth: 400,
          },
        }}
      >
        <DialogTitle sx={{ textAlign: 'center', pt: 3 }}>
          <WarningAmberRoundedIcon sx={{ fontSize: 48, color: 'error.main', mb: 1 }} />
          <Typography component="div" variant="h6" fontWeight={800}>
            Cancelar pedido?
          </Typography>
        </DialogTitle>
        <DialogContent>
          <DialogContentText color="text.secondary" textAlign="center">
            Tem a certeza que pretende cancelar o pedido nº {numeroLabel}?
          </DialogContentText>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 3, gap: 1, flexDirection: 'column' }}>
          <ClienteDangerButton disabled={busy} onClick={confirmarCancelar}>
            Sim, cancelar
          </ClienteDangerButton>
          <ClienteSecondaryButton onClick={() => setConfirmOpen(false)}>Não</ClienteSecondaryButton>
        </DialogActions>
      </Dialog>
    </Stack>
  )
}
