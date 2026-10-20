import {
  AppBar,
  Badge,
  BottomNavigation,
  BottomNavigationAction,
  Box,
  Button,
  Container,
  Paper,
  Toolbar,
  Typography,
} from '@mui/material'
import HomeOutlinedIcon from '@mui/icons-material/HomeOutlined'
import ReceiptLongOutlinedIcon from '@mui/icons-material/ReceiptLongOutlined'
import ShoppingCartOutlinedIcon from '@mui/icons-material/ShoppingCartOutlined'
import { Link as RouterLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { BrandLogo } from '../../shared/ui/BrandLogo'
import { useClienteAuth } from './ClienteAuthContext'
import { loadCarrinho } from './carrinhoStorage'

export function ClienteShell() {
  const { cliente, logout } = useClienteAuth()
  const navigate = useNavigate()
  const location = useLocation()

  // Lê o carrinho em cada render (storage local) para o badge acompanhar alterações.
  const cartCount = cliente
    ? loadCarrinho(cliente.no, cliente.estab).reduce((s, l) => s + l.qtt, 0)
    : 0

  const navValue = location.pathname.startsWith('/cliente/carrinho')
    ? 'carrinho'
    : location.pathname.startsWith('/cliente/pedidos') || location.hash === '#pedidos'
      ? 'pedidos'
      : location.pathname === '/cliente' || location.pathname === '/cliente/'
        ? 'home'
        : 'other'

  return (
    <Box
      minHeight="100dvh"
      display="flex"
      flexDirection="column"
      bgcolor="background.default"
      sx={{ backgroundImage: (t) => t.palette.portal.pageGradient }}
    >
      <AppBar
        position="sticky"
        elevation={0}
        sx={{
          top: 0,
          bgcolor: 'rgba(18, 26, 43, 0.92)',
          backdropFilter: 'blur(8px)',
          borderBottom: 1,
          borderColor: 'portal.border',
          backgroundImage: 'none',
        }}
      >
        <Toolbar sx={{ minHeight: 56, px: 2, gap: 1 }}>
          <Box
            component={RouterLink}
            to="/cliente"
            sx={{
              flex: 1,
              minWidth: 0,
              display: 'flex',
              alignItems: 'center',
              textDecoration: 'none',
              color: 'inherit',
            }}
          >
            <BrandLogo height={32} />
          </Box>
          <Button
            color="primary"
            size="small"
            variant="text"
            sx={{
              textTransform: 'none',
              fontWeight: 700,
              minHeight: 40,
              px: 1.5,
              ml: 'auto',
              flexShrink: 0,
            }}
            onClick={async () => {
              await logout()
              navigate('/cliente/login', { replace: true })
            }}
          >
            Sair
          </Button>
        </Toolbar>
        {cliente?.nome && (
          <Typography
            variant="caption"
            color="text.secondary"
            noWrap
            sx={{ px: 2, pb: 1, mt: -0.5, display: 'block' }}
          >
            {cliente.nome}
          </Typography>
        )}
      </AppBar>

      <Container
        maxWidth="sm"
        sx={{
          py: 2.5,
          pb: 'calc(72px + max(0.75rem, env(safe-area-inset-bottom)))',
          flex: 1,
          color: 'text.primary',
          width: '100%',
        }}
      >
        <Outlet />
      </Container>

      <Paper
        elevation={0}
        sx={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          zIndex: (t) => t.zIndex.appBar,
          borderTop: 1,
          borderColor: 'portal.border',
          bgcolor: 'rgba(18, 26, 43, 0.96)',
          backdropFilter: 'blur(10px)',
          backgroundImage: 'none',
          pb: 'env(safe-area-inset-bottom)',
        }}
      >
        <BottomNavigation
          showLabels
          value={navValue === 'other' ? false : navValue}
          onChange={(_, v) => {
            if (v === 'home') navigate('/cliente')
            else if (v === 'pedidos') navigate('/cliente#pedidos')
            else if (v === 'carrinho') navigate('/cliente/carrinho')
          }}
          sx={{
            bgcolor: 'transparent',
            height: 64,
            '& .MuiBottomNavigationAction-root': {
              color: 'text.secondary',
              minWidth: 0,
              py: 1,
            },
            '& .Mui-selected': { color: 'primary.main' },
            '& .MuiBottomNavigationAction-label': {
              fontSize: 11,
              fontWeight: 600,
              '&.Mui-selected': { fontSize: 11 },
            },
          }}
        >
          <BottomNavigationAction value="home" label="Home" icon={<HomeOutlinedIcon />} />
          <BottomNavigationAction
            value="pedidos"
            label="Pedidos"
            icon={<ReceiptLongOutlinedIcon />}
          />
          <BottomNavigationAction
            value="carrinho"
            label="Carrinho"
            icon={
              <Badge
                badgeContent={cartCount > 0 ? cartCount : 0}
                color="primary"
                max={99}
                invisible={cartCount <= 0}
              >
                <ShoppingCartOutlinedIcon />
              </Badge>
            }
          />
        </BottomNavigation>
      </Paper>
    </Box>
  )
}
