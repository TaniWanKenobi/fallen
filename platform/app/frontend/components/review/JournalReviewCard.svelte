<script lang="ts">
  import { tick } from 'svelte'
  import Markdown from '@/components/Markdown.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import { formatDateTime, formatMinutes } from '@/lib/format'
  import { journalDeflated, parseMinutes, type JournalCall } from '@/lib/review.svelte'
  import type { ReviewJournal } from '@/types'

  // One journal and the call on how much of its time counts: all of it, some of it (with a reason from the fixed
  // list, so reviews stay comparable), or none.
  let {
    journal,
    call = $bindable(),
    reasons,
    index,
    focused,
    readonly,
    onFocus,
  }: {
    journal: ReviewJournal
    call: JournalCall
    reasons: string[]
    index: number
    focused: boolean
    readonly: boolean
    onFocus: () => void
  } = $props()

  const logged = $derived(journal.duration_minutes ?? 0)
  const mode = $derived(
    call.minutes == null ? null : call.minutes >= logged ? 'full' : call.minutes === 0 ? 'none' : 'reduced',
  )
  const decided = $derived(call.minutes != null && !call.carried)
  // svelte-ignore state_referenced_locally
  let typed = $state(
    call.minutes != null && call.minutes < logged && call.minutes > 0 ? formatMinutes(call.minutes) : '',
  )
  let minutesInput: HTMLInputElement | undefined = $state()
  let root: HTMLElement

  const tracked = $derived(journal.tracked_minutes)
  const ai = $derived(journal.fraction_ai)

  export async function choose(next: 'full' | 'reduced' | 'none') {
    if (readonly) return
    if (next === 'full') call = { ...call, minutes: logged, reason: null, carried: false }
    else if (next === 'none') call = { ...call, minutes: 0, reason: call.reason, carried: false }
    else {
      const guess =
        call.minutes != null && call.minutes > 0 && call.minutes < logged
          ? call.minutes
          : Math.round(logged / 2)
      typed = formatMinutes(guess)
      call = { ...call, minutes: guess, carried: false }
      await tick()
      minutesInput?.select()
    }
  }

  export function scrollIntoView() {
    root?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }

  function setTyped(value: string) {
    typed = value
    const minutes = parseMinutes(value)
    if (minutes != null) call = { ...call, minutes: Math.min(Math.max(minutes, 0), logged), carried: false }
  }
</script>

<article
  bind:this={root}
  id="review-{journal.id}"
  onfocusin={onFocus}
  class={[
    'scroll-mt-4 rounded-md border border-l-4 bg-background transition-shadow',
    focused ? 'border-border shadow-[0_0_0_2px_var(--color-ring)]' : 'border-border',
    !decided && 'border-l-zinc-300 dark:border-l-zinc-700',
    decided && mode === 'full' && 'border-l-emerald-500',
    decided && mode === 'reduced' && 'border-l-amber-500',
    decided && mode === 'none' && 'border-l-red-500',
  ]}
