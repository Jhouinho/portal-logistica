import { useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Paper,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import ContentCopyIcon from '@mui/icons-material/ContentCopy'
import { Navigate, Outlet, useLocation, useSearchParams } from 'react-router-dom'
import {
  api,
  type AdminUtilizador,
  type ActivarAcessoResponse,
} from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { portalPageScrollSx } from '../centro/portalChrome'
import { PrevisoesEntradaPanel } from './PrevisoesEntradaPanel'

/** Layout partilhado + redirect de URLs antigas (`?tab=`). */
export function AdministracaoLayout() {
  const [searchParams] = useSearchParams()
  const location = useLocation()
  const tab = searchParams.get('tab')

  if (location.pathname === '/administracao' || location.pathname === '/administracao/') {
    if (tab === 'previsoes') {
      return <Navigate to="/administracao/previsoes" replace />
    }
    return <Navigate to="/administracao/utilizadores" replace />
  }

  return (
    <Box sx={portalPageScrollSx}>
      <Outlet />
    </Box>
  )
}

export function AdminUtilizadoresPage() {
  return (
    <>
      <Typography variant="h5" fontWeight={700} gutterBottom>
        {labels.adminUtilizadores}
      </Typography>
      <Typography variant="body2" color="text.secondary" mb={2}>
        Utilizadores PHC activos — activar portal, reset de password e perfil Admin
      </Typography>
      <AdminUtilizadoresPanel />
    </>
  )
}

export function AdminPrevisoesPage() {
  return <PrevisoesEntradaPanel />
}

function AdminUtilizadoresPanel() {
  const [items, setItems] = useState<AdminUtilizador[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [filtro, setFiltro] = useState('')
  const [busyEmail, setBusyEmail] = useState<string | null>(null)
  const [convite, setConvite] = useState<ActivarAcessoResponse | null>(null)
  const [copied, setCopied] = useState(false)

  async function carregar() {
    setLoading(true)
    setErro(null)
    try {
      setItems(await api.adminUtilizadores())
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void carregar()
  }, [])

  const filtrados = items.filter((u) => {
    const q = filtro.trim().toLowerCase()
    if (!q) return true
    return (
      u.login.toLowerCase().includes(q) ||
      u.nome.toLowerCase().includes(q) ||
      u.email.toLowerCase().includes(q)
    )
  })

  async function run(email: string, action: () => Promise<void>) {
    setBusyEmail(email)
    setErro(null)
    try {
      await action()
      await carregar()
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setBusyEmail(null)
    }
  }

  async function activar(email: string) {
    await run(email, async () => {
      const res = await api.activarAcesso(email)
      setConvite(res)
      setCopied(false)
    })
  }

  async function resetPassword(email: string) {
    await run(email, async () => {
      const res = await api.resetPassword(email)
      setConvite(res)
      setCopied(false)
    })
  }

  async function copyLink() {
    if (!convite) return
    await navigator.clipboard.writeText(convite.definirPasswordUrl)
    setCopied(true)
  }

  return (
    <>
      {erro && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
          {erro}
        </Alert>
      )}

      <Box display="flex" gap={2} mb={2} flexWrap="wrap" alignItems="center">
        <TextField
          size="small"
          label="Filtrar"
          value={filtro}
          onChange={(e) => setFiltro(e.target.value)}
          sx={{ minWidth: 260 }}
        />
        <Button variant="outlined" onClick={() => void carregar()} disabled={loading}>
          Actualizar
        </Button>
      </Box>

      {loading ? (
        <Box display="flex" justifyContent="center" py={6}>
          <CircularProgress />
        </Box>
      ) : (
        <Paper>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Login</TableCell>
                <TableCell>Nome</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Portal</TableCell>
                <TableCell>Conta</TableCell>
                <TableCell>Admin</TableCell>
                <TableCell align="right">Acções</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filtrados.map((u) => {
                const busy = busyEmail === u.email
                return (
                  <TableRow key={u.userstamp} hover>
                    <TableCell>{u.login}</TableCell>
                    <TableCell>{u.nome}</TableCell>
                    <TableCell>{u.email}</TableCell>
                    <TableCell>
                      {u.usaPort ? (
                        <Chip size="small" color="success" label="Activo" />
                      ) : (
                        <Chip size="small" label="Inactivo" />
                      )}
                    </TableCell>
                    <TableCell>
                      {!u.temContaIdentity
                        ? '—'
                        : u.temPassword
                          ? 'Password OK'
                          : 'Aguardar definição'}
                    </TableCell>
                    <TableCell>
                      <Switch
                        size="small"
                        checked={u.isAdmin}
                        disabled={busy || !u.temContaIdentity}
                        onChange={(e) => {
                          const checked = e.target.checked
                          void run(u.email, async () => {
                            if (checked) await api.atribuirAdmin(u.email)
                            else await api.removerAdmin(u.email)
                          })
                        }}
                      />
                    </TableCell>
                    <TableCell align="right">
                      <Box display="flex" gap={1} justifyContent="flex-end" flexWrap="wrap">
                        {!u.usaPort ? (
                          <Button
                            size="small"
                            variant="contained"
                            disabled={busy}
                            onClick={() => void activar(u.email)}
                          >
                            Activar acesso
                          </Button>
                        ) : (
                          <>
                            <Button
                              size="small"
                              variant="outlined"
                              disabled={busy}
                              onClick={() => void resetPassword(u.email)}
                            >
                              Reset password
                            </Button>
                            <Button
                              size="small"
                              color="warning"
                              disabled={busy}
                              onClick={() =>
                                void run(u.email, () => api.revogarAcesso(u.email))
                              }
                            >
                              Revogar
                            </Button>
                          </>
                        )}
                      </Box>
                    </TableCell>
                  </TableRow>
                )
              })}
              {filtrados.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7}>
                    <Typography variant="body2" color="text.secondary" py={2}>
                      Sem utilizadores.
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </Paper>
      )}

      <Dialog open={!!convite} onClose={() => setConvite(null)} maxWidth="sm" fullWidth>
        <DialogTitle>Link para definir password</DialogTitle>
        <DialogContent>
          <Typography variant="body2" mb={1}>
            {convite?.email}
          </Typography>
          <Box display="flex" gap={1} alignItems="center">
            <TextField
              size="small"
              fullWidth
              value={convite?.definirPasswordUrl ?? ''}
              InputProps={{ readOnly: true }}
            />
            <Tooltip title={copied ? 'Copiado' : 'Copiar'}>
              <IconButton onClick={() => void copyLink()}>
                <ContentCopyIcon />
              </IconButton>
            </Tooltip>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConvite(null)}>Fechar</Button>
        </DialogActions>
      </Dialog>
    </>
  )
}
