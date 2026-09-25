<script setup lang="ts">
// A product's shapes as cards: a picture, the status, the variants that use
// each, and what can be done with it. A new shape starts with its name, in
// the three languages (and its GLB, if at hand); everything else happens in the editor.
import { getApiErrorMessage } from '~/composables/useApi';
import type { AdminCatalogProduct, Shape } from '~/types/catalog';
import ShapePicture from '~/components/admin/products/ShapePicture.vue';
import ShapePreview from '~/components/admin/shapes/ShapePreview.vue';
import { isTranslated, textTranslations, trimTranslations } from '~/lib/admin/translations';

const props = defineProps<{ product: AdminCatalogProduct }>();
const { run, busy } = useCatalogAdminActions();
const { upload } = useMediaUpload();
const { t } = useI18n();
const localePath = useLocalePath();

const shapes = computed(() => props.product.shapes.filter(s => !s.archived && s.replaces_id === null));
const editorOf = (shape: Shape) => localePath(`/admin/products/${props.product.id}/shapes/${shape.id}`);
const revisionOf = (shape: Shape) => props.product.shapes.find(s => s.replaces_id === shape.id && !s.archived) ?? null;
const variantsOf = (shape: Shape) => props.product.variants.filter(v => v.shape_id === shape.id && !v.archived);

type Status = { text: string; tone: 'success' | 'warn' | 'info' | 'neutral' };
function statusOf(shape: Shape): Status {
  if (revisionOf(shape)) return { text: t('admin.shapeList.status.revision'), tone: 'info' };
  if (shape.status === 'ready') return { text: t('admin.shapeList.status.ready'), tone: 'success' };
  return { text: t('admin.shapeList.status.draft'), tone: 'warn' };
}

// ── A shape's overall size, "500 × 700 mm" ──
// A built body from its dims; a 3D model from its scale and its box
// measured once it loads; else its first area.
const sizeLabel = (w: number, h: number) => (w > 0 && h > 0 ? `${Math.round(w)} × ${Math.round(h)} mm` : null);
function bodySize(shape: Shape) {
  const d = shape.dims as Record<string, unknown>;
  const mm = (key: string) => Number(d[key]);
  if (shape.kind === 'plane') return sizeLabel(mm('width_mm'), mm('height_mm'));
  if (shape.kind === 'cylinder') return sizeLabel(mm('diameter_mm'), mm('height_mm'));
  if (shape.kind === 'disc') return sizeLabel(mm('diameter_mm'), mm('diameter_mm'));
  return null;
}
const measurable = (shape: Shape) => shape.kind === 'model' && Boolean(shape.model_url) && Number(shape.mm_per_unit) > 0;
const measured = reactive<Record<number, string | null>>({});
const measuredKey = new Map<number, string>();
async function measureModel(shape: Shape): Promise<string | null> {
  const kit = await import('~/lib/three/kit');
  const { THREE } = kit;
  const model = await kit.loadModel(shape.model_url!);
  model.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(model).getSize(new THREE.Vector3());
  const mt = shape.model_transform;
  const upright = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), mt?.up_axis === 'z' ? -Math.PI / 2 : 0);
  const yaw = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), THREE.MathUtils.degToRad(mt?.yaw_deg ?? 0));
  const toModel = yaw.multiply(upright).invert();
  const extent = (x: number, y: number, z: number) => {
    const v = new THREE.Vector3(x, y, z).applyQuaternion(toModel);
    return Math.abs(v.x) * box.x + Math.abs(v.y) * box.y + Math.abs(v.z) * box.z;
  };
  const mpu = Number(shape.mm_per_unit);
  const width = mt?.scale_ref ? Number(mt.scale_ref.mm) : extent(1, 0, 0) * mpu;
  return sizeLabel(width, extent(0, 1, 0) * mpu);
}
watch(shapes, (list) => {
  for (const shape of list) {
    if (!measurable(shape)) continue;
    const key = JSON.stringify([shape.model_url, shape.mm_per_unit, shape.model_transform]);
    if (measuredKey.get(shape.id) === key) continue;
    measuredKey.set(shape.id, key);
    measureModel(shape)
      .then((size) => {
        if (measuredKey.get(shape.id) === key) measured[shape.id] = size;
      })
      .catch(() => {
        if (measuredKey.get(shape.id) === key) measured[shape.id] = null;
      });
  }
}, { immediate: true });
function sizeOf(shape: Shape) {
  const body = bodySize(shape);
  if (body) return body;
  if (measurable(shape)) return measured[shape.id] ?? null;
  if (shape.kind === 'model' && shape.model_url) return t('admin.shapeList.noSize');
  return null;
}

