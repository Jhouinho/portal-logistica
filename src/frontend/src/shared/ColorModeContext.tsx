import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { ThemeProvider, type PaletteMode } from '@mui/material'
import { createAppTheme } from './theme'
import { setPortalColorMode } from '../features/centro/portalChrome'

const STORAGE_KEY = 'portal-color-mode'

type ColorModeContextValue = {
  mode: PaletteMode
  toggleColorMode: () => void
  setMode: (mode: PaletteMode) => void
}

const ColorModeContext = createContext<ColorModeContextValue | null>(null)

function readStoredMode(): PaletteMode {
  try {
    const v = localStorage.getItem(STORAGE_KEY)
    if (v === 'light' || v === 'dark') return v
  } catch {
    /* ignore */
  }
  return 'dark'
}

export function ColorModeProvider({ children }: { children: ReactNode }) {
  const [mode, setModeState] = useState<PaletteMode>(readStoredMode)

  // Sincroniza tokens estáticos (portalSurface / centroPageBg) com o modo actual.
  setPortalColorMode(mode)

  const setMode = useCallback((next: PaletteMode) => {
    setModeState(next)
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch {
      /* ignore */
    }
  }, [])

  const toggleColorMode = useCallback(() => {
    setMode(mode === 'dark' ? 'light' : 'dark')
  }, [mode, setMode])

  const theme = useMemo(() => createAppTheme(mode), [mode])

  const value = useMemo(
    () => ({ mode, toggleColorMode, setMode }),
    [mode, toggleColorMode, setMode],
  )

  return (
    <ColorModeContext.Provider value={value}>
      <ThemeProvider theme={theme}>{children}</ThemeProvider>
    </ColorModeContext.Provider>
  )
}

export function useColorMode(): ColorModeContextValue {
  const ctx = useContext(ColorModeContext)
  if (!ctx) {
    throw new Error('useColorMode deve ser usado dentro de ColorModeProvider')
  }
  return ctx
}
