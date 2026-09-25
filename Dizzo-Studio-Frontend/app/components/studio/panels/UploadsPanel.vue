<script setup lang="ts">
import type { ImageSource } from '~/lib/design/document';
import type { AssetCategory } from '~/lib/design/designAssets';
import { ASSET_CATEGORIES, CURATED_ASSETS } from '~/lib/design/designAssets';

const props = defineProps<{ images: ImageSource[]; busy: boolean; disabled: boolean }>();
const emit = defineEmits<{ upload: [file: File]; place: [image: ImageSource] }>();

const fileRef = ref<HTMLInputElement | null>(null);
const dragging = ref(false);
const activeCategory = ref<AssetCategory>('love');
const searchQuery = ref('');

function onFile(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (fileRef.value) fileRef.value.value = '';
  if (file) emit('upload', file);
}

function onDrop(event: DragEvent) {
  dragging.value = false;
  const file = event.dataTransfer?.files[0];
  if (file) emit('upload', file);
}

// Watch uploaded images — switch to "uploads" tab if user uploads something new
watch(() => props.images.length, (newLen, oldLen) => {
  if (newLen > (oldLen ?? 0)) {
    activeCategory.value = 'uploads';
  }
});

const categoryParam = computed(() => activeCategory.value === 'uploads' || activeCategory.value === 'all' ? null : activeCategory.value);
const assetsQuery = usePublicDesignAssets(categoryParam);

const filteredAssets = computed(() => {
  if (activeCategory.value === 'uploads') return [];
  const hasBackend = assetsQuery.data.value && assetsQuery.data.value.length > 0;
  let list = hasBackend ? assetsQuery.data.value! : CURATED_ASSETS;

  if (activeCategory.value !== 'all') {
    list = list.filter(item => item.category === activeCategory.value);
  }
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    list = list.filter(item => item.name.toLowerCase().includes(q));
  }
  return list;
});

</script>

