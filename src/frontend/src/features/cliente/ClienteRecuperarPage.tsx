import { FormEvent, useState } from 'react'
import { Box, Stack, Typography } from '@mui/material'
import { useNavigate } from 'react-router-dom'
import { clienteApi } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import {
  ClienteAlert,
  ClienteAuthCard,
  ClienteBackToLogin,
  ClientePageBg,
  ClientePrimaryButton,
  ClienteStepDots,
  ClienteTextField,
} from './clienteUi'

type Step = 'nif' | 'telemovel' | 'password'

export function ClienteRecuperarPage() {
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

  const stepNum = step === 'nif' ? 1 : step === 'telemovel' ? 2 : 3

  async function onNif(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    setBusy(true)
    try {
      const res = await clienteApi.recuperarIniciar(nif.trim())
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
      const res = await clienteApi.recuperarTelemovel(challengeToken, telemovel.trim())
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
      const res = await clienteApi.recuperarPassword(passwordToken, password)
      setCliente(res.utilizador)
      navigate('/cliente', { replace: true })
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Não foi possível definir a palavra-passe.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <ClientePageBg>
      <ClienteAuthCard
        title="Recuperar palavra-passe"
        subtitle="Valide o NIF e o telemóvel registado no PHC para definir uma nova palavra-passe."
      >
        <ClienteStepDots step={stepNum} />
        {erro && (
          <Box mb={2}>
            <ClienteAlert severity="error">{erro}</ClienteAlert>
          </Box>
        )}
        {step === 'nif' && (
          <Box component="form" onSubmit={onNif}>
            <Stack spacing={2}>
              <ClienteTextField
                label="NIF"
                value={nif}
                onChange={(e) => setNif(e.target.value)}
                required
                inputProps={{ inputMode: 'numeric' }}
              />
              <ClientePrimaryButton type="submit" disabled={busy}>
                Continuar
              </ClientePrimaryButton>
            </Stack>
          </Box>
        )}
        {step === 'telemovel' && (
          <Box component="form" onSubmit={onTelemovel}>
            <Stack spacing={2}>
              <Typography variant="body2" color="text.secondary">
                Introduza o telemóvel associado à sua ficha de cliente.
              </Typography>
              <ClienteTextField
                label="Telemóvel"
                value={telemovel}
                onChange={(e) => setTelemovel(e.target.value)}
                required
                inputProps={{ inputMode: 'tel' }}
              />
              <ClientePrimaryButton type="submit" disabled={busy}>
                Validar
              </ClientePrimaryButton>
            </Stack>
          </Box>
        )}
        {step === 'password' && (
          <Box component="form" onSubmit={onPassword}>
            <Stack spacing={2}>
              <ClienteTextField
                label="Nova palavra-passe"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                helperText="Mínimo 8 caracteres"
              />
              <ClientePrimaryButton type="submit" disabled={busy}>
                Guardar e entrar
              </ClientePrimaryButton>
            </Stack>
          </Box>
        )}
        <ClienteBackToLogin />
      </ClienteAuthCard>
    </ClientePageBg>
  )
}
