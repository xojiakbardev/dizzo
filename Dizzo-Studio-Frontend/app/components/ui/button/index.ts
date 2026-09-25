import type { VariantProps } from 'class-variance-authority'
import { cva } from 'class-variance-authority'

export { default as Button } from './Button.vue'

export const buttonVariants = cva(
  'focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 rounded-xl border border-transparent bg-clip-padding text-sm font-medium focus-visible:ring-3 aria-invalid:ring-3 active:not-aria-[haspopup]:translate-y-px [&_svg:not([class*=size-])]:size-4 group/button inline-flex shrink-0 items-center justify-center whitespace-nowrap transition-all outline-none select-none disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0',
  {
    variants: {
      variant: {
        // Filled buttons use the deeper CTA orange (--color-cta): white text on
        // the brand #ed5123 fails WCAG AA contrast.
        default: 'bg-cta text-primary-foreground hover:bg-cta-hover',
        outline: 'border-border bg-background hover:bg-muted hover:text-foreground dark:bg-input/30 dark:border-input dark:hover:bg-input/50 aria-expanded:bg-muted aria-expanded:text-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80 aria-expanded:bg-secondary aria-expanded:text-secondary-foreground',
        ghost: 'hover:bg-muted hover:text-foreground dark:hover:bg-muted/50 aria-expanded:bg-muted aria-expanded:text-foreground',
        destructive: 'bg-destructive/10 hover:bg-destructive/20 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 dark:bg-destructive/20 text-destructive focus-visible:border-destructive/40 dark:hover:bg-destructive/30',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        'default': 'h-10 gap-2 px-4 py-2 text-sm font-medium rounded-xl',
        'xs': 'h-7 gap-1 rounded-md px-2.5 text-xs',
        'sm': 'h-8.5 gap-1.5 rounded-lg px-3 text-xs',
        'lg': 'h-12 gap-2.5 rounded-2xl px-6 text-base font-semibold',
        'icon': 'size-10 rounded-xl',
        'icon-xs': 'size-7 rounded-md [&_svg:not([class*=size-])]:size-3.5',
        'icon-sm': 'size-8.5 rounded-lg [&_svg:not([class*=size-])]:size-4',
        'icon-lg': 'size-12 rounded-2xl [&_svg:not([class*=size-])]:size-5',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  },
)
export type ButtonVariants = VariantProps<typeof buttonVariants>
