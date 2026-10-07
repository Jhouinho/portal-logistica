import { useEffect, useState } from 'react'
import { Alert, Snackbar } from '@mui/material'

export type GravacaoSnack = {
  message: string
  severity: 'error' | 'success' | 'info' | 'warning'
}

/** Alerta temporário no canto inferior direito. */
export function GravacaoSnackbar({
  snack,
  onClose,
}: {
  snack: GravacaoSnack | null
  onClose: () => void
}) {
  const [open, setOpen] = useState(false)
  const [actual, setActual] = useState<GravacaoSnack | null>(null)

  useEffect(() => {
    if (snack) {
      setActual(snack)
      setOpen(true)
    } else {
      setOpen(false)
    }
  }, [snack])

  return (
    <Snackbar
      open={open}
      autoHideDuration={actual?.severity === 'success' ? 3500 : 6000}
      onClose={(_, reason) => {
        if (reason === 'clickaway') return
        setOpen(false)
        onClose()
      }}
      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      TransitionProps={{
        onExited: () => setActual(null),
      }}
    >
      {actual ? (
        <Alert
          severity={actual.severity}
          variant="filled"
          onClose={() => {
            setOpen(false)
            onClose()
          }}
          sx={{ width: '100%' }}
        >
          {actual.message}
        </Alert>
      ) : undefined}
    </Snackbar>
  )
}
