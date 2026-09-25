// A create form's slug: written from the title as it's typed (Uzbek
// apostrophes dropped, lowercase latin, digits and hyphens) and made unique
// against what's already loaded — "soat", "soat-2", "soat-3". Once the admin
// edits the slug by hand, the title stops overwriting it. `save` retries
// with the next free suffix when the backend still answers 409 (someone
// else took it meanwhile).
import { ApiError } from '~/composables/useApi';
import { slugify } from '~/lib/slugify';

/** `base`, or `base-2`, `base-3`… — the first one not in `taken`, cut to `maxLength`. */
export function uniqueSlug(base: string, taken: Iterable<string>, maxLength: number): string {
  const used = new Set(taken);
  const root = base.slice(0, maxLength).replace(/-+$/, '');
  if (!root) return '';
  if (!used.has(root)) return root;
  for (let n = 2; ; n++) {
    const suffix = `-${n}`;
    const candidate = `${root.slice(0, maxLength - suffix.length).replace(/-+$/, '')}${suffix}`;
    if (!used.has(candidate)) return candidate;
  }
}

/** "soat-3" → "soat": the part a numbered suffix hangs off. */
function slugRoot(slug: string): string {
  return slug.replace(/-\d+$/, '') || slug;
}

export function useSlugField(options: {
  /** The title the slug follows. */
  source: () => string;
  /** Slugs already in use (the loaded list, minus the item being edited). */
  taken: () => string[];
  maxLength: number;
}) {
  const slug = ref('');
  /** Edited by hand: the title no longer writes it. */
  const touched = ref(false);

  function fromSource() {
    return uniqueSlug(slugify(options.source()), options.taken(), options.maxLength);
  }

  watch(options.source, () => {
    if (!touched.value) slug.value = fromSource();
  });

  /** Bind to the slug input's @input: from now on it's the admin's. */
  function onInput() {
    touched.value = true;
  }

  /** Start over: `value` for an edit (kept as typed), or follow the title. */
  function reset(value?: string) {
    touched.value = value !== undefined;
    slug.value = value ?? fromSource();
  }

  /** Runs `work(slug)`; on a 409 moves to the next free suffix and tries again. */
  async function save<T>(work: (slug: string) => Promise<T>, attempts = 5): Promise<T> {
    const tried = new Set(options.taken());
    for (let i = 0; ; i++) {
      try {
        return await work(slug.value);
      }
      catch (err) {
        if (!(err instanceof ApiError) || err.status !== 409 || i >= attempts - 1) throw err;
        tried.add(slug.value);
        slug.value = uniqueSlug(slugRoot(slug.value), tried, options.maxLength);
      }
    }
  }

  return { slug, touched, onInput, reset, save };
}
