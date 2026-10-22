import { useEffect, useRef, useState } from 'react'
import { Box, IconButton, Stack, Typography } from '@mui/material'
import CloseIcon from '@mui/icons-material/Close'
import PhotoCameraIcon from '@mui/icons-material/PhotoCamera'
import { Html5Qrcode } from 'html5-qrcode'
import { ClienteAlert, ClientePrimaryButton, ClienteSecondaryButton } from './clienteUi'

const LIVE_REGION_ID = 'cliente-qr-live'
const FILE_REGION_ID = 'cliente-qr-file'

type Props = {
  open: boolean
  onClose: () => void
  onDecoded: (referencia: string) => void
}

/** QR de artigo contém só a referência; aceita também URL com ?ref= ou último segmento. */
export function normalizeQrPayload(raw: string): string {
  const t = raw.trim()
  if (!t) return t
  try {
    if (/^https?:\/\//i.test(t)) {
      const u = new URL(t)
      const fromQuery = u.searchParams.get('ref') ?? u.searchParams.get('referencia')
      if (fromQuery?.trim()) return fromQuery.trim()
      const parts = u.pathname.split('/').filter(Boolean)
      if (parts.length > 0) return decodeURIComponent(parts[parts.length - 1]!)
    }
  } catch {
    /* texto simples */
  }
  return t
}

export function isIosSafari(): boolean {
  if (typeof navigator === 'undefined') return false
  const ua = navigator.userAgent
  const iOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
  const webkit = /WebKit/i.test(ua)
  const chromeIos = /CriOS|FxiOS|EdgiOS/i.test(ua)
  return iOS && webkit && !chromeIos
}

export function httpsHintUrl(): string | null {
  if (typeof window === 'undefined' || window.isSecureContext) return null
  const { hostname, port } = window.location
  if (hostname === 'localhost' || hostname === '127.0.0.1') return null
  if (port === '8088') return `https://${hostname}:8443${window.location.pathname}${window.location.search}`
  return `https://${hostname}${window.location.pathname}${window.location.search}`
}

/**
 * iOS Safari exige getUserMedia no gesto do toque.
 * Chamar isto no onClick antes de abrir o overlay.
 */
export async function primeCameraForQr(): Promise<void> {
  if (!window.isSecureContext) {
    throw new Error(
      'A leitura em direto da câmara requer o portal em HTTPS com certificado válido (como em produção).',
    )
  }
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Este browser não permite acesso à câmara.')
  }
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: false,
    video: { facingMode: { ideal: 'environment' } },
  })
  stream.getTracks().forEach((t) => t.stop())
}

