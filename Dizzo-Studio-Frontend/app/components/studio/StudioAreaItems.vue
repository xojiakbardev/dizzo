<script setup lang="ts">
// The shape's print areas as menu items: the open one is marked and each
// says what it holds — how many elements, or that it is synced from another
// area. The stage's area button and "Hudud almashtirish" both show this list.
import type { PrintArea } from '~/types/catalog';

export interface AreaItem {
  area: PrintArea;
  own: number; // its own layers
  from: string | null; // the area it is synced from, if it is a target
  targets: number; // the areas it feeds
}

defineProps<{ items: AreaItem[]; selected: string | null }>();
const emit = defineEmits<{ pick: [key: string] }>();
</script>

<template>
  <UiDropdownMenuItem
    v-for="it in items"
    :key="it.area.key"
    class="gap-2"
    @select="emit('pick', it.area.key)"
  >
    <Icon
      name="lucide:check"
      class="text-base"
      :class="it.area.key === selected ? 'text-primary' : 'invisible'"
    />
    <span class="min-w-0 flex-1 truncate">{{ it.area.name }}</span>
    <span class="flex shrink-0 items-center gap-1 text-[11px] text-muted-foreground">
      <Icon
        v-if="it.from || it.targets"
        name="lucide:link-2"
        class="text-xs"
      />
      <template v-if="it.from">{{ $t('studio.areas.fromArea', { name: it.from }) }}</template>
      <template v-else>{{ it.own ? $t('studio.areas.count', it.own) : $t('studio.areas.empty') }}</template>
    </span>
  </UiDropdownMenuItem>
</template>
