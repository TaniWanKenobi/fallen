<script lang="ts">
  import type { MadeWith } from '@/lib/submission'
  import { docs } from '@/routes'

  let {
    ready = $bindable(),
    madeWith = $bindable(),
    resubmission,
  }: { ready: boolean[]; madeWith: MadeWith[]; resubmission: boolean } = $props()

  const PROMISES = [
    'My design is finished, and I’ve done my best to make sure it’ll work.',
    'My README says what it is, why I made it, and shows the 3D model, PCB and schematic.',
    'My repository has everything someone else would need to build it.',
    'It’s my own design. If I followed a guide, I changed it and made it mine.',
  ]
  const PARTS: { key: MadeWith; label: string; hint: string }[] = [
    { key: 'pcb', label: 'A custom PCB', hint: 'We’ll look for its source files and gerbers.' },
    { key: 'cad', label: '3D-printed or CAD parts', hint: 'We’ll look for STEP files and the CAD source.' },
    { key: 'firmware', label: 'Firmware', hint: 'We’ll look for its code.' },
  ]

  function toggle(key: MadeWith) {
    madeWith = madeWith.includes(key) ? madeWith.filter((k) => k !== key) : [...madeWith, key]
  }
</script>

<p class="text-center text-sm text-ink-soft">
  {#if resubmission}
    Welcome back! A reviewer will look at it again, along with what they said last time.
  {:else}
    A reviewer will read your journals and repo, then fund the parts you need to build it.
  {/if}
  Most send-backs are things you can fix in five minutes, so have a look at the
  <a
    href={docs.show({ page: 'submitting' }).url}
    target="_blank"
    class="font-semibold text-ink underline underline-offset-2">submission guidelines</a
  > first.
</p>

<fieldset class="mt-5">
  <legend class="mb-2 text-sm font-semibold text-ink">Is all of this true?</legend>
  <ul class="space-y-2">
    {#each PROMISES as promise, i (i)}
      <li>
        <label
          class={[
            'flex cursor-pointer items-start gap-3 rounded-xl border-2 px-3.5 py-3 text-sm transition-colors',
            ready[i] ? 'border-[#1cb0f6] bg-[#e8f7ff]' : 'border-paper-rim bg-[#fffdf8] hover:border-ink/25',
          ]}
        >
          <input
            type="checkbox"
            bind:checked={ready[i]}
            class="mt-0.5 size-4.5 shrink-0 rounded border-ink/30 text-[#1cb0f6] focus:ring-[#1cb0f6]"
          />
          <span class="text-ink">{promise}</span>
        </label>
      </li>
    {/each}
  </ul>
</fieldset>

<fieldset class="mt-6">
  <legend class="mb-2 text-sm font-semibold text-ink">What does your project have?</legend>
  <div class="grid gap-2 sm:grid-cols-3">
    {#each PARTS as part (part.key)}
      {@const on = madeWith.includes(part.key)}
      <button
        type="button"
        aria-pressed={on}
        onclick={() => toggle(part.key)}
        class={[
          'rounded-xl border-2 px-3 py-2.5 text-left transition-colors',
          on ? 'border-[#1cb0f6] bg-[#e8f7ff]' : 'border-paper-rim bg-[#fffdf8] hover:border-ink/25',
        ]}
      >
        <span class="block text-sm font-semibold text-ink">{part.label}</span>
        <span class="mt-0.5 block text-xs text-ink-soft">{part.hint}</span>
      </button>
    {/each}
  </div>
  <p class="mt-2 text-xs text-ink-soft">Pick all that apply. None of them? That’s fine too.</p>
</fieldset>