<template>
  <div class="space-y-3.5">
    <!-- Top compact upload banner/button -->
    <label
      class="group relative flex cursor-pointer items-center justify-between gap-3 overflow-hidden rounded-2xl border-2 border-dashed px-3.5 py-2.5 transition"
      :class="[
        dragging
          ? 'border-primary bg-primary/10'
          : 'border-border/80 bg-brand-surface-low/70 hover:border-primary/60 hover:bg-primary/5',
        busy || disabled ? 'pointer-events-none opacity-60' : '',
      ]"
      @dragover.prevent="dragging = true"
      @dragleave="dragging = false"
      @drop.prevent="onDrop"
    >
      <div class="flex items-center gap-2.5">
        <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary text-white shadow-xs transition group-hover:scale-105">
          <Icon
            :name="busy ? 'lucide:loader-circle' : 'lucide:cloud-upload'"
            class="h-4 w-4"
            :class="busy ? 'animate-spin' : ''"
          />
        </span>
        <div class="text-left">
          <p class="text-xs font-bold text-foreground">
            {{ busy ? $t('studio.uploads.uploading') : $t('studio.uploads.upload') }}
          </p>
          <p class="text-[10px] text-muted-foreground">
            PNG, JPG, WebP
          </p>
        </div>
      </div>

      <span class="rounded-xl border border-border bg-white px-2.5 py-1 text-[11px] font-semibold text-slate-700 shadow-2xs group-hover:border-primary/50 group-hover:text-primary">
        Tanlash
      </span>

      <input
        ref="fileRef"
        type="file"
        accept="image/png,image/jpeg,image/webp"
        class="sr-only"
        :disabled="busy || disabled"
        @change="onFile"
      >
    </label>

    <!-- Categories pills (scrollable) -->
    <div class="scrollbar-none -mx-1 flex snap-x items-center gap-1.5 overflow-x-auto px-1 py-0.5">
      <button
        v-for="cat in ASSET_CATEGORIES"
        :key="cat.key"
        type="button"
        class="flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold transition"
        :class="[
          activeCategory === cat.key
            ? 'bg-slate-900 text-white shadow-xs'
            : 'bg-muted/70 text-slate-600 hover:bg-muted hover:text-slate-900',
        ]"
        @click="activeCategory = cat.key"
      >
        <Icon :name="cat.icon" class="h-3.5 w-3.5" />
        {{ cat.label }}
        <span
          v-if="cat.key === 'uploads' && images.length"
          class="ml-0.5 rounded-full bg-white/20 px-1.5 text-[10px] font-bold"
        >
          {{ images.length }}
        </span>
      </button>
    </div>

    <!-- User Uploaded Images Tab -->
    <section v-if="activeCategory === 'uploads'" class="space-y-2 pt-1">
      <div v-if="images.length" class="grid grid-cols-2 gap-2">
        <button
          v-for="img in images"
          :key="img.media_id"
          type="button"
          class="group relative aspect-square overflow-hidden rounded-xl border border-border/70 bg-[conic-gradient(#f1f5f9_25%,#fff_0_50%,#f1f5f9_0_75%,#fff_0)] bg-[length:14px_14px] transition hover:border-primary hover:shadow-xs disabled:opacity-50"
          :disabled="disabled"
          :title="$t('studio.uploads.place')"
          @click="emit('place', img)"
        >
          <img
            :src="img.url"
            alt=""
            crossorigin="anonymous"
            loading="lazy"
            class="h-full w-full object-contain p-1.5 transition duration-200 group-hover:scale-105"
          >
          <span class="absolute inset-x-0 bottom-0 bg-slate-900/70 py-0.5 text-center text-[9px] font-medium text-white opacity-0 transition group-hover:opacity-100">
            Qo‘shish
          </span>
        </button>
      </div>
      <div v-else class="rounded-xl border border-dashed border-border/70 bg-muted/30 px-3 py-8 text-center text-xs text-muted-foreground">
        <Icon name="lucide:image" class="mx-auto mb-1.5 h-6 w-6 opacity-50" />
        <p class="font-medium text-slate-800">
          Hali rasm yuklanmagan
        </p>
        <p class="mt-0.5 text-[11px]">
          Tepadagi tugma orqali o‘z rasmingizni yuklashingiz mumkin.
        </p>
      </div>
    </section>

    <!-- Curated Ready Assets Grid -->
    <section v-else class="space-y-2 pt-1">
      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="asset in filteredAssets"
          :key="asset.id"
          type="button"
          class="group relative flex flex-col items-center overflow-hidden rounded-xl border border-border/60 bg-white p-2 transition hover:border-primary hover:shadow-md disabled:opacity-50"
          :disabled="disabled"
          :title="asset.name"
          @click="emit('place', { media_id: asset.media_id, url: asset.url, px_w: asset.px_w ?? 800, px_h: asset.px_h ?? 800 })"
        >
          <div
            class="relative aspect-square w-full overflow-hidden rounded-lg"
            :class="asset.type === 'sticker' ? 'bg-[conic-gradient(#f8fafc_25%,#fff_0_50%,#f8fafc_0_75%,#fff_0)] bg-[length:12px_12px]' : 'bg-muted/40'"
          >
            <img
              :src="asset.url"
              :alt="asset.name"
              crossorigin="anonymous"
              loading="lazy"
              class="h-full w-full transition duration-300 group-hover:scale-110"
              :class="asset.type === 'sticker' ? 'object-contain p-1' : 'object-cover'"
            >
          </div>
          <span class="mt-1.5 block w-full truncate text-center text-[10px] font-semibold text-slate-800">
            {{ asset.name }}
          </span>
          <span class="absolute inset-x-0 bottom-0 bg-primary py-0.5 text-center text-[9px] font-bold text-white opacity-0 transition group-hover:opacity-100">
            + Qo‘shish
          </span>
        </button>
      </div>
    </section>
  </div>
</template>

