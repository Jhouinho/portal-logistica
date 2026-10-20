import { useState, type ReactNode } from 'react'
import {
  Alert,
  Box,
  Button,
  Chip,
  IconButton,
  Link,
  Paper,
  Stack,
  TextField,
  Typography,
  type ButtonProps,
  type TextFieldProps,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import RemoveIcon from '@mui/icons-material/Remove'
import ArrowBackIosNewIcon from '@mui/icons-material/ArrowBackIosNew'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline'
import ScheduleIcon from '@mui/icons-material/Schedule'
import LocalShippingOutlinedIcon from '@mui/icons-material/LocalShippingOutlined'
import TaskAltIcon from '@mui/icons-material/TaskAlt'
import { Link as RouterLink, useNavigate } from 'react-router-dom'
import { BrandLogo } from '../../shared/ui/BrandLogo'
import { clienteArtigoImagemUrl } from './clienteApi'

/** Fundo de página auth / conteúdo alinhado ao mockup VANGFLOR. */
export function ClientePageBg({ children }: { children: ReactNode }) {
  return (
    <Box
      minHeight="100dvh"
      display="flex"
      flexDirection="column"
      alignItems="center"
      justifyContent="center"
      px={2}
      py={3}
      bgcolor="background.default"
      sx={{ backgroundImage: (t) => t.palette.portal.pageGradient }}
    >
      {children}
    </Box>
  )
}

export function ClienteAuthCard({
  title,
  subtitle,
  children,
}: {
  title: string
  subtitle?: string
  children: ReactNode
}) {
  return (
    <Paper
      elevation={0}
      sx={{
        p: 3,
        width: '100%',
        maxWidth: 420,
        borderRadius: 2,
        border: 1,
        borderColor: 'portal.border',
        bgcolor: 'background.paper',
        boxShadow: (t) => t.palette.portal.shadow,
      }}
    >
      <Box mb={2} display="flex" justifyContent="center">
        <BrandLogo height={40} />
      </Box>
      <Typography variant="h5" color="text.primary" fontWeight={700} gutterBottom>
        {title}
      </Typography>
      {subtitle && (
        <Typography variant="body2" color="text.secondary" mb={2.5}>
          {subtitle}
        </Typography>
      )}
      {children}
    </Paper>
  )
}

/** Indicador 1 — 2 — 3 do mockup (primeiro acesso / recuperar). */
export function ClienteStepDots({ step, total = 3 }: { step: number; total?: number }) {
  return (
    <Stack direction="row" spacing={1} justifyContent="center" mb={2.5}>
      {Array.from({ length: total }, (_, i) => {
        const n = i + 1
        const active = n === step
        const done = n < step
        return (
          <Box
            key={n}
            sx={{
              width: 28,
              height: 28,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 13,
              fontWeight: 700,
              bgcolor: active || done ? 'primary.main' : 'transparent',
              color: active || done ? '#0B1220' : 'text.secondary',
              border: 2,
              borderColor: active || done ? 'primary.main' : 'portal.border',
            }}
          >
            {n}
          </Box>
        )
      })}
    </Stack>
  )
}

export function ClientePrimaryButton(props: ButtonProps) {
  return (
    <Button
      variant="contained"
      size="large"
      fullWidth
      {...props}
      sx={{
        minHeight: 48,
        fontWeight: 700,
        textTransform: 'none',
        borderRadius: 1.5,
        ...props.sx,
      }}
    />
  )
}

export function ClienteSecondaryButton(props: ButtonProps) {
  return (
    <Button
      variant="outlined"
      size="large"
      fullWidth
      color="primary"
      {...props}
      sx={{
        minHeight: 48,
        fontWeight: 600,
        textTransform: 'none',
        borderRadius: 1.5,
        borderWidth: 1.5,
        ...props.sx,
      }}
    />
  )
}

export function ClienteDangerButton(props: ButtonProps) {
  return (
    <Button
      variant="contained"
      color="error"
      size="large"
      fullWidth
      {...props}
      sx={{
        minHeight: 48,
        fontWeight: 700,
        textTransform: 'none',
        borderRadius: 1.5,
        ...props.sx,
      }}
    />
  )
}

export function ClienteTextField(props: TextFieldProps) {
  return (
    <TextField
      fullWidth
      variant="outlined"
      {...props}
      InputLabelProps={{ shrink: true, ...props.InputLabelProps }}
      sx={{
        '& .MuiOutlinedInput-root': { borderRadius: 1.5, minHeight: 48 },
        ...props.sx,
      }}
    />
  )
}

export function ClientePanel({ children, sx }: { children: ReactNode; sx?: object }) {
  return (
    <Box
      bgcolor="background.paper"
      p={2}
      borderRadius={2}
      border={1}
      borderColor="portal.border"
      sx={{ boxShadow: (t) => t.palette.portal.shadow, ...sx }}
    >
      {children}
    </Box>
  )
}

const ESTADO_STYLES: Record<
  string,
  { bg: string; color: string; icon: typeof CheckCircleIcon }
> = {
  submetido: { bg: 'rgba(61, 220, 151, 0.22)', color: '#3DDC97', icon: CheckCircleIcon },
  recebido: { bg: 'rgba(61, 220, 151, 0.22)', color: '#3DDC97', icon: CheckCircleIcon },
  em_analise: { bg: 'rgba(255, 176, 32, 0.22)', color: '#FFB020', icon: ScheduleIcon },
  em_preparacao: { bg: 'rgba(255, 176, 32, 0.22)', color: '#FFB020', icon: ScheduleIcon },
  pronto: { bg: 'rgba(61, 178, 255, 0.22)', color: '#3DB2FF', icon: LocalShippingOutlinedIcon },
  pronto_para_levantamento: {
    bg: 'rgba(61, 178, 255, 0.22)',
    color: '#3DB2FF',
    icon: LocalShippingOutlinedIcon,
  },
  aprovado: { bg: 'rgba(61, 178, 255, 0.22)', color: '#3DB2FF', icon: TaskAltIcon },
  concluido: { bg: 'rgba(167, 139, 250, 0.22)', color: '#A78BFA', icon: TaskAltIcon },
  cancelado: { bg: 'rgba(255, 92, 92, 0.22)', color: '#FF5C5C', icon: ErrorOutlineIcon },
}

export function ClienteEstadoBadge({
  codigo,
  etiqueta,
}: {
  codigo?: string | null
  etiqueta: string
}) {
  const key = (codigo ?? '').toLowerCase().replace(/\s+/g, '_')
  const style = ESTADO_STYLES[key] ?? {
    bg: 'rgba(154, 168, 192, 0.15)',
    color: '#9AA8C0',
    icon: CheckCircleOutlineIcon,
  }
  const Icon = style.icon
  return (
    <Chip
      size="small"
      icon={<Icon sx={{ fontSize: '16px !important', color: `${style.color} !important` }} />}
      label={etiqueta}
      sx={{
        bgcolor: style.bg,
        color: style.color,
        fontWeight: 700,
        fontSize: 12,
        height: 28,
        borderRadius: 1.5,
        '& .MuiChip-label': { px: 0.75 },
      }}
    />
  )
}

/** Título de página interior com seta Voltar (mockup). */
export function ClientePageTitle({
  title,
  subtitle,
  backTo = '/cliente',
}: {
  title: string
  subtitle?: string
  backTo?: string
}) {
  const navigate = useNavigate()
  return (
    <Stack direction="row" alignItems="flex-start" spacing={1} mb={0.5}>
      <IconButton
        aria-label="Voltar"
        onClick={() => navigate(backTo)}
        sx={{
          mt: 0.25,
          color: 'primary.main',
          border: 1,
          borderColor: 'portal.border',
          borderRadius: 1.5,
          width: 40,
          height: 40,
        }}
      >
        <ArrowBackIosNewIcon sx={{ fontSize: 16 }} />
      </IconButton>
      <Box flex={1} minWidth={0}>
        <Typography variant="h5" fontWeight={800} color="text.primary">
          {title}
        </Typography>
        {subtitle && (
          <Typography variant="body2" color="text.secondary" mt={0.5}>
            {subtitle}
          </Typography>
        )}
      </Box>
    </Stack>
  )
}

export function ClienteQtyStepper({
  value,
  onChange,
  min = 1,
}: {
  value: number
  onChange: (n: number) => void
  min?: number
}) {
  return (
    <Stack direction="row" alignItems="center" spacing={0.5}>
      <IconButton
        aria-label="Diminuir"
        size="small"
        onClick={() => onChange(Math.max(min, value - 1))}
        disabled={value <= min}
        sx={{
          border: 1,
          borderColor: 'portal.border',
          borderRadius: 1,
          color: 'text.primary',
          width: 40,
          height: 40,
        }}
      >
        <RemoveIcon fontSize="small" />
      </IconButton>
      <Typography
        fontWeight={700}
        color="text.primary"
        sx={{ minWidth: 36, textAlign: 'center', fontSize: 18 }}
      >
        {value}
      </Typography>
      <IconButton
        aria-label="Aumentar"
        size="small"
        onClick={() => onChange(value + 1)}
        sx={{
          border: 1,
          borderColor: 'portal.border',
          borderRadius: 1,
          color: 'text.primary',
          width: 40,
          height: 40,
        }}
      >
        <AddIcon fontSize="small" />
      </IconButton>
    </Stack>
  )
}

export function ClienteArtigoThumb({
  refCode,
  alt,
  size = 64,
}: {
  refCode: string
  alt: string
  size?: number
}) {
  const [failed, setFailed] = useState(false)
  if (failed) {
    return (
      <Box
        sx={{
          width: size,
          height: size,
          flexShrink: 0,
          borderRadius: 1.5,
          bgcolor: 'portal.mutedFill',
          border: 1,
          borderColor: 'portal.border',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Typography variant="caption" color="text.secondary" px={0.5} textAlign="center">
          Sem img
        </Typography>
      </Box>
    )
  }
  return (
    <Box
      component="img"
      src={clienteArtigoImagemUrl(refCode)}
      alt={alt}
      loading="lazy"
      onError={() => setFailed(true)}
      sx={{
        width: size,
        height: size,
        flexShrink: 0,
        objectFit: 'cover',
        borderRadius: 1.5,
        bgcolor: 'background.default',
        border: 1,
        borderColor: 'portal.border',
      }}
    />
  )
}

export function ClienteSuccessPanel({
  title,
  detail,
  highlight,
  children,
}: {
  title: string
  detail?: string
  highlight?: string
  children?: ReactNode
}) {
  return (
    <ClientePanel>
      <Stack alignItems="center" spacing={2} py={3} px={1} textAlign="center">
        <Box
          sx={{
            width: 88,
            height: 88,
            borderRadius: '50%',
            bgcolor: 'rgba(61, 220, 151, 0.18)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <CheckCircleIcon sx={{ fontSize: 52, color: 'success.main' }} />
        </Box>
        <Typography variant="h6" fontWeight={800} color="text.primary">
          {title}
        </Typography>
        {detail && (
          <Typography variant="body2" color="text.secondary">
            {detail}
          </Typography>
        )}
        {highlight && (
          <Typography
            variant="body1"
            fontWeight={700}
            color="primary.main"
            sx={{ maxWidth: 320, lineHeight: 1.4 }}
          >
            {highlight}
          </Typography>
        )}
        {children}
      </Stack>
    </ClientePanel>
  )
}

export function ClienteErrorPanel({
  title,
  detail,
  children,
}: {
  title: string
  detail?: string
  children?: ReactNode
}) {
  return (
    <ClientePanel>
      <Stack alignItems="center" spacing={2} py={2} textAlign="center">
        <ErrorOutlineIcon sx={{ fontSize: 56, color: 'error.main' }} />
        <Typography variant="h6" fontWeight={700} color="text.primary">
          {title}
        </Typography>
        {detail && (
          <Typography variant="body2" color="text.secondary">
            {detail}
          </Typography>
        )}
        {children}
      </Stack>
    </ClientePanel>
  )
}

export function ClienteBackToLogin() {
  return (
    <Box mt={2.5} textAlign="center">
      <Link component={RouterLink} to="/cliente/login" underline="hover" color="primary">
        Voltar ao login
      </Link>
    </Box>
  )
}

export function ClienteAlert({
  severity,
  children,
}: {
  severity: 'error' | 'warning' | 'success' | 'info'
  children: ReactNode
}) {
  return (
    <Alert
      severity={severity}
      sx={{
        borderRadius: 1.5,
        alignItems: 'center',
        '& .MuiAlert-message': { width: '100%' },
      }}
    >
      {children}
    </Alert>
  )
}
