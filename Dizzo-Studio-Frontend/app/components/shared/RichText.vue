<script setup lang="ts">
// Rich text as the customer reads it (a variant's description), styled by
// the same `.rich-text` rules as the admin editor. The HTML is cleaned here
// too (utils/richText.ts, the backend's allow-list), so a page never trusts
// stored HTML on its own.
const props = defineProps<{ html: string }>();

// In the editor a line break at the very end of a paragraph still makes a
// new (empty) line; a browser drops it unless another one follows.
const shown = computed(() => cleanRichText(props.html).replace(/<br>(?=<\/(?:p|h2|h3|li)>)/g, '<br><br>'));
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -- cleaned to the editor's safe subset above -->
  <div
    class="rich-text text-sm text-foreground"
    v-html="shown"
  />
</template>
