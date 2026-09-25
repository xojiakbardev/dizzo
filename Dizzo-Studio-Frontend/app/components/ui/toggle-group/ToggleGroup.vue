<script setup lang="ts">
// shadcn ToggleGroup: segmented buttons (<UiToggleGroupItem> children),
// one choice by default (type="multiple" for several).
import type { ToggleGroupRootEmits, ToggleGroupRootProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'
import { reactiveOmit } from '@vueuse/core'
import { ToggleGroupRoot, useForwardPropsEmits } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = withDefaults(defineProps<ToggleGroupRootProps & { class?: HTMLAttributes['class'] }>(), {
  type: 'single',
})
const emits = defineEmits<ToggleGroupRootEmits>()

const delegatedProps = reactiveOmit(props, 'class')
const forwarded = useForwardPropsEmits(delegatedProps, emits)
</script>

<template>
  <ToggleGroupRoot
    v-slot="slotProps"
    data-slot="toggle-group"
    v-bind="forwarded"
    :class="cn('inline-flex w-fit items-center gap-1 rounded-xl bg-muted p-1', props.class)"
  >
    <slot v-bind="slotProps" />
  </ToggleGroupRoot>
</template>
