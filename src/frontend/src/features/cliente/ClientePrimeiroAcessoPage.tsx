import { FormEvent, useState } from 'react'
import { Alert, Box, Button, Paper, TextField, Typography } from '@mui/material'
import { Link as RouterLink, useNavigate } from 'react-router-dom'
import { clienteApi } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'

type Step = 'nif' | 'telemovel' | 'password'

export function ClientePrimeiroAcessoPage() {
  const { setCliente } = useClienteAuth()
  const navigate = useNavigate()
  const [step, setStep] = useState<Step>('nif')
  const [nif, setNif] = useState('')
  const [telemovel, setTelemovel] = useState('')
  const [password, setPassword] = useState('')
  const [challengeToken, setChallengeToken] = useState('')
  const [passwordToken, setPasswordToken] = useState('')
  const [busy, setBusy] = useState(false)
  const [erro, setErro] = useState<string | null>(null)

  async function onNif(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    setBusy(true)
    try {
      const res = await clienteApi.primeiroAcessoIniciar(nif.trim())
      setChallengeToken(res.challengeToken)
      setStep('telemovel')
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Não foi possível continuar.')
    } finally {
      setBusy(false)
    }
  }

  async function onTelemovel(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    setBusy(true)
    try {
      const res = await clienteApi.primeiroAcessoTelemovel(challengeToken, telemovel.trim())
      setPasswordToken(res.passwordToken)
      setStep('password')
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Telemóvel inválido.')
    } finally {
      setBusy(false)
    }
  }

  async function onPassword(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    setBusy(true)
    try {
      const res = await clienteApi.primeiroAcessoPassword(passwordToken, password)
      setCliente(res.utilizador)
      navigate('/cliente', { replace: true })
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Não foi possível definir a palavra-passe.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Box minHeight="100vh" display="flex" alignItems="center" justifyContent="center" px={2} bgcolor="#f5f5f5">
      <Paper sx={{ p: 3, width: '100%', maxWidth: 420 }}>
        <Typography variant="h5" gutterBottom>
          Primeiro acesso
        </Typography>
        {erro && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {erro}
          </Alert>
        )}
        {step === 'nif' && (
          <Box component="form" onSubmit={onNif} display="flex" flexDirection="column" gap={2}>
            <TextField label="NIF" value={nif} onChange={(e) => setNif(e.target.value)} required />
            <Button type="submit" variant="contained" disabled={busy}>
              Continuar
            </Button>
          </Box>
        )}
        {step === 'telemovel' && (
          <Box component="form" onSubmit={onTelemovel} display="flex" flexDirection="column" gap={2}>
            <Typography variant="body2">Valide o telemóvel registado no PHC.</Typography>
            <TextField label="Telemóvel" value={telemovel} onChange={(e) => setTelemovel(e.target.value)} required />
            <Button type="submit" variant="contained" disabled={busy}>
              Validar
            </Button>
          </Box>
        )}
        {step === 'password' && (
          <Box component="form" onSubmit={onPassword} display="flex" flexDirection="column" gap={2}>
            <TextField
              label="Nova palavra-passe"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              helperText="Mínimo 8 caracteres"
            />
            <Button type="submit" variant="contained" disabled={busy}>
              Definir e entrar
            </Button>
          </Box>
        )}
        <Button component={RouterLink} to="/cliente/login" sx={{ mt: 2 }}>
          Voltar ao login
        </Button>
      </Paper>
    </Box>
  )
}
