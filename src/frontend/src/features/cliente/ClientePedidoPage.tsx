import { useEffect, useState } from 'react'
import { Alert, Box, Button, CircularProgress, Typography } from '@mui/material'
import { Link as RouterLink, useParams } from 'react-router-dom'
import { clienteApi, type ClientePedidoDetalhe } from './clienteApi'

export function ClientePedidoPage() {
  const { bostamp = '' } = useParams()
  const [pedido, setPedido] = useState<ClientePedidoDetalhe | null>(null)
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [msg, setMsg] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    clienteApi
      .pedido(decodeURIComponent(bostamp))
      .then(setPedido)
      .catch((e) => setErro(e instanceof Error ? e.message : 'Erro'))
      .finally(() => setLoading(false))
  }, [bostamp])

  async function cancelar() {
    if (!pedido?.podeCancelar) return
    if (!window.confirm('Confirma o cancelamento deste pedido?')) return
    setBusy(true)
    setErro(null)
    try {
      const res = await clienteApi.cancelar(pedido.bostamp)
      setMsg(res.mensagem)
      setPedido(null)
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Não foi possível cancelar.')
    } finally {
      setBusy(false)
    }
  }

  if (loading) return <CircularProgress />
  if (msg)
    return (
      <Box>
        <Alert severity="success">{msg}</Alert>
        <Button component={RouterLink} to="/cliente" sx={{ mt: 2 }}>
          Voltar
        </Button>
      </Box>
    )
  if (erro || !pedido)
    return (
      <Box>
        <Alert severity="error">{erro ?? 'Pedido não encontrado.'}</Alert>
        <Button component={RouterLink} to="/cliente" sx={{ mt: 2 }}>
          Voltar
        </Button>
      </Box>
    )

  return (
    <Box display="flex" flexDirection="column" gap={2}>
      <Typography variant="h5">Pedido nº {pedido.obrano}</Typography>
      <Typography variant="body2" color="text.secondary">
        {pedido.estadoEtiqueta} · {new Date(pedido.dataObra).toLocaleDateString('pt-PT')}
        {pedido.hora ? ` ${pedido.hora}` : ''}
      </Typography>
      {pedido.linhas.map((l, i) => (
        <Box key={i} bgcolor="white" p={2} borderRadius={1}>
          <Typography fontWeight={600}>{l.design}</Typography>
          <Typography variant="body2">
            {l.ref}
            {l.cor ? ` · ${l.cor}` : ''} · qtd {l.qtt}
          </Typography>
          <Typography variant="body2">
            {l.precoUnitario.toFixed(2)} € · linha {l.totalLinha.toFixed(2)} €
          </Typography>
        </Box>
      ))}
      <Typography variant="h6">Total estimado: {pedido.etotaldeb.toFixed(2)} €</Typography>
      {pedido.podeCancelar && (
        <Button color="error" variant="outlined" disabled={busy} onClick={cancelar}>
          Cancelar pedido
        </Button>
      )}
      <Button component={RouterLink} to="/cliente">
        Página inicial
      </Button>
    </Box>
  )
}
