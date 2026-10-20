import { FormEvent, useRef, useState } from 'react'
import { Box, Stack, Typography } from '@mui/material'
import QrCodeScannerIcon from '@mui/icons-material/QrCodeScanner'
import { useNavigate } from 'react-router-dom'
import { clienteApi, clienteArtigoImagemUrl, type ClienteArtigo } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import { loadCarrinho, saveCarrinho, upsertLinha } from './carrinhoStorage'
import {
  ClienteAlert,
  ClientePageTitle,
  ClientePanel,
  ClientePrimaryButton,
  ClienteQtyStepper,
  ClienteSecondaryButton,
  ClienteTextField,
} from './clienteUi'

const COR_MAX_LENGTH = 100

export function ClienteArtigoPage() {
  const { cliente } = useClienteAuth()
  const navigate = useNavigate()
  const refInput = useRef<HTMLInputElement>(null)
  const [modo, setModo] = useState<'escolha' | 'manual' | 'resultado'>('escolha')
  const [ref, setRef] = useState('')
  const [artigo, setArtigo] = useState<ClienteArtigo | null>(null)
  const [cor, setCor] = useState('')
  const [qtt, setQtt] = useState(1)
  const [erro, setErro] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [imgFalhou, setImgFalhou] = useState(false)

  async function procurarRef(referencia: string) {
    setErro(null)
    setArtigo(null)
    setImgFalhou(false)
    setBusy(true)
    try {
      const a = await clienteApi.artigo(referencia.trim())
      setArtigo(a)
      setRef(a.ref)
      setCor('')
      setQtt(1)
      setModo('resultado')
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Artigo não encontrado.')
      setModo('manual')
    } finally {
      setBusy(false)
    }
  }

  async function onProcurar(e: FormEvent) {
    e.preventDefault()
    if (!ref.trim()) return
    await procurarRef(ref)
  }

  function adicionar() {
    if (!cliente || !artigo) return
    if (qtt < 1 || !Number.isInteger(qtt)) {
      setErro('A quantidade deve ser um número inteiro positivo.')
      return
    }
    const linhas = loadCarrinho(cliente.no, cliente.estab)
    const next = upsertLinha(linhas, {
      ref: artigo.ref,
      design: artigo.design,
      cor: cor.trim().slice(0, COR_MAX_LENGTH),
      qtt,
      precoUnitario: artigo.precoUnitario,
    })
    saveCarrinho(cliente.no, cliente.estab, next)
    navigate('/cliente/carrinho')
  }

  return (
    <Stack spacing={2.5}>
      <ClientePageTitle
        title="Novo pedido"
        subtitle="Identifique o artigo pela referência ou pelo QR Code."
      />

      {erro && <ClienteAlert severity="error">{erro}</ClienteAlert>}

      {modo === 'escolha' && (
        <Stack spacing={1.5}>
          <ClientePrimaryButton
            startIcon={<QrCodeScannerIcon />}
            onClick={() => {
              setModo('manual')
              setErro(null)
              window.setTimeout(() => refInput.current?.focus(), 50)
            }}
          >
            Ler QR Code
          </ClientePrimaryButton>
          <ClienteSecondaryButton
            onClick={() => {
              setModo('manual')
              setErro(null)
              window.setTimeout(() => refInput.current?.focus(), 50)
            }}
          >
            Introduzir referência
          </ClienteSecondaryButton>
          <Typography variant="caption" color="text.secondary" textAlign="center">
            Com o leitor QR do telemóvel, a referência é colada no campo seguinte.
          </Typography>
        </Stack>
      )}

      {(modo === 'manual' || modo === 'resultado') && (
        <Box component="form" onSubmit={onProcurar}>
          <Stack direction="row" spacing={1} alignItems="flex-start">
            <ClienteTextField
              label="Referência"
              value={ref}
              onChange={(e) => setRef(e.target.value)}
              required
              inputRef={refInput}
              inputProps={{ inputMode: 'text', autoCapitalize: 'characters' }}
            />
            <ClientePrimaryButton
              type="submit"
              disabled={busy}
              sx={{ width: 'auto', minWidth: 72, px: 2, flexShrink: 0 }}
            >
              OK
            </ClientePrimaryButton>
          </Stack>
        </Box>
      )}

      {artigo && modo === 'resultado' && (
        <ClientePanel>
          <Stack spacing={2}>
            {artigo.temImagem && !imgFalhou ? (
              <Box
                component="img"
                src={clienteArtigoImagemUrl(artigo.ref)}
                alt={artigo.design}
                loading="lazy"
                onError={() => setImgFalhou(true)}
                sx={{
                  width: '100%',
                  maxHeight: 260,
                  objectFit: 'contain',
                  borderRadius: 1.5,
                  bgcolor: 'background.default',
                }}
              />
            ) : (
              <Box
                sx={{
                  width: '100%',
                  height: 140,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  borderRadius: 1.5,
                  bgcolor: 'portal.mutedFill',
                  border: 1,
                  borderColor: 'portal.border',
                }}
              >
                <Typography variant="body2" color="text.secondary">
                  Imagem indisponível
                </Typography>
              </Box>
            )}

            <Box>
              <Typography fontWeight={800} fontSize={18} color="text.primary">
                {artigo.design}
              </Typography>
              <Typography variant="body2" color="text.secondary" mt={0.5}>
                Ref. {artigo.ref}
              </Typography>
              <Typography fontWeight={700} color="primary.main" mt={1} fontSize={20}>
                {artigo.precoUnitario.toFixed(2)} €
              </Typography>
            </Box>

            {artigo.avisoStockBaixo && (
              <ClienteAlert severity="warning">
                Disponibilidade limitada (a quantidade exacta não é mostrada).
              </ClienteAlert>
            )}

            <ClienteTextField
              label="Cor (opcional)"
              value={cor}
              onChange={(e) => setCor(e.target.value.slice(0, COR_MAX_LENGTH))}
              inputProps={{ maxLength: COR_MAX_LENGTH }}
              helperText={`Texto livre, até ${COR_MAX_LENGTH} caracteres.`}
            />

            <Box>
              <Typography variant="body2" color="text.secondary" mb={1}>
                Quantidade
              </Typography>
              <ClienteQtyStepper value={qtt} onChange={setQtt} />
            </Box>

            <ClientePrimaryButton onClick={adicionar}>Adicionar ao carrinho</ClientePrimaryButton>
            <ClienteSecondaryButton
              onClick={() => {
                setArtigo(null)
                setRef('')
                setModo('escolha')
                setErro(null)
              }}
            >
              Outro artigo
            </ClienteSecondaryButton>
          </Stack>
        </ClientePanel>
      )}
    </Stack>
  )
}
