import { Box, Typography } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { labels } from '../i18n/labels'
import logoLsflores from '../../assets/logo-lsflores.png'

type BrandLogoProps = {
  /** Mostra «Portal de Logística» ao lado do logotipo. */
  withTitle?: boolean
  /** Altura do logotipo em px */
  height?: number
  titleVariant?: 'h5' | 'h6' | 'subtitle1' | 'body2'
  sx?: SxProps<Theme>
}

/**
 * Logotipo L&S Flores (PNG branco — adequado a fundo escuro).
 */
export function BrandLogo({
  withTitle = false,
  height = 40,
  titleVariant = 'body2',
  sx,
}: BrandLogoProps) {
  return (
    <Box
      display="flex"
      alignItems="center"
      gap={1.5}
      sx={[{ color: 'inherit', minWidth: 0 }, ...(Array.isArray(sx) ? sx : sx ? [sx] : [])]}
    >
      <Box
        component="img"
        src={logoLsflores}
        alt="L&S Flores"
        sx={{
          height,
          width: 'auto',
          maxWidth: '100%',
          objectFit: 'contain',
          display: 'block',
          flexShrink: 0,
        }}
      />
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
