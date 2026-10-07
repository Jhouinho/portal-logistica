import { Typography } from '@mui/material'
import { labels } from '../shared/i18n/labels'

export function PlaceholderPage({ title }: { title: string }) {
  return (
    <>
      <Typography variant="h4" gutterBottom>
        {title}
      </Typography>
      <Typography color="text.secondary">{labels.emConstrucao}</Typography>
    </>
  )
}
