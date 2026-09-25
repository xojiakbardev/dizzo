<script setup lang="ts">
// A status pill: a Badge in one of the status tones, with a dot.
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

export type StatusTone = 'success' | 'warn' | 'info' | 'danger' | 'destructive' | 'neutral' | 'brand'

const props = withDefaults(defineProps<{
  tone?: StatusTone
  withDot?: boolean
  class?: HTMLAttributes['class']
}>(), { tone: 'neutral', withDot: true })

const TONES: Record<StatusTone, string> = {
  success: 'border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-800/60 dark:bg-emerald-950/40 dark:text-emerald-300',
  warn: 'border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-800/60 dark:bg-amber-950/40 dark:text-amber-300',
  info: 'border-sky-200 bg-sky-50 text-sky-700 dark:border-sky-800/60 dark:bg-sky-950/40 dark:text-sky-300',
  danger: 'border-rose-200 bg-rose-50 text-rose-700 dark:border-rose-800/60 dark:bg-rose-950/40 dark:text-rose-300',
  destructive: 'border-rose-200 bg-rose-50 text-rose-700 dark:border-rose-800/60 dark:bg-rose-950/40 dark:text-rose-300',
  neutral: 'border-slate-200 bg-slate-100 text-slate-700 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-300',
  brand: 'border-secondary-200 bg-secondary-50 text-secondary-700 dark:border-secondary-800/60 dark:bg-secondary-950/40 dark:text-secondary-300',
}
const DOTS: Record<StatusTone, string> = {
  success: 'bg-emerald-500',
  warn: 'bg-amber-500',
  info: 'bg-sky-500',
  danger: 'bg-rose-500',
  destructive: 'bg-rose-500',
  neutral: 'bg-slate-400',
  brand: 'bg-secondary-500',
}
</script>

<template>
  <UiBadge
    variant="outline"
    :class="cn('h-6 gap-1.5 px-2.5 font-semibold', TONES[props.tone], props.class)"
  >
    <span
      v-if="withDot"
      :class="cn('size-1.5 shrink-0 rounded-full', DOTS[props.tone])"
    />
    <slot />
  </UiBadge>
</template>
