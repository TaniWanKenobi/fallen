<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import Segmented from '@/components/review/Segmented.svelte'
  import NumberInput from '@/components/NumberInput.svelte'
  import Morph from '@/components/admin/Morph.svelte'
  import { pop } from '@/components/review/motion'
  import {
    itemFunded,
    itemRequested,
    type ItemVerdict,
    type ReviewDraft,
    type ReviewPage,
  } from '@/lib/review.svelte'
  import { fromCents, money, toCents } from '@/lib/submission'

  // The bill of materials line by line: approve it, lower it, or cut it, with a reason from the fixed lists. The
  // funding is the sum of what's let through.
  let {
    page,
    draft = $bindable(),
    readonly,
  }: { page: ReviewPage; draft: ReviewDraft; readonly: boolean } = $props()

  let showCsv = $state(false)
  const items = $derived(page.submission.bom_items)
  const requested = $derived(items.reduce((sum, item) => sum + itemRequested(item), 0))
  const funded = $derived(items.reduce((sum, item) => sum + (itemFunded(item, draft.bom[item.id]) ?? 0), 0))
  const undecided = $derived(items.filter((item) => !draft.bom[item.id]?.verdict).length)

  function set(id: string, verdict: ItemVerdict) {
    if (readonly) return
    const call = draft.bom[id]
    const item = items.find((i) => i.id === id)!
    draft.bom[id] = {
      verdict,
      reason: verdict === 'approved' ? null : call?.verdict === verdict ? call.reason : null,
      cents: verdict === 'adjusted' ? (call?.cents ?? Math.round(itemRequested(item) / 2)) : null,
    }
  }

  function approveRest() {
    for (const item of items) if (!draft.bom[item.id]?.verdict) set(item.id, 'approved')
  }

  const host = (link: string | null) => {
    try {
      return link ? new URL(link).hostname.replace(/^www\./, '') : null
    } catch {
      return null
    }
  }
  const safe = (link: string | null) => (link && /^https?:\/\//i.test(link) ? link : null)
</script>

<div class="flex flex-col">
  <div
    class="sticky top-0 z-10 flex flex-wrap items-center gap-3 border-b border-border bg-background/95 px-4 py-2 backdrop-blur"
  >
    <span class="text-sm"><span class="font-semibold">{items.length}</span> lines</span>
    <span class="font-mono text-sm"
      ><Morph text={money(requested)} /> <span class="text-muted-foreground">asked →</span>
      <span class="font-semibold"><Morph text={money(funded)} /></span></span
    >
    {#if !readonly && undecided}
      <span
        class="rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800 dark:bg-amber-950 dark:text-amber-300"
        >{undecided} to decide</span
      >
    {/if}
    <div class="ml-auto flex gap-1">
      {#if page.repo?.bom_csv}
        <Button size="sm" variant="ghost" onclick={() => (showCsv = !showCsv)}
          >{showCsv ? 'Hide' : 'Show'} repo’s {page.repo.bom_path}</Button
        >
      {/if}
      {#if !readonly && undecided}
        <Button size="sm" variant="outline" onclick={approveRest}>Approve the other {undecided}</Button>
      {/if}
    </div>
  </div>

  {#if showCsv && page.repo?.bom_csv}
    <pre
      class="mx-4 mt-3 max-h-64 overflow-auto rounded-md border border-border bg-muted/50 p-3 font-mono text-[11px]">{page
        .repo.bom_csv}</pre>
  {/if}

  <div class="overflow-x-auto p-4">
    <table class="w-full min-w-[820px] text-sm">
      <thead class="text-left text-xs text-muted-foreground">
        <tr class="border-b border-border">
          <th class="py-2 pr-2 font-medium">Part</th>
          <th class="px-2 py-2 text-right font-medium">Qty</th>
          <th class="px-2 py-2 text-right font-medium">Each</th>
          <th class="px-2 py-2 text-right font-medium">Asked</th>
          <th class="px-2 py-2 font-medium">Decision</th>
          <th class="py-2 pl-2 text-right font-medium">Funded</th>
        </tr>
      </thead>
      <tbody>
        {#each items as item (item.id)}
          {@const call = draft.bom[item.id]}
          {@const out = itemFunded(item, call)}
          <tr class="border-b border-border align-top last:border-0">
            <td class="py-2 pr-2">
              <div class="flex items-center gap-1.5">
                {#if item.kind !== 'part'}<span class="rounded bg-muted px-1 text-[10px] uppercase"
                    >{item.kind}</span
                  >{/if}
                <span class="font-medium">{item.name}</span>
                {#if item.owned}<span
                    class="rounded bg-zinc-100 px-1 text-[10px] text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300"
                    >owned</span
                  >{/if}
              </div>
              {#if item.purpose}<p class="text-xs text-muted-foreground">{item.purpose}</p>{/if}
              <p class="text-xs">
                {#if safe(item.link)}
                  <a
                    href={safe(item.link)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-blue-600 hover:underline dark:text-blue-400">{host(item.link)} ↗</a
                  >
                {:else if item.kind === 'part' && !item.owned}
                  <span class="text-red-600">no link</span>
                {/if}
                {#if item.vendor}<span class="text-muted-foreground"> · {item.vendor}</span>{/if}
              </p>
            </td>
            <td class="px-2 py-2 text-right font-mono tabular-nums">{item.quantity}</td>
            <td class="px-2 py-2 text-right font-mono text-muted-foreground tabular-nums"
              >{item.unit_cents != null ? money(item.unit_cents) : ''}</td
            >
            <td
              class={[
                'px-2 py-2 text-right font-mono tabular-nums',
                item.owned && 'text-muted-foreground line-through',
              ]}>{money(item.total_cents)}</td
            >
            <td class="px-2 py-2">
              <div class="flex flex-wrap items-center gap-1.5">
                <Segmented
                  label="Decision on {item.name}"
                  value={call?.verdict}
                  disabled={readonly}
                  onChange={(value) => set(item.id, value)}
                  options={[
                    { value: 'approved', label: 'Approve', tint: 'green' },
                    { value: 'adjusted', label: 'Lower', tint: 'amber' },
                    { value: 'cut', label: 'Cut', tint: 'red' },
                  ]}
                />
                {#if call?.verdict === 'adjusted'}
                  <span transition:pop class="inline-flex items-center gap-1 text-xs">
                    $<NumberInput
                      value={fromCents(call.cents)}
                      onchange={(value) => (draft.bom[item.id] = { ...call, cents: toCents(value) })}
                      max={itemRequested(item) / 100}
                      separators
                      disabled={readonly}
                      label="Lowered amount"
                      class="h-7 w-20 rounded-md border border-input bg-background px-1.5 font-mono"
                    />
                  </span>
                {/if}
                {#if call?.verdict === 'adjusted' || call?.verdict === 'cut'}
                  <select
                    transition:pop
                    bind:value={draft.bom[item.id].reason}
                    disabled={readonly}
                    aria-label="Why"
                    class={[
                      'h-7 max-w-56 rounded-md border bg-background py-0 pr-7 pl-1.5 text-xs',
                      !call.reason ? 'border-red-400 text-muted-foreground' : 'border-input',
                    ]}
                  >
                    <option value={null}>Why?</option>
                    {#each call.verdict === 'cut' ? page.options.cut_reasons : page.options.adjust_reasons as reason (reason)}
                      <option value={reason}>{reason}</option>
                    {/each}
                  </select>
                {/if}
              </div>
            </td>
            <td class="py-2 pl-2 text-right font-mono font-semibold tabular-nums"
              >{#if out != null}<Morph text={money(out)} />{/if}</td
            >
          </tr>
        {/each}
      </tbody>
      <tfoot>
        <tr class="border-t-2 border-border">
          <td colspan="3" class="py-2 text-xs text-muted-foreground"
            >Owned parts are listed at their price but ask for nothing.</td
          >
          <td class="px-2 py-2 text-right font-mono tabular-nums"><Morph text={money(requested)} /></td>
          <td></td>
          <td class="py-2 pl-2 text-right font-mono text-base font-semibold tabular-nums"
            ><Morph text={money(funded)} /></td
          >
        </tr>
      </tfoot>
    </table>
  </div>
</div>
