import { TimePicker } from '@mui/x-date-pickers/TimePicker'
import dayjs, { type Dayjs } from 'dayjs'
import customParseFormat from 'dayjs/plugin/customParseFormat'

dayjs.extend(customParseFormat)

/** Campo de hora com selector (valor API: HH:mm ou ''). */
export function TimeFilterField({
  label,
  value,
  onChange,
  width = 128,
}: {
  label: string
  value: string
  onChange: (hhMm: string) => void
  width?: number
}) {
  const parsed: Dayjs | null = value ? dayjs(value, 'HH:mm', true) : null
  const valid = parsed?.isValid() ? parsed : null

  return (
    <TimePicker
      ampm={false}
      label={label}
      value={valid}
      onChange={(d) => {
        onChange(d && d.isValid() ? d.format('HH:mm') : '')
      }}
      format="HH:mm"
      slotProps={{
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
              width: '100%',
            },
          },
        },
        openPickerButton: { size: 'small' },
      }}
    />
  )
}
