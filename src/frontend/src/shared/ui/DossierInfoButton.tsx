import { useId, useState, type MouseEvent } from 'react'
import { Box, IconButton, Popover, Typography } from '@mui/material'
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined'
import { labels } from '../i18n/labels'
import { fmtDate, fmtMetodoExpedicao } from '../format'
import { ClienteNomeDisplay, clienteNomeTitle } from './ClienteNomeDisplay'

export type DossierInfoButtonProps = {
  clienteNome?: string | null
  clienteNome2?: string | null
  /** BO2.u_mEntrega — texto corrido; omitido se vazio. */
  moradaEntrega?: string | null
  /** Só mostrar se o contexto já tiver o dado (ex. lista encomendas / detalhe). */
  dataEntrega?: string | null
  showDataEntrega?: boolean
  /** Só mostrar se o contexto já tiver o dado. */
  metodoExpedicao?: string | null
  showMetodoExpedicao?: boolean
  size?: 'small' | 'medium'
}

function textoMorada(v?: string | null): string | null {
  const t = v?.trim() ?? ''
  return t ? t : null
}

/**
 * ⓘ — informação adicional do dossier/encomenda (Popover MUI).
 * Não interfere com clique da linha (stopPropagation).
 */
export function DossierInfoButton({
  clienteNome,
  clienteNome2,
  moradaEntrega,
  dataEntrega,
  showDataEntrega = false,
  metodoExpedicao,
  showMetodoExpedicao = false,
  size = 'small',
}: DossierInfoButtonProps) {
  const [anchor, setAnchor] = useState<HTMLElement | null>(null)
  const titleId = useId()
  const morada = textoMorada(moradaEntrega)
  const open = Boolean(anchor)
  const aria = labels.infoEncomendaAria

  return (
    <>
      <IconButton
        size={size}
        aria-label={aria}
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-controls={open ? titleId : undefined}
        title={aria}
        onClick={(ev: MouseEvent<HTMLElement>) => {
          ev.stopPropagation()
          ev.preventDefault()
          setAnchor(ev.currentTarget)
        }}
        sx={{
          color: 'text.secondary',
          // Touch confortável sem aumentar o layout da linha em excesso.
          minWidth: 36,
          minHeight: 36,
          p: 0.75,
        }}
      >
        <InfoOutlinedIcon fontSize="small" />
      </IconButton>
      <Popover
        id={titleId}
        open={open}
        anchorEl={anchor}
        onClose={() => setAnchor(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
        transformOrigin={{ vertical: 'top', horizontal: 'left' }}
        onClick={(ev) => ev.stopPropagation()}
        slotProps={{
          paper: {
            sx: {
              p: 1.5,
              maxWidth: 360,
              minWidth: 240,
            },
          },
        }}
      >
        <Typography variant="subtitle2" component="h3" gutterBottom>
          {labels.infoEncomendaTitulo}
        </Typography>

        <Typography variant="caption" color="text.secondary" component="div">
          {labels.infoEncomendaCliente}
        </Typography>
        <Box sx={{ mb: 1.25 }} title={clienteNomeTitle(clienteNome, clienteNome2)}>
          <ClienteNomeDisplay nome={clienteNome} nome2={clienteNome2} />
        </Box>

        {morada ? (
          <Box sx={{ mb: showDataEntrega || showMetodoExpedicao ? 1.25 : 0 }}>
            <Typography variant="caption" color="text.secondary" component="div">
              {labels.moradaEntrega}
            </Typography>
            <Typography
              variant="body2"
              component="div"
              sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}
            >
              {morada}
            </Typography>
          </Box>
        ) : null}

        {showDataEntrega ? (
          <Box sx={{ mb: showMetodoExpedicao ? 1.25 : 0 }}>
            <Typography variant="caption" color="text.secondary" component="div">
              {labels.colEntrega}
            </Typography>
            <Typography variant="body2" component="div">
              {fmtDate(dataEntrega)}
            </Typography>
          </Box>
        ) : null}

        {showMetodoExpedicao ? (
          <Box>
            <Typography variant="caption" color="text.secondary" component="div">
              {labels.colMetodoExpedicao}
            </Typography>
            <Typography variant="body2" component="div">
              {fmtMetodoExpedicao(metodoExpedicao)}
            </Typography>
          </Box>
        ) : null}
      </Popover>
    </>
  )
}
