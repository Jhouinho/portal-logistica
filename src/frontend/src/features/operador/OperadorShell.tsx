import { AppBar, Box, IconButton, ThemeProvider, Toolbar, Tooltip } from '@mui/material'
import LogoutOutlinedIcon from '@mui/icons-material/LogoutOutlined'
import PersonOutlineIcon from '@mui/icons-material/PersonOutline'
import SmartphoneIcon from '@mui/icons-material/Smartphone'
import ArrowBackIosNewIcon from '@mui/icons-material/ArrowBackIosNew'
import { createSearchParams, Outlet, useLocation, useNavigate, matchPath } from 'react-router-dom'
import { useAuth } from '../autenticacao/AuthContext'
import { stashOperadorReturnUrl } from '../autenticacao/safeReturnUrl'
import { createAppTheme } from '../../shared/theme'
import { OperadorPageShell, OperadorSectionTitle } from './operadorUi'

const OPERADOR_HOME = '/operador/pedidos-mobile'
const operadorDarkTheme = createAppTheme('dark')

/**
 * Layout mobile PHC — visual «Dashboard Pedidos Mobile» (azul escuro).
 * Fora do AppShell / hub Logística; autenticação Identity existente.
 */
export function OperadorShell() {
  const { utilizador, logout } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()

  const detailMatch = matchPath(
    { path: '/operador/pedidos-mobile/:pedidoId', end: true },
    location.pathname,
  )
  const isDetail = !!detailMatch

  async function onLogout() {
    await logout()
    stashOperadorReturnUrl(OPERADOR_HOME)
    navigate(
      {
        pathname: '/login',
        search: `?${createSearchParams({ returnUrl: OPERADOR_HOME })}`,
      },
      { state: { returnUrl: OPERADOR_HOME }, replace: true },
    )
  }

  const label = utilizador?.nome?.trim() || utilizador?.login || 'Operador'

  return (
    <ThemeProvider theme={operadorDarkTheme}>
      <OperadorPageShell>
        <AppBar
          position="sticky"
          elevation={0}
          sx={{
            top: 0,
            bgcolor: 'rgba(11, 18, 32, 0.92)',
            backdropFilter: 'blur(10px)',
            borderBottom: 1,
            borderColor: 'portal.border',
            backgroundImage: 'none',
          }}
        >
          <Toolbar sx={{ minHeight: 64, px: 1.5, gap: 1 }}>
            {isDetail ? (
              <IconButton
                edge="start"
                color="inherit"
                aria-label="Voltar"
                onClick={() => navigate(OPERADOR_HOME)}
                sx={{ mr: 0.5 }}
              >
                <ArrowBackIosNewIcon fontSize="small" />
              </IconButton>
            ) : (
              <Box
                sx={{
                  width: 40,
                  height: 40,
                  borderRadius: 2,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  bgcolor: 'rgba(61, 178, 255, 0.12)',
                  color: 'primary.main',
                  flexShrink: 0,
                }}
              >
                <SmartphoneIcon fontSize="small" />
              </Box>
            )}

            <Box flex={1} minWidth={0}>
              <OperadorSectionTitle
                title={isDetail ? 'Pedido' : 'Pedidos Mobile'}
                subtitle={isDetail ? label : 'Gestão de pedidos internos'}
              />
            </Box>

            <Tooltip title={label}>
              <IconButton color="primary" aria-label="Utilizador" size="medium">
                <PersonOutlineIcon />
              </IconButton>
            </Tooltip>
            <Tooltip title="Sair">
              <IconButton color="primary" aria-label="Sair" onClick={() => void onLogout()}>
                <LogoutOutlinedIcon />
              </IconButton>
            </Tooltip>
          </Toolbar>
        </AppBar>

        <Box
          component="main"
          flex={1}
          px={1.75}
          py={2}
          width="100%"
          maxWidth={480}
          mx="auto"
          boxSizing="border-box"
        >
          <Outlet />
        </Box>
      </OperadorPageShell>
    </ThemeProvider>
  )
}
