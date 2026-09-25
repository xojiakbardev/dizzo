<script setup lang="ts">
// A file drop zone: click or drop files; emits them as `select`. The slot
// is its content (an icon and a caption, or the chosen file's name).
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  accept?: string
  multiple?: boolean
  disabled?: boolean
  class?: HTMLAttributes['class']
}>()
const emit = defineEmits<{ select: [files: File[]] }>()

const input = ref<HTMLInputElement | null>(null)
const dragging = ref(false)

function pick(list: FileList | null | undefined) {
  const files = Array.from(list ?? [])
  if (files.length) emit('select', props.multiple ? files : files.slice(0, 1))
}

function onChange(event: Event) {
  const el = event.target as HTMLInputElement
  pick(el.files)
  el.value = ''
}

function onDrop(event: DragEvent) {
  dragging.value = false
  if (!props.disabled) pick(event.dataTransfer?.files)
}

defineExpose({ open: () => input.value?.click() })
</script>

<template>
  <label
    data-slot="file-input"
    :class="cn(
      'relative overflow-hidden flex cursor-pointer items-center justify-center gap-2 rounded-xl border border-dashed border-input bg-card px-4 py-3 text-sm text-muted-foreground transition-colors hover:border-primary/60 hover:bg-muted/40 hover:text-foreground has-[:focus-visible]:ring-3 has-[:focus-visible]:ring-ring/50',
      dragging && 'border-primary bg-primary/5 text-foreground',
      disabled && 'pointer-events-none opacity-50',
      props.class,
    )"
    @dragover.prevent="dragging = true"
    @dragleave="dragging = false"
    @drop.prevent="onDrop"
  >
    <slot />
    <input
      ref="input"
      type="file"
      class="sr-only"
      tabindex="-1"
      :accept="accept"
      :multiple="multiple"
      :disabled="disabled"
      @change="onChange"
    >
  </label>
</template>
