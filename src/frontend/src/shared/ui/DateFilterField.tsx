import { DatePicker } from '@mui/x-date-pickers/DatePicker'
import dayjs, { type Dayjs } from 'dayjs'
import customParseFormat from 'dayjs/plugin/customParseFormat'

dayjs.extend(customParseFormat)

/** Campo de data com calendário (valor API: yyyy-MM-dd ou ''). */
export function DateFilterField({
  label,
  value,
  onChange,
  width = 168,
  disabled = false,
}: {
  label: string
  value: string
  onChange: (yyyyMmDd: string) => void
  width?: number
  disabled?: boolean
}) {
  const parsed: Dayjs | null = value ? dayjs(value, 'YYYY-MM-DD', true) : null
  const valid = parsed?.isValid() ? parsed : null

  return (
    <DatePicker
      label={label}
      value={valid}
      disabled={disabled}
      onChange={(d) => {
        onChange(d && d.isValid() ? d.format('YYYY-MM-DD') : '')
      }}
      format="DD/MM/YYYY"
      slotProps={{
        field: { clearable: !disabled },
        clearButton: { size: 'small', 'aria-label': `Limpar ${label}` },
        textField: {
          size: 'small',
          sx: {
            width,
            minWidth: width,
            flexShrink: 0,
            '& .MuiInputAdornment-root': { ml: 0 },
            '& .MuiIconButton-root': { p: 0.5 },
            '& .MuiPickersSectionList-root, & .MuiPickersInputBase-sectionsContainer': {
              overflow: 'hidden',
              textOverflow: 'clip',
              width: '100%',
            },
          },
        },
        openPickerButton: { size: 'small' },
      }}
    />
  )
}
