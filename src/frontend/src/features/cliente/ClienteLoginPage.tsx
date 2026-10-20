import { FormEvent, useState } from 'react'
import { Box, Link, Stack } from '@mui/material'
import { Link as RouterLink, useNavigate } from 'react-router-dom'
import { clienteApi } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import {
  ClienteAlert,
  ClienteAuthCard,
  ClientePageBg,
  ClientePrimaryButton,
  ClienteTextField,
} from './clienteUi'

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
    <ClientePageBg>
      <ClienteAuthCard title="Entrar">
        {erro && (
          <Box mb={2}>
            <ClienteAlert severity="error">{erro}</ClienteAlert>
          </Box>
        )}
        <Box component="form" onSubmit={onSubmit}>
          <Stack spacing={2}>
            <ClienteTextField
              label="NIF"
              value={nif}
              onChange={(e) => setNif(e.target.value)}
              required
              autoComplete="username"
              inputProps={{ inputMode: 'numeric' }}
            />
            <ClienteTextField
              label="Palavra-passe"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
            <ClientePrimaryButton type="submit" disabled={busy}>
              Entrar
            </ClientePrimaryButton>
          </Stack>
        </Box>
        <Stack spacing={1.25} mt={3} alignItems="center">
          <Link component={RouterLink} to="/cliente/primeiro-acesso" underline="hover" color="primary">
            Primeiro acesso
          </Link>
          <Link component={RouterLink} to="/cliente/recuperar" underline="hover" color="primary">
            Recuperar palavra-passe
          </Link>
        </Stack>
      </ClienteAuthCard>
    </ClientePageBg>
  )
}
