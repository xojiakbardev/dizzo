<template>
  <!-- Sign in and register: the form alone, centred — no side poster to wait for. -->
  <div class="flex min-h-dvh w-full flex-col justify-center bg-white px-4 py-8 sm:px-6">
    <main
      id="main-content"
      class="mx-auto w-full max-w-[540px]"
    >
      <slot />
    </main>
  </div>
</template>
