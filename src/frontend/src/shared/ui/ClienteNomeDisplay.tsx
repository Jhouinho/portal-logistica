import { Box, Typography, type SxProps, type Theme } from '@mui/material'

/** Título completo para tooltip / aria (nome2 + nome). */
export function clienteNomeTitle(
  nome?: string | null,
  nome2?: string | null,
): string {
  const n2 = nome2?.trim() ?? ''
  const n = nome?.trim() ?? ''
  if (n2 && n) return `${n2} — ${n}`
  return n2 || n
}

/**
 * PR5 — Apresentação do cliente:
 * nome2 = principal (negrito); nome = secundário (menor) só quando ambos existem.
 * Se só houver nome, esse assume o estilo principal.
 */
export function ClienteNomeDisplay({
  nome,
  nome2,
  clienteNo,
  showClienteNo = false,
  compact = false,
  dense = false,
  fallback = '—',
  sx,
}: {
  nome?: string | null
  nome2?: string | null
  clienteNo?: number | null
  showClienteNo?: boolean
  compact?: boolean
  /** Ainda mais pequeno que `compact` — listas densas (ex.: Centro). */
  dense?: boolean
  fallback?: string
  sx?: SxProps<Theme>
}) {
  const n2 = nome2?.trim() ?? ''
  const n = nome?.trim() ?? ''
  const primary = n2 || n
  const secondary = n2 && n ? n : ''
  const prefix =
    showClienteNo && clienteNo != null && Number.isFinite(clienteNo)
      ? `${clienteNo} — `
      : ''

  if (!primary) {
    return (
      <Typography
        component="span"
        variant="body2"
        sx={[{ minWidth: 0 }, ...(sx ? (Array.isArray(sx) ? sx : [sx]) : [])]}
      >
        {prefix}
        {fallback}
      </Typography>
    )
  }

  return (
    <Box
      component="span"
      sx={[
        {
          display: 'inline-flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          minWidth: 0,
          maxWidth: '100%',
        },
        ...(sx ? (Array.isArray(sx) ? sx : [sx]) : []),
      ]}
    >
      <Typography
        component="span"
        fontWeight={700}
        title={clienteNomeTitle(nome, nome2)}
        sx={{
          fontSize: dense ? '0.7rem' : compact ? '0.8125rem' : '0.9375rem',
          lineHeight: 1.2,
          letterSpacing: 0.01,
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
          maxWidth: '100%',
        }}
      >
        {prefix}
        {primary}
      </Typography>
      {secondary ? (
        <Typography
          component="span"
          fontWeight={400}
          color="text.secondary"
          title={secondary}
          sx={{
            fontSize: dense ? '0.6rem' : compact ? '0.6875rem' : '0.75rem',
            lineHeight: 1.15,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
            maxWidth: '100%',
          }}
        >
          {secondary}
        </Typography>
      ) : null}
    </Box>
  )
}
