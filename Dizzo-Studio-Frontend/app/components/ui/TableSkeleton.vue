<script setup lang="ts">
// Loading rows for a table, padded like UiDataTable's cells so the table
// keeps its height when the rows come in.
withDefaults(defineProps<{ columns?: number; rows?: number }>(), { columns: 5, rows: 6 });

const WIDTHS = ['w-3/4', 'w-1/2', 'w-2/3', 'w-4/5', 'w-1/3'];
</script>

<template>
  <UiTableRow
    v-for="r in rows"
    :key="r"
    class="border-b border-border hover:bg-transparent"
  >
    <UiTableCell
      v-for="c in columns"
      :key="c"
      class="px-4 py-3.5"
    >
      <UiSkeleton :class="`h-4 rounded-md ${WIDTHS[(r + c) % WIDTHS.length]}`" />
    </UiTableCell>
  </UiTableRow>
</template>
