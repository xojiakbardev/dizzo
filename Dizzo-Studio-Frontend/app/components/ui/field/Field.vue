<script setup lang="ts">
// A labelled form control: <UiField label="Nomi" for="x"><UiInput id="x" /></UiField>,
// with an optional hint under it and an error in place of the hint.
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  label?: string
  for?: string
  hint?: string
  error?: string | null
  class?: HTMLAttributes['class']
}>()
</script>

<template>
  <div
    data-slot="field"
    :class="cn('grid min-w-0 gap-1.5', props.class)"
  >
    <UiLabel
      v-if="label"
      :for="props.for"
      class="text-xs font-semibold text-foreground"
    >
      {{ label }}
    </UiLabel>
    <slot />
    <p
      v-if="error"
      class="text-xs text-destructive"
    >
      {{ error }}
    </p>
    <p
      v-else-if="hint"
      class="text-xs text-muted-foreground"
    >
      {{ hint }}
    </p>
  </div>
</template>
