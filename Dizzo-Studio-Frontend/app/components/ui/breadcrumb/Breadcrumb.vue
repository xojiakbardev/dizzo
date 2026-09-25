<script lang="ts" setup>
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
  items?: Array<{ label: string; to?: string }>
}>()
</script>

<template>
  <nav
    :aria-label="$t('common.ui.breadcrumb')"
    data-slot="breadcrumb"
    :class="cn('min-w-0', props.class)"
  >
    <ol
      v-if="props.items && props.items.length"
      class="flex min-w-0 items-center gap-1.5 text-sm text-muted-foreground"
    >
      <template
        v-for="(item, i) in props.items"
        :key="i"
      >
        <li
          v-if="i > 0"
          role="presentation"
          aria-hidden="true"
          class="flex shrink-0 text-muted-foreground/60"
        >
          <Icon
            name="lucide:chevron-right"
            class="h-4 w-4"
          />
        </li>
        <li class="inline-flex min-w-0 items-center">
          <NuxtLink
            v-if="item.to && i < props.items.length - 1"
            :to="item.to"
            class="truncate font-medium transition-colors hover:text-foreground"
          >
            {{ item.label }}
          </NuxtLink>
          <span
            v-else
            :aria-current="i === props.items.length - 1 ? 'page' : undefined"
            class="truncate font-semibold text-foreground"
          >{{ item.label }}</span>
        </li>
      </template>
    </ol>
    <slot v-else />
  </nav>
</template>
