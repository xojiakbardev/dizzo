<script setup lang="ts">
// The body itself: a model's file, turn and real size (the first step of a
// new shape), or a built body's dimensions.
import type { ModelInfo, ShapeDraft } from '~/lib/admin/shapeDraft';
import { round1 } from '~/lib/admin/shapeDraft';
import MmField from '~/components/admin/shapes/MmField.vue';

const props = defineProps<{
  draft: ShapeDraft;
  info: ModelInfo | null;
  guided: boolean; // the size step: nothing else can be done yet
  uploading: boolean;
  uploadError: string | null;
  bodySize: { width: number; height: number } | null;
}>();
const emit = defineEmits<{
  width: [mm: number];
  orient: [upAxis: 'y' | 'z', yawDeg: 0 | 90 | 180 | 270];
  file: [file: File];
  dims: [dims: Record<string, unknown>, group?: string];
  bodySize: [width: number, height: number];
  done: [];
}>();

const { t } = useI18n();
const model = computed(() => props.draft.kind === 'model');
const mpu = computed(() => props.draft.model.mmPerUnit);
const size = computed(() => {
  const i = props.info;
  const m = mpu.value;
  if (!i || !m) return null;
  return { width: round1(i.widthUnits * m), height: round1(i.heightUnits * m), depth: round1(i.depthUnits * m) };
});
function setHeight(v: number | null) {
  if (v && props.info) emit('width', (v * props.info.widthUnits) / props.info.heightUnits);
}
function setDepth(v: number | null) {
  if (v && props.info) emit('width', (v * props.info.widthUnits) / props.info.depthUnits);
}
const PRESETS = computed(() => [
  { key: 'tshirtM', label: t('admin.shapes.panel.preset.tshirtM'), mm: 500 },
  { key: 'tshirtL', label: t('admin.shapes.panel.preset.tshirtL'), mm: 530 },
  { key: 'hoodie', label: t('admin.shapes.panel.preset.hoodie'), mm: 600 },
  { key: 'cap', label: t('admin.shapes.panel.preset.cap'), mm: 190 },
  { key: 'mug', label: t('admin.shapes.panel.preset.mug'), mm: 82 },
]);

const dims = computed(() => props.draft.dims as Record<string, unknown>);
const dim = (key: string) => (dims.value[key] === undefined ? null : Number(dims.value[key]));
function setDim(key: string, value: unknown) {
  emit('dims', { ...dims.value, [key]: typeof value === 'number' ? String(value) : value }, key);
}
</script>

