import { IconButton, Tooltip } from '@mui/material'
import DarkModeOutlinedIcon from '@mui/icons-material/DarkModeOutlined'
import LightModeOutlinedIcon from '@mui/icons-material/LightModeOutlined'
import { useColorMode } from '../ColorModeContext'
import { labels } from '../i18n/labels'

/** Alterna tema claro / escuro (persistido em localStorage). */
export function ColorModeToggle({ size = 'medium' }: { size?: 'small' | 'medium' }) {
  const { mode, toggleColorMode } = useColorMode()
  const isDark = mode === 'dark'
  return (
    <Tooltip title={isDark ? labels.temaClaro : labels.temaEscuro}>
      <IconButton
        color="inherit"
        onClick={toggleColorMode}
        size={size}
        aria-label={isDark ? labels.temaClaro : labels.temaEscuro}
      >
        {isDark ? <LightModeOutlinedIcon /> : <DarkModeOutlinedIcon />}
      </IconButton>
    </Tooltip>
  )
}
