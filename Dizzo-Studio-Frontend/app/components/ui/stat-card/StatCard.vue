<script setup lang="ts">
// A dashboard figure on a Card: title, big value, a hint and a tinted icon.
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = withDefaults(defineProps<{
  title: string
  value: string | number
  hint?: string
  icon?: string
  tone?: 'default' | 'success' | 'warn' | 'info' | 'danger'
  class?: HTMLAttributes['class']
}>(), { tone: 'default', hint: undefined, icon: undefined })

const ICON_TONES = {
  default: 'bg-secondary-50 text-secondary-600',
  success: 'bg-emerald-50 text-emerald-600',
  warn: 'bg-amber-50 text-amber-700',
  info: 'bg-sky-50 text-sky-600',
  danger: 'bg-rose-50 text-rose-600',
} as const
</script>

<template>
  <UiCard :class="cn('shadow-xs', props.class)">
    <UiCardContent class="flex items-start justify-between gap-3">
      <div class="min-w-0 flex-1">
        <p class="text-xs font-medium text-muted-foreground">
          {{ title }}
        </p>
        <p class="mt-2 truncate text-2xl font-bold leading-none tracking-tight text-foreground tabular-nums">
          {{ value }}
        </p>
        <p
          v-if="hint"
          class="mt-2 text-xs text-muted-foreground"
        >
          {{ hint }}
        </p>
      </div>
      <span
        v-if="icon"
        :class="cn('flex size-10 shrink-0 items-center justify-center rounded-xl', ICON_TONES[props.tone])"
      >
        <Icon
          :name="icon"
          class="size-5"
        />
      </span>
    </UiCardContent>
  </UiCard>
</template>
