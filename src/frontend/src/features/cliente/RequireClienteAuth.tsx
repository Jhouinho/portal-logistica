import { useEffect, useState } from 'react'
import { Navigate, Outlet } from 'react-router-dom'
import { Box, CircularProgress } from '@mui/material'
import { useClienteAuth } from './ClienteAuthContext'

const LOADING_FALLBACK_MS = 6_000

export function RequireClienteAuth() {
  const { cliente, loading } = useClienteAuth()
  const [timedOut, setTimedOut] = useState(false)

  useEffect(() => {
    if (!loading) {
      setTimedOut(false)
      return
    }
    const id = window.setTimeout(() => setTimedOut(true), LOADING_FALLBACK_MS)
    return () => window.clearTimeout(id)
  }, [loading])

  if (loading && !timedOut) {
    return (
      <Box
        minHeight="100dvh"
        display="flex"
        alignItems="center"
        justifyContent="center"
        bgcolor="background.default"
        sx={{ backgroundImage: (t) => t.palette.portal.pageGradient }}
      >
        <CircularProgress />
      </Box>
    )
  }
  if (!cliente) return <Navigate to="/cliente/login" replace />
  return <Outlet />
}
