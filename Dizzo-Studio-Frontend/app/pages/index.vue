<script setup lang="ts">
// Hero → products (the point of the page) → video tutorials → real work,
// full width → reviews beside the FAQ → the last call. The tutorials show
// once the admin has published one; the gallery once there are three
// pieces of real work (in grey while it loads, so the page doesn't reflow).
// Reviews and the FAQ share a row on wide screens; the FAQ takes it alone
// until a review is approved.

const tutorials = useTutorials();
// The gallery page's own first page: opening /gallery after this is instant.
const gallery = useGalleryFeed(ref(null));
const reviews = usePublicReviews(3);
const tutorialItems = computed(() => tutorials.data.value ?? []);
const galleryItems = computed(() => (gallery.data.value?.pages[0] ?? []).slice(0, 8));
const reviewItems = computed(() => reviews.data.value ?? []);
if (import.meta.server) {
  await Promise.all([
    tutorials.suspense(), gallery.suspense(), reviews.suspense(), usePopularProducts().suspense(),
  ]).catch(() => {});
}
const showGallery = computed(() => gallery.isPending.value || galleryItems.value.length >= 3);
const showReviews = computed(() => reviews.isPending.value || reviewItems.value.length > 0);
// After deleting the account (?deleted=1): a short goodbye at the top.
const route = useRoute();
const router = useRouter();
const deleted = ref(route.query.deleted === '1');
onMounted(() => {
  if (deleted.value) void router.replace({ query: {} });
});
</script>

<template>
  <div class="overflow-x-clip">
    <div
      v-if="deleted"
      class="mx-auto max-w-7xl px-4 pt-4 sm:px-6 lg:px-8"
    >
      <UiAlert>
        <Icon name="lucide:circle-check" />
        {{ $t('user.deleteAccount.done') }}
      </UiAlert>
    </div>
    <HeroSection />
    <OurProducts />

    <div class="mx-auto max-w-7xl space-y-10 px-4 py-10 sm:px-6 sm:py-12 lg:space-y-12 lg:px-8 lg:py-14">
      <TutorialVideos
        v-if="tutorialItems.length"
        :items="tutorialItems"
      />
      <CustomerGallery
        v-if="showGallery"
        :items="galleryItems"
        :loading="gallery.isPending.value"
      />
      <CustomerReviews
        v-if="showReviews"
        :reviews="reviewItems"
        :loading="reviews.isPending.value"
      />
      <div class="grid items-stretch gap-8 lg:grid-cols-2 lg:gap-8">
        <LandingFaq />
        <FinalCta />
      </div>
    </div>
  </div>
</template>
