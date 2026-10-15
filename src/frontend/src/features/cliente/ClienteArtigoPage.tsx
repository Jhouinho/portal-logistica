import { FormEvent, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  TextField,
  Typography,
} from '@mui/material'
import { useNavigate } from 'react-router-dom'
import { clienteApi, type ClienteArtigo } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import { loadCarrinho, saveCarrinho, upsertLinha } from './carrinhoStorage'

/** Alinhado a BI.u_cor varchar(100) e ClienteCorLimits.MaxLength. */
const COR_MAX_LENGTH = 100

export function ClienteArtigoPage() {
  const { cliente } = useClienteAuth()
  const navigate = useNavigate()
  const [ref, setRef] = useState('')
  const [artigo, setArtigo] = useState<ClienteArtigo | null>(null)
  const [cor, setCor] = useState('')
  const [qtt, setQtt] = useState(1)
  const [erro, setErro] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function procurar(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    setArtigo(null)
    setBusy(true)
    try {
      const a = await clienteApi.artigo(ref.trim())
      setArtigo(a)
      setCor('')
      setQtt(1)
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Artigo não encontrado.')
    } finally {
      setBusy(false)
    }
  }

  function adicionar() {
    if (!cliente || !artigo) return
    if (qtt < 1 || !Number.isInteger(qtt)) {
      setErro('A quantidade deve ser um número inteiro positivo.')
      return
    }
    const linhas = loadCarrinho(cliente.no, cliente.estab)
    const next = upsertLinha(linhas, {
      ref: artigo.ref,
      design: artigo.design,
      cor: cor.trim().slice(0, COR_MAX_LENGTH),
      qtt,
      precoUnitario: artigo.precoUnitario,
    })
    saveCarrinho(cliente.no, cliente.estab, next)
    navigate('/cliente/carrinho')
  }

  return (
    <Box display="flex" flexDirection="column" gap={2}>
      <Typography variant="h5">Artigo</Typography>
      <Typography variant="body2" color="text.secondary">
        Introduza a referência ou leia o QR Code do artigo (apenas a referência).
      </Typography>
      {erro && <Alert severity="error">{erro}</Alert>}
      <Box component="form" onSubmit={procurar} display="flex" gap={1}>
        <TextField
          label="Referência"
          value={ref}
          onChange={(e) => setRef(e.target.value)}
          fullWidth
          required
          inputProps={{ inputMode: 'text', autoCapitalize: 'characters' }}
        />
        <Button type="submit" variant="contained" disabled={busy}>
          OK
        </Button>
      </Box>

      {artigo && (
        <Box display="flex" flexDirection="column" gap={2}>
          <Typography fontWeight={600}>{artigo.design}</Typography>
          <Typography variant="body2">Ref. {artigo.ref}</Typography>
          <Typography>{artigo.precoUnitario.toFixed(2)} €</Typography>
          {artigo.avisoStockBaixo && (
            <Alert severity="warning">Disponibilidade limitada (a quantidade exacta não é mostrada).</Alert>
          )}
          <TextField
            label="Cor (opcional)"
            value={cor}
            onChange={(e) => setCor(e.target.value.slice(0, COR_MAX_LENGTH))}
            fullWidth
            inputProps={{ maxLength: COR_MAX_LENGTH }}
            helperText={`Texto livre, até ${COR_MAX_LENGTH} caracteres. Pode deixar em branco.`}
          />
          <TextField
            label="Quantidade"
            type="number"
            value={qtt}
            onChange={(e) => setQtt(Number(e.target.value))}
            inputProps={{ min: 1, step: 1 }}
          />
          <Button variant="contained" onClick={adicionar}>
            Adicionar ao carrinho
          </Button>
        </Box>
      )}
    </Box>
  )
}
