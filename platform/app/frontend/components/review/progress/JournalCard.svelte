<script lang="ts">
  import { tick } from 'svelte'
  import MessageSquarePlus from '@lucide/svelte/icons/message-square-plus'
  import JournalEvidence from '@/components/review/JournalEvidence.svelte'
  import Key from '@/components/review/Key.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import VerdictBadge from '@/components/review/progress/VerdictBadge.svelte'
  import { formatDate, formatDateTime, formatMinutes } from '@/lib/format'
  import type { EarlierNote } from '@/lib/progressReview'
  import type { ReviewJournal } from '@/types'

  // One journal on the journal review page: who wrote it and when, the hours it states and what backs them, whether
  // it's new since the last review, notes earlier reviews left on it, and this review's note on it, which goes to
  // the team with the feedback.
  let {
    journal,
    index,
    fresh,
    focused,
    onFocus,
    note = $bindable(),
    earlier,
    editable,
    maxNote,
  }: {
    journal: ReviewJournal
    index: number
    fresh: boolean
    focused: boolean
    onFocus: () => void
    note: string
    earlier: EarlierNote[]
    editable: boolean
    maxNote: number
  } = $props()

  let root: HTMLElement
  let noteRef: HTMLTextAreaElement | undefined = $state()
  let writing = $state(false)
  const ai = $derived(journal.fraction_ai)
  const open = $derived(writing || !!note)

  export function scrollIntoView() {
    root?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }

  export async function editNote() {
    if (!editable) return
    writing = true
    await tick()
    noteRef?.focus()
  }
</script>

<article
  bind:this={root}
  onfocusin={onFocus}
  class={[
    'scroll-mt-14 overflow-hidden rounded-lg border bg-card transition-[box-shadow,border-color] duration-200',
    focused
      ? 'border-ring shadow-[0_0_0_3px_color-mix(in_oklch,var(--ring)_25%,transparent)]'
      : 'border-border',
  ]}
>
  <header
    class="flex flex-wrap items-center gap-x-2 gap-y-1 border-b border-border px-3 py-2 text-xs text-muted-foreground"
  >
    <span class="grid size-5 place-items-center rounded-full bg-muted font-mono text-[10px] font-semibold"
      >{index + 1}</span
    >
    <PersonChip person={journal.author} class="text-foreground" />
    <span title={formatDateTime(journal.created_at)}
      >{new Date(journal.created_at).toLocaleDateString(undefined, {
        month: 'short',
        day: 'numeric',
        weekday: 'short',
      })}</span
    >
    {#if journal.duration_minutes}
      <span class="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">{journal.duration_text}</span>
    {:else}
      <span class="rounded bg-muted px-1.5 py-0.5">No hours yet</span>
    {/if}
    {#if fresh}
      <span class="rounded bg-sky-100 px-1.5 py-0.5 text-sky-700 dark:bg-sky-950 dark:text-sky-300"
        >New since last review</span
      >
    {/if}
    {#if journal.source === 'transfer'}
      <span
        class="rounded bg-violet-100 px-1.5 py-0.5 text-violet-700 dark:bg-violet-950 dark:text-violet-300"
        title="Logged in another program, so its hours don't count toward journal review"
        >Transferred, not counted</span
      >
    {:else if journal.hours_self_claimed}
      <span
        class="rounded bg-amber-100 px-1.5 py-0.5 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
        title="Logged more than the timer and timelapses show"
      >
        Self-claimed{journal.tracked_minutes != null
          ? `, ${formatMinutes(journal.tracked_minutes)} tracked`
          : ''}
      </span>
    {:else if journal.tracked_minutes != null}
      <span>{formatMinutes(journal.tracked_minutes)} tracked</span>
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
    <JournalEvidence {journal} />
  </div>

  {#if earlier.length || editable}
    <footer class="space-y-2 border-t border-border bg-muted/30 px-3 py-2.5">
      {#each earlier as past (past.id)}
        <div class="text-xs">
          <p class="flex flex-wrap items-center gap-1.5 text-muted-foreground">
            <VerdictBadge verdict={past.verdict} />
            Note from {past.reviewer?.name ?? 'a reviewer'}, {formatDate(past.at)}
          </p>
          <p class="mt-1 border-l-2 border-border pl-2 text-[13px] whitespace-pre-wrap">{past.note}</p>
        </div>
      {/each}

      {#if editable}
        {#if open}
          <label class="block space-y-1">
            <span class="text-xs text-muted-foreground"
              >Your note on this journal <span class="text-muted-foreground/60">(sent to the team)</span
              ></span
            >
            <textarea
              bind:this={noteRef}
              bind:value={note}
              onblur={() => (writing = false)}
              maxlength={maxNote}
              rows="2"
              placeholder="What about this journal in particular: what's missing, what was great..."
              class="block w-full resize-y rounded-md border border-input bg-background px-2.5 py-1.5 text-sm outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
            ></textarea>
          </label>
        {:else}
          <button
            type="button"
            onclick={editNote}
            class="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground"
          >
            <MessageSquarePlus class="size-3.5" /> Add a note on this journal <Key>M</Key>
          </button>
        {/if}
      {/if}
    </footer>
  {/if}
</article>
