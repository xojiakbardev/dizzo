// Reordering a list or a grid by dragging (mouse or touch). Each item
// registers its element; pressing its handle lifts the item, which then
// follows the pointer; the item nearest the pointer becomes the drop place,
// and releasing calls onMove.
import type { ComponentPublicInstance } from 'vue';

export function useDragSort(onMove: (from: number, to: number) => void) {
  const dragging = ref<number | null>(null);
  const over = ref<number | null>(null);
  const shift = ref({ x: 0, y: 0 });
  let origin = { x: 0, y: 0 };
  const els: (HTMLElement | null)[] = [];

  function register(index: number) {
    return (el: Element | ComponentPublicInstance | null) => {
      els[index] = el instanceof HTMLElement ? el : (el as ComponentPublicInstance | null)?.$el ?? null;
    };
  }

  function nearest(x: number, y: number): number | null {
    let best: number | null = null;
    let bestDistance = Infinity;
    els.forEach((el, i) => {
      if (!el?.isConnected) return;
      const r = el.getBoundingClientRect();
      // The lifted item is measured where it was, not where it floats.
      const [dx, dy] = i === dragging.value ? [shift.value.x, shift.value.y] : [0, 0];
      const d = Math.hypot(x - (r.left - dx + r.width / 2), y - (r.top - dy + r.height / 2));
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    });
    return best;
  }

  function onPointerMove(event: PointerEvent) {
    event.preventDefault();
    shift.value = { x: event.clientX - origin.x, y: event.clientY - origin.y };
    over.value = nearest(event.clientX, event.clientY) ?? over.value;
  }

  function stop(commit: boolean) {
    window.removeEventListener('pointermove', onPointerMove);
    window.removeEventListener('pointerup', onPointerUp);
    window.removeEventListener('pointercancel', onPointerCancel);
    const from = dragging.value;
    const to = over.value;
    dragging.value = null;
    over.value = null;
    shift.value = { x: 0, y: 0 };
    if (commit && from !== null && to !== null && from !== to) onMove(from, to);
  }
  const onPointerUp = () => stop(true);
  const onPointerCancel = () => stop(false);

  /** Starts a drag of item [index] (bind to the handle's pointerdown). */
  function start(event: PointerEvent, index: number) {
    if (event.button !== 0) return;
    // A button inside the item (delete, …) keeps its own click.
    if ((event.target as HTMLElement).closest('button, a, input') && !(event.currentTarget as HTMLElement).matches('button')) return;
    event.preventDefault();
    origin = { x: event.clientX, y: event.clientY };
    shift.value = { x: 0, y: 0 };
    dragging.value = index;
    over.value = index;
    window.addEventListener('pointermove', onPointerMove, { passive: false });
    window.addEventListener('pointerup', onPointerUp);
    window.addEventListener('pointercancel', onPointerCancel);
  }

  onBeforeUnmount(() => stop(false));

  /** Classes and style for item [index]: the lifted one follows the pointer,
   * the drop place is outlined. */
  function itemClass(index: number) {
    if (dragging.value === index) return 'relative z-30 scale-[1.02] shadow-xl ring-2 ring-primary/40 cursor-grabbing';
    if (dragging.value !== null && over.value === index) return 'ring-2 ring-primary ring-offset-2 ring-offset-background';
    return '';
  }
  function itemStyle(index: number) {
    if (dragging.value !== index) return undefined;
    return { transform: `translate(${shift.value.x}px, ${shift.value.y}px) scale(1.02)`, transition: 'none' };
  }

  return { dragging, over, register, start, itemClass, itemStyle };
}