// ── New shape ──
const creating = ref(false);
const name = ref('');
const nameTr = ref(textTranslations(null, ['name', 'description']));
const canCreate = computed(() => Boolean(name.value.trim()) && isTranslated(nameTr.value, 'name'));
const modelFile = ref<File | null>(null);
const error = ref<string | null>(null);
const working = ref(false);
watch(creating, () => {
  name.value = '';
  nameTr.value = textTranslations(null, ['name', 'description']);
  modelFile.value = null;
  error.value = null;
});

async function create() {
  if (!canCreate.value) return;
  error.value = null;
  working.value = true;
  try {
    let mediaId: string | null = null;
    if (modelFile.value) {
      const kit = await import('~/lib/three/kit');
      const inspected = await kit.inspectGlbFile(modelFile.value);
      if ('error' in inspected) {
        error.value = inspected.error;
        return;
      }
      mediaId = (await upload(new Blob([modelFile.value], { type: kit.GLB_CONTENT_TYPE }), 'model')).id;
    }
    const before = new Set(props.product.shapes.map(s => s.id));
    const product = await run('post', `/admin/catalog/products/${props.product.id}/shapes/`, {
      name: name.value.trim(), translations: trimTranslations(nameTr.value), kind: 'model', dims: {},
    });
    const shape = product.shapes.find(s => !before.has(s.id))!;
    if (mediaId) await run('patch', `/admin/catalog/shapes/${shape.id}/`, { model_media_id: mediaId });
    creating.value = false;
    await navigateTo(editorOf(shape));
  }
  catch (err) {
    error.value = getApiErrorMessage(err, err instanceof Error ? err.message : t('admin.shapeList.createFailed'));
  }
  finally {
    working.value = false;
  }
}

// ── Actions ──
const actionError = ref<string | null>(null);
async function act(fn: () => Promise<unknown>, fallback: string) {
  actionError.value = null;
  try {
    await fn();
  }
  catch (err) {
    actionError.value = getApiErrorMessage(err, fallback);
  }
}
const duplicate = (shape: Shape) => act(() => run('post', `/admin/catalog/shapes/${shape.id}/duplicate/`), t('admin.shapeList.duplicateFailed'));
const toDraft = (shape: Shape) => act(() => run('post', `/admin/catalog/shapes/${shape.id}/draft/`), t('admin.shapeList.toDraftFailed'));

const previewing = ref<Shape | null>(null);
const previewOpen = computed({
  get: () => previewing.value !== null,
  set: (v: boolean) => {
    if (!v) previewing.value = null;
  },
});

const removing = ref<Shape | null>(null);
const removeError = ref<string | null>(null);
async function remove() {
  const shape = removing.value;
  if (!shape) return;
  removeError.value = null;
  try {
    // A shape customers designed on stays for their designs, hidden.
    if (shape.locked) await run('patch', `/admin/catalog/shapes/${shape.id}/`, { archived: true });
    else await run('delete', `/admin/catalog/shapes/${shape.id}/`);
    removing.value = null;
  }
  catch (err) {
    removeError.value = getApiErrorMessage(err, t('admin.common.deleteFailed'));
  }
}
</script>

