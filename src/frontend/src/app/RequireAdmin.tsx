import { Navigate, Outlet } from 'react-router-dom'
import { Box, CircularProgress } from '@mui/material'
import { useAuth } from '../features/autenticacao/AuthContext'

export function RequireAdmin() {
  const { utilizador, loading } = useAuth()
  if (loading) {
    return (
      <Box minHeight="40vh" display="flex" alignItems="center" justifyContent="center">
        <CircularProgress />
      </Box>
    )
  }
  if (!utilizador?.isAdmin) return <Navigate to="/" replace />
  return <Outlet />
}
