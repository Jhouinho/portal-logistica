import { useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  CircularProgress,
  Typography,
} from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import { clienteApi, type ClientePedidoLista } from './clienteApi'

export function ClienteHomePage() {
  const [pedidos, setPedidos] = useState<ClientePedidoLista[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)

  useEffect(() => {
    clienteApi
      .pedidos(10)
      .then(setPedidos)
      .catch((e) => setErro(e instanceof Error ? e.message : 'Erro'))
      .finally(() => setLoading(false))
  }, [])

  return (
    <Box display="flex" flexDirection="column" gap={2}>
      <Typography variant="h5">Olá</Typography>
      <Button component={RouterLink} to="/cliente/novo" variant="contained" size="large">
        Novo pedido
      </Button>
      <Button component={RouterLink} to="/cliente/carrinho" variant="outlined">
        Ver carrinho
      </Button>

      <Typography variant="h6" mt={1}>
        Últimos pedidos
      </Typography>
      {loading && <CircularProgress size={28} />}
      {erro && <Alert severity="error">{erro}</Alert>}
      {!loading && !erro && pedidos.length === 0 && (
        <Typography color="text.secondary">Ainda não tem pedidos.</Typography>
      )}
      {pedidos.map((p) => (
        <Card key={p.bostamp} variant="outlined">
          <CardActionArea component={RouterLink} to={`/cliente/pedidos/${encodeURIComponent(p.bostamp)}`}>
            <CardContent>
              <Typography fontWeight={600}>Pedido nº {p.obrano}</Typography>
              <Typography variant="body2" color="text.secondary">
                {p.estadoEtiqueta} · {new Date(p.dataObra).toLocaleDateString('pt-PT')}
                {p.hora ? ` ${p.hora}` : ''}
              </Typography>
              <Typography variant="body2">{p.etotaldeb.toFixed(2)} €</Typography>
            </CardContent>
          </CardActionArea>
        </Card>
      ))}
    </Box>
  )
}