export function ClienteQrScanner({ open, onClose, onDecoded }: Props) {
  const scannerRef = useRef<Html5Qrcode | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const handledRef = useRef(false)
  const onDecodedRef = useRef(onDecoded)
  const onCloseRef = useRef(onClose)
  const [hint, setHint] = useState<string | null>(null)
  const [erro, setErro] = useState<string | null>(null)
  const [busyFile, setBusyFile] = useState(false)
  const [liveActive, setLiveActive] = useState(false)
  const [starting, setStarting] = useState(false)

  onDecodedRef.current = onDecoded
  onCloseRef.current = onClose

  useEffect(() => {
    if (!open) return

    handledRef.current = false
    setErro(null)
    setHint(null)
    setLiveActive(false)
    setBusyFile(false)
    setStarting(true)

    let cancelled = false
    const ios = isIosSafari()

    async function stopLive() {
      const s = scannerRef.current
      scannerRef.current = null
      if (!s) return
      try {
        if (s.isScanning) await s.stop()
        s.clear()
      } catch {
        /* ignore */
      }
    }

    function onSuccess(decoded: string) {
      if (cancelled || handledRef.current) return
      handledRef.current = true
      void stopLive().then(() => {
        onDecodedRef.current(normalizeQrPayload(decoded))
        onCloseRef.current()
      })
    }

    async function startLive() {
      // Dois frames: overlay já no DOM (crítico no iOS)
      await new Promise<void>((r) => requestAnimationFrame(() => requestAnimationFrame(() => r())))
      if (cancelled) return

      if (!window.isSecureContext) {
        setStarting(false)
        setHint(
          'Neste endereço a câmara em direto não está disponível. Use «Fotografar código» ou abra o portal pelo URL HTTPS de produção.',
        )
        return
      }

      const host = document.getElementById(LIVE_REGION_ID)
      if (!host) {
        setStarting(false)
        setHint('Não foi possível preparar o leitor. Feche e tente novamente.')
        return
      }

      const boxSize = Math.min(260, Math.floor(Math.min(window.innerWidth, window.innerHeight) * 0.65))
      const config = {
        fps: ios ? 10 : 12,
        qrbox: { width: boxSize, height: boxSize },
        aspectRatio: 1.0,
        // iOS: não inverter — melhora estabilidade
        disableFlip: ios,
      }

      try {
        await stopLive()
        const scanner = new Html5Qrcode(LIVE_REGION_ID, { verbose: false })
        scannerRef.current = scanner

        // iOS: deviceId via getCameras costuma falhar / labels vazios — preferir facingMode
        if (ios) {
          await scanner.start({ facingMode: 'environment' }, config, onSuccess, () => undefined)
        } else {
          try {
            const cameras = await Html5Qrcode.getCameras()
            const back =
              cameras.find((c) => /back|rear|traseir|environment/i.test(c.label)) ??
              cameras[cameras.length - 1]
            if (back?.id) {
              await scanner.start(back.id, config, onSuccess, () => undefined)
            } else {
              await scanner.start({ facingMode: 'environment' }, config, onSuccess, () => undefined)
            }
          } catch {
            await scanner.start({ facingMode: 'environment' }, config, onSuccess, () => undefined)
          }
        }

        if (cancelled) {
          await stopLive()
          return
        }
        setLiveActive(true)
        setStarting(false)
        setHint(null)
      } catch (err) {
        if (cancelled) return
        setLiveActive(false)
        setStarting(false)
        const msg = err instanceof Error ? err.message : String(err)
        setHint(
          `Não foi possível abrir a câmara em direto (${msg}). Autorize a câmara no browser ou use «Fotografar código».`,
        )
      }
    }

    void startLive()

    return () => {
      cancelled = true
      void stopLive()
    }
  }, [open])

  async function onPickFile(file: File | undefined) {
    if (!file || handledRef.current) return
    setBusyFile(true)
    setErro(null)
    try {
      const scanner = new Html5Qrcode(FILE_REGION_ID, { verbose: false })
      const decoded = await scanner.scanFile(file, false)
      try {
        scanner.clear()
      } catch {
        /* ignore */
      }
      handledRef.current = true
      onDecodedRef.current(normalizeQrPayload(decoded))
      onCloseRef.current()
    } catch {
      setErro('Não foi possível ler um QR Code nesta imagem. Aproxime-se e tente outra fotografia.')
    } finally {
      setBusyFile(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  if (!open) return null

  return (
    <Box
      role="dialog"
      aria-modal="true"
      aria-label="Ler QR Code"
      sx={{
        position: 'fixed',
        inset: 0,
        zIndex: (t) => t.zIndex.modal + 2,
        bgcolor: 'background.paper',
        display: 'flex',
        flexDirection: 'column',
        // iOS Safari: evitar bounce / barra que parte o video
        height: '100dvh',
        overflow: 'auto',
        WebkitOverflowScrolling: 'touch',
      }}
    >
      <Stack direction="row" alignItems="center" justifyContent="space-between" px={2} py={1.5}>
        <Typography fontWeight={700} fontSize={18}>
          Ler QR Code
        </Typography>
        <IconButton aria-label="Fechar" onClick={onClose} edge="end">
          <CloseIcon />
        </IconButton>
      </Stack>

      <Stack spacing={2} px={2} pb={3} flex={1}>
        {erro && <ClienteAlert severity="error">{erro}</ClienteAlert>}
        {hint && (
          <ClienteAlert severity="info">
            <Typography component="span" variant="body2" whiteSpace="pre-line">
              {hint}
            </Typography>
          </ClienteAlert>
        )}

        <Box
          id={LIVE_REGION_ID}
          sx={{
            width: '100%',
            minHeight: liveActive || starting ? 320 : 0,
            overflow: 'hidden',
            borderRadius: 1.5,
            bgcolor: liveActive || starting ? 'common.black' : 'transparent',
            '& video': {
              width: '100%',
              borderRadius: 1.5,
              objectFit: 'cover',
            },
          }}
        />

        <Box id={FILE_REGION_ID} sx={{ display: 'none' }} />

        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          hidden
          onChange={(e) => void onPickFile(e.target.files?.[0])}
        />

        <Typography variant="body2" color="text.secondary">
          {liveActive
            ? 'Aponte a câmara para o QR Code — a referência é lida automaticamente.'
            : starting
              ? 'A abrir a câmara…'
              : 'Se a câmara em direto não abrir, use «Fotografar código».'}
        </Typography>

        <ClientePrimaryButton
          startIcon={<PhotoCameraIcon />}
          disabled={busyFile}
          onClick={() => fileInputRef.current?.click()}
        >
          {busyFile ? 'A ler…' : 'Fotografar código'}
        </ClientePrimaryButton>
        <ClienteSecondaryButton onClick={onClose}>Cancelar</ClienteSecondaryButton>
      </Stack>
    </Box>
  )
}
