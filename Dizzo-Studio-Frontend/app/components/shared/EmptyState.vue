<script setup lang="ts">
// An empty (or not found / failed) block on the shadcn Empty parts: an icon,
// a title, an optional line under it, and actions in the default slot.
import { cn } from '~/lib/utils';

const props = withDefaults(defineProps<{
  title: string;
  description?: string;
  icon?: string;
  tone?: 'default' | 'destructive';
  class?: string;
}>(), { description: undefined, icon: 'lucide:package-open', tone: 'default', class: '' });
</script>

<template>
  <UiEmpty :class="cn('rounded-2xl border border-dashed border-border bg-card py-10', props.class)">
    <UiEmptyHeader>
      <UiEmptyMedia
        variant="icon"
        :class="cn('size-11 rounded-xl', tone === 'destructive' ? 'bg-destructive/10 text-destructive' : 'bg-muted text-muted-foreground')"
      >
        <Icon
          :name="icon"
          class="text-xl"
        />
      </UiEmptyMedia>
      <UiEmptyTitle class="font-semibold text-foreground">
        {{ title }}
      </UiEmptyTitle>
      <UiEmptyDescription v-if="description">
        {{ description }}
      </UiEmptyDescription>
    </UiEmptyHeader>
    <UiEmptyContent v-if="$slots.default">
      <slot />
    </UiEmptyContent>
  </UiEmpty>
</template>
