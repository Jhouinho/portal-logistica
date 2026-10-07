import { createTheme, type PaletteMode, type Theme } from '@mui/material/styles'

/** Tokens de superfície do portal (Centro, TV, painéis). */
export type PortalSurfaceTokens = {
  panel: string
  border: string
  radius: number
  pageBg: string
  pageGradient: string
  rowBorder: string
  mutedFill: string
  shadow: string
}

export const portalTokensByMode: Record<PaletteMode, PortalSurfaceTokens> = {
  dark: {
    panel: '#121A2B',
    border: 'rgba(91, 147, 255, 0.25)',
    radius: 1.5,
    pageBg: '#0B1220',
    pageGradient: 'radial-gradient(ellipse at top, #152038 0%, #0B1220 55%)',
    rowBorder: 'rgba(255,255,255,0.07)',
    mutedFill: 'rgba(255,255,255,0.03)',
    shadow: '0 8px 28px rgba(0,0,0,0.22)',
  },
  light: {
    panel: '#FFFFFF',
    border: 'rgba(15, 23, 42, 0.12)',
    radius: 1.5,
    pageBg: '#F0F3F8',
    pageGradient: 'radial-gradient(ellipse at top, #FFFFFF 0%, #E4EAF3 55%)',
    rowBorder: 'rgba(15, 23, 42, 0.08)',
    mutedFill: 'rgba(15, 23, 42, 0.03)',
    shadow: '0 8px 28px rgba(15, 23, 42, 0.08)',
  },
}

declare module '@mui/material/styles' {
  interface Palette {
    portal: PortalSurfaceTokens
  }
  interface PaletteOptions {
    portal?: Partial<PortalSurfaceTokens>
  }
}

export function createAppTheme(mode: PaletteMode): Theme {
  const portal = portalTokensByMode[mode]
  return createTheme({
    palette: {
      mode,
      portal,
      ...(mode === 'dark'
        ? {
            background: { default: '#0B1220', paper: '#121A2B' },
            primary: { main: '#3DB2FF' },
            warning: { main: '#FFB020' },
            success: { main: '#3DDC97' },
            error: { main: '#FF5C5C' },
            info: { main: '#7B8CDE' },
            text: { primary: '#E8EEF8', secondary: '#9AA8C0' },
          }
        : {
            background: { default: '#F0F3F8', paper: '#FFFFFF' },
            primary: { main: '#2B7FD4', contrastText: '#FFFFFF' },
            warning: { main: '#D97706' },
            success: { main: '#059669' },
            error: { main: '#DC2626' },
            info: { main: '#4F46E5' },
            text: { primary: '#0F172A', secondary: '#475569' },
            divider: 'rgba(15, 23, 42, 0.12)',
            action: {
              active: '#475569',
              hover: 'rgba(15, 23, 42, 0.04)',
              selected: 'rgba(15, 23, 42, 0.08)',
              disabled: 'rgba(15, 23, 42, 0.38)',
              disabledBackground: 'rgba(15, 23, 42, 0.12)',
            },
          }),
    },
    typography: {
      fontFamily: '"Segoe UI", "Roboto", "Helvetica", "Arial", sans-serif',
    },
    components: {
      MuiAppBar: {
        styleOverrides: {
          root: {
            backgroundImage: 'none',
          },
        },
      },
      MuiPaper: {
        styleOverrides: {
          root: {
            backgroundImage: 'none',
          },
        },
      },
      MuiOutlinedInput: {
        styleOverrides: {
          root: ({ theme }) =>
            theme.palette.mode === 'light'
              ? {
                  backgroundColor: '#FFFFFF',
                  '& .MuiOutlinedInput-notchedOutline': {
                    borderColor: 'rgba(15, 23, 42, 0.22)',
                  },
                  '&:hover .MuiOutlinedInput-notchedOutline': {
                    borderColor: 'rgba(15, 23, 42, 0.4)',
                  },
                }
              : {},
        },
      },
      MuiInputLabel: {
        styleOverrides: {
          root: ({ theme }) =>
            theme.palette.mode === 'light'
              ? {
                  color: theme.palette.text.secondary,
                  '&.Mui-focused': { color: theme.palette.primary.main },
                }
              : {},
        },
      },
    },
  })
}

/** @deprecated Prefer createAppTheme(mode) — mantido para imports legados. */
export const theme = createAppTheme('dark')
