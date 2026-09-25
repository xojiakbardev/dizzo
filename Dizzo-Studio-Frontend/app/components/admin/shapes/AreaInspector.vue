<script setup lang="ts">
// Everything about the selected area, top to bottom: its name (in three
// languages), key and placement note,
// size, place on the model, face, pair and print methods.
import type { CatalogMethod } from '~/types/catalog';
import { isPlacedModelAnchor, METHOD_LABELS } from '~/types/catalog';
import type { AreaMeasure, DraftArea, Problem, ShapeDraft } from '~/lib/admin/shapeDraft';
import { isPlaced, METHODS, partnerOf, SIDE_LABELS } from '~/lib/admin/shapeDraft';
import type { AlignHow, AreaOps } from '~/components/admin/shapes/ops';
import type { TextTranslations } from '~/lib/admin/translations';
import MethodCard from '~/components/admin/shapes/MethodCard.vue';
import MmField from '~/components/admin/shapes/MmField.vue';

const props = defineProps<{
  draft: ShapeDraft;
  area: DraftArea;
  measure: AreaMeasure | null;
  problems: Problem[];
  ops: AreaOps;
  activeMethod: CatalogMethod | null;
  openMethods: CatalogMethod[];
  stripAt: number;
  playing: boolean;
  rotation: number | null;
}>();
const emit = defineEmits<{
  editZone: [method: CatalogMethod | null];
  openMethod: [method: CatalogMethod];
  stripAt: [value: number];
  play: [];
}>();

const { t } = useI18n();
const uid = computed(() => props.area.uid);
const model = computed(() => props.draft.kind === 'model');
const placed = computed(() => isPlaced(props.draft, props.area));
const anchor = computed(() => (isPlacedModelAnchor(props.area.anchor) ? props.area.anchor : null));
const face = computed<'rect' | 'rounded' | 'round'>(() => (anchor.value?.round ? 'round' : Number(anchor.value?.corner_radius_mm ?? 0) > 0 ? 'rounded' : 'rect'));
const corner = computed(() => Number(anchor.value?.corner_radius_mm ?? 0));
const fieldError = (field: string) => props.problems.find(p => p.field === field && !p.method)?.text ?? null;
const areaProblems = computed(() => props.problems.filter(p => !p.method && !['name', 'key', 'w', 'h'].includes(p.field ?? '')));

// Name and note in Uzbek (the area's own fields) and translated (area.tr);
// every edit is an undo step, typing merged into one.
const nameText = computed({
  get: () => props.area.name,
  set: (name: string) => props.ops.patch(uid.value, { name }, 'name'),
});
const noteText = computed({
  get: () => props.area.note,
  set: (note: string) => props.ops.patch(uid.value, { note }, 'note'),
});
const trFor = (group: string) => computed({
  get: () => props.area.tr,
  set: (tr: TextTranslations) => props.ops.patch(uid.value, { tr }, group),
});
const nameTr = trFor('name-tr');
const noteTr = trFor('note-tr');

// Name and key: the key follows the name until it is typed by hand.
const keyText = ref(props.area.key);
watch(() => props.area.key, (k) => {
  keyText.value = k;
});
function commitKey() {
  const k = keyText.value.trim().toLowerCase();
  if (k && k !== props.area.key) props.ops.patch(uid.value, { key: k });
  else keyText.value = props.area.key;
}

const keepRatio = ref(false);
function setW(v: number | null) {
  if (v === null) return;
  props.ops.resize(uid.value, v, keepRatio.value ? Math.round(((v * props.area.h) / props.area.w) * 10) / 10 : props.area.h);
}
function setH(v: number | null) {
  if (v === null) return;
  props.ops.resize(uid.value, keepRatio.value ? Math.round(((v * props.area.w) / props.area.h) * 10) / 10 : props.area.w, v);
}

