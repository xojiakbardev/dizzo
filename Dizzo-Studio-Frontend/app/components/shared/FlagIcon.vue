<script setup lang="ts">
// A language's flag, a 3:2 rectangle with softened corners drawn inline (no request, no
// emoji font — Windows shows flag emoji as two letters): Uzbekistan,
// Russia, the UK.
defineProps<{ code: 'uz' | 'ru' | 'en' | string }>();
</script>

<template>
  <svg
    viewBox="0 0 30 20"
    class="h-[1em] w-[1.5em] shrink-0 overflow-hidden rounded-[3px]"
    preserveAspectRatio="none"
    aria-hidden="true"
  >
    <template v-if="code === 'uz'">
      <rect
        width="30"
        height="20"
        fill="#fff"
      />
      <rect
        width="30"
        height="6.4"
        fill="#0099b5"
      />
      <rect
        y="13.6"
        width="30"
        height="6.4"
        fill="#1eb53a"
      />
      <rect
        y="6.4"
        width="30"
        height="0.5"
        fill="#ce1126"
      />
      <rect
        y="13.1"
        width="30"
        height="0.5"
        fill="#ce1126"
      />
      <circle
        cx="4.6"
        cy="3.2"
        r="2.1"
        fill="#fff"
      />
      <circle
        cx="5.4"
        cy="3.2"
        r="1.8"
        fill="#0099b5"
      />
      <g fill="#fff">
        <circle
          v-for="(p, i) in [[9.4, 1.3], [11, 1.3], [12.6, 1.3], [9.4, 2.9], [11, 2.9], [12.6, 2.9], [11, 4.5], [12.6, 4.5], [7.8, 4.5], [9.4, 4.5]]"
          :key="i"
          :cx="p[0]"
          :cy="p[1]"
          r="0.42"
        />
      </g>
    </template>
    <template v-else-if="code === 'ru'">
      <rect
        width="30"
        height="6.67"
        fill="#fff"
      />
      <rect
        y="6.67"
        width="30"
        height="6.67"
        fill="#0039a6"
      />
      <rect
        y="13.33"
        width="30"
        height="6.67"
        fill="#d52b1e"
      />
    </template>
    <template v-else>
      <rect
        width="30"
        height="20"
        fill="#012169"
      />
      <path
        d="M0 0 30 20M30 0 0 20"
        stroke="#fff"
        stroke-width="4"
      />
      <path
        d="M0 0 30 20M30 0 0 20"
        stroke="#c8102e"
        stroke-width="1.3"
      />
      <path
        d="M15 0v20M0 10h30"
        stroke="#fff"
        stroke-width="6.5"
      />
      <path
        d="M15 0v20M0 10h30"
        stroke="#c8102e"
        stroke-width="4"
      />
    </template>
  </svg>
</template>
