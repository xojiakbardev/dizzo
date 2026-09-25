<script setup lang="ts">
const route = useRoute();
const localePath = useLocalePath();
const router = useRouter();

definePageMeta({ layout: 'cabinet', ssr: false });

const initialAddress = computed(() => typeof route.query.address === 'string' ? route.query.address : '');
const initialCity = computed(() => typeof route.query.city === 'string' ? route.query.city : 'Toshkent');
const initialLat = computed(() => {
  const value = typeof route.query.lat === 'string' ? Number(route.query.lat) : NaN;
  return Number.isFinite(value) ? value : 41.311081;
});
const initialLon = computed(() => {
  const value = typeof route.query.lon === 'string' ? Number(route.query.lon) : NaN;
  return Number.isFinite(value) ? value : 69.240562;
});

function handleConfirm(value: { latitude: number; longitude: number; address: string; city: string }) {
  const returnPath = typeof route.query.return === 'string' ? route.query.return : '/user/checkout';
  const target = { path: localePath(returnPath), query: { selected_address: value.address, selected_city: value.city, lat: String(value.latitude), lon: String(value.longitude) } };
  void router.push(target);
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-6 sm:px-6 lg:px-8">
    <div class="mb-6 flex items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-foreground">Yetkazish manzilini tanlang</h1>
      </div>
      <UiButton type="button" variant="outline" @click="router.back()">
        <Icon name="lucide:arrow-left" class="size-4" />
        Orqaga
      </UiButton>
    </div>

    <UiCard class="shadow-xs">
      <UiCardContent class="p-4 sm:p-6">
        <LocationPickerMap
          :latitude="initialLat"
          :longitude="initialLon"
          :address="initialAddress"
          :city="initialCity"
          @confirm="handleConfirm"
        />
      </UiCardContent>
    </UiCard>
  </div>
</template>
