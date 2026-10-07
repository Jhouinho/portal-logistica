import { Box, Tooltip } from '@mui/material'
import { labels } from '../i18n/labels'

/** Indicador mínimo só de leitura — não é acção. */
export function UrgenteIcon() {
  return (
    <Tooltip title={labels.urgente} arrow>
      <Box
        component="span"
        aria-label={labels.urgente}
        sx={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          width: 18,
          height: 18,
          cursor: 'default',
        }}
      >
        <Box
          component="span"
          sx={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            bgcolor: 'error.main',
            boxShadow: (t) => `0 0 0 2px ${t.palette.error.main}33`,
          }}
        />
      </Box>
    </Tooltip>
  )
}
