import { createSearchParams, Navigate, Outlet, useLocation } from 'react-router-dom'
import { CircularProgress, Box } from '@mui/material'
import { useAuth } from '../features/autenticacao/AuthContext'
import { stashOperadorReturnUrl } from '../features/autenticacao/safeReturnUrl'

export function RequireAuth() {
  const { utilizador, loading } = useAuth()
  const location = useLocation()

  if (loading) {
    return (
      <Box minHeight="100vh" display="flex" alignItems="center" justifyContent="center">
        <CircularProgress />
      </Box>
    )
  }

  if (!utilizador) {
    const returnUrl = `${location.pathname}${location.search}`
    const isOperador = returnUrl === '/operador' || returnUrl.startsWith('/operador/')
    if (isOperador) {
      stashOperadorReturnUrl(returnUrl)
      // Object form + createSearchParams: uma só codificação (evitar %252F no query).
      return (
        <Navigate
          to={{
            pathname: '/login',
            search: `?${createSearchParams({ returnUrl })}`,
          }}
          state={{ returnUrl }}
          replace
        />
      )
    }
    return <Navigate to="/login" replace />
  }

  return <Outlet />
}
