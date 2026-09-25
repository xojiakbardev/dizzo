<script setup lang="ts">
// Rich text in a form (product and variant descriptions): bold, italic,
// underline, strike, two heading sizes, lists, quotes, links. Pasting from a
// chat or a document keeps its bold and italics. v-model is HTML ("" when
// empty); the backend keeps only this safe subset (services/rich_text.py)
// and RichText shows it with the same `.rich-text` style.
import StarterKit from '@tiptap/starter-kit';
import { EditorContent, useEditor } from '@tiptap/vue-3';

const props = defineProps<{ modelValue: string; placeholder?: string; id?: string }>();
const emit = defineEmits<{ 'update:modelValue': [html: string] }>();
const { t } = useI18n();

// An older plain-text description: one paragraph per line, as it was read.
// (The backend may have escaped it already: "&amp;" stays as it is.)
const esc = (text: string) => text.replace(/&(?!(?:[a-z]+|#\d+);)/gi, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const asHtml = (value: string) => (!value || /<[a-z][^>]*>/i.test(value)
  ? value
  : value.split(/\r?\n/).map(line => `<p>${esc(line)}</p>`).join(''));

const editor = useEditor({
  content: asHtml(props.modelValue),
  extensions: [StarterKit.configure({
    heading: { levels: [2, 3] },
    codeBlock: false,
    horizontalRule: false,
    link: { openOnClick: false, autolink: true, defaultProtocol: 'https' },
  })],
  editorProps: {
    attributes: {
      ...(props.id ? { id: props.id } : {}),
      class: 'rich-text min-h-48 px-3.5 py-3 text-sm outline-none',
      'aria-label': props.placeholder ?? t('storefront.richText.text'),
    },
  },
  onUpdate: ({ editor: e }) => emit('update:modelValue', e.isEmpty ? '' : e.getHTML()),
});

// A new value from outside (reset, another product) replaces the text.
watch(() => props.modelValue, (html) => {
  const e = editor.value;
  if (!e) return;
  const now = e.isEmpty ? '' : e.getHTML();
  if (html !== now) e.commands.setContent(asHtml(html || ''), { emitUpdate: false });
});

onBeforeUnmount(() => editor.value?.destroy());

type Mark = 'bold' | 'italic' | 'underline' | 'strike';
const MARKS = computed<Array<{ mark: Mark; icon: string; label: string }>>(() => [
  { mark: 'bold', icon: 'lucide:bold', label: t('storefront.richText.bold') },
  { mark: 'italic', icon: 'lucide:italic', label: t('storefront.richText.italic') },
  { mark: 'underline', icon: 'lucide:underline', label: t('storefront.richText.underline') },
  { mark: 'strike', icon: 'lucide:strikethrough', label: t('storefront.richText.strike') },
]);
function toggleMark(mark: Mark) {
  const chain = editor.value?.chain().focus();
  if (!chain) return;
  ({ bold: () => chain.toggleBold(), italic: () => chain.toggleItalic(), underline: () => chain.toggleUnderline(), strike: () => chain.toggleStrike() })[mark]().run();
}
function setLink() {
  const e = editor.value;
  if (!e) return;
  const current = e.getAttributes('link').href as string | undefined;
  const url = window.prompt(t('storefront.richText.linkPrompt'), current ?? 'https://');
  if (url === null) return;
  if (!url.trim() || url.trim() === 'https://') e.chain().focus().unsetLink().run();
  else e.chain().focus().extendMarkRange('link').setLink({ href: url.trim() }).run();
}
const active = (name: string, attrs?: Record<string, unknown>) => editor.value?.isActive(name, attrs) ?? false;
const btn = (on: boolean) => (on ? 'bg-primary/10 text-primary hover:bg-primary/15 hover:text-primary' : 'text-muted-foreground');
</script>

<template>
  <div class="overflow-hidden rounded-xl border border-input bg-background focus-within:border-ring focus-within:ring-3 focus-within:ring-ring/50">
    <div
      class="flex flex-wrap items-center gap-0.5 border-b border-border bg-muted/40 p-1"
      role="toolbar"
      :aria-label="t('storefront.richText.toolbar')"
    >
      <UiButton
        v-for="m in MARKS"
        :key="m.mark"
        type="button"
        variant="ghost"
        size="icon-sm"
        :class="btn(active(m.mark))"
        :title="m.label"
        :aria-label="m.label"
        :aria-pressed="active(m.mark)"
        @click="toggleMark(m.mark)"
      >
        <Icon
          :name="m.icon"
          class="text-base"
        />
      </UiButton>
      <UiSeparator
        orientation="vertical"
        class="mx-1 h-5"
      />
      <UiButton
        v-for="level in ([2, 3] as const)"
        :key="level"
        type="button"
        variant="ghost"
        size="icon-sm"
        :class="btn(active('heading', { level }))"
        :title="level === 2 ? t('storefront.richText.heading') : t('storefront.richText.subheading')"
        :aria-label="level === 2 ? t('storefront.richText.heading') : t('storefront.richText.subheading')"
        :aria-pressed="active('heading', { level })"
        @click="editor?.chain().focus().toggleHeading({ level }).run()"
      >
        <Icon
          :name="level === 2 ? 'lucide:heading-2' : 'lucide:heading-3'"
          class="text-base"
        />
      </UiButton>
      <UiButton
        type="button"
        variant="ghost"
        size="icon-sm"
        :class="btn(active('bulletList'))"
        :title="t('storefront.richText.bulletList')"
        :aria-label="t('storefront.richText.bulletList')"
        :aria-pressed="active('bulletList')"
        @click="editor?.chain().focus().toggleBulletList().run()"
      >
        <Icon
          name="lucide:list"
          class="text-base"
        />
      </UiButton>
      <UiButton
        type="button"
        variant="ghost"
        size="icon-sm"
        :class="btn(active('orderedList'))"
        :title="t('storefront.richText.orderedList')"
        :aria-label="t('storefront.richText.orderedList')"
        :aria-pressed="active('orderedList')"
        @click="editor?.chain().focus().toggleOrderedList().run()"
      >
        <Icon
          name="lucide:list-ordered"
          class="text-base"
        />
      </UiButton>
      <UiButton
        type="button"
        variant="ghost"
        size="icon-sm"
        :class="btn(active('blockquote'))"
        :title="t('storefront.richText.quote')"
        :aria-label="t('storefront.richText.quote')"
        :aria-pressed="active('blockquote')"
        @click="editor?.chain().focus().toggleBlockquote().run()"
      >
        <Icon
          name="lucide:quote"
          class="text-base"
        />
      </UiButton>
      <UiButton
        type="button"
        variant="ghost"
        size="icon-sm"
        :class="btn(active('link'))"
        :title="t('storefront.richText.link')"
        :aria-label="t('storefront.richText.link')"
        :aria-pressed="active('link')"
        @click="setLink"
      >
        <Icon
          name="lucide:link"
          class="text-base"
        />
      </UiButton>
      <div class="ml-auto flex gap-0.5">
        <UiButton
          type="button"
          variant="ghost"
          size="icon-sm"
          class="text-muted-foreground"
          :title="t('storefront.richText.undo')"
          :aria-label="t('storefront.richText.undo')"
          :disabled="!editor?.can().undo()"
          @click="editor?.chain().focus().undo().run()"
        >
          <Icon
            name="lucide:undo-2"
            class="text-base"
          />
        </UiButton>
        <UiButton
          type="button"
          variant="ghost"
          size="icon-sm"
          class="text-muted-foreground"
          :title="t('storefront.richText.redo')"
          :aria-label="t('storefront.richText.redo')"
          :disabled="!editor?.can().redo()"
          @click="editor?.chain().focus().redo().run()"
        >
          <Icon
            name="lucide:redo-2"
            class="text-base"
          />
        </UiButton>
      </div>
    </div>
    <EditorContent :editor="editor" />
  </div>
</template>