>
  <header
    class="flex flex-wrap items-center gap-x-2 gap-y-1 border-b border-border px-3 py-2 text-xs text-muted-foreground"
  >
    <span class="font-mono text-[10px] text-muted-foreground/70">#{index + 1}</span>
    <PersonChip person={journal.author} class="text-foreground" />
    <span title={formatDateTime(journal.created_at)}
      >{new Date(journal.created_at).toLocaleDateString(undefined, {
        month: 'short',
        day: 'numeric',
        weekday: 'short',
      })}</span
    >
    <span class="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">{journal.duration_text}</span>
    {#if journal.source === 'transfer'}
      <span
        class="rounded bg-violet-100 px-1.5 py-0.5 text-violet-700 dark:bg-violet-950 dark:text-violet-300"
        >Transferred</span
      >
    {:else if journal.hours_self_claimed}
      <span
        class="rounded bg-amber-100 px-1.5 py-0.5 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
        title="Logged more than the timer and timelapses show"
      >
        Self-claimed{tracked != null ? `, ${formatMinutes(tracked)} tracked` : ''}
      </span>
    {:else if tracked != null}
      <span>{formatMinutes(tracked)} tracked</span>
    {/if}
    {#if ai != null && ai >= 0.2}
      <span
        class={[
          'rounded px-1.5 py-0.5',
          ai >= 0.5
            ? 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300'
            : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300',
        ]}
      >
        {Math.round(ai * 100)}% AI
      </span>
    {/if}
    {#if journal.slack_url}
      <a
        href={journal.slack_url}
        target="_blank"
        rel="noopener"
        class="ml-auto hover:text-foreground hover:underline">Slack ↗</a
      >
    {/if}
  </header>

  <div class="space-y-3 px-3 py-3">
    <Markdown source={journal.body} photos={journal.images.map((i) => i.id)} admin />

    {#if journal.images.length}
      <div class="flex flex-wrap gap-1.5">
        {#each journal.images as image (image.id)}
          <a
            href={image.url}
            target="_blank"
            rel="noopener"
            class="block size-20 overflow-hidden rounded border border-border bg-muted"
          >
            <img src={image.url} alt={image.filename} loading="lazy" class="h-full w-full object-cover" />
          </a>
        {/each}
      </div>
    {/if}

    {#if journal.timelapses.length}
      <div class="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
        {#each journal.timelapses as t (t.id)}
          <a
            href={t.url}
            target="_blank"
            rel="noopener"
            class="group flex items-center gap-2 rounded border border-border p-1.5 text-xs hover:bg-muted"
          >
            {#if t.thumbnail_url}
              <img
                src={t.thumbnail_url}
                alt=""
                loading="lazy"
                class="h-10 w-16 shrink-0 rounded-sm bg-muted object-cover"
              />
            {/if}
            <span class="min-w-0">
              <span
                class="block rounded bg-purple-100 px-1 text-[10px] font-medium text-purple-700 dark:bg-purple-950 dark:text-purple-300"
                >Lapse</span
              >
              <span class="block truncate">{t.name ?? 'Timelapse'}</span>
              <span class="text-muted-foreground">{formatMinutes(t.duration_minutes)} ↗</span>
            </span>
          </a>
        {/each}
      </div>
    {/if}
  </div>

  <footer class="space-y-2 border-t border-border bg-muted/30 px-3 py-2.5">
    {#if call.carried}
      <p class="text-xs text-sky-700 dark:text-sky-300">
        Last review counted {formatMinutes(call.minutes ?? 0)}{call.reason
          ? ` (${call.reason.toLowerCase()})`
          : ''}. Confirm or change it.
      </p>
    {/if}
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-xs text-muted-foreground">Counts</span>
      <div
        class="inline-flex overflow-hidden rounded-md border border-border text-xs"
        role="radiogroup"
        aria-label="How much of this journal counts"
      >
        {#each [['full', `All ${journal.duration_text}`, 'A'], ['reduced', 'Less', 'R'], ['none', 'None', 'X']] as [value, label, key] (value)}
          {@const on = mode === value && (decided || call.carried)}
          <button
            type="button"
            role="radio"
            aria-checked={on}
            disabled={readonly}
            onclick={() => choose(value as 'full' | 'reduced' | 'none')}
            class={[
              'border-r border-border px-2.5 py-1 last:border-r-0 disabled:cursor-default',
              on && value === 'full' && 'bg-emerald-600 text-white',
              on && value === 'reduced' && 'bg-amber-500 text-white',
              on && value === 'none' && 'bg-red-600 text-white',
              !on && 'bg-background hover:bg-muted',
              call.carried && on && 'opacity-60',
            ]}
            title="{label} ({key})">{label}</button
          >
        {/each}
      </div>
      {#if mode === 'reduced'}
        <input
          bind:this={minutesInput}
          value={typed}
          oninput={(e) => setTyped(e.currentTarget.value)}
          disabled={readonly}
          aria-label="Time that counts"
          placeholder="1h 30m"
          class="h-7 w-24 rounded-md border border-input bg-background px-2 font-mono text-xs"
        />
        <span class="text-xs text-muted-foreground">of {journal.duration_text}</span>
      {/if}
      {#if mode === 'reduced' || mode === 'none'}
        <select
          bind:value={call.reason}
          disabled={readonly}
          aria-label="Why"
          class={[
            'h-7 rounded-md border bg-background py-0 pr-7 pl-1.5 text-xs',
            !call.reason ? 'border-red-400 text-muted-foreground' : 'border-input',
          ]}
        >
          <option value={null}>Why?</option>
          {#each reasons as reason (reason)}<option value={reason}>{reason}</option>{/each}
        </select>
      {/if}
    </div>
    {#if journalDeflated(journal, call) || call.note}
      <input
        bind:value={call.note}
        disabled={readonly}
        maxlength="1000"
        placeholder="Note for other reviewers (optional)"
        class="h-7 w-full rounded-md border border-input bg-background px-2 text-xs"
      />
    {/if}
  </footer>
</article>
