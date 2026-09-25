<script setup lang="ts">
// The review form for a completed order (the order page opens it in a
// dialog): stars, a few words, the city and up to six photos. It goes to
// the admin first; once approved it shows in "Mijozlarimiz".
import { getApiErrorMessage } from '~/composables/useApi';
import { DESIGN_IMAGE_MAX_MB, MEDIA_IMAGE_TYPES } from '~/composables/useMediaUpload';

const MAX_PHOTOS = 6;

const props = defineProps<{ orderId: number }>();
const emit = defineEmits<{ sent: [] }>();

const { t } = useI18n();
const create = useCreateReview();
const { upload } = useMediaUpload();

const rating = ref(5);
const text = ref('');
const city = ref('');
const photos = ref<{ id: string; url: string }[]>([]);
const uploading = ref(false);
const error = ref<string | null>(null);
const fileInput = ref<HTMLInputElement | null>(null);

async function addPhotos(event: Event) {
  const input = event.target as HTMLInputElement;
  const files = [...(input.files ?? [])].slice(0, MAX_PHOTOS - photos.value.length);
  input.value = '';
  error.value = null;
  const wrong = files.find(f => !MEDIA_IMAGE_TYPES.includes(f.type) || f.size > DESIGN_IMAGE_MAX_MB * 1024 * 1024);
  if (wrong) {
    error.value = t('user.review.badFile', { name: wrong.name, mb: DESIGN_IMAGE_MAX_MB });
    return;
  }
  uploading.value = true;
  try {
    for (const file of files) {
      const media = await upload(file, 'design');
      photos.value.push({ id: media.id, url: media.url });
    }
  }
  catch (e) {
    error.value = getApiErrorMessage(e, t('user.review.uploadError'));
  }
  finally {
    uploading.value = false;
  }
}

async function submit() {
  error.value = null;
  if (text.value.trim().length < 10) {
    error.value = t('user.review.tooShort');
    return;
  }
  try {
    await create.mutateAsync({
      order_id: props.orderId,
      rating: rating.value,
      text: text.value.trim(),
      city: city.value.trim(),
      photo_ids: photos.value.map(p => p.id),
    });
    emit('sent');
  }
  catch (e) {
    error.value = getApiErrorMessage(e, t('user.review.sendError'));
  }
}
</script>

<template>
  <form
    class="space-y-4"
    @submit.prevent="submit"
  >
    <UiField :label="t('user.review.rating')">
      <StarRating
        v-model="rating"
        class="h-7 w-7"
      />
    </UiField>
    <UiField
      :label="t('user.review.text')"
      for="review-text"
    >
      <UiTextarea
        id="review-text"
        v-model="text"
        rows="4"
        maxlength="1000"
        class="min-h-[6.5rem] resize-none"
        :placeholder="t('user.review.textPlaceholder')"
      />
    </UiField>
    <UiField
      :label="t('user.review.city')"
      for="review-city"
    >
      <UiInput
        id="review-city"
        v-model="city"
        maxlength="60"
        :placeholder="t('user.review.cityPlaceholder')"
      />
    </UiField>
    <UiField :label="t('user.review.photos', { count: photos.length, max: MAX_PHOTOS })">
      <div class="flex flex-wrap gap-2">
        <div
          v-for="(p, i) in photos"
          :key="p.id"
          class="relative"
        >
          <MediaThumb
            :src="p.url"
            class="size-16 rounded-xl"
          />
          <UiButton
            type="button"
            variant="secondary"
            size="icon-xs"
            class="absolute -top-1.5 -right-1.5 border-border shadow-xs"
            :aria-label="t('user.review.removePhoto')"
            @click="photos.splice(i, 1)"
          >
            <Icon
              name="lucide:x"
              class="text-sm"
            />
          </UiButton>
        </div>
        <button
          v-if="photos.length < MAX_PHOTOS"
          type="button"
          :disabled="uploading"
          class="flex size-16 flex-col items-center justify-center gap-1 rounded-xl border border-dashed border-border text-[11px] font-semibold text-muted-foreground transition hover:border-primary hover:text-primary disabled:opacity-60"
          @click="fileInput?.click()"
        >
          <Icon
            :name="uploading ? 'lucide:loader-circle' : 'lucide:image-plus'"
            class="text-xl"
            :class="{ 'animate-spin': uploading }"
          />
          {{ uploading ? t('user.review.uploading') : t('user.review.add') }}
        </button>
      </div>
      <input
        ref="fileInput"
        type="file"
        accept="image/png,image/jpeg,image/webp"
        multiple
        class="hidden"
        @change="addPhotos"
      >
    </UiField>
    <UiAlert
      v-if="error"
      variant="destructive"
    >
      <Icon name="lucide:circle-alert" />
      <UiAlertDescription>{{ error }}</UiAlertDescription>
    </UiAlert>
    <UiButton
      type="submit"
      class="w-full"
      :disabled="create.isPending.value || uploading"
    >
      <Icon
        v-if="create.isPending.value"
        name="lucide:loader-2"
        class="animate-spin text-base"
      />
      {{ create.isPending.value ? t('user.review.sending') : t('user.review.send') }}
    </UiButton>
  </form>
</template>
