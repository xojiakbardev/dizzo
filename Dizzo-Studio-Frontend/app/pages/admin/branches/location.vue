<script setup lang="ts">
definePageMeta({ layout: 'admin', ssr: false });

const route = useRoute();
const router = useRouter();
const localePath = useLocalePath();

useAdminCrumbs(() => [
  { label: 'Filiallar', to: '/admin/branches' },
  { label: 'Joylashuv' },
]);

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
  void router.push({
    path: localePath('/admin/branches'),
    query: {
      selected_address: value.address,
      selected_city: value.city,
      lat: String(value.latitude),
      lon: String(value.longitude),
    },
  });
}
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-4">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold tracking-tight text-foreground">
          Filial joylashuvi
        </h1>
        <p class="mt-1 text-sm text-muted-foreground">
          Xarita ustiga bosing yoki qidiring, keyin tasdiqlang.
        </p>
      </div>
      <UiButton
        type="button"
        variant="outline"
        @click="router.back()"
      >
        <Icon
          name="lucide:arrow-left"
          class="size-4"
        />
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
          map-class="h-[min(32rem,calc(100dvh-16rem))] w-full"
          @confirm="handleConfirm"
        />
      </UiCardContent>
    </UiCard>
  </div>
</template>