const step = ref(1);
const ALIGN = computed<Array<{ how: AlignHow; label: string; icon: string }>>(() => [
  { how: 'x', label: t('admin.shapes.inspector.alignX'), icon: 'lucide:align-center-vertical' },
  { how: 'y', label: t('admin.shapes.inspector.alignY'), icon: 'lucide:align-center-horizontal' },
  { how: 'top', label: t('admin.shapes.inspector.alignTop'), icon: 'lucide:align-start-horizontal' },
  { how: 'bottom', label: t('admin.shapes.inspector.alignBottom'), icon: 'lucide:align-end-horizontal' },
]);
const NUDGE = computed<Array<{ key: string; label: string; icon: string; dx: number; dy: number }>>(() => [
  { key: 'left', label: t('admin.shapes.inspector.nudgeLeft'), icon: 'lucide:arrow-left', dx: -1, dy: 0 },
  { key: 'up', label: t('admin.shapes.inspector.nudgeUp'), icon: 'lucide:arrow-up', dx: 0, dy: 1 },
  { key: 'down', label: t('admin.shapes.inspector.nudgeDown'), icon: 'lucide:arrow-down', dx: 0, dy: -1 },
  { key: 'right', label: t('admin.shapes.inspector.nudgeRight'), icon: 'lucide:arrow-right', dx: 1, dy: 0 },
]);

// Pairs: any other area that isn't paired elsewhere.
const partner = computed(() => partnerOf(props.draft, props.area));
const candidates = computed(() => props.draft.areas.filter(a => a.uid !== uid.value && (!a.pairKey || a.pairKey === props.area.key)));
function pickPartner(value: unknown) {
  const key = value === '__none' ? null : String(value);
  props.ops.pair(uid.value, key, props.area.pairMirror);
}

const missing = computed(() => METHODS.filter(m => !props.area.methods.some(x => x.method === m)));
function toggleEdit(method: CatalogMethod) {
  emit('editZone', props.activeMethod === method ? null : method);
}
</script>

