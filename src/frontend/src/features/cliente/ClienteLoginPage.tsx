import { FormEvent, useState } from 'react'
import { Alert, Box, Button, Link, Paper, TextField, Typography } from '@mui/material'
import { Link as RouterLink, useNavigate } from 'react-router-dom'
import { clienteApi } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'

export function ClienteLoginPage() {
  const { setCliente } = useClienteAuth()
  const navigate = useNavigate()
  const [nif, setNif] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [erro, setErro] = useState<string | null>(null)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    setBusy(true)
    try {
      const res = await clienteApi.login(nif.trim(), password)
      setCliente(res.utilizador)
      navigate('/cliente', { replace: true })
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Credenciais inválidas.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Box minHeight="100vh" display="flex" alignItems="center" justifyContent="center" px={2} bgcolor="#f5f5f5">
      <Paper sx={{ p: 3, width: '100%', maxWidth: 420 }}>
        <Typography variant="h5" gutterBottom>
          Portal Mobile
        </Typography>
        <Typography variant="body2" color="text.secondary" mb={2}>
          Entre com o NIF e a palavra-passe.
        </Typography>
        {erro && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {erro}
          </Alert>
        )}
        <Box component="form" onSubmit={onSubmit} display="flex" flexDirection="column" gap={2}>
          <TextField label="NIF" value={nif} onChange={(e) => setNif(e.target.value)} required autoComplete="username" />
          <TextField
            label="Palavra-passe"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
          />
          <Button type="submit" variant="contained" disabled={busy}>
            Entrar
          </Button>
        </Box>
        <Box mt={2} display="flex" flexDirection="column" gap={1}>
          <Link component={RouterLink} to="/cliente/primeiro-acesso">
            Primeiro acesso
          </Link>
          <Link component={RouterLink} to="/cliente/recuperar">
            Recuperar palavra-passe
          </Link>
        </Box>
      </Paper>
    </Box>
  )
}
