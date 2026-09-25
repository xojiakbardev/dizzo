<script setup lang="ts">
const props = withDefaults(defineProps<{ lat: number; lon: number; zoom?: number }>(), { zoom: 16 });
const href = computed(() => `https://yandex.uz/maps/?pt=${props.lon},${props.lat}&z=${props.zoom}&l=map`);
</script>

<template>
  <a
    :href="href"
    target="_blank"
    rel="noopener"
    class="group relative block h-28 overflow-hidden rounded-xl bg-gradient-to-br from-[#fdf4ec] via-[#f5f7fb] to-[#eef6ff] ring-1 ring-inset ring-foreground/10 outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
    :aria-label="$t('user.map.openInMap')"
  >
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_50%_30%,rgba(237,81,35,0.12),transparent_30%),linear-gradient(135deg,rgba(59,130,246,0.08),rgba(14,165,233,0.08))]" />
    <div class="absolute inset-x-3 top-3 flex items-center justify-between gap-2 rounded-full bg-background/90 px-2.5 py-1 shadow-sm backdrop-blur-sm">
      <span class="flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-foreground/70">
        <span class="size-2 rounded-full bg-primary" />
        Yandex
      </span>
      <span class="text-[9px] font-medium text-muted-foreground">{{ $t('user.map.openInMap') }}</span>
    </div>
    <div class="absolute inset-x-0 bottom-0 h-10 bg-gradient-to-t from-background/90 to-transparent" />
    <Icon
      name="lucide:map-pin"
      class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-full text-3xl text-primary drop-shadow"
    />
    <span class="absolute right-2 bottom-2 flex items-center gap-1 rounded-md bg-background/90 px-2 py-1 text-xs font-medium text-foreground shadow-xs">
      <Icon
        name="lucide:external-link"
        class="text-xs"
      />
      {{ $t('user.map.openInMap') }}
    </span>
  </a>
</template>
