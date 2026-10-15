import { Navigate, Outlet } from 'react-router-dom'
import { Box, CircularProgress } from '@mui/material'
import { useClienteAuth } from './ClienteAuthContext'

export function RequireClienteAuth() {
  const { cliente, loading } = useClienteAuth()
  if (loading) {
    return (
      <Box minHeight="100vh" display="flex" alignItems="center" justifyContent="center">
        <CircularProgress />
      </Box>
    )
  }
  if (!cliente) return <Navigate to="/cliente/login" replace />
  return <Outlet />
}
