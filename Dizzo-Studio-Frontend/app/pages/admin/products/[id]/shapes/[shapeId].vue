<script setup lang="ts">
// Editing a shape. A shape nobody uses yet is edited as it is; one on sale
// is edited through its revision — a draft copy the backend makes on first
// edit, which takes its place when "Save" makes it ready, or is dropped
// on "Cancel". Customers keep the old shape until then.
import { getApiErrorMessage } from '~/composables/useApi';
import type { Shape } from '~/types/catalog';
import ShapeEditor from '~/components/admin/shapes/ShapeEditor.vue';

definePageMeta({ layout: 'admin' });

const { t } = useI18n();
const localePath = useLocalePath();

const route = useRoute();
const productId = computed(() => Number(route.params.id));
const shapeId = computed(() => Number(route.params.shapeId));
const productQuery = useCatalogAdminProduct(productId);
const product = computed(() => productQuery.data.value ?? null);
const { run } = useCatalogAdminActions();

const original = computed(() => product.value?.shapes.find(s => s.id === shapeId.value) ?? null);
const isOwnDraft = (s: Shape) => s.replaces_id !== null || (s.status === 'draft' && !s.locked);
/** The shape being edited: the shape itself, or its revision. */
const draft = computed<Shape | null>(() => {
  const shape = original.value;
  if (!shape || !product.value) return null;
  return isOwnDraft(shape) ? shape : product.value.shapes.find(s => s.replaces_id === shape.id && !s.archived) ?? null;
});
const error = ref<string | null>(null);

// Asked once, and only for a shape that opened as it is on sale: after
// "Save" or "Cancel" the draft is gone (or ready) on purpose.
let revised = false;
watch(original, async (shape) => {
  if (!shape || revised) return;
  if (isOwnDraft(shape) || draft.value) {
    revised = true;
    return;
  }
  revised = true;
  try {
    await run('post', `/admin/catalog/shapes/${shape.id}/revise/`);
  }
  catch (err) {
    error.value = getApiErrorMessage(err, t('admin.shapes.page.openFailed'));
  }
}, { immediate: true });

// The editor is made once for the draft it opened: later product updates
// (its own saves) don't restart it.
const opened = shallowRef<Shape | null>(null);
watch(draft, (d) => {
  if (d && (!opened.value || opened.value.id !== d.id)) opened.value = d;
}, { immediate: true });

useAdminCrumbs(() => (product.value && original.value
  ? [{ label: product.value.name, to: localePath(`/admin/products/${product.value.id}?tab=shapes`) }, { label: original.value.name }]
  : []));

const editor = ref<InstanceType<typeof ShapeEditor> | null>(null);
const back = () => navigateTo(localePath(`/admin/products/${productId.value}?tab=shapes`));

// Leaving with unsaved changes: saved on the way out, or asked.
const leaveOpen = ref(false);
let resolveLeave: ((ok: boolean) => void) | null = null;
onBeforeRouteLeave(async () => {
  if (!editor.value || (await editor.value.flush())) return true;
  leaveOpen.value = true;
  return new Promise<boolean>((resolve) => {
    resolveLeave = resolve;
  });
});
function answerLeave(ok: boolean) {
  leaveOpen.value = false;
  resolveLeave?.(ok);
  resolveLeave = null;
}
</script>

<template>
  <div class="h-[calc(100dvh-5rem)] min-h-[520px] sm:h-[calc(100dvh-5.5rem)]">
    <EmptyState
      v-if="productQuery.isError.value || (product && !original)"
      :title="productQuery.isError.value ? t('admin.shapes.page.loadFailed') : t('admin.shapes.page.notFound')"
      :icon="productQuery.isError.value ? 'lucide:circle-alert' : 'lucide:box'"
      :tone="productQuery.isError.value ? 'destructive' : 'default'"
    >
      <UiButton
        variant="outline"
        size="sm"
        @click="back"
      >
        <Icon
          name="lucide:arrow-left"
          class="size-4"
        />
        {{ t('admin.shapes.page.backToShapes') }}
      </UiButton>
    </EmptyState>
    <div
      v-else-if="!opened"
      class="flex h-full flex-col gap-3"
    >
      <UiAlert
        v-if="error"
        variant="destructive"
      >
        <Icon name="lucide:circle-alert" />
        {{ error }}
      </UiAlert>
      <UiSkeleton class="h-13 rounded-xl" />
      <div class="flex min-h-0 flex-1 gap-3">
        <UiSkeleton class="hidden w-60 rounded-xl lg:block" />
        <UiSkeleton class="flex-1 rounded-xl" />
        <UiSkeleton class="hidden w-[22rem] rounded-xl lg:block" />
      </div>
    </div>
    <ShapeEditor
      v-else
      ref="editor"
      :key="opened.id"
      :shape="opened"
      :product-id="productId"
      :revision="opened.replaces_id !== null"
      @leave="back"
    />

    <UiAlertDialog :open="leaveOpen">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.shapes.page.leaveTitle') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel @click="answerLeave(false)">
            {{ t('admin.shapes.page.stay') }}
          </UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            @click="answerLeave(true)"
          >
            {{ t('admin.shapes.page.leave') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