<template>
  <div
    class="space-y-5 p-4"
    data-testid="area-inspector"
  >
    <!-- Name, key, actions -->
    <div class="space-y-3">
      <div class="flex items-start gap-2">
        <TranslatableInput
          id="area-name"
          v-model="nameText"
          v-model:translations="nameTr"
          field="name"
          :label="t('admin.common.name')"
          required
          class="flex-1"
          input-class="h-9 rounded-lg font-semibold"
        />
        <UiDropdownMenu>
          <UiDropdownMenuTrigger as-child>
            <UiButton
              variant="outline"
              size="icon-sm"
              class="mt-[34px]"
              :aria-label="t('admin.shapes.inspector.actions')"
            >
              <Icon
                name="lucide:ellipsis"
                class="size-4"
              />
            </UiButton>
          </UiDropdownMenuTrigger>
          <UiDropdownMenuContent
            align="end"
            class="w-56"
          >
            <UiDropdownMenuItem @select="ops.duplicate(uid)">
              <Icon name="lucide:copy" />
              {{ t('admin.shapes.inspector.duplicate') }}
            </UiDropdownMenuItem>
            <template v-if="model && placed">
              <UiDropdownMenuItem @select="ops.mirrorCopy(uid, 'front')">
                <Icon name="lucide:flip-horizontal-2" />
                {{ t('admin.shapes.inspector.copyFrontBack') }}
              </UiDropdownMenuItem>
              <UiDropdownMenuItem @select="ops.mirrorCopy(uid, 'side')">
                <Icon name="lucide:flip-horizontal" />
                {{ t('admin.shapes.inspector.copyLeftRight') }}
              </UiDropdownMenuItem>
            </template>
            <UiDropdownMenuItem @select="ops.place(uid)">
              <Icon name="lucide:crosshair" />
              {{ t('admin.shapes.inspector.moveElsewhere') }}
            </UiDropdownMenuItem>
            <UiDropdownMenuSeparator />
            <UiDropdownMenuItem
              class="text-destructive focus:text-destructive"
              data-testid="area-delete"
              @select="ops.remove(uid)"
            >
              <Icon name="lucide:trash-2" />
              {{ t('admin.common.delete') }}
            </UiDropdownMenuItem>
          </UiDropdownMenuContent>
        </UiDropdownMenu>
      </div>
      <div class="grid gap-1">
        <UiLabel
          for="area-key"
          class="text-xs font-medium text-muted-foreground"
        >
          {{ t('admin.shapes.inspector.key') }}
        </UiLabel>
        <input
          id="area-key"
          v-model="keyText"
          class="h-8 rounded-lg border bg-muted/40 px-2.5 font-mono text-xs outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
          :class="fieldError('key') ? 'border-destructive' : 'border-input'"
          spellcheck="false"
          autocomplete="off"
          @blur="commitKey"
          @keydown.enter.prevent="commitKey"
        >
        <p
          v-if="fieldError('key')"
          class="text-[11px] text-destructive"
        >
          {{ fieldError('key') }}
        </p>
      </div>
      <TranslatableInput
        id="area-note"
        v-model="noteText"
        v-model:translations="noteTr"
        field="placement_note"
        kind="textarea"
        :label="t('admin.shapes.inspector.note')"
        :placeholder="t('admin.shapes.inspector.notePlaceholder')"
        maxlength="200"
        input-class="min-h-16 rounded-lg text-sm"
      />
      <ul
        v-if="areaProblems.length"
        class="space-y-1 rounded-lg border border-amber-200 bg-amber-50 p-2.5 text-xs text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-200"
      >
        <li
          v-for="p in areaProblems"
          :key="p.text"
          class="flex gap-1.5"
        >
          <Icon
            :name="p.blocking ? 'lucide:circle-alert' : 'lucide:triangle-alert'"
            class="mt-px size-3.5 shrink-0"
          />
          {{ p.text }}
        </li>
      </ul>
    </div>

    <!-- Size -->
    <section class="space-y-2">
      <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {{ t('admin.shapes.inspector.size') }}
      </h3>
      <div class="flex items-start gap-2">
        <MmField
          id="area-w"
          :label="t('admin.shapes.inspector.width')"
          class="flex-1"
          :model-value="area.w"
          :min="1"
          :error="fieldError('w')"
          @update:model-value="setW"
        />
        <UiTooltip>
          <UiTooltipTrigger as-child>
            <UiButton
              variant="ghost"
              size="icon-sm"
              class="mt-5 shrink-0"
              :class="keepRatio ? 'text-primary' : 'text-muted-foreground'"
              :aria-pressed="keepRatio"
              :aria-label="t('admin.shapes.inspector.keepRatio')"
              @click="keepRatio = !keepRatio"
            >
              <Icon
                :name="keepRatio ? 'lucide:link' : 'lucide:unlink'"
                class="size-4"
              />
            </UiButton>
          </UiTooltipTrigger>
          <UiTooltipContent>{{ t('admin.shapes.inspector.keepRatio') }}</UiTooltipContent>
        </UiTooltip>
        <MmField
          id="area-h"
          :label="t('admin.shapes.inspector.height')"
          class="flex-1"
          :model-value="area.h"
          :min="1"
          :error="fieldError('h')"
          @update:model-value="setH"
        />
      </div>
      <p
        v-if="measure && model"
        class="text-[11px] text-muted-foreground tabular-nums"
      >
        {{ t('admin.shapes.inspector.coverage', { n: Math.round(measure.coverage * 100) }) }}<template v-if="measure.side">
          · {{ SIDE_LABELS[measure.side] }}
        </template>
      </p>
    </section>

    <!-- Placement -->
    <section class="space-y-2">
      <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {{ t('admin.shapes.inspector.placement') }}
      </h3>
      <div
        v-if="!placed"
        class="flex items-center justify-between gap-2 rounded-lg border border-dashed border-border p-2.5 text-xs text-muted-foreground"
      >
        {{ t('admin.shapes.problem.notPlaced') }}
        <UiButton
          size="xs"
          @click="ops.place(uid)"
        >
          <Icon
            name="lucide:crosshair"
            class="size-3.5"
          />
          {{ t('admin.shapes.inspector.place') }}
        </UiButton>
      </div>
      <template v-else>
        <div class="flex flex-wrap items-center gap-1">
          <UiTooltip
            v-for="a in ALIGN"
            :key="a.how"
          >
            <UiTooltipTrigger as-child>
              <UiButton
                variant="outline"
                size="icon-sm"
                :aria-label="a.label"
                @click="ops.align(uid, a.how)"
              >
                <Icon
                  :name="a.icon"
                  class="size-4"
                />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ a.label }}</UiTooltipContent>
          </UiTooltip>
          <span class="mx-1 h-6 w-px bg-border" />
          <UiTooltip
            v-for="n in NUDGE"
            :key="n.key"
          >
            <UiTooltipTrigger as-child>
              <UiButton
                variant="ghost"
                size="icon-sm"
                :aria-label="t('admin.shapes.inspector.nudgeAria', { dir: n.label })"
                @click="ops.nudge(uid, n.dx * step, n.dy * step)"
              >
                <Icon
                  :name="n.icon"
                  class="size-4"
                />
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.shapes.inspector.nudgeHint', { dir: n.label, n: step }) }}</UiTooltipContent>
          </UiTooltip>
          <UiToggleGroup
            type="single"
            :model-value="String(step)"
            class="ml-auto p-0.5"
            :aria-label="t('admin.shapes.inspector.step')"
            @update:model-value="(v) => v && (step = Number(v))"
          >
            <UiToggleGroupItem
              v-for="s in [1, 10]"
              :key="s"
              :value="String(s)"
              class="h-7 px-2 text-xs"
            >
              {{ s }} mm
            </UiToggleGroupItem>
          </UiToggleGroup>
        </div>
        <div
          v-if="model"
          class="flex items-center gap-1"
        >
          <UiButton
            v-for="d in [-90, -5, 5, 90]"
            :key="d"
            variant="ghost"
            size="xs"
            class="tabular-nums"
            :aria-label="t('admin.shapes.inspector.rotateAria', { n: `${d > 0 ? '+' : ''}${d}` })"
            @click="ops.rotate(uid, d)"
          >
            <Icon
              :name="d < 0 ? 'lucide:rotate-ccw' : 'lucide:rotate-cw'"
              class="size-3.5"
            />
            {{ Math.abs(d) }}°
          </UiButton>
          <span class="ml-auto text-xs text-muted-foreground tabular-nums">
            {{ rotation === null ? '' : `${Math.round(rotation)}°` }}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-1.5">
          <UiButton
            variant="outline"
            size="xs"
            @click="ops.lookAt(uid)"
          >
            <Icon
              name="lucide:focus"
              class="size-3.5"
            />
            {{ t('admin.shapes.inspector.lookAt') }}
          </UiButton>
          <UiTooltip>
            <UiTooltipTrigger as-child>
              <UiButton
                variant="outline"
                size="xs"
                @click="ops.saveCamera(uid)"
              >
                <Icon
                  name="lucide:camera"
                  class="size-3.5"
                />
                {{ area.camera ? t('admin.shapes.inspector.updateView') : t('admin.shapes.inspector.saveView') }}
              </UiButton>
            </UiTooltipTrigger>
            <UiTooltipContent>{{ t('admin.shapes.inspector.viewHint') }}</UiTooltipContent>
          </UiTooltip>
          <UiButton
            v-if="area.camera"
            variant="ghost"
            size="xs"
            class="text-muted-foreground"
            @click="ops.clearCamera(uid)"
          >
            {{ t('admin.shapes.inspector.clearView') }}
          </UiButton>
        </div>
      </template>
    </section>

    <!-- Face -->
    <section
      v-if="model"
      class="space-y-2"
    >
      <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {{ t('admin.shapes.inspector.face') }}
      </h3>
      <UiToggleGroup
        type="single"
        :model-value="face"
        class="w-full"
        :disabled="!placed"
        :aria-label="t('admin.shapes.inspector.face')"
        @update:model-value="(v) => v && ops.face(uid, v === 'round' ? { round: true, corner: null } : v === 'rounded' ? { round: false, corner: corner || 5 } : { round: false, corner: null })"
      >
        <UiToggleGroupItem
          value="rect"
          class="flex-1"
        >
          <Icon
            name="lucide:square"
            class="size-3.5"
          />
          {{ t('admin.shapes.inspector.faceRect') }}
        </UiToggleGroupItem>
        <UiToggleGroupItem
          value="rounded"
          class="flex-1"
        >
          <Icon
            name="lucide:squircle"
            class="size-3.5"
          />
          {{ t('admin.shapes.inspector.faceRounded') }}
        </UiToggleGroupItem>
        <UiToggleGroupItem
          value="round"
          class="flex-1"
        >
          <Icon
            name="lucide:circle"
            class="size-3.5"
          />
          {{ t('admin.shapes.inspector.faceRound') }}
        </UiToggleGroupItem>
      </UiToggleGroup>
      <div class="flex items-end gap-3">
        <MmField
          v-if="face === 'rounded'"
          :label="t('admin.shapes.inspector.cornerRadius')"
          class="w-32"
          hide-cm
          :model-value="corner"
          :min="0.5"
          :max="Math.min(area.w, area.h) / 2"
          @update:model-value="(v) => ops.face(uid, { corner: v })"
        />
        <UiLabel class="flex h-9 cursor-pointer items-center gap-2 text-sm font-normal">
          <UiSwitch
            size="sm"
            :model-value="anchor?.dial === true"
            :disabled="!placed"
            @update:model-value="(on: boolean) => ops.face(uid, { dial: on })"
          />
          {{ t('admin.shapes.inspector.dial') }}
        </UiLabel>
      </div>
    </section>

    <!-- Pair -->
    <section class="space-y-2">
      <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {{ t('admin.shapes.inspector.pair') }}
      </h3>
      <div class="flex items-center gap-2">
        <UiSelect
          :model-value="area.pairKey ?? '__none'"
          @update:model-value="pickPartner"
        >
          <UiSelectTrigger
            class="h-9 min-w-0 flex-1 rounded-lg"
            :aria-label="t('admin.shapes.inspector.pair')"
            :disabled="!candidates.length && !area.pairKey"
          >
            <UiSelectValue :placeholder="t('admin.shapes.inspector.noPair')" />
          </UiSelectTrigger>
          <UiSelectContent position="popper">
            <UiSelectItem value="__none">
              {{ t('admin.shapes.inspector.noPair') }}
            </UiSelectItem>
            <UiSelectItem
              v-for="c in candidates"
              :key="c.uid"
              :value="c.key"
            >
              {{ c.name || c.key }}
            </UiSelectItem>
          </UiSelectContent>
        </UiSelect>
        <UiLabel
          v-if="partner"
          class="flex h-9 shrink-0 cursor-pointer items-center gap-2 text-sm font-normal"
        >
          <UiSwitch
            size="sm"
            :model-value="area.pairMirror"
            @update:model-value="(on: boolean) => ops.pair(uid, area.pairKey, on)"
          />
          {{ t('admin.shapes.inspector.mirror') }}
        </UiLabel>
      </div>
      <p
        v-if="partner"
        class="text-[11px] text-muted-foreground"
      >
        {{ t('admin.shapes.inspector.pairHint', { name: partner.name }) }}
      </p>
      <p
        v-if="fieldError('pair')"
        class="text-[11px] text-destructive"
      >
        {{ fieldError('pair') }}
      </p>
    </section>

    <!-- Methods -->
    <section class="space-y-2">
      <div class="flex items-center justify-between gap-2">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {{ t('admin.shapes.inspector.methods') }}
        </h3>
        <UiButton
          v-for="m in missing"
          :key="m"
          variant="outline"
          size="xs"
          :data-add-method="m"
          @click="ops.toggleMethod(uid, m)"
        >
          <Icon
            name="lucide:plus"
            class="size-3.5"
          />
          {{ METHOD_LABELS[m] }}
        </UiButton>
      </div>
      <MethodCard
        v-for="m in area.methods"
        :key="m.method"
        :area="area"
        :method="m"
        :editing="activeMethod === m.method"
        :open="openMethods.includes(m.method)"
        :strip-at="stripAt"
        :playing="playing"
        :removable="area.methods.length > 1"
        :round="face === 'round'"
        :corner-mm="corner"
        @patch="(patch, group) => ops.method(uid, m.method, patch, group)"
        @zone="(rect, phase) => ops.zone(uid, m.method, rect, phase)"
        @toggle-edit="toggleEdit(m.method)"
        @toggle-open="emit('openMethod', m.method)"
        @strip-at="emit('stripAt', $event)"
        @play="emit('play')"
        @remove="ops.toggleMethod(uid, m.method)"
      />
    </section>
  </div>
</template>
