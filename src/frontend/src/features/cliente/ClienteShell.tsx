import { AppBar, Box, Button, Container, Toolbar, Typography } from '@mui/material'
import { Link as RouterLink, Outlet, useNavigate } from 'react-router-dom'
import { useClienteAuth } from './ClienteAuthContext'

export function ClienteShell() {
  const { cliente, logout } = useClienteAuth()
  const navigate = useNavigate()

  return (
    <Box minHeight="100vh" display="flex" flexDirection="column" bgcolor="#f5f5f5">
      <AppBar position="sticky" color="primary" elevation={0}>
        <Toolbar sx={{ gap: 1, flexWrap: 'wrap' }}>
          <Typography
            component={RouterLink}
            to="/cliente"
            variant="h6"
            sx={{ color: 'inherit', textDecoration: 'none', flexGrow: 1 }}
          >
            Portal Mobile
          </Typography>
          <Typography variant="body2" sx={{ opacity: 0.9 }}>
            {cliente?.nome}
          </Typography>
          <Button
            color="inherit"
            size="small"
            onClick={async () => {
              await logout()
              navigate('/cliente/login', { replace: true })
            }}
          >
            Sair
          </Button>
        </Toolbar>
      </AppBar>
      <Container maxWidth="sm" sx={{ py: 2, flex: 1 }}>
        <Outlet />
      </Container>
    </Box>
  )
}
