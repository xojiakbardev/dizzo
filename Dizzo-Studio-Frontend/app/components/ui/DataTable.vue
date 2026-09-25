<script setup lang="ts" generic="T">
// A table from column definitions, built on the Table parts: cells come
// from `#cell-<key>` slots, loading shows skeleton rows, no rows an Empty
// (an icon and a title only — no description line under it).
// Every admin list uses it, so they all look like "Buyurtmalar". A column's
// className goes on its header and its cells (`hidden md:table-cell` hides
// a secondary column on phones).
export interface DataTableColumn {
  key: string;
  header: string;
  className?: string;
  width?: string;
}

const props = withDefaults(
  defineProps<{
    columns: DataTableColumn[];
    data: T[] | undefined | null;
    isLoading?: boolean;
    emptyText?: string;
    emptyIcon?: string;
    skeletonRows?: number;
    rowKey?: (item: T, index: number) => string | number;
    clickable?: boolean;
  }>(),
  {
    isLoading: false,
    emptyText: undefined,
    emptyIcon: 'lucide:inbox',
    skeletonRows: 5,
    rowKey: (_: T, index: number) => index,
    clickable: false,
  },
);

const emit = defineEmits<{
  'rowClick': [item: T];
  'row-click': [item: T];
}>();

function handleRowClick(row: T) {
  emit('rowClick', row);
  emit('row-click', row);
}
</script>

<template>
  <div class="w-full overflow-hidden rounded-2xl border border-border bg-card shadow-xs">
    <UiTable>
      <UiTableHeader>
        <UiTableRow class="border-b border-border bg-muted/30 hover:bg-muted/30">
          <UiTableHead
            v-for="col in props.columns"
            :key="col.key"
            :class="['h-11 px-4 text-xs font-semibold text-foreground', col.className]"
            :style="{ width: col.width }"
          >
            {{ col.header }}
          </UiTableHead>
        </UiTableRow>
      </UiTableHeader>
      <UiTableBody>
        <UiTableSkeleton
          v-if="props.isLoading"
          :columns="props.columns.length"
          :rows="props.skeletonRows"
        />
        <UiTableRow
          v-else-if="!props.data?.length"
          class="hover:bg-transparent"
        >
          <UiTableCell
            :colspan="props.columns.length"
            class="p-0 whitespace-normal"
          >
            <EmptyState
              :title="props.emptyText ?? $t('common.ui.table.empty')"
              :icon="props.emptyIcon"
              class="rounded-none border-0 bg-transparent py-12"
            >
              <template
                v-if="$slots.empty"
                #default
              >
                <slot name="empty" />
              </template>
            </EmptyState>
          </UiTableCell>
        </UiTableRow>
        <template v-else>
          <UiTableRow
            v-for="(row, idx) in props.data"
            :key="props.rowKey(row, idx)"
            :class="[
              'border-b border-border transition-colors last:border-b-0 hover:bg-muted/50',
              props.clickable ? 'cursor-pointer' : '',
            ]"
            @click="handleRowClick(row)"
          >
            <UiTableCell
              v-for="col in props.columns"
              :key="col.key"
              :class="['px-4 py-3.5 align-middle text-sm text-foreground', col.className]"
            >
              <slot
                :name="`cell-${col.key}`"
                :row="row"
                :index="idx"
              >
                {{ (row as Record<string, unknown>)[col.key] }}
              </slot>
            </UiTableCell>
          </UiTableRow>
        </template>
      </UiTableBody>
    </UiTable>

    <slot name="footer" />
  </div>
</template>
