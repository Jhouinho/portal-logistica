import { useMemo, useState, type FormEvent } from 'react'
import { Alert, Box, Button, Paper, TextField, Typography } from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { Link as RouterLink, useNavigate, useSearchParams } from 'react-router-dom'
import { api } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { BrandLogo } from '../../shared/ui/BrandLogo'
import { ColorModeToggle } from '../../shared/ui/ColorModeToggle'
import { centroPageBg } from '../centro/centroUi'

export function DefinirPasswordPage() {
  const theme = useTheme()
  const isLight = theme.palette.mode === 'light'
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const email = useMemo(() => params.get('email')?.trim() ?? '', [params])
  const token = useMemo(() => params.get('token')?.trim() ?? '', [params])
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [erro, setErro] = useState<string | null>(null)
  const [ok, setOk] = useState(false)

  const linkInvalido = !email || !token

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setErro(null)
    if (password !== confirm) {
      setErro('A confirmação da palavra-passe não coincide.')
      return
    }
    setBusy(true)
    try {
      await api.definirPassword(email, token, password, confirm)
      setOk(true)
      setTimeout(() => navigate('/login', { replace: true }), 1500)
    } catch (err) {
      setErro(err instanceof Error ? err.message : labels.erroGenerico)
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
          maxWidth: 420,
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
            <BrandLogo height={40} />
            <Typography variant="body2" fontWeight={700} sx={{ opacity: 0.95 }}>
              {labels.appName}
            </Typography>
          </Box>
        ) : null}

        <Box sx={isLight ? { p: 3 } : undefined}>
          <Typography variant="h5" fontWeight={700} gutterBottom>
            Definir palavra-passe
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={3}>
            Primeiro acesso ao {labels.appName}
          </Typography>

          {linkInvalido ? (
            <Alert severity="error">
              Link inválido. Peça um novo convite ao administrador.
            </Alert>
          ) : ok ? (
            <Alert severity="success">
              Palavra-passe definida. A redireccionar para o login…
            </Alert>
          ) : (
            <Box component="form" onSubmit={onSubmit} display="flex" flexDirection="column" gap={2}>
              {erro && <Alert severity="error">{erro}</Alert>}
              <TextField label={labels.email} value={email} fullWidth InputProps={{ readOnly: true }} />
              <TextField
                label={labels.password}
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                fullWidth
                autoFocus
                helperText="Mín. 8 caracteres, com maiúscula, minúscula e dígito."
              />
              <TextField
                label="Confirmar palavra-passe"
                type="password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                required
                fullWidth
              />
              <Button type="submit" variant="contained" size="large" disabled={busy}>
                Guardar
              </Button>
              <Button component={RouterLink} to="/login">
                Ir para login
              </Button>
            </Box>
          )}
        </Box>
      </Paper>
    </Box>
  )
}
