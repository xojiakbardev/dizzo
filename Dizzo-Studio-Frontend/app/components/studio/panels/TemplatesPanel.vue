<script setup lang="ts">
// "Galereya": ready designs for the chosen type, made by the shop's
// admins. Picking one replaces the design ("Ortga" brings it back); every
// element of it stays editable.
import type { PublicTemplate } from '~/types/catalog';

const props = defineProps<{
  templates: PublicTemplate[];
  loading: boolean;
}>();
const emit = defineEmits<{ apply: [template: PublicTemplate] }>();

const query = ref('');
const plain = (s: string) => s.toLowerCase().replace(/[‘’ʻʼ`']/g, '\'');
const found = computed(() => {
  const words = plain(query.value).split(/\s+/).filter(Boolean);
  return props.templates.filter(t => words.every(w => plain(t.name).includes(w)));
});
</script>

<template>
  <div class="space-y-3">
    <label class="relative block">
      <Icon
        name="lucide:search"
        class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-brand-muted"
      />
      <input
        v-model="query"
        type="search"
        class="h-10 w-full rounded-xl border border-brand-border/60 bg-white pl-9 pr-3 text-sm outline-none focus:border-secondary-400"
        :placeholder="$t('studio.templates.search')"
        :aria-label="$t('studio.templates.search')"
      >
    </label>

    <div
      v-if="loading"
      class="grid grid-cols-2 gap-2"
    >
      <UiSkeleton
        v-for="i in 4"
        :key="i"
        class="aspect-square rounded-xl"
      />
    </div>
    <p
      v-else-if="!templates.length"
      class="rounded-xl bg-brand-surface-low px-3 py-8 text-center text-xs leading-5 text-brand-muted"
    >
      {{ $t('studio.templates.empty') }}<br>{{ $t('studio.templates.emptyHint') }}
    </p>
    <p
      v-else-if="!found.length"
      class="rounded-xl bg-brand-surface-low px-3 py-6 text-center text-xs text-brand-muted"
    >
      {{ $t('studio.templates.notFound') }}
    </p>
    <div class="grid grid-cols-2 gap-2">
      <button
        v-for="t in found"
        :key="t.id"
        type="button"
        class="group overflow-hidden rounded-xl border border-brand-border/50 bg-white text-left transition hover:border-secondary-400 hover:shadow-md"
        :title="t.name"
        @click="emit('apply', t)"
      >
        <span class="block aspect-square overflow-hidden bg-brand-surface-low">
          <img
            v-bind="thumbSmall(t.preview_url)"
            :alt="t.name"
            loading="lazy"
            class="h-full w-full object-cover transition duration-300 group-hover:scale-105"
          >
        </span>
        <span class="block truncate px-2 py-1.5 text-[11px] font-semibold text-slate-800">{{ t.name }}</span>
      </button>
    </div>
  </div>
</template>
