<script setup lang="ts">
// An order's five steps in one row: modern icons and names,
// current step highlighted with active ring and shadow, completed ones checked.
import { orderStep, orderStepLabels } from '~/lib/orderStatus';

const props = defineProps<{ status?: string; skeleton?: boolean; spacious?: boolean }>();

// The global t() reads the locale, so the names follow a language switch.
const labels = computed(() => orderStepLabels());

const ICONS = [
  'lucide:shopping-bag',
  'lucide:credit-card',
  'lucide:printer',
  'lucide:package-check',
  'lucide:badge-check',
];

const current = computed(() => orderStep(props.status ?? ''));
const completed = computed(() => props.status === 'COMPLETED');
const done = (i: number) => i < current.value || completed.value;
</script>

<template>
  <ol
    class="grid grid-cols-5 gap-1"
    :class="props.spacious ? 'sm:gap-2 sm:py-2' : ''"
  >
    <li
      v-for="(label, i) in labels"
      :key="label"
      class="relative flex flex-col items-center gap-2 text-center"
      :aria-current="!skeleton && i === current ? 'step' : undefined"
    >
      <!-- connecting line to the next step -->
      <span
        v-if="i < labels.length - 1"
        aria-hidden="true"
        class="absolute top-4.5 left-[calc(50%+1.25rem)] right-[calc(-50%+1.25rem)] h-1 rounded-full transition-colors duration-300"
        :class="[
          props.spacious ? 'sm:top-7 sm:left-[calc(50%+1.75rem)] sm:right-[calc(-50%+1.75rem)]' : 'sm:top-5',
          !skeleton && (done(i + 1) || (i < current)) ? 'bg-primary' : 'bg-border/60 dark:bg-border/40',
        ]"
      />

      <!-- skeleton circle -->
      <UiSkeleton
        v-if="skeleton"
        class="size-9 rounded-full"
        :class="props.spacious ? 'sm:size-14' : 'sm:size-10'"
      />

      <!-- step icon circle -->
      <span
        v-else
        class="relative z-10 flex size-9 items-center justify-center rounded-full transition-all duration-300 select-none"
        :class="[
          props.spacious ? 'sm:size-14' : 'sm:size-10',
          done(i)
            ? 'bg-primary text-primary-foreground shadow-xs'
            : i === current
              ? 'bg-primary text-primary-foreground shadow-md ring-4 ring-primary/25 scale-105'
              : 'bg-muted/70 text-muted-foreground/60 border border-border/80 dark:border-border/50'
        ]"
      >
        <Icon
          :name="done(i) ? 'lucide:check' : ICONS[i]!"
          class="transition-transform"
          :class="[
            done(i) ? (props.spacious ? 'size-4.5 sm:size-6 stroke-[2.6]' : 'size-4.5 sm:size-5 stroke-[2.6]') : (props.spacious ? 'size-4 sm:size-5.5 stroke-[2]' : 'size-4 sm:size-4.5 stroke-[2]')
          ]"
        />
      </span>

      <!-- skeleton label -->
      <span
        v-if="skeleton"
        class="flex h-4 items-center justify-center"
      >
        <UiSkeleton class="h-2.5 w-12 sm:w-16 rounded" />
      </span>

      <!-- step label -->
      <span
        v-else
        class="text-[11px] leading-tight transition-colors"
        :class="[
          props.spacious ? 'sm:text-sm' : 'sm:text-xs',
          i === current && !completed
            ? 'font-bold text-foreground'
            : done(i)
              ? 'font-medium text-foreground/90'
              : 'font-normal text-muted-foreground'
        ]"
      >
        {{ label }}
      </span>
    </li>
  </ol>
</template>
