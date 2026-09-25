<script setup lang="ts">
// "Video darsliklar": the admin puts up the landing's tutorial videos — a
// cover, a title and, once recorded, the video's link (YouTube, Telegram
// or an MP4 file). Published ones show on the landing, in this order.
import { getApiErrorMessage } from '~/composables/useApi';
import { DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';
import type { AdminTutorial } from '~/composables/queries/useTutorials';
import type { TextTranslations } from '~/lib/admin/translations';
import { isTranslated, textTranslations, trimTranslations } from '~/lib/admin/translations';

const { t } = useI18n();

const listQuery = useAdminTutorials();
const items = computed(() => listQuery.data.value ?? []);
const actions = useAdminTutorialActions();
const { upload } = useMediaUpload();

const error = ref<string | null>(null);
async function act(action: () => Promise<unknown>, fallback: string) {
  error.value = null;
  try {
    await action();
  }
  catch (e) {
    error.value = getApiErrorMessage(e, fallback);
  }
}

const route = useRoute();
const router = useRouter();
const props = defineProps<{ search?: string; hideHeader?: boolean }>();
const search = ref((route.query.search as string) || props.search || '');
watch(() => props.search, (val) => {
  if (val !== undefined) search.value = val;
}, { immediate: true });

defineExpose({
  openNew,
});
watch(search, (val) => {
  const query: Record<string, string | undefined> = {};
  if (val.trim()) query.search = val.trim();
  router.replace({ query });
});
const searching = computed(() => search.value.trim() !== '');
const fold = (text: string) => text.toLowerCase().replace(/[‘’ʻʼ`']/g, '\'');
function matches(item: { title: string; video_url: string | null; is_published: boolean }): boolean {
  const q = fold(search.value.trim());
  if (!q) return true;
  return [item.title, item.video_url, item.is_published ? t('admin.tutorials.published') : t('admin.tutorials.publish'), item.video_url ? 'video' : t('admin.tutorials.comingSoon')].some(v => v != null && fold(String(v)).includes(q));
}
const noMatch = computed(() => searching.value && !items.value.some(matches));

// Insert-style drag for the table; the new order saves at once.
const drag = useInsertDragSort((from, to) => {
  void act(() => actions.reorder(moved(items.value.map(i => i.id), from, to)), t('admin.tutorials.errors.order'));
});

function togglePublished(item: AdminTutorial, value: boolean) {
  void act(() => actions.update(item.id, { is_published: value }), t('admin.tutorials.errors.status'));
}

// ── New or edited item ──
interface Cover { media_id: string; url: string; width: number | null; height: number | null }

const formOpen = ref(false);
const editing = ref<AdminTutorial | null>(null);
const form = reactive({ title: '', video_url: '', is_published: true });
const tr = ref<TextTranslations>(textTranslations(null, ['title']));
const cover = ref<Cover | null>(null);
const uploading = ref(false);
const formError = ref<string | null>(null);

function openNew() {
  editing.value = null;
  Object.assign(form, { title: '', video_url: '', is_published: true });
  tr.value = textTranslations(null, ['title']);
  cover.value = null;
  formError.value = null;
  formOpen.value = true;
}

function openEdit(item: AdminTutorial) {
  editing.value = item;
  Object.assign(form, { title: item.title, video_url: item.video_url ?? '', is_published: item.is_published });
  tr.value = textTranslations(item.translations, ['title']);
  cover.value = { media_id: item.cover_media_id, url: item.cover_url, width: item.cover_width, height: item.cover_height };
  formError.value = null;
  formOpen.value = true;
}

async function pickCover(picked: File[]) {
  const file = picked[0];
  if (!file) return;
  formError.value = null;
  if (!MEDIA_IMAGE_TYPES.includes(file.type) || file.size > DESIGN_IMAGE_MAX_MB * 1024 * 1024) {
    formError.value = t('admin.tutorials.errors.fileType', { name: file.name, mb: DESIGN_IMAGE_MAX_MB });
    return;
  }
  uploading.value = true;
  try {
    const blob = await resizeImageToBlob(file, 1600, 0.88, 'image/webp');
    const bitmap = await createImageBitmap(blob);
    const size = { width: bitmap.width, height: bitmap.height };
    bitmap.close();
    const media = await upload(blob, 'catalog');
    cover.value = { media_id: media.id, url: media.url, ...size };
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, e instanceof Error ? e.message : t('admin.tutorials.errors.upload'));
  }
  finally {
    uploading.value = false;
  }
}

const videoUrlValid = computed(() => {
  const url = form.video_url.trim();
  return !url || /^https?:\/\/\S+$/i.test(url);
});

const canSave = computed(() =>
  !actions.busy.value && !uploading.value && form.title.trim() !== '' && isTranslated(tr.value, 'title') && cover.value !== null && videoUrlValid.value);

async function save() {
  if (!canSave.value || !cover.value) return;
  formError.value = null;
  const body = {
    title: form.title.trim(),
    translations: trimTranslations(tr.value),
    video_url: form.video_url.trim() || null,
    is_published: form.is_published,
    ...(editing.value?.cover_media_id === cover.value.media_id
      ? {}
      : { cover_media_id: cover.value.media_id, cover_width: cover.value.width, cover_height: cover.value.height }),
  };
  try {
    if (editing.value) await actions.update(editing.value.id, body);
    else await actions.create({ cover_media_id: cover.value.media_id, ...body });
    formOpen.value = false;
  }
  catch (e) {
    formError.value = getApiErrorMessage(e, t('admin.tutorials.errors.save'));
  }
}

const deleting = ref<AdminTutorial | null>(null);
const deleteOpen = computed({
  get: () => deleting.value !== null,
  set: (open: boolean) => {
    if (!open) deleting.value = null;
  },
});
async function confirmDelete() {
  const item = deleting.value;
  if (!item) return;
  await act(() => actions.remove(item.id), t('admin.tutorials.errors.delete'));
  deleting.value = null;
}
</script>

<template>
  <div class="space-y-5">
    <AdminPageHeader
      v-if="!hideHeader"
      v-model:search="search"
      :placeholder="t('admin.tutorials.searchPlaceholder')"
      :refreshing="listQuery.isFetching.value"
      @refresh="listQuery.refetch()"
    >
      <template #actions>
        <UiButton
          size="sm"
          class="h-9 px-3 gap-2 flex items-center justify-center"
          :title="t('admin.tutorials.add')"
          @click="openNew"
        >
          <Icon
            name="lucide:video"
            class="size-6 shrink-0"
          />
          <span class="text-xl font-normal select-none leading-none -translate-y-0.5">+</span>
        </UiButton>
      </template>
    </AdminPageHeader>

    <UiAlert
      v-if="error || listQuery.isError.value"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      {{ error ?? t('admin.tutorials.errors.load') }}
    </UiAlert>

    <!-- ── Loading skeleton ── -->
    <div
      v-if="listQuery.isLoading.value"
      class="w-full rounded-2xl border border-border bg-card shadow-xs [overflow:visible]"
      aria-busy="true"
    >
      <div class="flex h-11 items-center border-b border-border bg-muted/30 px-4 gap-4">
        <UiSkeleton class="h-3 w-6" />
        <UiSkeleton class="h-3 w-48" />
        <UiSkeleton class="ml-auto h-3 w-32" />
        <UiSkeleton class="h-3 w-16" />
      </div>
      <div
        v-for="i in 4"
        :key="i"
        class="flex items-center gap-4 border-b border-border px-4 py-3 last:border-b-0"
      >
        <UiSkeleton class="size-4 rounded" />
        <UiSkeleton class="h-10 w-16 rounded-lg shrink-0" />
        <div class="flex-1 space-y-1.5">
          <UiSkeleton class="h-3.5 w-1/3" />
          <UiSkeleton class="h-3 w-1/2" />
        </div>
        <UiSkeleton class="h-5 w-9 rounded-full" />
        <UiSkeleton class="size-7 rounded-md" />
      </div>
    </div>

    <!-- ── Empty state ── -->
    <EmptyState
      v-else-if="!items.length && !listQuery.isError.value"
      icon="lucide:clapperboard"
      :title="t('admin.tutorials.empty')"
    >
      <UiButton @click="openNew">
        <Icon name="lucide:plus" />
        {{ t('admin.tutorials.add') }}
      </UiButton>
    </EmptyState>

    <!-- ── Table ── -->
    <div
      v-else-if="items.length"
      class="w-full rounded-2xl border border-border bg-card shadow-xs [overflow:visible]"
    >
      <!-- header -->
      <div
        class="grid items-center border-b border-border bg-muted/30 rounded-t-2xl"
        style="grid-template-columns: 28px 68px 1fr 64px 80px"
      >
        <div />
        <div />
        <div class="px-4 py-2.5 text-xs font-semibold text-foreground">{{ t('admin.tutorials.col.title') }}</div>
        <div class="px-2 py-2.5 text-xs font-semibold text-foreground">{{ t('admin.tutorials.col.status') }}</div>
        <div class="px-2 py-2.5 text-xs font-semibold text-foreground" />
      </div>

      <!-- rows -->
      <div
        v-for="(item, i) in items"
        :key="item.id"
        v-show="matches(item)"
        :ref="drag.register(i)"
        class="grid items-center border-b border-border last:border-b-0 transition-colors hover:bg-muted/40"
        :class="drag.rowClass(i)"
        :style="drag.rowStyle(i)"
        style="grid-template-columns: 28px 68px 1fr 64px 80px"
      >
        <!-- drag handle -->
        <button
          type="button"
          class="flex h-full w-full cursor-grab touch-none items-center justify-center text-muted-foreground hover:text-foreground active:cursor-grabbing disabled:opacity-30"
          :aria-label="t('admin.tutorials.dragToSort')"
          :disabled="actions.busy.value || searching"
          @pointerdown="drag.start($event, i)"
        >
          <Icon name="lucide:grip-vertical" class="size-4" />
        </button>

        <!-- cover thumbnail (click → edit) -->
        <button
          type="button"
          class="flex items-center justify-center py-2 pl-1 pr-2"
          @click="openEdit(item)"
        >
          <MediaThumb
            :src="item.cover_url"
            :alt="item.title"
            class="h-10 w-16 rounded-lg border border-border object-cover"
          />
        </button>

        <!-- title + video URL (click → edit) -->
        <button
          type="button"
          class="flex min-w-0 flex-col items-start justify-center gap-0.5 px-4 py-3 text-left cursor-pointer"
          @click="openEdit(item)"
        >
          <span class="block w-full truncate font-semibold text-sm text-foreground">{{ item.title }}</span>
          <span class="flex items-center gap-1.5 w-full min-w-0 text-xs text-muted-foreground">
            <Icon
              :name="item.video_url ? 'lucide:circle-play' : 'lucide:clock'"
              class="shrink-0 size-3"
            />
            <span class="truncate">{{ item.video_url || t('admin.tutorials.comingSoonTitle') }}</span>
          </span>
        </button>

        <!-- published toggle -->
        <div
          class="flex items-center px-2 py-3"
          @click.stop
        >
          <UiSwitch
            :model-value="item.is_published"
            :disabled="actions.busy.value"
            @update:model-value="togglePublished(item, $event)"
          />
        </div>

        <!-- actions -->
        <div
          class="flex items-center justify-end gap-0.5 px-2 py-3"
          @click.stop
        >
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="ghost"
                :aria-label="t('admin.common.edit')"
                @click="openEdit(item)"
              >
                <Icon name="lucide:pencil" class="text-base" />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.common.edit') }}</UiTooltipContent>
          </UiTooltip>
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton
                size="icon-sm"
                variant="ghost"
                class="text-destructive hover:bg-destructive/10 hover:text-destructive"
                :aria-label="t('admin.common.delete')"
                @click="deleting = item"
              >
                <Icon name="lucide:trash-2" class="text-base" />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.common.delete') }}</UiTooltipContent>
          </UiTooltip>
        </div>
      </div>
    </div>

    <p
      v-if="noMatch"
      class="rounded-2xl border border-dashed border-border p-6 text-center text-sm text-muted-foreground"
    >
      {{ t('admin.tutorials.noMatch') }}
    </p>

    <UiDialog v-model:open="formOpen">
      <UiDialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
        <UiDialogHeader>
          <UiDialogTitle>
            {{ editing ? t('admin.tutorials.editTitle') : t('admin.tutorials.add') }}
          </UiDialogTitle>
        </UiDialogHeader>

        <form
          class="space-y-4"
          @submit.prevent="save"
        >
          <UiField :label="t('admin.tutorials.cover')">
            <div class="relative overflow-hidden rounded-xl border border-border bg-muted">
              <MediaThumb
                v-if="cover"
                :src="cover.url"
                class="w-full"
                :style="{ aspectRatio: cover.width && cover.height ? `${cover.width} / ${cover.height}` : '4 / 3' }"
              />
              <div
                v-else
                class="aspect-[4/3] w-full"
              />
              <UiFileInput
                accept="image/png,image/jpeg,image/webp"
                :disabled="uploading"
                class="h-9 w-auto px-3 text-sm font-medium"
                :class="cover ? 'absolute bottom-3 right-3 bg-card/95 shadow-sm' : 'absolute inset-0 m-auto size-fit'"
                :aria-label="cover ? t('admin.tutorials.replaceCover') : t('admin.tutorials.uploadCover')"
                @select="pickCover"
              >
                <Icon
                  :name="uploading ? 'lucide:loader-circle' : cover ? 'lucide:refresh-cw' : 'lucide:image-plus'"
                  class="text-base"
                  :class="{ 'animate-spin': uploading }"
                />
                {{ cover ? t('admin.tutorials.replace') : t('admin.tutorials.upload') }}
              </UiFileInput>
            </div>
          </UiField>

          <TranslatableInput
            id="tutorial-title"
            v-model="form.title"
            v-model:translations="tr"
            field="title"
            :label="t('admin.tutorials.titleLabel')"
            maxlength="120"
            required
          />

          <UiField
            :label="t('admin.tutorials.videoLink')"
            for="tutorial-video"
            :error="videoUrlValid ? undefined : t('admin.tutorials.videoLinkInvalid')"
          >
            <UiInput
              id="tutorial-video"
              v-model="form.video_url"
              type="url"
              inputmode="url"
              maxlength="500"
              placeholder="https://youtu.be/…"
            />
          </UiField>

          <label class="flex cursor-pointer items-center justify-between gap-3 rounded-xl border border-border p-3 text-sm font-medium">
            {{ t('admin.tutorials.publish') }}
            <UiSwitch v-model="form.is_published" />
          </label>

          <UiAlert
            v-if="formError"
            variant="destructive"
          >
            <Icon name="lucide:circle-alert" />
            {{ formError }}
          </UiAlert>
          <UiDialogFooter>
            <UiButton
              type="button"
              variant="outline"
              @click="formOpen = false"
            >
              {{ t('admin.common.cancel') }}
            </UiButton>
            <UiButton
              type="submit"
              :disabled="!canSave"
            >
              <Icon
                v-if="actions.busy.value"
                name="lucide:loader-2"
                class="animate-spin text-base"
              />
              {{ t('admin.common.save') }}
            </UiButton>
          </UiDialogFooter>
        </form>
      </UiDialogContent>
    </UiDialog>

    <UiAlertDialog v-model:open="deleteOpen">
      <UiAlertDialogContent>
        <UiAlertDialogHeader>
          <UiAlertDialogTitle>{{ t('admin.tutorials.deleteTitle') }}</UiAlertDialogTitle>
        </UiAlertDialogHeader>
        <UiAlertDialogFooter>
          <UiAlertDialogCancel>
            {{ t('admin.common.cancel') }}
          </UiAlertDialogCancel>
          <UiButton
            variant="destructive"
            :disabled="actions.busy.value"
            @click="confirmDelete"
          >
            <Icon
              v-if="actions.busy.value"
              name="lucide:loader-2"
              class="animate-spin text-base"
            />
            {{ t('admin.common.delete') }}
          </UiButton>
        </UiAlertDialogFooter>
      </UiAlertDialogContent>
    </UiAlertDialog>
  </div>
</template>