// ── Insert-style drag for tables ──────────────────────────────────────────────
// The dragged row stays in-place (faded). Rows between `from` and `over`
// shift by the dragged row's measured height so a visible gap opens at the
// target position. Releasing commits the reorder.
export function useInsertDragSort(onMove: (from: number, to: number) => void) {
  const dragging = ref<number | null>(null);
  const over = ref<number | null>(null);
  const shiftY = ref(0);
  let startY = 0;
  const els: (HTMLElement | null)[] = [];

  function register(index: number) {
    return (el: Element | ComponentPublicInstance | null) => {
      els[index] = el instanceof HTMLElement ? el : (el as ComponentPublicInstance | null)?.$el ?? null;
    };
  }

  function overAt(y: number): number | null {
    let best: number | null = null;
    let bestDist = Infinity;
    els.forEach((el, i) => {
      if (!el?.isConnected) return;
      const r = el.getBoundingClientRect();
      const mid = r.top + r.height / 2;
      const d = Math.abs(y - mid);
      if (d < bestDist) { bestDist = d; best = i; }
    });
    return best;
  }

  function onPointerMove(event: PointerEvent) {
    event.preventDefault();
    shiftY.value = event.clientY - startY;
    over.value = overAt(event.clientY) ?? over.value;
  }

  function stop(commit: boolean) {
    window.removeEventListener('pointermove', onPointerMove);
    window.removeEventListener('pointerup', onPointerUp);
    window.removeEventListener('pointercancel', onPointerCancel);
    const from = dragging.value;
    const to = over.value;
    dragging.value = null;
    over.value = null;
    shiftY.value = 0;
    if (commit && from !== null && to !== null && from !== to) onMove(from, to);
  }
  const onPointerUp = () => stop(true);
  const onPointerCancel = () => stop(false);

  function start(event: PointerEvent, index: number) {
    if (event.button !== 0) return;
    event.preventDefault();
    startY = event.clientY;
    shiftY.value = 0;
    dragging.value = index;
    over.value = index;
    window.addEventListener('pointermove', onPointerMove, { passive: false });
    window.addEventListener('pointerup', onPointerUp);
    window.addEventListener('pointercancel', onPointerCancel);
  }

  onBeforeUnmount(() => stop(false));

  /** Class for row [index]:
   * - dragging row: fully visible, elevated (shadow + ring), cursor grabbing
   * - drop-target row: coloured border shows where the row will land
   */
  function rowClass(index: number): string {
    if (dragging.value === null) return '';
    if (dragging.value === index)
      return 'relative z-30 ring-2 ring-primary/60 bg-card/95 backdrop-blur-xs cursor-grabbing select-none shadow-2xl';
    if (over.value === index) {
      return dragging.value < index
        ? 'border-b-[3px] border-b-primary'
        : 'border-t-[3px] border-t-primary';
    }
    return '';
  }

  /** TranslateY for row [index]:
   * - dragging row: floats above other rows following the pointer vertically with shadow
   * - rows between `from` and `over` slide to reveal the drop slot
   */
  function rowStyle(index: number): Record<string, string> | undefined {
    const from = dragging.value;
    const to = over.value;
    if (from === null) return undefined;

    // Lifted row: follows the pointer vertically with elevated shadow and higher z-index
    if (index === from) {
      return {
        zIndex: '30',
        position: 'relative',
        transform: `translateY(${shiftY.value}px)`,
        boxShadow: '0 12px 32px -4px rgba(0,0,0,0.2), 0 4px 12px -2px rgba(0,0,0,0.12)',
        pointerEvents: 'none',
        transition: 'box-shadow 150ms ease',
      };
    }

    if (to === null || from === to) return undefined;

    const dragEl = els[from];
    const h = dragEl ? dragEl.getBoundingClientRect().height : 48;
    const dir = from < to ? 1 : -1;
    const lo = Math.min(from, to);
    const hi = Math.max(from, to);
    if (index > lo && index <= hi) {
      return { transform: `translateY(${dir > 0 ? -h : h}px)`, transition: 'transform 180ms cubic-bezier(0.2, 0, 0, 1)' };
    }
    return { transition: 'transform 180ms cubic-bezier(0.2, 0, 0, 1)' };
  }

  return { dragging, over, register, start, rowClass, rowStyle };
}

/** A copy of [list] with the item at [from] moved to [to]. */
export function moved<T>(list: readonly T[], from: number, to: number): T[] {
  const copy = [...list];
  const [item] = copy.splice(from, 1);
  copy.splice(to, 0, item!);
  return copy;
}
