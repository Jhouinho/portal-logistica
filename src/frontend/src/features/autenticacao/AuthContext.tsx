import { useMemo, useState, type ReactNode, createContext, useCallback, useContext, useEffect } from 'react'
import { api, type Utilizador } from '../../shared/api'

type AuthState = {
  utilizador: Utilizador | null
  loading: boolean
  login: (login: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [utilizador, setUtilizador] = useState<Utilizador | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api
      .me()
      .then((me) => setUtilizador({ login: me.login, nome: me.nome, isAdmin: !!me.isAdmin }))
      .catch(() => setUtilizador(null))
      .finally(() => setLoading(false))
  }, [])

  const login = useCallback(async (loginName: string, password: string) => {
    const res = await api.login(loginName, password)
    setUtilizador({
      login: res.utilizador.login,
      nome: res.utilizador.nome,
      isAdmin: !!res.utilizador.isAdmin,
    })
  }, [])

  const logout = useCallback(async () => {
    await api.logout()
    setUtilizador(null)
  }, [])

  const value = useMemo(
    () => ({ utilizador, loading, login, logout }),
    [utilizador, loading, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth fora de AuthProvider')
  return ctx
}
