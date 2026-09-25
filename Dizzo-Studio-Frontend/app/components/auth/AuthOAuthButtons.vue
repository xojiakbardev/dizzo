<script setup lang="ts">
const error = ref<string | null>(null);
function handleError(message: string) {
  error.value = message;
}
</script>

<template>
  <div>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <AuthGoogleButton @error="handleError" />
      <AuthTelegramButton @error="handleError" />
    </div>

    <p
      v-if="error"
      class="mt-2.5 text-center text-xs font-medium text-rose-600"
    >
      {{ error }}
    </p>
  </div>
</template>