<template>
  <div>
    <Teleport
      defer
      to="#product-tab-actions"
    >
      <UiButton @click="creating = true">
        <Icon
          name="lucide:plus"
          class="text-base"
        />
        {{ t('admin.shapeList.add') }}
      </UiButton>
    </Teleport>

    <UiAlert
      v-if="actionError"
      variant="destructive"
      class="mb-4"
    >
      <Icon name="lucide:circle-alert" />
      {{ actionError }}
    </UiAlert>

    <EmptyState
      v-if="!shapes.length"
      :title="t('admin.shapeList.empty')"
      icon="lucide:box"
    >
      <UiButton
        variant="outline"
        size="sm"
        @click="creating = true"
      >
        <Icon
          name="lucide:plus"
          class="text-sm"
        />
        {{ t('admin.shapeList.add') }}
      </UiButton>
    </EmptyState>
    <div
      v-else
      class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4"
    >
      <UiCard
        v-for="shape in shapes"
        :key="shape.id"
        class="group gap-0 overflow-hidden py-0 transition-shadow hover:shadow-md"
        :data-shape="shape.id"
      >
        <NuxtLink
          :to="editorOf(shape)"
          class="relative block bg-muted outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
          :aria-label="t('admin.shapeList.editAria', { name: shape.name })"
        >
          <ShapePicture
            :shape="revisionOf(shape) ?? shape"
            class="rounded-none transition group-hover:brightness-[1.03]"
          />
          <div class="absolute inset-x-2 top-2 flex items-start justify-between gap-2">
            <UiStatusBadge
              :tone="statusOf(shape).tone"
              class="bg-card/95 shadow-xs backdrop-blur-sm"
            >
              {{ statusOf(shape).text }}
            </UiStatusBadge>
            <span
              v-if="shape.locked"
              class="flex size-6 items-center justify-center rounded-lg bg-card/95 text-muted-foreground shadow-xs"
              :title="t('admin.shapeList.locked')"
            >
              <Icon
                name="lucide:lock"
                class="size-3.5"
              />
            </span>
          </div>
          <div class="absolute inset-x-2 bottom-2 flex flex-wrap gap-1.5">
            <UiBadge
              variant="outline"
              class="h-6 rounded-lg border-border/70 bg-card/90 px-2 text-[11px] font-semibold text-foreground shadow-xs backdrop-blur-sm"
            >
              {{ shape.areas.length ? t('admin.shapeList.areas', { n: shape.areas.length }, shape.areas.length) : t('admin.shapeList.noAreas') }}
            </UiBadge>
            <UiBadge
              v-if="sizeOf(shape)"
              variant="outline"
              class="h-6 rounded-lg border-border/70 bg-card/90 px-2 text-[11px] font-semibold text-foreground tabular-nums shadow-xs backdrop-blur-sm"
            >
              {{ sizeOf(shape) }}
            </UiBadge>
          </div>
        </NuxtLink>
        <UiCardContent class="flex flex-1 flex-col gap-3 border-t py-3.5">
          <div class="min-w-0">
            <p class="truncate font-semibold text-foreground">
              {{ shape.name }}
            </p>
            <div class="mt-1.5 flex min-h-6 flex-wrap gap-1">
              <span
                v-for="v in variantsOf(shape).slice(0, 3)"
                :key="v.id"
                class="max-w-full truncate rounded-md bg-muted px-1.5 py-0.5 text-[11px] font-medium text-muted-foreground"
              >{{ v.name }}</span>
              <span
                v-if="variantsOf(shape).length > 3"
                class="rounded-md bg-muted px-1.5 py-0.5 text-[11px] font-medium text-muted-foreground"
              >+{{ variantsOf(shape).length - 3 }}</span>
              <span
                v-if="!variantsOf(shape).length"
                class="py-0.5 text-[11px] text-muted-foreground"
              >{{ t('admin.shapeList.unused') }}</span>
            </div>
          </div>
          <div class="mt-auto flex gap-2">
            <UiButton
              as-child
              size="sm"
              class="flex-1"
            >
              <NuxtLink :to="editorOf(shape)">
                <Icon
                  name="lucide:pencil"
                  class="text-sm"
                />
                {{ revisionOf(shape) ? t('admin.shapeList.continue') : t('admin.shapeList.open') }}
              </NuxtLink>
            </UiButton>
            <UiTooltip>
              <UiTooltipTrigger as-child>
                <UiButton
                  size="icon-sm"
                  variant="outline"
                  :disabled="!shape.areas.length"
                  :aria-label="t('admin.shapeList.preview')"
                  @click="previewing = shape"
                >
                  <Icon
                    name="lucide:eye"
                    class="text-base"
                  />
                </UiButton>
              </UiTooltipTrigger>
              <UiTooltipContent>{{ t('admin.shapeList.preview') }}</UiTooltipContent>
            </UiTooltip>
            <UiDropdownMenu>
              <UiDropdownMenuTrigger as-child>
                <UiButton
                  size="icon-sm"
                  variant="ghost"
                  :aria-label="t('admin.shapeList.moreActions')"
                  :disabled="busy"
                >
                  <Icon
                    name="lucide:ellipsis-vertical"
                    class="text-base"
                  />
                </UiButton>
              </UiDropdownMenuTrigger>
              <UiDropdownMenuContent
                align="end"
                class="w-52"
              >
                <UiDropdownMenuItem @select="duplicate(shape)">
                  <Icon name="lucide:copy" />
                  {{ t('admin.shapeList.duplicate') }}
                </UiDropdownMenuItem>
                <UiDropdownMenuItem
                  v-if="shape.status === 'ready'"
                  :disabled="shape.locked || variantsOf(shape).length > 0"
                  @select="toDraft(shape)"
                >
                  <Icon name="lucide:file-pen" />
                  {{ t('admin.shapeList.toDraft') }}
                </UiDropdownMenuItem>
                <UiDropdownMenuItem
                  v-else
                  as-child
                >
                  <NuxtLink :to="editorOf(shape)">
                    <Icon name="lucide:check" />
                    {{ t('admin.shapeList.makeReady') }}
                  </NuxtLink>
                </UiDropdownMenuItem>
                <UiDropdownMenuSeparator />
                <UiDropdownMenuItem
                  class="text-destructive focus:text-destructive"
                  @select="removing = shape; removeError = null"
                >
                  <Icon :name="shape.locked ? 'lucide:archive' : 'lucide:trash-2'" />
                  {{ shape.locked ? t('admin.shapeList.archive') : t('admin.common.delete') }}
                </UiDropdownMenuItem>
              </UiDropdownMenuContent>
            </UiDropdownMenu>
          </div>
        </UiCardContent>
      </UiCard>
    </div>

    <UiDialog v-model:open="creating">
      <UiDialogContent class="sm:max-w-lg">
        <UiDialogHeader>
          <UiDialogTitle>{{ t('admin.shapeList.newTitle') }}</UiDialogTitle>
        </UiDialogHeader>
        <form
          class="space-y-4"
          @submit.prevent="create"
        >
          <TranslatableInput
            id="new-shape-name"
            v-model="name"
            v-model:translations="nameTr"
            field="name"
            :label="t('admin.common.name')"
            :placeholder="t('admin.shapeList.namePlaceholder')"
            required
          />
          <UiField
            :label="t('admin.shapeList.modelLabel')"
            :hint="t('admin.shapeList.modelHint')"
          >
            <UiFileInput
              accept=".glb,model/gltf-binary"
              class="justify-start gap-3 py-4 text-foreground"
              @select="(files: File[]) => { modelFile = files[0] ?? null; }"
            >
              <Icon
                :name="modelFile ? 'lucide:file-check' : 'lucide:upload'"
                class="size-5 shrink-0 text-muted-foreground"
              />
              <span class="min-w-0 truncate">{{ modelFile ? modelFile.name : t('admin.shapeList.pickGlb') }}</span>
            </UiFileInput>
          </UiField>
          <UiAlert
            v-if="error"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ error }}
          </UiAlert>
          <UiDialogFooter>
            <UiButton
              variant="outline"
              type="button"
              @click="creating = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="working || busy || !canCreate"
            >
              <Icon
                v-if="working"
                name="lucide:loader-2"
                class="size-4 animate-spin"
              />
              {{ t('admin.common.add') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>

    <UiDialog v-model:open="previewOpen">
      <UiDialogContent class="sm:max-w-3xl">
        <UiDialogHeader v-if="previewing">
          <UiDialogTitle>{{ previewing.name }}</UiDialogTitle>
        </UiDialogHeader>
        <ShapePreview
          v-if="previewing"
          :key="previewing.id"
          :shape="previewing"
        />
      </UiDialogContent>
    </UiDialog>

    <UiAlertDialog
      :open="Boolean(removing)"
      @update:open="(v: boolean) => { if (!v) removing = null; }"
    >
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ removing?.locked ? t('admin.shapeList.archiveTitle') : t('admin.shapeList.deleteTitle') }}</UiAlertDialogTitle>
          <UiAlertDialogDescription :class="removeError ? 'text-destructive' : ''">
            {{ removeError ?? `“${removing?.name}”` }}
          </UiAlertDialogDescription>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel @click="removing = null">
            {{ t('admin.common.cancel') }}
          </UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="busy"
            @click="remove"
          >
            <Icon
              v-if="busy"
              name="lucide:loader-2"
              class="size-4 animate-spin"
            />
            {{ removing?.locked ? t('admin.shapeList.archive') : t('admin.common.delete') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
