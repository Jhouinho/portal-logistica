import { useMemo, useState, type FormEvent } from 'react'
import { Alert, Box, Button, Paper, TextField, Typography } from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { Link as RouterLink, useNavigate, useSearchParams } from 'react-router-dom'
import { useAuth } from './AuthContext'
import { labels } from '../../shared/i18n/labels'
import { BrandLogo } from '../../shared/ui/BrandLogo'
import { ColorModeToggle } from '../../shared/ui/ColorModeToggle'
import { centroPageBg } from '../centro/centroUi'

function messageForError(code: string | null): string | null {
  if (!code) return null
  if (code === 'utilizador_nao_mapeado') return labels.utilizadorNaoMapeado
  if (code === 'microsoft_auth_failed') return labels.microsoftAuthFalhou
  return labels.erroGenerico
}

export function LoginPage() {
  const theme = useTheme()
  const isLight = theme.palette.mode === 'light'
  const { login } = useAuth()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const [utilizador, setUtilizador] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [erroLocal, setErroLocal] = useState<string | null>(null)
  const erroQuery = useMemo(() => messageForError(params.get('error')), [params])
  const erro = erroLocal ?? erroQuery

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setErroLocal(null)
    setBusy(true)
    try {
      await login(utilizador.trim(), password)
      navigate('/', { replace: true })
    } catch (err) {
      setErroLocal(err instanceof Error ? err.message : labels.credenciaisInvalidas)
    } finally {
      setBusy(false)
    }
  }

  return (
    <Box
      minHeight="100vh"
      display="flex"
      alignItems="center"
      justifyContent="center"
      px={2}
      sx={[centroPageBg, { position: 'relative' }]}
    >
      <Box position="absolute" top={12} right={12}>
        <ColorModeToggle />
      </Box>
      <Paper
        elevation={isLight ? 0 : 4}
        sx={(t) => ({
          width: '100%',
          maxWidth: 400,
          overflow: 'hidden',
          bgcolor: 'background.paper',
          ...(isLight
            ? {
                border: `1px solid ${t.palette.portal.border}`,
                borderRadius: t.palette.portal.radius,
                boxShadow: t.palette.portal.shadow,
              }
            : { p: 4 }),
        })}
      >
        {isLight ? (
          <Box
            sx={{
              bgcolor: 'primary.main',
              color: 'primary.contrastText',
              px: 3,
              py: 2.25,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-start',
              gap: 0.75,
            }}
          >
            <BrandLogo height={44} />
            <Typography variant="body2" fontWeight={700} sx={{ opacity: 0.95, letterSpacing: 0.2 }}>
              {labels.appName}
            </Typography>
          </Box>
        ) : (
          <>
            <Box mb={2}>
              <BrandLogo height={52} />
            </Box>
            <Typography variant="body2" color="text.secondary" mb={3}>
              {labels.appName}
            </Typography>
          </>
        )}

        <Box
          component="form"
          onSubmit={onSubmit}
          display="flex"
          flexDirection="column"
          gap={2}
          sx={isLight ? { p: 3 } : undefined}
        >
          {erro && <Alert severity="error">{erro}</Alert>}
          <TextField
            label={labels.utilizador}
            value={utilizador}
            onChange={(e) => setUtilizador(e.target.value)}
            autoComplete="username"
            required
            fullWidth
            autoFocus
          />
          <TextField
            label={labels.password}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
            fullWidth
          />
          <Button type="submit" variant="contained" size="large" disabled={busy}>
            {labels.login}
          </Button>
          <Button
            component={RouterLink}
            to="/tv"
            variant="text"
            size="small"
            sx={{ alignSelf: 'center', fontWeight: isLight ? 600 : undefined }}
          >
            Vista TV (sem login)
          </Button>
        </Box>
      </Paper>
    </Box>
  )
}
