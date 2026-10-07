import { Navigate, Outlet } from 'react-router-dom'
import { CircularProgress, Box } from '@mui/material'
import { useAuth } from '../features/autenticacao/AuthContext'

export function RequireAuth() {
  const { utilizador, loading } = useAuth()
  if (loading) {
    return (
      <Box minHeight="100vh" display="flex" alignItems="center" justifyContent="center">
        <CircularProgress />
      </Box>
    )
  }
  if (!utilizador) return <Navigate to="/login" replace />
  return <Outlet />
}
