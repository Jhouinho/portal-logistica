import { Box, Typography } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { labels } from '../i18n/labels'

type BrandLogoProps = {
  /** Mostra «Portal de Logística» (marca em texto — logotipo PNG fora do repositório público). */
  withTitle?: boolean
  /** Altura de referência tipográfica em px */
  height?: number
  titleVariant?: 'h5' | 'h6' | 'subtitle1' | 'body2'
  sx?: SxProps<Theme>
}

/**
 * Marca em texto (sem PNG no GitHub público).
 * O ficheiro local `logo-lsflores.png` pode existir à parte (gitignore).
 */
export function BrandLogo({
  withTitle = false,
  height = 40,
  titleVariant = 'body2',
  sx,
}: BrandLogoProps) {
  const fontSize = Math.max(14, Math.round(height * 0.55))
  return (
    <Box
      display="flex"
      alignItems="center"
      gap={1.5}
      sx={[{ color: 'inherit', minWidth: 0 }, ...(Array.isArray(sx) ? sx : sx ? [sx] : [])]}
    >
      <Typography
        component="span"
        fontWeight={800}
        noWrap
        sx={{
          fontSize,
          letterSpacing: 0.2,
          lineHeight: 1.1,
          flexShrink: 0,
        }}
      >
        L&S Flores
      </Typography>
      {withTitle && (
        <Typography
          variant={titleVariant}
          fontWeight={600}
          noWrap
          component="span"
          sx={{ opacity: 0.95 }}
        >
          {labels.appName}
        </Typography>
      )}
    </Box>
  )
}
