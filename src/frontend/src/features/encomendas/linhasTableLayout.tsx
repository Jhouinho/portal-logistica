import type { SxProps, Theme } from '@mui/material/styles'

/**
 * Larguras fixas (só %).
 * withCor: Artigo, Descrição, Cor, Unidade, Encomendada, Autorizada, Preço, Total, Stock
 * withoutCor: sem Cor
 * rastreio: Nº, !, Cliente, Artigo, Descrição, Cor, Unidade, Original, Actual, Fornecida, Por satisfazer, Autorizada, Preço, Total, Stock
 * rastreioSemArtigo: Nº, !, Cliente, Entrega, Expedição, Cor, Unidade, Por sat., Autorizada, Preço, Total, Stock
 */
export const linhasColWidths = {
  withCor: ['11%', '24%', '7%', '6%', '9%', '11%', '11%', '10%', '11%'] as const,
  withoutCor: ['13%', '30%', '7%', '10%', '12%', '11%', '9%', '8%'] as const,
  /** Separado ndos=66: Artigo, Descrição, Cor, Unidade, Qtd. documento, Expedida, Pendente */
  separadoExpedicao: ['14%', '28%', '8%', '8%', '14%', '14%', '14%'] as const,
  // Nº, !, Cliente, Artigo, Descrição, Cor, Unidade, Original, Actual, Fornecida, Por sat., Autorizada, Preço, Total, Stock
  rastreio: ['5%', '3%', '12%', '7%', '20%', '5%', '4%', '5%', '5%', '5%', '5%', '7%', '7%', '5%', '5%'] as const,
  // Nº, !, Cliente, Entrega, Expedição, Cor, Unidade, Por sat., Autorizada, Preço, Total, Stock
  rastreioSemArtigo: [
    '5%',
    '3%',
    '22%',
    '8%',
    '10%',
    '5%',
    '5%',
    '8%',
    '7%',
    '7%',
    '8%',
    '12%',
  ] as const,
}
export const linhasTableSx: SxProps<Theme> = {
  tableLayout: 'fixed',
  width: '100%',
  minWidth: 0,
  '& .MuiTableCell-root': {
    py: 0.35,
    px: 0.5,
    fontSize: '0.8125rem',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    verticalAlign: 'middle',
  },
  '& .MuiTableCell-head': {
    py: 0.85,
    px: 0.75,
    fontWeight: 700,
    fontSize: '0.75rem',
    letterSpacing: '0.02em',
    color: 'text.secondary',
    backgroundColor: (theme) => theme.palette.portal.mutedFill,
    borderBottom: '2px solid',
    borderColor: 'primary.main',
    position: 'sticky',
    top: 0,
    zIndex: 2,
  },
}

export const encomendasTableSx: SxProps<Theme> = {
  tableLayout: 'fixed',
  width: '100%',
  minWidth: 0,
  maxWidth: '100%',
  '& .MuiTableCell-root': {
    py: 0.5,
    px: { xs: 0.4, sm: 0.55 },
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    verticalAlign: 'middle',
  },
  '& .MuiTableCell-head': {
    py: 0.65,
  },
}

/** Célula numérica / input: conteúdo alinhado à direita da coluna. */
export const cellInputSx: SxProps<Theme> = {
  textAlign: 'right',
  px: 0.5,
}

export function LinhasColGroup({
  withCor,
  variant = 'encomenda',
}: {
  withCor?: boolean
  variant?: 'encomenda' | 'rastreio' | 'rastreioSemArtigo' | 'separadoExpedicao'
}) {
  const widths =
    variant === 'rastreioSemArtigo'
      ? linhasColWidths.rastreioSemArtigo
      : variant === 'rastreio'
        ? linhasColWidths.rastreio
        : variant === 'separadoExpedicao'
          ? linhasColWidths.separadoExpedicao
          : withCor
            ? linhasColWidths.withCor
            : linhasColWidths.withoutCor
  return (
    <colgroup>
      {widths.map((w, i) => (
        <col key={i} style={{ width: w }} />
      ))}
    </colgroup>
  )
}
