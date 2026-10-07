import { useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Card,
  CardActionArea,
  CardContent,
  CircularProgress,
  Typography,
} from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import { api, type PainelKpis } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'

type KpiCard = {
  key: keyof PainelKpis
  label: string
  to?: string
  emphasize?: boolean
}

const cards: KpiCard[] = [
  { key: 'encomendasEmAberto', label: 'Encomendas em aberto', to: '/encomendas' },
  {
    key: 'encomendasAposCorte',
    label: 'Encomendas após limite definido',
    to: '/encomendas?estado=AposCorte',
    emphasize: true,
  },
  { key: 'artigosEmRutura', label: 'Artigos em rutura', to: '/encomendas?vista=referencia', emphasize: true },
  { key: 'quantidadePorSatisfazer', label: 'Quantidade por satisfazer' },
  { key: 'quantidadeAutorizada', label: 'Quantidade autorizada' },
  { key: 'clientesAfetados', label: 'Clientes afectados' },
]

export function PainelPage() {
  const [kpis, setKpis] = useState<PainelKpis | null>(null)
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)

  useEffect(() => {
    let cancel = false
    setLoading(true)
    api
      .painelKpis()
      .then((data) => {
        if (!cancel) setKpis(data)
      })
      .catch((e: Error) => {
        if (!cancel) setErro(e.message)
      })
      .finally(() => {
        if (!cancel) setLoading(false)
      })
    return () => {
      cancel = true
    }
  }, [])

  return (
    <Box>
      <Typography variant="h5" fontWeight={700} gutterBottom>
        {labels.painel}
      </Typography>
      <Typography variant="body2" color="text.secondary" mb={3}>
        Visão operacional das encomendas em aberto
      </Typography>

      {erro && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {erro}
        </Alert>
      )}

      {loading || !kpis ? (
        <Box display="flex" justifyContent="center" py={8}>
          <CircularProgress />
        </Box>
      ) : (
        <Box
          display="grid"
          gap={2}
          gridTemplateColumns={{ xs: '1fr', sm: '1fr 1fr', md: '1fr 1fr 1fr' }}
        >
          {cards.map((c) => {
            const value = kpis[c.key]
            const content = (
              <CardContent sx={{ minHeight: 120 }}>
                <Typography variant="body2" color="text.secondary" gutterBottom>
                  {c.label}
                </Typography>
                <Typography
                  variant="h4"
                  fontWeight={700}
                  color={c.emphasize ? 'warning.main' : 'text.primary'}
                >
                  {fmt(value)}
                </Typography>
              </CardContent>
            )

            return (
              <Card
                key={c.key}
                variant="outlined"
                sx={{
                  height: '100%',
                  borderColor: c.emphasize ? 'warning.main' : 'divider',
                }}
              >
                {c.to ? (
                  <CardActionArea
                    component={RouterLink}
                    to={c.to}
                    sx={{ height: '100%', alignItems: 'stretch' }}
                  >
                    {content}
                  </CardActionArea>
                ) : (
                  content
                )}
              </Card>
            )
          })}
        </Box>
      )}
    </Box>
  )
}

function fmt(n: number) {
  return new Intl.NumberFormat('pt-PT', {
    maximumFractionDigits: Number.isInteger(n) ? 0 : 2,
  }).format(n)
}
