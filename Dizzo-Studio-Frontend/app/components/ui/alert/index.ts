import type { VariantProps } from 'class-variance-authority'
import { cva } from 'class-variance-authority'

export { default as Alert } from './Alert.vue'
export { default as AlertAction } from './AlertAction.vue'
export { default as AlertDescription } from './AlertDescription.vue'
export { default as AlertTitle } from './AlertTitle.vue'

// `<Icon>` renders a span.iconify, so it lays out like a leading svg does.
export const alertVariants = cva('grid gap-0.5 rounded-xl border px-3.5 py-2.5 text-left text-sm has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2.5 *:[svg]:row-span-2 *:[svg]:translate-y-0.5 *:[svg]:text-current *:[svg:not([class*=size-])]:size-4 has-[>.iconify]:grid-cols-[auto_1fr] has-[>.iconify]:gap-x-2.5 [&>.iconify]:row-span-2 [&>.iconify]:mt-0.5 [&>.iconify]:size-4 group/alert relative w-full', {
  variants: {
    variant: {
      default: 'bg-card text-card-foreground',
      destructive: 'border-destructive/30 bg-destructive/5 text-destructive *:data-[slot=alert-description]:text-destructive/90 *:[svg]:text-current',
      warning: 'border-amber-200 bg-amber-50 text-amber-900 *:data-[slot=alert-description]:text-amber-900/80',
      success: 'border-emerald-200 bg-emerald-50 text-emerald-800 *:data-[slot=alert-description]:text-emerald-800/80',
    },
  },
  defaultVariants: {
    variant: 'default',
  },
})

export type AlertVariants = VariantProps<typeof alertVariants>