<template>
  <div
    class="space-y-5 p-4"
    data-testid="shape-panel"
  >
    <template v-if="model">
      <section
        class="space-y-3"
        :class="guided ? 'rounded-xl border-2 border-primary/40 bg-primary/5 p-3' : ''"
      >
        <div class="flex items-center gap-2">
          <span
            v-if="guided"
            class="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground"
          >1</span>
          <h3 class="text-sm font-semibold">
            {{ t('admin.shapes.panel.modelSize') }}
          </h3>
        </div>
        <div
          v-if="!draft.model.url"
          class="text-xs text-muted-foreground"
        >
          {{ t('admin.shapes.panel.uploadFirst') }}
        </div>
        <template v-else>
          <div class="grid grid-cols-3 gap-2">
            <MmField
              id="model-width"
              :label="t('admin.shapes.panel.width')"
              :model-value="size?.width ?? null"
              :min="1"
              placeholder="—"
              :disabled="!info"
              @update:model-value="(v) => v && emit('width', v)"
            />
            <MmField
              :label="t('admin.shapes.panel.height')"
              :model-value="size?.height ?? null"
              :min="1"
              placeholder="—"
              :disabled="!info"
              @update:model-value="setHeight"
            />
            <MmField
              :label="t('admin.shapes.panel.depth')"
              :model-value="size?.depth ?? null"
              :min="1"
              placeholder="—"
              :disabled="!info"
              @update:model-value="setDepth"
            />
          </div>
          <p class="text-[11px] text-muted-foreground">
            {{ t('admin.shapes.panel.widthHint') }}
          </p>
          <div class="flex flex-wrap gap-1.5">
            <UiButton
              v-for="p in PRESETS"
              :key="p.key"
              variant="outline"
              size="xs"
              class="tabular-nums"
              :disabled="!info"
              @click="emit('width', p.mm)"
            >
              {{ p.label }} · {{ p.mm }}
            </UiButton>
          </div>
          <UiButton
            v-if="guided"
            class="w-full"
            :disabled="!mpu"
            data-testid="size-done"
            @click="emit('done')"
          >
            {{ t('admin.shapes.panel.continue') }}
            <Icon
              name="lucide:arrow-right"
              class="size-4"
            />
          </UiButton>
        </template>
      </section>

      <section class="space-y-2">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {{ t('admin.shapes.panel.model3d') }}
        </h3>
        <UiFileInput
          accept=".glb,model/gltf-binary"
          class="justify-start gap-3 py-3 text-foreground"
          :disabled="uploading"
          @select="(files: File[]) => files[0] && emit('file', files[0])"
        >
          <Icon
            :name="uploading ? 'lucide:loader-2' : draft.model.url ? 'lucide:refresh-cw' : 'lucide:upload'"
            class="size-5 shrink-0 text-muted-foreground"
            :class="uploading ? 'animate-spin' : ''"
          />
          <span class="min-w-0 truncate text-sm">
            {{ uploading ? t('admin.shapes.panel.uploading') : draft.model.url ? t('admin.shapes.panel.replaceModel') : t('admin.shapes.panel.pickGlb') }}
          </span>
        </UiFileInput>
        <p
          v-if="uploadError"
          class="text-xs text-destructive"
        >
          {{ uploadError }}
        </p>
      </section>

      <section
        v-if="draft.model.url"
        class="space-y-2"
      >
        <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {{ t('admin.shapes.panel.orientation') }}
        </h3>
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs text-muted-foreground">{{ t('admin.shapes.panel.upAxis') }}</span>
          <UiToggleGroup
            type="single"
            :model-value="draft.model.upAxis"
            @update:model-value="(v) => v && emit('orient', v as 'y' | 'z', draft.model.yawDeg)"
          >
            <UiToggleGroupItem
              value="y"
              class="h-7 px-2.5 text-xs"
            >
              Y
            </UiToggleGroupItem>
            <UiToggleGroupItem
              value="z"
              class="h-7 px-2.5 text-xs"
            >
              Z
            </UiToggleGroupItem>
          </UiToggleGroup>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs text-muted-foreground">{{ t('admin.shapes.panel.frontFacing') }}</span>
          <UiToggleGroup
            type="single"
            :model-value="String(draft.model.yawDeg)"
            @update:model-value="(v) => v !== undefined && v !== '' && emit('orient', draft.model.upAxis, Number(v) as 0 | 90 | 180 | 270)"
          >
            <UiToggleGroupItem
              v-for="d in [0, 90, 180, 270]"
              :key="d"
              :value="String(d)"
              class="h-7 px-2 text-xs tabular-nums"
            >
              {{ d }}°
            </UiToggleGroupItem>
          </UiToggleGroup>
        </div>
      </section>
    </template>

    <section
      v-else
      class="space-y-3"
    >
      <h3 class="text-sm font-semibold">
        {{ t('admin.shapes.panel.dims') }}
      </h3>
      <div
        v-if="draft.kind === 'cylinder'"
        class="grid grid-cols-2 gap-2"
      >
        <MmField
          :label="t('admin.shapes.panel.diameter')"
          :model-value="dim('diameter_mm')"
          :min="1"
          @update:model-value="(v) => v && bodySize && emit('bodySize', v, bodySize.height)"
        />
        <MmField
          :label="t('admin.shapes.panel.heightCyl')"
          :model-value="dim('height_mm')"
          :min="1"
          @update:model-value="(v) => v && bodySize && emit('bodySize', bodySize.width, v)"
        />
        <MmField
          :label="t('admin.shapes.panel.handleGap')"
          :model-value="dim('handle_gap_mm')"
          @update:model-value="(v) => setDim('handle_gap_mm', v ?? 0)"
        />
        <UiLabel class="mt-5 flex h-9 cursor-pointer items-center gap-2 text-sm font-normal">
          <UiSwitch
            size="sm"
            :model-value="dims.handle !== false"
            @update:model-value="(on: boolean) => setDim('handle', on)"
          />
          {{ t('admin.shapes.panel.handle') }}
        </UiLabel>
      </div>
      <div
        v-else-if="draft.kind === 'plane'"
        class="grid grid-cols-2 gap-2"
      >
        <MmField
          :label="t('admin.shapes.panel.width')"
          :model-value="dim('width_mm')"
          :min="1"
          @update:model-value="(v) => v && bodySize && emit('bodySize', v, bodySize.height)"
        />
        <MmField
          :label="t('admin.shapes.panel.height')"
          :model-value="dim('height_mm')"
          :min="1"
          @update:model-value="(v) => v && bodySize && emit('bodySize', bodySize.width, v)"
        />
        <div class="col-span-2 flex items-center gap-2">
          <span class="text-xs text-muted-foreground">{{ t('admin.shapes.panel.sides') }}</span>
          <UiToggleGroup
            type="single"
            :model-value="String(dims.sides ?? 1)"
            @update:model-value="(v) => v && setDim('sides', Number(v))"
          >
            <UiToggleGroupItem
              value="1"
              class="h-7 px-2.5 text-xs"
            >
              {{ t('admin.shapes.panel.oneSided') }}
            </UiToggleGroupItem>
            <UiToggleGroupItem
              value="2"
              class="h-7 px-2.5 text-xs"
            >
              {{ t('admin.shapes.panel.twoSided') }}
            </UiToggleGroupItem>
          </UiToggleGroup>
        </div>
      </div>
      <MmField
        v-else
        :label="t('admin.shapes.panel.diameter')"
        class="w-40"
        :model-value="dim('diameter_mm')"
        :min="1"
        @update:model-value="(v) => v && emit('bodySize', v, v)"
      />
    </section>
  </div>
</template>
